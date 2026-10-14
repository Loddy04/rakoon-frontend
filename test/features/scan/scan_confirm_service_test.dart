import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

ScanResultItem _item() => ScanResultItem(
      namaProduk: 'Beras Premium 5kg',
      harga: 72000.0,
      ukuran: 5.0,
      satuan: 'kg',
      kategori: 'Makanan Pokok',
      confidence: 'tinggi',
      needsVerification: false,
    );

void main() {
  setUp(() {
    AuthService.mockSession = Session(
      accessToken: 'test-token',
      tokenType: 'bearer',
      user: User(
        id: 'user-uuid-123',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  });

  tearDown(() => AuthService.mockSession = null);

  Future<ConfirmScanResult> confirmWith(Map<String, dynamic> body) {
    final client = MockClient((request) async => http.Response(jsonEncode(body), 201));
    return ScanService.confirmScan(
      storeId: 'store-1',
      userId: 'user-uuid-123',
      items: [_item()],
      baseUrl: 'http://localhost:8000',
      client: client,
    );
  }

  group('ConfirmScanResult.fromJson', () {
    test('items_pending_review defaults to 0 when the backend does not send it', () {
      final result = ConfirmScanResult.fromJson({
        'items_saved': 3,
        'products_created': 1,
        'message': 'ok',
      });
      expect(result.itemsSaved, 3);
      expect(result.productsCreated, 1);
      expect(result.itemsPendingReview, 0);
      expect(result.message, 'ok');
    });

    test('reads items_pending_review when present', () {
      final result = ConfirmScanResult.fromJson({
        'items_saved': 3,
        'products_created': 0,
        'items_pending_review': 2,
        'message': 'ok',
      });
      expect(result.itemsPendingReview, 2);
    });

    test('tolerates null or missing fields without throwing', () {
      final result = ConfirmScanResult.fromJson({'items_pending_review': null});
      expect(result.itemsSaved, 0);
      expect(result.productsCreated, 0);
      expect(result.itemsPendingReview, 0);
      expect(result.message, isNull);
    });
  });

  group('ScanService.confirmScan response model', () {
    test('returns a model with itemsPendingReview 0 for an old-style response', () async {
      final result = await confirmWith({'items_saved': 1, 'products_created': 0, 'message': 'Berhasil'});
      expect(result.itemsSaved, 1);
      expect(result.itemsPendingReview, 0);
    });

    test('returns itemsPendingReview from the backend response', () async {
      final result = await confirmWith({
        'items_saved': 2,
        'products_created': 1,
        'items_pending_review': 1,
        'message': 'Berhasil',
      });
      expect(result.itemsSaved, 2);
      expect(result.productsCreated, 1);
      expect(result.itemsPendingReview, 1);
    });
  });
}
