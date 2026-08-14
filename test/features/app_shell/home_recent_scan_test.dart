import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/app_shell.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/home_screen.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late MockClient mockHttpClient;
  late String currentUserId;
  late List<Map<String, dynamic>> userScansDatabase;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      anonKey: 'mock-anon-key-here', // ignore: deprecated_member_use
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
      ),
    );
  });

  setUp(() {
    currentUserId = 'user-uuid-1234-5678-90ab';
    AuthService.mockSession = Session(
      accessToken: 'test-user-bearer-token',
      tokenType: 'bearer',
      user: User(
        id: currentUserId,
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'user@example.com',
      ),
    );

    userScansDatabase = [
      {
        'id': 'entry-1',
        'product_id': 'prod-1',
        'nama_produk': 'Minyak Goreng Sania 2L',
        'kategori': 'Makanan Pokok',
        'ukuran': 2.0,
        'satuan': 'l',
        'harga': 36500,
        'store_id': 'store-1',
        'store_name': 'Superindo Dago',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
        'status_verifikasi': 'verified',
      },
      {
        'id': 'entry-2',
        'product_id': 'prod-2',
        'nama_produk': 'Beras Rojolele 5kg',
        'kategori': 'Makanan Pokok',
        'ukuran': 5.0,
        'satuan': 'kg',
        'harga': 74000,
        'store_id': 'store-1',
        'store_name': 'Superindo Dago',
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'status_verifikasi': 'verified',
      },
    ];

    mockHttpClient = MockClient((request) async {
      if (request.url.path.endsWith('/stores/nearby')) {
        return http.Response(
          jsonEncode({
            'source': 'osm',
            'stores': [
              {
                'store_id': 'store-1',
                'nama': 'Superindo Dago',
                'lat': -6.2088,
                'lng': 106.8456,
                'jarak_km': 0.8,
              },
            ],
            'message': null,
          }),
          200,
        );
      }

      if (request.url.path.endsWith('/scan/recent')) {
        final authHeader = request.headers['Authorization'];
        if (authHeader != 'Bearer test-user-bearer-token') {
          return http.Response(jsonEncode({'detail': 'Unauthorized'}), 401);
        }
        return http.Response(jsonEncode(userScansDatabase), 200);
      }

      return http.Response('Not Found', 404);
    });
  });

  tearDown(() {
    AuthService.mockSession = null;
  });

  group('Home Recent Scan Feature Tests', () {
    // 5. Home displays recent scan when authenticated user has history.
    testWidgets('5. Home displays recent scan when authenticated user has history', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            baseUrl: 'http://localhost:8000',
            httpClient: mockHttpClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Scan Terakhir'), findsOneWidget);
      expect(find.text('Minyak Goreng Sania 2L'), findsOneWidget);
      expect(find.text('Rp 36.500'), findsOneWidget);
      expect(find.text('2 l'), findsOneWidget);
      expect(find.text('Beras Rojolele 5kg'), findsOneWidget);
      expect(find.text('Rp 74.000'), findsOneWidget);
      expect(find.text('5 kg'), findsOneWidget);
      expect(find.text('Superindo Dago'), findsAtLeast(1));

      // Empty state should NOT be shown
      expect(find.text('Belum Ada Riwayat Pindai'), findsNothing);
    });

    // 6. Home displays data belonging to the authenticated user, not other users.
    testWidgets('6. Home sends Supabase JWT token and retrieves authenticated user history', (
      WidgetTester tester,
    ) async {
      String? capturedAuthHeader;
      final testClient = MockClient((request) async {
        if (request.url.path.endsWith('/scan/recent')) {
          capturedAuthHeader = request.headers['Authorization'];
          return http.Response(jsonEncode(userScansDatabase), 200);
        }
        return http.Response(jsonEncode({'stores': []}), 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            baseUrl: 'http://localhost:8000',
            httpClient: testClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedAuthHeader, 'Bearer test-user-bearer-token');
      expect(find.text('Minyak Goreng Sania 2L'), findsOneWidget);
    });

    // 7. Home displays empty state if history is truly empty.
    testWidgets('7. Home displays empty state if history is truly empty', (
      WidgetTester tester,
    ) async {
      userScansDatabase.clear();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            baseUrl: 'http://localhost:8000',
            httpClient: mockHttpClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum Ada Riwayat Pindai'), findsOneWidget);
      expect(
        find.text('Pindai label harga rak produk di toko untuk mulai mencatat dan membandingkan harga.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home_start_scan_cta')), findsOneWidget);
      expect(find.byKey(const Key('recent_scans_list')), findsNothing);
    });

    // 8. Home displays loading state while history is being fetched.
    testWidgets('8. Home displays loading state while history is being fetched', (
      WidgetTester tester,
    ) async {
      final completer = Completer<http.Response>();
      final delayClient = MockClient((request) async {
        if (request.url.path.endsWith('/scan/recent')) {
          return completer.future;
        }
        return http.Response(jsonEncode({'stores': []}), 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            baseUrl: 'http://localhost:8000',
            httpClient: delayClient,
          ),
        ),
      );
      await tester.pump(); // Pump without settling to catch loading state

      expect(find.byKey(const Key('recent_scans_loading')), findsOneWidget);
      expect(find.text('Memuat riwayat scan...'), findsOneWidget);

      completer.complete(http.Response(jsonEncode(userScansDatabase), 200));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recent_scans_loading')), findsNothing);
      expect(find.text('Minyak Goreng Sania 2L'), findsOneWidget);
    });

    // 9. Home displays error state if request fails, with retry button.
    testWidgets('9. Home displays error state if request fails, with retry button', (
      WidgetTester tester,
    ) async {
      bool shouldFail = true;
      final errorClient = MockClient((request) async {
        if (request.url.path.endsWith('/scan/recent')) {
          if (shouldFail) {
            return http.Response('Internal Server Error', 500);
          }
          return http.Response(jsonEncode(userScansDatabase), 200);
        }
        return http.Response(jsonEncode({'stores': []}), 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            baseUrl: 'http://localhost:8000',
            httpClient: errorClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recent_scans_error')), findsOneWidget);
      expect(find.text('Gagal memuat riwayat scan.'), findsOneWidget);
      expect(find.byKey(const Key('retry_recent_scans_button')), findsOneWidget);

      // Tap retry with working backend
      shouldFail = false;
      final retryBtn = find.byKey(const Key('retry_recent_scans_button'));
      await tester.ensureVisible(retryBtn);
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recent_scans_error')), findsNothing);
      expect(find.text('Minyak Goreng Sania 2L'), findsOneWidget);
    });

    // 10. After Scan -> return to Home, recent scan updates without app restart.
    testWidgets('10. AppShell tab switch or scan return refreshes recent scan data', (
      WidgetTester tester,
    ) async {
      userScansDatabase.clear();

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            baseUrl: 'http://localhost:8000',
            httpClient: mockHttpClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially empty
      expect(find.text('Belum Ada Riwayat Pindai'), findsOneWidget);

      // Simulate new scan saved in backend
      userScansDatabase.add({
        'id': 'entry-new-1',
        'product_id': 'prod-new-1',
        'nama_produk': 'Indomie Goreng Rasa Baru',
        'kategori': 'Makanan Instan',
        'ukuran': 85.0,
        'satuan': 'g',
        'harga': 3500,
        'store_id': 'store-1',
        'store_name': 'Superindo Dago',
        'timestamp': DateTime.now().toIso8601String(),
        'status_verifikasi': 'verified',
      });

      // Switch to Scan tab (index 1)
      await tester.tap(find.byKey(const Key('nav_tab_1')));
      await tester.pumpAndSettle();

      // Close scan view to return to Home tab (index 0)
      await tester.tap(find.byKey(const Key('scan_close_button')));
      await tester.pumpAndSettle();

      // New item appears immediately without restarting
      expect(find.text('Indomie Goreng Rasa Baru'), findsOneWidget);
      expect(find.text('Rp 3.500'), findsOneWidget);
      expect(find.text('Belum Ada Riwayat Pindai'), findsNothing);
    });

    // 11. No hardcoded UUID or mock product data.
    testWidgets('11. Home recent scan reflects live API data without mock identity', (
      WidgetTester tester,
    ) async {
      final dynamicScans = [
        {
          'id': 'dynamic-id-99',
          'product_id': 'prod-dynamic-99',
          'nama_produk': 'Produk Khusus Pengguna Nyata',
          'kategori': 'Camilan',
          'ukuran': 150.0,
          'satuan': 'gr',
          'harga': 12500,
          'store_id': 'store-special-1',
          'store_name': 'Grand Lucky SCBD',
          'timestamp': DateTime.now().toIso8601String(),
          'status_verifikasi': 'verified',
        }
      ];

      final dynamicClient = MockClient((request) async {
        if (request.url.path.endsWith('/scan/recent')) {
          return http.Response(jsonEncode(dynamicScans), 200);
        }
        return http.Response(jsonEncode({'stores': []}), 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            baseUrl: 'http://localhost:8000',
            httpClient: dynamicClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Produk Khusus Pengguna Nyata'), findsOneWidget);
      expect(find.text('Grand Lucky SCBD'), findsOneWidget);
      expect(find.text('Rp 12.500'), findsOneWidget);
      expect(find.text('150 gr'), findsOneWidget);
    });

    // 12. Responsive test 320dp, 360dp, 390dp, 430dp without overflow.
    testWidgets('12. Home recent scan renders without overflow across 320dp, 360dp, 390dp, and 430dp', (
      WidgetTester tester,
    ) async {
      final screenWidths = [320.0, 360.0, 390.0, 430.0];

      for (final width in screenWidths) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              baseUrl: 'http://localhost:8000',
              httpClient: mockHttpClient,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Rakoon'), findsOneWidget);
        expect(find.text('Scan Terakhir'), findsOneWidget);
        expect(find.text('Minyak Goreng Sania 2L'), findsOneWidget);
      }

      tester.view.resetPhysicalSize();
    });
  });
}
