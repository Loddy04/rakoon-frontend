import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/home_screen.dart';
import 'package:rakoon_frontend/features/scan/presentation/pages/scan_history_screen.dart';
import 'package:rakoon_frontend/features/scan/presentation/pages/scan_session_detail_screen.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late MockClient mockHttpClient;
  late String currentUserId;
  late List<Map<String, dynamic>> userScansDatabase;
  late Map<String, dynamic> sampleSessionDetail;

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

    // Using explicit ISO-8601 with UTC offset
    userScansDatabase = [
      {
        'id': 'session-1',
        'store_id': 'store-1',
        'store_name': 'Supermarket Toko Amanah',
        'timestamp': '2026-08-14T07:32:00Z',
        'product_count': 2,
      },
      {
        'id': 'session-2',
        'store_id': 'store-2',
        'store_name': 'Alfamart Dago',
        'timestamp': '2026-08-14T03:15:00Z',
        'product_count': 1,
      },
    ];

    sampleSessionDetail = {
      'id': 'session-1',
      'store_id': 'store-1',
      'store_name': 'Supermarket Toko Amanah',
      'timestamp': '2026-08-14T07:32:00Z',
      'product_count': 2,
      'items': [
        {
          'product_id': 'prod-1',
          'nama_produk': 'Minyak Goreng Sania',
          'kategori': 'Minyak & Mentega',
          'ukuran': 2.0,
          'satuan': 'L',
          'harga': 36500,
        },
        {
          'product_id': 'prod-2',
          'nama_produk': 'Beras Pandan Wangi',
          'kategori': 'Beras & Biji-Bijian',
          'ukuran': 5.0,
          'satuan': 'kg',
          'harga': 75000,
        },
      ],
    };

    mockHttpClient = MockClient((request) async {
      final authHeader = request.headers['Authorization'];
      if (authHeader != 'Bearer test-user-bearer-token') {
        return http.Response(jsonEncode({'detail': 'Unauthorized'}), 401);
      }

      if (request.url.path == '/scan/recent') {
        return http.Response(jsonEncode(userScansDatabase), 200);
      }

      if (request.url.path == '/scan/session/session-1') {
        return http.Response(jsonEncode(sampleSessionDetail), 200);
      }

      if (request.url.path.startsWith('/scan/session/')) {
        return http.Response(
          jsonEncode({'detail': 'Sesi scan tidak ditemukan.'}),
          404,
        );
      }

      if (request.url.path.endsWith('/stores/nearby')) {
        return http.Response(
          jsonEncode({
            'source': 'osm',
            'stores': [],
            'message': null,
          }),
          200,
        );
      }

      return http.Response('Not Found', 404);
    });
  });

  tearDown(() {
    AuthService.mockSession = null;
  });

  group('ScanSessionDetailScreen & Navigation Tests', () {
    testWidgets('1. ScanSessionDetailScreen renders store header, count badge, and product items', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ScanSessionDetailScreen(
            scanSessionId: 'session-1',
            baseUrl: 'http://localhost:8000',
            httpClient: mockHttpClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Detail Sesi Scan'), findsOneWidget);
      expect(find.text('Supermarket Toko Amanah'), findsOneWidget);
      expect(find.text('2 produk dipindai'), findsOneWidget);

      final expectedLocalTime = DateTime.parse('2026-08-14T07:32:00Z').toLocal();
      final expectedHour = expectedLocalTime.hour.toString().padLeft(2, '0');
      final expectedMinute = expectedLocalTime.minute.toString().padLeft(2, '0');
      expect(find.textContaining('$expectedHour:$expectedMinute'), findsOneWidget);

      // Product items
      expect(find.text('Minyak Goreng Sania'), findsOneWidget);
      expect(find.text('Minyak & Mentega'), findsOneWidget);
      expect(find.text('2 L'), findsOneWidget);
      expect(find.text('Rp 36.500'), findsOneWidget);

      expect(find.text('Beras Pandan Wangi'), findsOneWidget);
      expect(find.text('Beras & Biji-Bijian'), findsOneWidget);
      expect(find.text('5 kg'), findsOneWidget);
      expect(find.text('Rp 75.000'), findsOneWidget);

      // No edit/delete buttons (read-only history)
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.text('Simpan'), findsNothing);
    });

    testWidgets('2. ScanSessionDetailScreen handles error with retry', (
      WidgetTester tester,
    ) async {
      bool shouldFail = true;
      final retryClient = MockClient((request) async {
        if (request.url.path == '/scan/session/session-1') {
          if (shouldFail) {
            return http.Response('Internal Server Error', 500);
          }
          return http.Response(jsonEncode(sampleSessionDetail), 200);
        }
        return http.Response('Not Found', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ScanSessionDetailScreen(
            scanSessionId: 'session-1',
            baseUrl: 'http://localhost:8000',
            httpClient: retryClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scan_session_detail_error')), findsOneWidget);
      expect(find.byKey(const Key('retry_scan_session_detail_button')), findsOneWidget);

      // Tap retry
      shouldFail = false;
      await tester.tap(find.byKey(const Key('retry_scan_session_detail_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scan_session_detail_error')), findsNothing);
      expect(find.text('Minyak Goreng Sania'), findsOneWidget);
    });

    testWidgets('3. ScanHistoryScreen displays list and navigates to detail on tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ScanHistoryScreen(
            baseUrl: 'http://localhost:8000',
            httpClient: mockHttpClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Riwayat Scan'), findsOneWidget);
      expect(find.text('Supermarket Toko Amanah'), findsOneWidget);
      expect(find.text('2 produk dipindai'), findsOneWidget);
      expect(find.text('Alfamart Dago'), findsOneWidget);
      expect(find.text('1 produk dipindai'), findsOneWidget);

      // Tap first session card
      await tester.tap(find.text('Supermarket Toko Amanah'));
      await tester.pumpAndSettle();

      // Navigated to detail screen
      expect(find.text('Detail Sesi Scan'), findsOneWidget);
      expect(find.text('Minyak Goreng Sania'), findsOneWidget);
    });

    testWidgets('4. ScanHistoryScreen displays empty state when user has no scan history', (
      WidgetTester tester,
    ) async {
      userScansDatabase.clear();

      await tester.pumpWidget(
        MaterialApp(
          home: ScanHistoryScreen(
            baseUrl: 'http://localhost:8000',
            httpClient: mockHttpClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum Ada Riwayat Scan'), findsOneWidget);
      expect(find.byKey(const Key('scan_history_empty')), findsOneWidget);
    });

    testWidgets('5. HomeScreen "Lihat semua" opens ScanHistoryScreen', (
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

      // Find "Lihat semua" in Scan Terakhir section
      final seeAllBtn = find.byKey(const Key('scan_terakhir_see_all'));
      expect(seeAllBtn, findsOneWidget);

      await tester.ensureVisible(seeAllBtn);
      await tester.tap(seeAllBtn);
      await tester.pumpAndSettle();

      // Assert navigated to ScanHistoryScreen (not ProductHistoryListPage)
      expect(find.text('Riwayat Scan'), findsOneWidget);
      expect(find.text('Riwayat Produk Pindai'), findsNothing);
    });

    testWidgets('6. HomeScreen recent scan card tap opens ScanSessionDetailScreen', (
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

      final scanCard = find.byKey(const Key('recent_scan_item_session-1'));
      expect(scanCard, findsOneWidget);

      await tester.ensureVisible(scanCard);
      await tester.tap(scanCard);
      await tester.pumpAndSettle();

      // Assert navigated to ScanSessionDetailScreen
      expect(find.text('Detail Sesi Scan'), findsOneWidget);
      expect(find.text('Minyak Goreng Sania'), findsOneWidget);
    });

    testWidgets('7. ScanSessionDetailScreen responsive test across 320dp, 360dp, 390dp, 430dp', (
      WidgetTester tester,
    ) async {
      final widths = [320.0, 360.0, 390.0, 430.0];

      for (final width in widths) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: ScanSessionDetailScreen(
              scanSessionId: 'session-1',
              baseUrl: 'http://localhost:8000',
              httpClient: mockHttpClient,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Detail Sesi Scan'), findsOneWidget);
        expect(find.text('Supermarket Toko Amanah'), findsOneWidget);
      }

      tester.view.resetPhysicalSize();
    });
  });

  group('Timestamp & Timezone Parsing Unit Tests', () {
    test('8. UTC timestamp parses and converts to local time correctly', () {
      const utcString = '2026-08-14T16:15:00Z';
      final localTime = parseScanTimestamp(utcString);
      final expected = DateTime.parse(utcString).toLocal();

      expect(localTime.isUtc, false);
      expect(localTime.millisecondsSinceEpoch, expected.millisecondsSinceEpoch);
      expect(localTime.hour, expected.hour);
    });

    test('9. +07:00 timezone offset string parses to identical epoch', () {
      const offsetString = '2026-08-14T23:15:00+07:00';
      final localTime = parseScanTimestamp(offsetString);
      final expected = DateTime.parse(offsetString).toLocal();

      expect(localTime.millisecondsSinceEpoch, expected.millisecondsSinceEpoch);
    });

    test('10. Timestamp does not get double-converted', () {
      const offsetString = '2026-08-14T16:15:00Z';
      final time1 = parseScanTimestamp(offsetString);
      final time2 = time1.toLocal();

      expect(time1.millisecondsSinceEpoch, time2.millisecondsSinceEpoch);
      expect(time1.hour, time2.hour);
    });

    test('11. Legacy naive ISO string parses without error and converts safely', () {
      const naiveString = '2026-08-14T16:15:00';
      final localTime = parseScanTimestamp(naiveString);

      expect(localTime, isNotNull);
      expect(localTime.isUtc, false);
    });

    test('12. Malformed or null timestamp safely falls back without crash', () {
      final t1 = parseScanTimestamp(null);
      final t2 = parseScanTimestamp('invalid-date-format');
      final t3 = parseScanTimestamp('');

      expect(t1, isA<DateTime>());
      expect(t2, isA<DateTime>());
      expect(t3, isA<DateTime>());
    });
  });
}
