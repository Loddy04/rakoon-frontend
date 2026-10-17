import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:rakoon_frontend/features/auth/presentation/widgets/google_sign_in_button.dart';
import 'package:rakoon_frontend/features/budget_shopping/budget_shopping_screen.dart';
import 'package:rakoon_frontend/features/nearby/nearby_stores_screen.dart';
import 'package:rakoon_frontend/features/price_check/presentation/pages/price_check_catalog_page.dart';
import 'package:rakoon_frontend/features/price_check/presentation/pages/unified_product_price_detail_page.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';

void main() {
  group('Touch targets >= 48x48 and Tooltips/Semantics', () {
    testWidgets('google_sign_in_button google_login_button has touch target >= 48dp height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(onSuccess: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final googleBtn = find.byKey(const Key('google_login_button'));
      expect(googleBtn, findsOneWidget);
      final size = tester.getSize(googleBtn);
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    });

    testWidgets('nearby_stores_screen close button has touch target >= 48x48dp and tooltip Tutup', (tester) async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/stores/nearby')) {
          return http.Response(
            jsonEncode({
              'stores': [
                {
                  'store_id': 's1',
                  'nama': 'Super Indo Babarsari',
                  'alamat': 'Jl. Babarsari No. 10',
                  'lat': -7.78,
                  'lng': 110.40,
                  'jarak_km': 0.5,
                }
              ],
              'total': 1,
            }),
            200,
          );
        }
        if (request.url.path.contains('/products')) {
          return http.Response(jsonEncode({'items': [], 'total': 0, 'has_more': false}), 200);
        }
        return http.Response('[]', 200);
      });

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: NearbyStoresScreen(
              baseUrl: 'http://localhost:8000',
              httpClient: client,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap store card to open detail modal
        await tester.tap(find.text('Super Indo Babarsari'));
        await tester.pumpAndSettle();

        final closeBtnFinder = find.byTooltip('Tutup');
        expect(closeBtnFinder, findsOneWidget);
        final size = tester.getSize(closeBtnFinder);
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));
      });
    });

    testWidgets('budget_shopping_screen action buttons have touch targets >= 48x48 and Indonesian tooltips', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: BudgetShoppingScreen(
              baseUrl: 'http://localhost:8000',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Floating hide bar button
        final hideBtnFinder = find.byIcon(Icons.keyboard_arrow_down_rounded);
        expect(hideBtnFinder, findsOneWidget);
        final hideBtnParent = find.ancestor(of: hideBtnFinder, matching: find.byType(IconButton));
        expect(hideBtnParent, findsOneWidget);
        final hideSize = tester.getSize(hideBtnParent);
        expect(hideSize.width, greaterThanOrEqualTo(48.0));
        expect(hideSize.height, greaterThanOrEqualTo(48.0));
        final hideWidget = tester.widget<IconButton>(hideBtnParent);
        expect(hideWidget.tooltip, isNotNull);
        expect(hideWidget.tooltip, isNotEmpty);
      }, () => MockClient((_) async => http.Response('[]', 200)));
    });
  });

  group('320dp narrow viewport overflow tests', () {
    testWidgets('PriceCheckCatalogPage renders without overflow on 320dp', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final client = MockClient((request) async {
        if (request.url.path.contains('/products/catalog')) {
          return http.Response(jsonEncode([
            {
              'id': 'p1',
              'nama': 'Minyak Goreng Sawit 2L Sania Spesial Promo Murah',
              'kategori': 'Makanan Pokok',
              'harga_terendah': 34500,
              'nama_toko_terendah': 'Super Indo Babarsari',
              'jumlah_toko': 3,
              'updated_at': '2026-10-10T00:00:00Z',
              'stale': false,
            }
          ]), 200);
        }
        return http.Response('[]', 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PriceCheckCatalogPage(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('NearbyStoresScreen renders without overflow on 320dp', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final client = MockClient((request) async {
        if (request.url.path.contains('/stores/nearby')) {
          return http.Response(jsonEncode({
            'stores': [
              {
                'store_id': 's1',
                'nama': 'Manna Kampus (Mirota Kampus) Babarsari Terdekat',
                'alamat': 'Jl. Babarsari No. 100 Depok Sleman DIY',
                'lat': -7.78,
                'lng': 110.40,
                'jarak_km': 0.85,
              }
            ],
            'total': 1,
          }), 200);
        }
        return http.Response('[]', 200);
      });

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: NearbyStoresScreen(
              baseUrl: 'http://localhost:8000',
              httpClient: client,
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

      expect(tester.takeException(), isNull);
    });

    testWidgets('UnifiedProductPriceDetailPage renders without overflow on 320dp with long store name', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final client = MockClient((request) async {
        if (request.url.path.contains('/price/compare/')) {
          return http.Response(jsonEncode({
            'product_id': 'prod-001',
            'nama_produk': 'Indomie Mi Instan Goreng Spesial Jumbo',
            'comparison': [
              {
                'store_id': 's1',
                'nama_toko': 'Manna Kampus (Mirota Kampus) Swalayan Modern',
                'lat': -7.78,
                'lng': 110.40,
                'jarak_km': 1.25,
                'harga_terbaru': 3500,
                'tanggal_update': '2026-10-10T00:00:00Z',
              }
            ],
          }), 200);
        }
        if (request.url.path.contains('price-history')) {
          return http.Response(jsonEncode({
            'product_id': 'prod-001',
            'total': 0,
            'items': [],
            'trend': [],
          }), 200);
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedProductPriceDetailPage(
            product: RecommendedProduct(
              id: 'prod-001',
              nama: 'Indomie Mi Instan Goreng Spesial Jumbo',
              kategori: 'Makanan Instan',
              harga: 3500.0,
              namaToko: 'Manna Kampus (Mirota Kampus) Swalayan Modern',
              updatedAt: '2026-10-10T00:00:00Z',
            ),
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
