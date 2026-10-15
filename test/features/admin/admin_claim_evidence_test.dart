import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/admin/presentation/pages/admin_store_claims_page.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _docPath = 'documents/0123456789abcdef0123456789abcdef0123456789abcdef.pdf';
const _photoPath = 'photos/0123456789abcdef0123456789abcdef0123456789abcdef.jpg';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://mock.supabase.co',
        anonKey: 'mock-anon-key', // ignore: deprecated_member_use
        authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage()),
      );
    } catch (_) {}
  });

  setUp(() {
    AuthService.mockSession = Session(
      accessToken: 'mock-admin-token',
      tokenType: 'bearer',
      user: const User(
        id: 'admin-1',
        email: 'admin@rakoon.app',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      ),
    );
    AuthService.mockIsAdmin = true;
  });
  tearDown(() {
    AuthService.mockSession = null;
    AuthService.mockIsAdmin = null;
  });

  Map<String, dynamic> claim({String doc = _docPath, String? photo = _photoPath}) => {
        'user_id': 'user-1',
        'store_id': 'store-1',
        'store_nama': 'Toko Berkah',
        'status': 'pending',
        'created_at': '2026-10-10T10:00:00Z',
        'submission_id': 'claim-1',
        'claim_type': 'claim',
        'document_url': doc,
        'store_photo_url': photo,
      };

  Map<String, dynamic> newStore() => {
        'user_id': 'user-2',
        'store_id': '',
        'store_nama': 'Warung Baru',
        'status': 'pending',
        'created_at': '2026-10-11T10:00:00Z',
        'submission_id': 'sub-1',
        'claim_type': 'new_store',
        'document_url': _docPath,
        'latitude': 3.5952,
        'longitude': 98.6722,
      };

  late List<Uri> evidenceRequests;
  late List<Uri> launched;
  int evidenceStatus = 200;
  bool evidenceBodyIsGarbage = false;

  Future<void> openPage(WidgetTester tester, List<Map<String, dynamic>> claims) async {
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/ads/pending-claims')) {
        return http.Response(jsonEncode(claims), 200, headers: {'content-type': 'application/json'});
      }
      if (path.endsWith('/ads/claim-evidence-url')) {
        evidenceRequests.add(request.url);
        if (evidenceBodyIsGarbage) return http.Response('<html>FormatException at http://db.internal</html>', 200);
        if (evidenceStatus != 200) {
          return http.Response(jsonEncode({'detail': 'psycopg2 secret'}), evidenceStatus);
        }
        return http.Response(jsonEncode({'url': 'https://mock.supabase.co/sign?token=t', 'expires_in': 300}), 200);
      }
      return http.Response('Not Found', 404);
    });
    await tester.pumpWidget(MaterialApp(
      home: AdminStoreClaimsPage(
        baseUrl: 'https://api.test',
        httpClient: client,
        evidenceLauncher: (uri, {mode = LaunchMode.externalApplication}) async {
          launched.add(uri);
          return true;
        },
      ),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() {
    evidenceRequests = [];
    launched = [];
    evidenceStatus = 200;
    evidenceBodyIsGarbage = false;
  });

  testWidgets('document and photo each get a "Lihat bukti" button for claims and submissions', (tester) async {
    await openPage(tester, [claim(), newStore()]);
    expect(find.byKey(const Key('view_document_claim-1')), findsOneWidget);
    expect(find.byKey(const Key('view_photo_claim-1')), findsOneWidget);
    expect(find.byKey(const Key('view_document_sub-1')), findsOneWidget);
    expect(find.byKey(const Key('view_photo_sub-1')), findsNothing); // no photo on that row
    expect(find.text('Lihat bukti'), findsWidgets);
  });

  testWidgets('tapping asks the backend for a signed URL and opens it externally', (tester) async {
    await openPage(tester, [claim()]);
    await tester.tap(find.byKey(const Key('view_document_claim-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('view_photo_claim-1')));
    await tester.pumpAndSettle();

    expect(evidenceRequests.map((u) => u.queryParameters['path']).toList(), [_docPath, _photoPath]);
    expect(launched.map((u) => u.toString()).toSet(), {'https://mock.supabase.co/sign?token=t'});
  });

  testWidgets('a backend failure shows a friendly message without the raw body and opens nothing', (tester) async {
    for (final status in [403, 503]) {
      evidenceStatus = status;
      await openPage(tester, [claim()]);
      await tester.tap(find.byKey(const Key('view_document_claim-1')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Gagal membuka bukti'), findsOneWidget, reason: '$status');
      expect(find.textContaining('psycopg2'), findsNothing, reason: '$status');
      expect(launched, isEmpty);
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
    }
  });

  testWidgets('evidence from the old system (not an object path) is not sent to the backend', (tester) async {
    await openPage(tester, [claim(doc: '/ads/documents/doc_old.pdf', photo: null)]);
    await tester.tap(find.byKey(const Key('view_document_claim-1')));
    await tester.pumpAndSettle();

    expect(evidenceRequests, isEmpty);
    expect(find.textContaining('tidak dapat dibuka'), findsOneWidget);
  });

  testWidgets('an unexpected exception shows the generic message, never the exception text', (tester) async {
    evidenceBodyIsGarbage = true;
    await openPage(tester, [claim()]);
    await tester.tap(find.byKey(const Key('view_document_claim-1')));
    await tester.pumpAndSettle();

    expect(find.text('Gagal membuka bukti: Terjadi kesalahan, coba lagi'), findsOneWidget);
    expect(find.textContaining('FormatException'), findsNothing);
    expect(find.textContaining('http://'), findsNothing);
    expect(launched, isEmpty);
  });
}
