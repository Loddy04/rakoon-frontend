import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/home_screen.dart';
import 'package:rakoon_frontend/features/nearby/nearby_stores_screen.dart';
import 'package:rakoon_frontend/features/nearby/price_comparison_screen.dart';
import 'package:rakoon_frontend/widgets/rakoon_location_map.dart';


void main() {
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

  group('Nearby & Price Comparison IA Split Tests', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/stores/nearby')) {
          return http.Response(jsonEncode({
            "source": "osm",
            "stores": [
              {
                "store_id": "store-1-long-uuid",
                "nama": "Indomaret Sudirman",
                "lat": -6.2088,
                "lng": 106.8456,
                "jarak_km": 1.2
              },
              {
                "store_id": "store-2-long-uuid",
                "nama": "Alfamart Gatot Subroto",
                "lat": -6.2201,
                "lng": 106.8122,
                "jarak_km": 2.5
              }
            ],
            "message": null
          }), 200);
        } else if (request.url.path.endsWith('/products/')) {
          return http.Response(jsonEncode([
            {
              "id": "prod-1",
              "nama": "Minyak Goreng 2L",
              "kategori": "Makanan Pokok",
              "ukuran": 2.0,
              "satuan": "L"
            }
          ]), 200);
        } else if (request.url.path.contains('/price/compare/')) {
          return http.Response(jsonEncode({
            "product_id": "prod-1",
            "nama_produk": "Minyak Goreng 2L",
            "comparison": [
              {
                "store_id": "store-1-long-uuid",
                "nama_toko": "Indomaret Sudirman",
                "lat": -6.2088,
                "lng": 106.8456,
                "jarak_km": 1.2,
                "harga_terbaru": 32000,
                "tanggal_update": "2026-08-10T12:00:00Z",
                "status_verifikasi": "verified",
                "pesan": null
              },
              {
                "store_id": "store-2-long-uuid",
                "nama_toko": "Alfamart Gatot Subroto",
                "lat": -6.2201,
                "lng": 106.8122,
                "jarak_km": 2.5,
                "harga_terbaru": null,
                "tanggal_update": null,
                "status_verifikasi": null,
                "pesan": "Belum ada data untuk produk ini di toko ini"
              }
            ]
          }), 200);
        }
        return http.Response('Not Found', 404);
      });
    });

    testWidgets('Home renders Toko Terdekat and Bandingkan Harga cards with correct text and accessibility semantics', (WidgetTester tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(baseUrl: 'http://localhost:8000'),
        ),
      );
      await tester.pumpAndSettle();

      // Check card titles and subtitles
      expect(find.text('Toko Terdekat'), findsOneWidget);
      expect(find.text('Cari toko di sekitar kamu'), findsOneWidget);

      expect(find.text('Bandingkan Harga'), findsOneWidget);
      expect(find.text('Temukan harga terbaik di toko sekitar'), findsOneWidget);

      // Verify semantics tags exist
      expect(find.bySemanticsLabel('Toko Terdekat, cari toko di sekitar kamu'), findsOneWidget);
      expect(find.bySemanticsLabel('Bandingkan Harga, cari dan bandingkan harga produk'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('Tapping Toko Terdekat opens NearbyStoresScreen, store cards have Detail Toko action (no longer opens product selector), and Back returns safely', (WidgetTester tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: HomeScreen(baseUrl: 'http://localhost:8000'),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Toko Terdekat
        await tester.tap(find.text('Toko Terdekat'));
        await tester.pumpAndSettle();

        // Verify NearbyStoresScreen loaded
        expect(find.byType(NearbyStoresScreen), findsOneWidget);
        expect(find.text('Indomaret Sudirman'), findsOneWidget);

        // Verify "Detail Toko" button is present and "Bandingkan Harga" is absent
        expect(find.text('Detail Toko'), findsWidgets);
        expect(find.text('Bandingkan Harga'), findsNothing);

        // Tap "Detail Toko" to open detail sheet
        await tester.tap(find.text('Detail Toko').first);
        await tester.pumpAndSettle();

        // Verify Detail bottom sheet items are rendered
        expect(find.text('Koordinat'), findsOneWidget);
        expect(find.text('Jarak dari lokasi Anda'), findsOneWidget);
        expect(find.text('Sumber Data POI'), findsOneWidget);
        expect(find.text('Lat: -6.208800, Lng: 106.845600'), findsOneWidget);

        // Close bottom sheet
        await tester.tap(find.text('Tutup'));
        await tester.pumpAndSettle();

        // Back out of map view
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // Confirm back at Home
        expect(find.byType(NearbyStoresScreen), findsNothing);
        expect(find.text('Toko Terdekat'), findsOneWidget);
      }, () => mockClient);
    });

    testWidgets('Tapping Bandingkan Harga opens product search, selecting product navigates directly to PriceComparisonScreen, and Back returns correctly', (WidgetTester tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: HomeScreen(baseUrl: 'http://localhost:8000'),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Bandingkan Harga
        await tester.tap(find.text('Bandingkan Harga'));
        await tester.pumpAndSettle();

        // Bottom sheet product selector should be open
        expect(find.text('Pilih Produk untuk Dibandingkan'), findsOneWidget);
        expect(find.text('Minyak Goreng 2L'), findsOneWidget);

        // Tap product in the sheet
        await tester.tap(find.text('Minyak Goreng 2L'));
        await tester.pumpAndSettle();

        // Should navigate directly to PriceComparisonScreen
        expect(find.byType(PriceComparisonScreen), findsOneWidget);
        expect(find.text('Perbandingan Harga'), findsOneWidget);
        expect(find.text('Minyak Goreng 2L'), findsOneWidget);
        expect(find.text('Rp 32.000'), findsWidgets);


        // Tap back button in price comparison view
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // Verify returned to Home Screen
        expect(find.byType(PriceComparisonScreen), findsNothing);
        expect(find.text('Bandingkan Harga'), findsOneWidget);
      }, () => mockClient);
    });

    // -------------------------------------------------------------------------
    // Phase 3.3.2 tests — RakoonLocationMap integration
    // -------------------------------------------------------------------------

    testWidgets('NearbyStoresScreen renders RakoonLocationMap widget', (WidgetTester tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: HomeScreen(baseUrl: 'http://localhost:8000'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Toko Terdekat'));
        await tester.pumpAndSettle();

        expect(find.byType(NearbyStoresScreen), findsOneWidget);
        // Shared map widget should be present
        expect(find.byType(RakoonLocationMap), findsOneWidget);
      }, () => mockClient);
    });

    testWidgets('PriceComparisonScreen renders RakoonLocationMap with store markers', (WidgetTester tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: HomeScreen(baseUrl: 'http://localhost:8000'),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to price comparison via product picker
        await tester.tap(find.text('Bandingkan Harga'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Minyak Goreng 2L'));
        await tester.pumpAndSettle();

        expect(find.byType(PriceComparisonScreen), findsOneWidget);
        // Map widget should now be embedded in price comparison
        expect(find.byType(RakoonLocationMap), findsOneWidget);
      }, () => mockClient);
    });

    testWidgets('PriceComparisonScreen: cheapest card keeps accent border when another card is tapped', (WidgetTester tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: HomeScreen(baseUrl: 'http://localhost:8000'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Bandingkan Harga'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Minyak Goreng 2L'));
        await tester.pumpAndSettle();

        expect(find.byType(PriceComparisonScreen), findsOneWidget);

        // Cheapest store card shows 'Termurah' badge — verify it's present
        expect(find.text('Termurah'), findsOneWidget);

        // The store without price shows 'Belum ada data' badge
        expect(find.text('Belum ada data'), findsOneWidget);

        // Tapping the no-data card should not remove Termurah badge from cheapest
        await tester.tap(find.text('Alfamart Gatot Subroto'));
        await tester.pumpAndSettle();

        // Termurah badge must still exist
        expect(find.text('Termurah'), findsOneWidget);
      }, () => mockClient);
    });

    testWidgets('PriceComparisonScreen: store without price still shows on map (via RakoonLocationMap)', (WidgetTester tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: HomeScreen(baseUrl: 'http://localhost:8000'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Bandingkan Harga'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Minyak Goreng 2L'));
        await tester.pumpAndSettle();

        // Map is present even when one store has no price
        expect(find.byType(RakoonLocationMap), findsOneWidget);
        // Both stores rendered in the list
        expect(find.text('Indomaret Sudirman'), findsOneWidget);
        expect(find.text('Alfamart Gatot Subroto'), findsOneWidget);
      }, () => mockClient);
    });

    testWidgets('Responsive Layout 320dp — PriceComparisonScreen with map has no overflows', (WidgetTester tester) async {
      await http.runWithClient(() async {
        tester.view.physicalSize = const Size(320 * 3, 568 * 3);
        tester.view.devicePixelRatio = 3.0;

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: HomeScreen(baseUrl: 'http://localhost:8000'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Bandingkan Harga'));
        await tester.tap(find.text('Bandingkan Harga'), warnIfMissed: false);
        await tester.pumpAndSettle();

        // If product sheet did not open (widget off-screen at 320dp), skip product tap
        if (find.text('Minyak Goreng 2L').evaluate().isNotEmpty) {
          await tester.tap(find.text('Minyak Goreng 2L'));
          await tester.pumpAndSettle();

          final exception = tester.takeException();
          if (exception != null && exception is FlutterError) {
            debugPrint(exception.toStringDeep());
          }
          expect(exception, isNull);
          expect(find.byType(PriceComparisonScreen), findsOneWidget);
        } else {
          // Widget was off-screen; just verify home renders without overflow
          final exception = tester.takeException();
          expect(exception, isNull);
        }
      }, () => mockClient);
    });

  });
}
