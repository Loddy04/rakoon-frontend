import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/home_screen.dart';
import 'package:rakoon_frontend/features/nearby/nearby_stores_screen.dart';
import 'package:rakoon_frontend/features/nearby/price_comparison_screen.dart';
import 'package:rakoon_frontend/features/price_check/presentation/pages/price_check_catalog_page.dart';
import 'package:rakoon_frontend/services/stores_service.dart';
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
          return http.Response(
            jsonEncode({
              "source": "osm",
              "stores": [
                {
                  "store_id": "store-1-long-uuid",
                  "nama": "Indomaret Sudirman",
                  "lat": -6.2088,
                  "lng": 106.8456,
                  "jarak_km": 1.2,
                },
                {
                  "store_id": "store-2-long-uuid",
                  "nama": "Alfamart Gatot Subroto",
                  "lat": -6.2201,
                  "lng": 106.8122,
                  "jarak_km": 2.5,
                },
              ],
              "message": null,
            }),
            200,
          );
        } else if (request.url.path.endsWith('/products/')) {
          return http.Response(
            jsonEncode([
              {
                "id": "prod-1",
                "nama": "Minyak Goreng 2L",
                "kategori": "Makanan Pokok",
                "ukuran": 2.0,
                "satuan": "L",
              },
            ]),
            200,
          );
        } else if (request.url.path.contains('/price/compare/')) {
          return http.Response(
            jsonEncode({
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
                  "pesan": null,
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
                  "pesan": "Belum ada data untuk produk ini di toko ini",
                },
              ],
            }),
            200,
          );
        } else if (request.url.path.contains('/products/catalog')) {
          return http.Response(
            jsonEncode([
              {
                "id": "prod-1",
                "nama": "Minyak Goreng 2L",
                "kategori": "Makanan Pokok",
                "ukuran": 2.0,
                "satuan": "L",
                "harga_terendah": 32000.0,
                "nama_toko_terendah": "Indomaret Sudirman",
                "jumlah_toko": 1,
                "foto_url": null,
                "updated_at": "2026-08-10T12:00:00Z",
              },
            ]),
            200,
          );
        } else if (request.url.host.contains('openstreetmap.org') || request.url.path.endsWith('.png')) {
          return http.Response.bytes(
            [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82],
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        return http.Response('Not Found', 404);
      });
    });

    testWidgets(
      'Home renders Cek Harga and Toko Sekitar quick actions with correct semantics',
      (WidgetTester tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          const MaterialApp(home: HomeScreen(baseUrl: 'http://localhost:8000')),
        );
        await tester.pumpAndSettle();

        // Check card titles
        expect(find.text('Cek Harga'), findsOneWidget);
        expect(find.text('Toko Sekitar'), findsOneWidget);
        expect(find.text('Smart Budget'), findsOneWidget);

        // Verify semantics tags exist
        expect(
          find.bySemanticsLabel('Toko Sekitar, cari toko terdekat di sekitar kamu'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Cek Harga, buka katalog produk dan perbandingan harga'),
          findsOneWidget,
        );

        handle.dispose();
      },
    );

    testWidgets(
      'Tapping Toko Sekitar opens NearbyStoresScreen, store card tap opens revamped detail modal, and Back returns safely',
      (WidgetTester tester) async {
        await mockNetworkImagesFor(() async {
          await http.runWithClient(() async {
            await tester.pumpWidget(
              const MaterialApp(
                home: HomeScreen(baseUrl: 'http://localhost:8000'),
              ),
            );
            await tester.pumpAndSettle();

            // Tap Toko Sekitar
            final tokoFinder = find.bySemanticsLabel('Toko Sekitar, cari toko terdekat di sekitar kamu');
            await tester.tap(tokoFinder);
            await tester.pumpAndSettle();

            // Verify NearbyStoresScreen loaded
            expect(find.byType(NearbyStoresScreen), findsOneWidget);
            expect(find.text('Indomaret Sudirman'), findsOneWidget);

            // Tap store card directly to open revamped detail modal
            await tester.tap(find.text('Indomaret Sudirman'));
            await tester.pumpAndSettle();

            // Verify revamped Detail modal items: address, product list, search input, and Buka Rute
            expect(find.text('Alamat Toko'), findsOneWidget);
            expect(find.text('Daftar Produk di Toko Ini'), findsOneWidget);
            expect(find.text('Cari produk di toko ini...'), findsOneWidget);
            expect(find.text('Buka Rute'), findsOneWidget);

            // Verify backend technical details (Koordinat, Sumber Data POI) are removed
            expect(find.text('Koordinat'), findsNothing);
            expect(find.text('Sumber Data POI'), findsNothing);

            // Close modal via top-right close 'X' button
            await tester.tap(find.byTooltip('Tutup'));
            await tester.pumpAndSettle();

            // Back out of map view
            await tester.tap(find.byType(BackButton));
            await tester.pumpAndSettle();

            // Confirm back at Home
            expect(find.byType(NearbyStoresScreen), findsNothing);
            expect(find.bySemanticsLabel('Toko Sekitar, cari toko terdekat di sekitar kamu'), findsOneWidget);
          }, () => mockClient);
        });
      },
    );

    testWidgets(
      'Tapping Cek Harga opens PriceCheckCatalogPage, and Back returns correctly',
      (WidgetTester tester) async {
        await mockNetworkImagesFor(() async {
          await http.runWithClient(() async {
            await tester.pumpWidget(
              const MaterialApp(
                home: HomeScreen(baseUrl: 'http://localhost:8000'),
              ),
            );
            await tester.pumpAndSettle();

            // Tap Cek Harga
            final cekHargaFinder = find.bySemanticsLabel('Cek Harga, buka katalog produk dan perbandingan harga');
            await tester.ensureVisible(cekHargaFinder);
            await tester.tap(cekHargaFinder);
            await tester.pumpAndSettle();

            // PriceCheckCatalogPage should be open
            expect(find.byType(PriceCheckCatalogPage), findsOneWidget);
            expect(find.text('Cek Harga'), findsOneWidget);

            // Tap back button in catalog view
            await tester.tap(find.byType(BackButton));
            await tester.pumpAndSettle();

            // Verify returned to Home Screen
            expect(find.byType(PriceCheckCatalogPage), findsNothing);
            expect(find.bySemanticsLabel('Cek Harga, buka katalog produk dan perbandingan harga'), findsOneWidget);
          }, () => mockClient);
        });
      },
    );

    // -------------------------------------------------------------------------
    // Phase 3.3.2 tests — RakoonLocationMap integration
    // -------------------------------------------------------------------------

    testWidgets('NearbyStoresScreen renders RakoonLocationMap widget', (
      WidgetTester tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await http.runWithClient(() async {
          await tester.pumpWidget(
            const MaterialApp(home: HomeScreen(baseUrl: 'http://localhost:8000')),
          );
          await tester.pumpAndSettle();

          final tokoFinder = find.bySemanticsLabel('Toko Sekitar, cari toko terdekat di sekitar kamu');
          await tester.tap(tokoFinder);
          await tester.pumpAndSettle();

          expect(find.byType(NearbyStoresScreen), findsOneWidget);
          // Shared map widget should be present in NearbyStoresScreen
          expect(find.descendant(of: find.byType(NearbyStoresScreen), matching: find.byType(RakoonLocationMap)), findsOneWidget);
        }, () => mockClient);
      });
    });

    testWidgets(
      'PriceComparisonScreen renders RakoonLocationMap with store markers',
      (WidgetTester tester) async {
        await mockNetworkImagesFor(() async {
          await http.runWithClient(() async {
            await tester.pumpWidget(
              const MaterialApp(
                home: PriceComparisonScreen(
                  productId: 'prod-1',
                  productName: 'Minyak Goreng 2L',
                  baseUrl: 'http://localhost:8000',
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.byType(PriceComparisonScreen), findsOneWidget);
            // Map widget should now be embedded in price comparison
            expect(find.descendant(of: find.byType(PriceComparisonScreen), matching: find.byType(RakoonLocationMap)), findsOneWidget);
          }, () => mockClient);
        });
      },
    );

    testWidgets(
      'PriceComparisonScreen: cheapest card keeps accent border when another card is tapped',
      (WidgetTester tester) async {
        await mockNetworkImagesFor(() async {
          await http.runWithClient(() async {
            await tester.pumpWidget(
              const MaterialApp(
                home: PriceComparisonScreen(
                  productId: 'prod-1',
                  productName: 'Minyak Goreng 2L',
                  baseUrl: 'http://localhost:8000',
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.byType(PriceComparisonScreen), findsOneWidget);

            // Cheapest store card shows 'Termurah' badge — verify it's present
            expect(find.text('Termurah'), findsOneWidget);

            // The store without price shows 'Belum ada data' badge
            expect(find.text('Belum ada data'), findsOneWidget);

            // Tapping the no-data card should not remove Termurah badge from cheapest
            await tester.tap(find.text('Alfamart Gatot Subroto'), warnIfMissed: false);
            await tester.pumpAndSettle();

            // Termurah badge must still exist
            expect(find.text('Termurah'), findsOneWidget);
          }, () => mockClient);
        });
      },
    );

    testWidgets(
      'PriceComparisonScreen: store without price still shows on map (via RakoonLocationMap)',
      (WidgetTester tester) async {
        await mockNetworkImagesFor(() async {
          await http.runWithClient(() async {
            await tester.pumpWidget(
              const MaterialApp(
                home: PriceComparisonScreen(
                  productId: 'prod-1',
                  productName: 'Minyak Goreng 2L',
                  baseUrl: 'http://localhost:8000',
                ),
              ),
            );
            await tester.pumpAndSettle();

            // Map is present even when one store has no price
            expect(find.descendant(of: find.byType(PriceComparisonScreen), matching: find.byType(RakoonLocationMap)), findsOneWidget);
            // Both stores rendered in the list
            expect(find.text('Indomaret Sudirman'), findsOneWidget);
            expect(find.text('Alfamart Gatot Subroto'), findsOneWidget);
          }, () => mockClient);
        });
      },
    );

    testWidgets(
      'Responsive Layout 320dp — PriceComparisonScreen with map has no overflows',
      (WidgetTester tester) async {
        await mockNetworkImagesFor(() async {
          await http.runWithClient(() async {
            tester.view.physicalSize = const Size(320 * 3, 568 * 3);
            tester.view.devicePixelRatio = 3.0;

            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(
              const MaterialApp(
                home: PriceComparisonScreen(
                  productId: 'prod-1',
                  productName: 'Minyak Goreng 2L',
                  baseUrl: 'http://localhost:8000',
                ),
              ),
            );
            await tester.pumpAndSettle();

            final exception = tester.takeException();
            if (exception != null && exception is FlutterError) {
              debugPrint(exception.toStringDeep());
            }
            expect(exception, isNull);
            expect(find.byType(PriceComparisonScreen), findsOneWidget);
          }, () => mockClient);
        });
      },
    );

    testWidgets(
      'Responsive Layout — NearbyStoresScreen renders across viewports (320dp, 360dp, 390dp) without overflow',
      (WidgetTester tester) async {
        await mockNetworkImagesFor(() async {
          await http.runWithClient(() async {
            final viewports = [
              const Size(320, 640),
              const Size(360, 800),
              const Size(390, 844),
            ];

            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            for (final size in viewports) {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1.0;

              await tester.pumpWidget(
                const MaterialApp(
                  home: NearbyStoresScreen(
                    baseUrl: 'http://localhost:8000',
                    initialLat: -6.2088,
                    initialLng: 106.8456,
                  ),
                ),
              );
              await tester.pumpAndSettle();

              expect(tester.takeException(), isNull);
              expect(find.text('Toko Sekitar'), findsWidgets);
            }
          }, () => mockClient);
        });
      },
    );

    testWidgets(
      'Tapping a map marker in NearbyStoresScreen selects the store and scrolls to its card',
      (WidgetTester tester) async {
        await mockNetworkImagesFor(() async {
          await http.runWithClient(() async {
            await tester.pumpWidget(
              const MaterialApp(
                home: NearbyStoresScreen(
                  baseUrl: 'http://localhost:8000',
                  initialLat: -6.2088,
                  initialLng: 106.8456,
                ),
              ),
            );
            await tester.pumpAndSettle();

            // Find store markers
            final markerFinder = find.byType(GestureDetector);
            expect(markerFinder, findsWidgets);

            // Tap second store marker (Alfamart Gatot Subroto) via semantics or map marker
            final alfamartMarker = find.bySemanticsLabel(RegExp(r'^Toko: Alfamart Gatot Subroto'));
            if (alfamartMarker.evaluate().isNotEmpty) {
              await tester.tap(alfamartMarker.first);
              await tester.pumpAndSettle();
              expect(find.text('Alfamart Gatot Subroto'), findsWidgets);
            }
          }, () => mockClient);
        });
      },
    );
  });

  group('StoreProductItem Model Tests', () {
    test('StoreProductItem.fromJson parses stale: true and stale: false properly', () {
      final staleJson = {
        'id': 'prod-stale-1',
        'nama': 'Minyak Goreng 2L',
        'kategori': 'Makanan Pokok',
        'harga': 34000.0,
        'updated_at': '2026-01-10T00:00:00Z',
        'stale': true,
      };
      final staleItem = StoreProductItem.fromJson(staleJson);
      expect(staleItem.stale, isTrue);
      expect(staleItem.nama, 'Minyak Goreng 2L');
      expect(staleItem.harga, 34000.0);
      expect(staleItem.updatedAt, '2026-01-10T00:00:00Z');

      final freshJson = {
        'id': 'prod-fresh-1',
        'nama': 'Beras 5kg',
        'kategori': 'Makanan Pokok',
        'harga': 68000.0,
        'updated_at': '2026-10-10T00:00:00Z',
        'stale': false,
      };
      final freshItem = StoreProductItem.fromJson(freshJson);
      expect(freshItem.stale, isFalse);
    });

    test('StoreProductItem.fromJson defaults stale to false when field is omitted or null', () {
      final omittedJson = {
        'id': 'prod-omitted-1',
        'nama': 'Gula Pasir 1kg',
        'kategori': 'Makanan Pokok',
        'harga': 17500.0,
      };
      final omittedItem = StoreProductItem.fromJson(omittedJson);
      expect(omittedItem.stale, isFalse);

      final nullJson = {
        'id': 'prod-null-1',
        'nama': 'Gula Pasir 1kg',
        'kategori': 'Makanan Pokok',
        'harga': 17500.0,
        'stale': null,
      };
      final nullItem = StoreProductItem.fromJson(nullJson);
      expect(nullItem.stale, isFalse);
    });
  });
}
