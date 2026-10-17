import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/price_check/presentation/pages/unified_product_price_detail_page.dart';
import 'package:rakoon_frontend/services/location_service.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';

import '../../helpers/fake_geolocator.dart';

void main() {
  testWidgets('Store row without distance omits distance and separator, and null price shows Tidak tersedia', (tester) async {
    final mockClient = MockClient((request) async {
      final headers = {'content-type': 'application/json'};
      if (request.url.path.contains('/price/compare/')) {
        return http.Response(
          jsonEncode({
            'product_id': 'prod-001',
            'nama_produk': 'Indomie Goreng',
            'comparison': [
              {
                'store_id': 's1',
                'nama_toko': 'Toko Tanpa Jarak',
                'jarak_km': null,
                'harga_terbaru': null,
              },
              {
                'store_id': 's2',
                'nama_toko': 'Toko Berjarak',
                'jarak_km': 1.5,
                'harga_terbaru': 3500,
              },
            ],
          }),
          200,
          headers: headers,
        );
      }
      if (request.url.path.contains('price-history')) {
        return http.Response(
          jsonEncode({'product_id': 'prod-001', 'total': 0, 'items': [], 'trend': []}),
          200,
          headers: headers,
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedProductPriceDetailPage(
          product: RecommendedProduct(
            id: 'prod-001',
            nama: 'Indomie Goreng',
            kategori: 'Makanan Instan',
            harga: 3500.0,
            namaToko: 'Toko Berjarak',
            updatedAt: '2026-10-10T00:00:00Z',
          ),
          baseUrl: 'http://localhost:8000',
          httpClient: mockClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verification 1: Store row without distance must NOT contain "Supermarket terdekat"
    expect(find.textContaining('Supermarket terdekat'), findsNothing);

    // Verification 2: Store row without distance must not leave trailing " · "
    expect(find.textContaining('Toko Tanpa Jarak ·'), findsNothing);
    expect(find.text('Toko Tanpa Jarak'), findsWidgets);

    // Verification 3: Store row with distance shows store name and distance
    expect(find.text('Toko Berjarak'), findsWidgets);
    expect(find.text('± 1,5 km'), findsOneWidget);

    // Verification 4: Empty price displays "Tidak tersedia" instead of "N/A"
    expect(find.text('N/A'), findsNothing);
    expect(find.text('Tidak tersedia'), findsOneWidget);

    // Verification 5: Back button has tooltip "Kembali"
    expect(find.byTooltip('Kembali'), findsOneWidget);
  });

  testWidgets('Chip Rute touch target size is at least 48x48', (tester) async {
    final mockClient = MockClient((request) async {
      final headers = {'content-type': 'application/json'};
      if (request.url.path.contains('/price/compare/')) {
        return http.Response(
          jsonEncode({
            'product_id': 'prod-001',
            'nama_produk': 'Indomie Goreng',
            'comparison': [
              {
                'store_id': 's1',
                'nama_toko': 'Toko Berjarak',
                'lat': -7.78,
                'lng': 110.40,
                'jarak_km': 1.5,
                'harga_terbaru': 3500,
              },
            ],
          }),
          200,
          headers: headers,
        );
      }
      if (request.url.path.contains('price-history')) {
        return http.Response(
          jsonEncode({'product_id': 'prod-001', 'total': 0, 'items': [], 'trend': []}),
          200,
          headers: headers,
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedProductPriceDetailPage(
          product: RecommendedProduct(
            id: 'prod-001',
            nama: 'Indomie Goreng',
            kategori: 'Makanan Instan',
            harga: 3500.0,
            namaToko: 'Toko Berjarak',
            updatedAt: '2026-10-10T00:00:00Z',
          ),
          baseUrl: 'http://localhost:8000',
          httpClient: mockClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ruteGestureFinder = find.ancestor(
      of: find.text('Rute'),
      matching: find.byType(GestureDetector),
    );
    expect(ruteGestureFinder, findsOneWidget);
    final size = tester.getSize(ruteGestureFinder);
    expect(size.width, greaterThanOrEqualTo(48.0));
    expect(size.height, greaterThanOrEqualTo(48.0));

    // Button text size must be legible (fontSize >= 13)
    final textWidget = tester.widget<Text>(find.text('Rute'));
    expect(textWidget.style?.fontSize, greaterThanOrEqualTo(13.0));
  });

  testWidgets('Renders without overflow on 320dp narrow viewport with 48dp Rute button', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockClient = MockClient((request) async {
      final headers = {'content-type': 'application/json'};
      if (request.url.path.contains('/price/compare/')) {
        return http.Response(
          jsonEncode({
            'product_id': 'prod-001',
            'nama_produk': 'Indomie Goreng Rasa Ayam Bawang Ekstra Pedas Spesial',
            'comparison': [
              {
                'store_id': 's1',
                'nama_toko': 'Supermarket Sangat Panjang Namanya Sekali',
                'lat': -7.78,
                'lng': 110.40,
                'jarak_km': 15.8,
                'harga_terbaru': 125000,
              },
            ],
          }),
          200,
          headers: headers,
        );
      }
      if (request.url.path.contains('price-history')) {
        return http.Response(
          jsonEncode({'product_id': 'prod-001', 'total': 0, 'items': [], 'trend': []}),
          200,
          headers: headers,
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedProductPriceDetailPage(
          product: RecommendedProduct(
            id: 'prod-001',
            nama: 'Indomie Goreng Rasa Ayam Bawang Ekstra Pedas Spesial',
            kategori: 'Makanan Instan',
            harga: 125000.0,
            namaToko: 'Supermarket Sangat Panjang Namanya Sekali',
            updatedAt: '2026-10-10T00:00:00Z',
          ),
          baseUrl: 'http://localhost:8000',
          httpClient: mockClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final ruteFinder = find.ancestor(of: find.text('Rute'), matching: find.byType(GestureDetector));
    final ruteSize = tester.getSize(ruteFinder);
    expect(ruteSize.height, greaterThanOrEqualTo(48.0));
    expect(ruteSize.width, greaterThanOrEqualTo(48.0));
  });

  group('Product detail location and distance behavior', () {
    late FakeGeolocator fake;
    late GeolocatorPlatform original;

    setUp(() {
      original = GeolocatorPlatform.instance;
      fake = FakeGeolocator();
      GeolocatorPlatform.instance = fake;
      LocationService.testUsePlatform = true;
      LocationService.testResolveCalls = 0;
      LocationService.testPermissionRequests = 0;
      LocationService.clearCache();
    });

    tearDown(() {
      GeolocatorPlatform.instance = original;
      LocationService.testUsePlatform = false;
      LocationService.testOutcome = null;
      LocationService.clearCache();
    });

    testWidgets('with location: sends lat/lng and shows "Nama · ± 800 m"', (tester) async {
      Uri? compareUri;
      fake.permission = LocationPermission.whileInUse;

      final mockClient = MockClient((request) async {
        final headers = {'content-type': 'application/json'};
        if (request.url.path.contains('/price/compare/')) {
          compareUri = request.url;
          return http.Response(
            jsonEncode({
              'product_id': 'prod-001',
              'nama_produk': 'Indomie Goreng',
              'comparison': [
                {
                  'store_id': 's1',
                  'nama_toko': 'Super Indo Seturan',
                  'lat': -6.2088,
                  'lng': 106.8456,
                  'jarak_km': 0.8,
                  'harga_terbaru': 3500,
                },
              ],
            }),
            200,
            headers: headers,
          );
        }
        if (request.url.path.contains('price-history')) {
          return http.Response(
            jsonEncode({'product_id': 'prod-001', 'total': 0, 'items': [], 'trend': []}),
            200,
            headers: headers,
          );
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedProductPriceDetailPage(
            product: RecommendedProduct(
              id: 'prod-001',
              nama: 'Indomie Goreng',
              kategori: 'Makanan Instan',
              harga: 3500.0,
              namaToko: 'Super Indo Seturan',
              updatedAt: '2026-10-10T00:00:00Z',
            ),
            baseUrl: 'http://localhost:8000',
            httpClient: mockClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(compareUri, isNotNull);
      expect(compareUri!.queryParameters['lat'], isNotNull);
      expect(compareUri!.queryParameters['lng'], isNotNull);
      expect(fake.requestCount, 0, reason: 'Must not request permission from detail page');
      expect(find.text('Super Indo Seturan'), findsWidgets);
      expect(find.text('± 800 m'), findsOneWidget);
    });

    testWidgets('without location: does not send lat/lng, does not call requestPermission, and shows "Nama" without " · " and without "± 800 m"', (tester) async {
      Uri? compareUri;
      fake.permission = LocationPermission.denied;

      final mockClient = MockClient((request) async {
        final headers = {'content-type': 'application/json'};
        if (request.url.path.contains('/price/compare/')) {
          compareUri = request.url;
          return http.Response(
            jsonEncode({
              'product_id': 'prod-001',
              'nama_produk': 'Indomie Goreng',
              'comparison': [
                {
                  'store_id': 's1',
                  'nama_toko': 'Super Indo Seturan',
                  'lat': -6.2088,
                  'lng': 106.8456,
                  'jarak_km': null,
                  'harga_terbaru': 3500,
                },
              ],
            }),
            200,
            headers: headers,
          );
        }
        if (request.url.path.contains('price-history')) {
          return http.Response(
            jsonEncode({'product_id': 'prod-001', 'total': 0, 'items': [], 'trend': []}),
            200,
            headers: headers,
          );
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedProductPriceDetailPage(
            product: RecommendedProduct(
              id: 'prod-001',
              nama: 'Indomie Goreng',
              kategori: 'Makanan Instan',
              harga: 3500.0,
              namaToko: 'Super Indo Seturan',
              updatedAt: '2026-10-10T00:00:00Z',
            ),
            baseUrl: 'http://localhost:8000',
            httpClient: mockClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(compareUri, isNotNull);
      expect(compareUri!.queryParameters.containsKey('lat'), isFalse, reason: 'Must not send default lat without real location');
      expect(compareUri!.queryParameters.containsKey('lng'), isFalse, reason: 'Must not send default lng without real location');
      expect(fake.requestCount, 0, reason: 'Must not request permission from detail page');
      expect(find.text('Super Indo Seturan'), findsWidgets);
      expect(find.textContaining('± 800 m'), findsNothing);
      expect(find.textContaining('800 m'), findsNothing);
      expect(find.textContaining(' · '), findsNothing);
    });

    testWidgets('long store name "Manna Kampus (Mirota Kampus)" renders distance cleanly below store name without overflow on 320dp', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fake.permission = LocationPermission.whileInUse;

      final mockClient = MockClient((request) async {
        final headers = {'content-type': 'application/json'};
        if (request.url.path.contains('/price/compare/')) {
          return http.Response(
            jsonEncode({
              'product_id': 'prod-001',
              'nama_produk': 'Indomie Goreng',
              'comparison': [
                {
                  'store_id': 's1',
                  'nama_toko': 'Manna Kampus (Mirota Kampus)',
                  'lat': -6.2088,
                  'lng': 106.8456,
                  'jarak_km': 0.8,
                  'harga_terbaru': 3500,
                },
              ],
            }),
            200,
            headers: headers,
          );
        }
        if (request.url.path.contains('price-history')) {
          return http.Response(
            jsonEncode({'product_id': 'prod-001', 'total': 0, 'items': [], 'trend': []}),
            200,
            headers: headers,
          );
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedProductPriceDetailPage(
            product: RecommendedProduct(
              id: 'prod-001',
              nama: 'Indomie Goreng',
              kategori: 'Makanan Instan',
              harga: 3500.0,
              namaToko: 'Manna Kampus (Mirota Kampus)',
              updatedAt: '2026-10-10T00:00:00Z',
            ),
            baseUrl: 'http://localhost:8000',
            httpClient: mockClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(fake.requestCount, 0, reason: 'Must not request permission from detail page');
      expect(find.text('± 800 m'), findsOneWidget);
      expect(find.text('Manna Kampus (Mirota Kampus)'), findsWidgets);
    });

    testWidgets('LocationService.cachedPosition is used by detail page when userLat is null without requesting permission', (tester) async {
      LocationService.cachePosition(Position(
        latitude: -7.78,
        longitude: 110.40,
        timestamp: DateTime.now(),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ));

      Uri? compareUri;
      fake.permission = LocationPermission.denied;

      final mockClient = MockClient((request) async {
        final headers = {'content-type': 'application/json'};
        if (request.url.path.contains('/price/compare/')) {
          compareUri = request.url;
          return http.Response(
            jsonEncode({
              'product_id': 'prod-001',
              'nama_produk': 'Indomie Goreng',
              'comparison': [
                {
                  'store_id': 's1',
                  'nama_toko': 'Manna Kampus',
                  'lat': -7.78,
                  'lng': 110.40,
                  'jarak_km': 0.8,
                  'harga_terbaru': 3500,
                },
              ],
            }),
            200,
            headers: headers,
          );
        }
        if (request.url.path.contains('price-history')) {
          return http.Response(
            jsonEncode({'product_id': 'prod-001', 'total': 0, 'items': [], 'trend': []}),
            200,
            headers: headers,
          );
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedProductPriceDetailPage(
            product: RecommendedProduct(
              id: 'prod-001',
              nama: 'Indomie Goreng',
              kategori: 'Makanan Instan',
              harga: 3500.0,
              namaToko: 'Manna Kampus',
              updatedAt: '2026-10-10T00:00:00Z',
            ),
            baseUrl: 'http://localhost:8000',
            httpClient: mockClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(compareUri, isNotNull);
      expect(compareUri!.queryParameters['lat'], '-7.78');
      expect(compareUri!.queryParameters['lng'], '110.4');
      expect(find.text('± 800 m'), findsOneWidget);
    });
  });
}
