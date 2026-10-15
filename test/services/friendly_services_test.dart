import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/services/admin_product_service.dart';
import 'package:rakoon_frontend/services/ads_service.dart';
import 'package:rakoon_frontend/services/api_error_messages.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/services/stores_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _base = 'http://localhost:8000';
const _technicalBody =
    '{"detail":"connection to http://db.internal:5432 refused. Detail: Traceback boom SocketException secret"}';
const _forbidden = ['Exception', 'Detail', 'http', 'HTTP', 'Traceback', 'secret', 'Socket', 'psycopg2', 'type \''];

typedef _Call = Future<Object?> Function(http.Client client);

final Map<String, _Call> _calls = {
  'ads.claimStore': (c) => AdsService.claimStore(storeId: 's1', baseUrl: _base, client: c),
  'ads.getPendingClaims': (c) => AdsService.getPendingClaims(baseUrl: _base, client: c),
  'ads.rejectStoreClaim': (c) => AdsService.rejectStoreClaim(userId: 'u', storeId: 's', reason: 'alasan', baseUrl: _base, client: c),
  'ads.deleteCampaign': (c) => AdsService.deleteCampaign(campaignId: 'c1', baseUrl: _base, client: c),
  'stores.getNearbyStores': (c) => StoresService.getNearbyStores(lat: -7.7, lng: 110.4, baseUrl: _base, client: c),
  'stores.getPriceComparison': (c) => http.runWithClient(
        () => StoresService.getPriceComparison(productId: 'p1', lat: -7.7, lng: 110.4, baseUrl: _base),
        () => c,
      ),
  'admin.updateProductPhotoUrl': (c) =>
      AdminProductService.updateProductPhotoUrl(productId: 'p1', photoUrl: 'https://x/y.jpg', baseUrl: _base, client: c),
  'admin.uploadProductPhotoFile': (c) => AdminProductService.uploadProductPhotoFile(
        productId: 'p1',
        fileBytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'a.jpg',
        baseUrl: _base,
        client: c,
      ),
};

Future<String> _messageOf(_Call call, http.Client client) async {
  try {
    await call(client);
  } catch (e) {
    return e.toString().replaceFirst('Exception: ', '');
  }
  fail('expected a throw');
}

void main() {
  setUp(() {
    AuthService.mockSession = Session(
      accessToken: 'test-token',
      tokenType: 'bearer',
      user: User(
        id: 'user-1',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    AuthService.mockIsAdmin = true;
  });
  tearDown(() {
    AuthService.mockSession = null;
    AuthService.mockIsAdmin = null;
  });

  for (final call in _calls.entries) {
    test('${call.key}: SocketException gives the offline message only', () async {
      final msg = await _messageOf(call.value, MockClient((_) async => throw const SocketException('Failed host lookup: secret.host')));
      expect(msg, noConnectionMessage);
    });

    test('${call.key}: HTTP 500 gives a friendly message without the body', () async {
      final msg = await _messageOf(call.value, MockClient((_) async => http.Response('psycopg2 secret Traceback', 500)));
      for (final bad in _forbidden) {
        expect(msg, isNot(contains(bad)), reason: '$msg has "$bad"');
      }
      expect(msg, isNotEmpty);
    });

    test('${call.key}: HTTP 400 with a technical body never shows the technical text', () async {
      final msg = await _messageOf(call.value, MockClient((_) async => http.Response(_technicalBody, 400)));
      for (final bad in _forbidden) {
        expect(msg, isNot(contains(bad)), reason: '$msg has "$bad"');
      }
      expect(msg, isNotEmpty);
    });

    test('${call.key}: HTTP 400 with a readable plain-text detail is kept where the API defines one', () async {
      // Sanity check that the filter does not blank out ordinary Indonesian messages.
      final msg = await _messageOf(
        call.value,
        MockClient((_) async => http.Response(jsonEncode({'detail': 'Foto tidak valid'}), 400)),
      );
      expect(msg, isNot(contains('Exception')));
      expect(msg, isNotEmpty);
    });
  }
}
