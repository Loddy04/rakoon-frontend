// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/admin/presentation/pages/admin_store_claims_page.dart';
import 'package:rakoon_frontend/features/merchant/presentation/pages/merchant_dashboard_page.dart';
import 'package:rakoon_frontend/features/profile/presentation/pages/profile_page.dart';
import 'package:rakoon_frontend/services/ads_service.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://mock.supabase.co',
        anonKey: 'mock-anon-key', // ignore: deprecated_member_use
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
        ),
      );
    } catch (_) {
      // Already initialized
    }
  });

  setUp(() {
    AuthService.mockSession = Session(
      accessToken: 'mock-admin-token',
      tokenType: 'bearer',
      user: const User(
        id: 'mock-admin-user',
        email: 'admin@rakoon.app',
        appMetadata: {'role': 'admin'},
        userMetadata: {'role': 'admin', 'name': 'Super Admin'},
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

  final mockPendingClaims = [
    {
      'user_id': 'user-123',
      'store_id': 'store-456',
      'store_nama': 'Toko Berkah Mandiri',
      'store_alamat': 'Jl. Kaliurang KM 5 No. 10, Sleman',
      'user_nama': 'Pak Bambang',
      'user_email': 'bambang@gmail.com',
      'status': 'pending',
      'created_at': '2026-10-10T10:00:00Z',
    },
    {
      'user_id': 'user-789',
      'store_id': 'store-101',
      'store_nama': 'Warung Bu Siti',
      'store_alamat': 'Jl. Gejayan No. 22, Sleman',
      'user_nama': 'Bu Siti',
      'user_email': 'siti@gmail.com',
      'status': 'pending',
      'created_at': '2026-10-10T11:00:00Z',
    },
  ];

  http.Client createMockClient({
    List<Map<String, dynamic>>? claims,
    bool shouldFailFetch = false,
    bool Function()? shouldFailFetchFn,
    bool shouldFailAction = false,
  }) {
    var currentClaims = List<Map<String, dynamic>>.from(claims ?? mockPendingClaims);

    return MockClient((request) async {
      final path = request.url.path;

      if (path.endsWith('/ads/pending-claims') && request.method == 'GET') {
        final fail = shouldFailFetchFn != null ? shouldFailFetchFn() : shouldFailFetch;
        if (fail) {
          return http.Response(
            jsonEncode({'detail': 'Gagal mengambil daftar klaim pending.'}),
            500,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode(currentClaims),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/ads/verify-claim') && request.method == 'POST') {
        if (shouldFailAction) {
          return http.Response(jsonEncode({'detail': 'Aksi verifikasi gagal'}), 500);
        }
        final body = jsonDecode(request.body);
        currentClaims.removeWhere((c) => c['store_id'] == body['store_id']);
        return http.Response(
          jsonEncode({
            'is_claimed': true,
            'claim_status': 'verified',
            'store_id': body['store_id'],
            'store_nama': 'Toko Berkah Mandiri',
            'campaigns': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/ads/reject-claim') && request.method == 'POST') {
        if (shouldFailAction) {
          return http.Response(jsonEncode({'detail': 'Aksi penolakan gagal'}), 500);
        }
        final body = jsonDecode(request.body);
        currentClaims.removeWhere((c) => c['store_id'] == body['store_id']);
        return http.Response(
          jsonEncode({
            'is_claimed': false,
            'claim_status': 'rejected',
            'store_id': body['store_id'],
            'store_nama': 'Toko Berkah Mandiri',
            'campaigns': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/ads/my-store')) {
        return http.Response(
          jsonEncode({
            'is_claimed': false,
            'claim_status': null,
            'store_id': null,
            'store_nama': null,
            'campaigns': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/stores/nearby')) {
        return http.Response(
          jsonEncode({
            'source': 'osm',
            'stores': [
              {
                'store_id': 'store-456',
                'nama': 'Toko Berkah Mandiri',
                'lat': -7.7829,
                'lng': 110.4083,
                'jarak_km': 0.5,
                'alamat': 'Jl. Kaliurang KM 5 No. 10, Sleman',
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response('Not Found', 404);
    });
  }

  group('AdminStoreClaimsPage Widget Tests', () {
    testWidgets('Displays list of pending store claims with merchant and store details', (tester) async {
      final client = createMockClient();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminStoreClaimsPage(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );

      // Loading state initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      // Page title
      expect(find.text('Verifikasi Klaim Toko'), findsOneWidget);
      expect(find.text('Panel Administrator'), findsOneWidget);

      // Claim cards
      expect(find.text('Toko Berkah Mandiri'), findsOneWidget);
      expect(find.text('Jl. Kaliurang KM 5 No. 10, Sleman'), findsOneWidget);
      expect(find.text('Pak Bambang'), findsOneWidget);
      expect(find.text('bambang@gmail.com'), findsOneWidget);

      expect(find.text('Warung Bu Siti'), findsOneWidget);
      expect(find.text('Bu Siti'), findsOneWidget);

      // Status badge and action buttons
      expect(find.text('Menunggu Verifikasi'), findsNWidgets(2));
      expect(find.byKey(const Key('approve_claim_store-456')), findsOneWidget);
      expect(find.byKey(const Key('reject_claim_store-456')), findsOneWidget);
    });

    testWidgets('Displays empty state when no pending claims exist', (tester) async {
      final client = createMockClient(claims: []);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminStoreClaimsPage(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Semua Klaim Sudah Diproses'), findsOneWidget);
      expect(find.text('Saat ini tidak ada permohonan klaim toko yang menunggu verifikasi admin.'), findsOneWidget);
    });

    testWidgets('Displays error state and allows retry on fetch failure', (tester) async {
      bool fail = true;
      final client = createMockClient(shouldFailFetchFn: () => fail);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminStoreClaimsPage(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Gagal mengambil daftar klaim pending.'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);

      // Verify retry button re-fetches and updates UI state to success
      fail = false;
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();

      expect(find.text('Gagal mengambil daftar klaim pending.'), findsNothing);
      expect(find.text('Toko Berkah Mandiri'), findsOneWidget);
    });

    testWidgets('Approving a claim shows confirmation dialog and updates list on success', (tester) async {
      final client = createMockClient();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminStoreClaimsPage(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Setujui on store-456
      await tester.tap(find.byKey(const Key('approve_claim_store-456')));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Setujui Klaim Toko?'), findsOneWidget);
      expect(find.byKey(const Key('cancel_approve_button')), findsOneWidget);
      expect(find.byKey(const Key('confirm_approve_button')), findsOneWidget);

      // Tap confirm
      await tester.tap(find.byKey(const Key('confirm_approve_button')));
      await tester.pumpAndSettle();

      // SnackBar success appears
      expect(find.text('Klaim toko "Toko Berkah Mandiri" berhasil disetujui!'), findsOneWidget);

      // Toko Berkah Mandiri is no longer in pending list
      expect(find.text('Toko Berkah Mandiri'), findsNothing);
      expect(find.text('Warung Bu Siti'), findsOneWidget);
    });

    testWidgets('Rejecting a claim shows confirmation dialog, supports reason, and updates list', (tester) async {
      final client = createMockClient();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminStoreClaimsPage(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Tolak on store-456
      await tester.tap(find.byKey(const Key('reject_claim_store-456')));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Tolak Klaim Toko?'), findsOneWidget);
      expect(find.byKey(const Key('reject_reason_input')), findsOneWidget);

      // Enter optional reason
      await tester.enterText(find.byKey(const Key('reject_reason_input')), 'Foto bukti tidak sesuai');

      // Tap confirm reject
      await tester.tap(find.byKey(const Key('confirm_reject_button')));
      await tester.pumpAndSettle();

      // SnackBar outcome appears
      expect(find.text('Klaim toko "Toko Berkah Mandiri" telah ditolak.'), findsOneWidget);

      // Toko Berkah Mandiri removed from pending list
      expect(find.text('Toko Berkah Mandiri'), findsNothing);
      expect(find.text('Warung Bu Siti'), findsOneWidget);
    });
  });

  group('Navigation & Authorization Tests', () {
    testWidgets('ProfilePage displays Verifikasi Klaim Toko tile for admin, hidden for non-admin', (tester) async {
      final client = createMockClient();

      // 1. Admin user sees tile
      AuthService.mockIsAdmin = true;
      await tester.pumpWidget(
        MaterialApp(
          home: ProfilePage(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_admin_badge')), findsOneWidget);
      expect(find.byKey(const Key('admin_claim_approval_tile')), findsOneWidget);
      expect(find.text('Verifikasi Klaim Toko'), findsOneWidget);

      // 2. Non-admin user does NOT see tile
      AuthService.mockIsAdmin = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ProfilePage(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin_claim_approval_tile')), findsNothing);
      expect(find.text('Verifikasi Klaim Toko'), findsNothing);
    });

    testWidgets('MerchantDashboardPage displays admin claim button and banner for admin only', (tester) async {
      final client = createMockClient();

      // 1. Admin user sees claims button and unclaimed banner
      AuthService.mockIsAdmin = true;
      await tester.pumpWidget(
        MaterialApp(
          home: MerchantDashboardPage(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('merchant_admin_claims_button')), findsOneWidget);
      expect(find.byKey(const Key('admin_unclaimed_claims_banner')), findsOneWidget);

      // 2. Non-admin user does NOT see claims button or banner
      AuthService.mockIsAdmin = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MerchantDashboardPage(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('merchant_admin_claims_button')), findsNothing);
      expect(find.byKey(const Key('admin_unclaimed_claims_banner')), findsNothing);
    });
  });
}
