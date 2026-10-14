import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/price_check/data/models/product_catalog_model.dart';
import 'package:rakoon_frontend/features/price_check/presentation/pages/price_check_catalog_page.dart';
import 'package:rakoon_frontend/features/price_check/presentation/pages/unified_product_price_detail_page.dart';
import 'package:rakoon_frontend/features/price_check/presentation/providers/price_check_provider.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/services/stores_service.dart';
import 'package:rakoon_frontend/widgets/price_freshness_label.dart';

void main() {
  group('PriceCheck Model & Provider Tests', () {
    test('CatalogProduct.fromJson parses valid JSON correctly', () {
      final json = {
        'id': 'p123',
        'nama': 'INDOMIE MI GORENG',
        'kategori': 'Makanan Instan',
        'ukuran': 85.0,
        'satuan': 'g',
        'harga_terendah': 3100.0,
        'nama_toko_terendah': 'Indomaret Babarsari 1',
        'jumlah_toko': 3,
        'foto_url': 'http://example.com/indomie.png',
        'updated_at': '2026-08-11T18:33:27Z',
      };

      final product = CatalogProduct.fromJson(json);

      expect(product.id, 'p123');
      expect(product.nama, 'INDOMIE MI GORENG');
      expect(product.kategori, 'Makanan Instan');
      expect(product.ukuran, 85.0);
      expect(product.satuan, 'g');
      expect(product.hargaTerendah, 3100.0);
      expect(product.namaTokoTerendah, 'Indomaret Babarsari 1');
      expect(product.jumlahToko, 3);
      expect(product.fotoUrl, 'http://example.com/indomie.png');
      expect(product.updatedAt, '2026-08-11T18:33:27Z');
      expect(product.stale, isFalse);
    });

    test('CatalogProduct.fromJson parses stale and updated_at, defaults to false when omitted', () {
      final staleJson = {
        'id': 'p124',
        'nama': 'Minyak Goreng 2L',
        'kategori': 'Makanan Pokok',
        'harga_terendah': 34000.0,
        'updated_at': '2026-01-10T00:00:00Z',
        'stale': true,
      };
      final staleProduct = CatalogProduct.fromJson(staleJson);
      expect(staleProduct.stale, isTrue);
      expect(staleProduct.updatedAt, '2026-01-10T00:00:00Z');

      final freshJson = {
        'id': 'p125',
        'nama': 'Beras 5kg',
        'kategori': 'Makanan Pokok',
        'harga_terendah': 68000.0,
        'updated_at': '2026-10-10T00:00:00Z',
        'stale': false,
      };
      final freshProduct = CatalogProduct.fromJson(freshJson);
      expect(freshProduct.stale, isFalse);

      final omittedJson = {
        'id': 'p126',
        'nama': 'Gula Pasir 1kg',
        'kategori': 'Makanan Pokok',
        'harga_terendah': 17500.0,
      };
      final omittedProduct = CatalogProduct.fromJson(omittedJson);
      expect(omittedProduct.stale, isFalse);
    });

    test('PriceCheckProvider initializes with default categories and search query', () {
      final provider = PriceCheckProvider();
      expect(provider.searchQuery, '');
      expect(provider.selectedCategory, 'Semua');
      expect(PriceCheckProvider.categories, contains('Semua'));
      expect(PriceCheckProvider.categories, contains('Makanan Instan'));
    });
  });

  group('PriceCheck Widget Render Tests', () {
    testWidgets('PriceCheckCatalogPage renders search bar and category chips', (widgetTester) async {
      await widgetTester.pumpWidget(
        const MaterialApp(
          home: PriceCheckCatalogPage(),
        ),
      );

      expect(find.text('Cek Harga'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Minuman'), findsOneWidget);
      expect(find.text('Makanan Instan'), findsOneWidget);
    });

    testWidgets('PriceCheckCatalogPage renders across viewports without overflow and supports scrolling', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final viewports = [
        const Size(320, 640),
        const Size(360, 800),
        const Size(390, 844),
        const Size(430, 932),
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: PriceCheckCatalogPage(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cek Harga'), findsOneWidget);
        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('UnifiedProductPriceDetailPage renders product summary header and chart title', (widgetTester) async {
      final mockProduct = RecommendedProduct(
        id: 'prod-001',
        nama: 'INDOMIE GORENG 85G',
        kategori: 'Makanan Instan',
        harga: 3100.0,
        ukuran: 85.0,
        satuan: 'g',
        namaToko: 'Indomaret Babarsari 1',
        jarakKm: 1.04,
        updatedAt: '2026-08-11T18:33:00Z',
      );

      await widgetTester.pumpWidget(
        MaterialApp(
          home: UnifiedProductPriceDetailPage(product: mockProduct),
        ),
      );

      expect(find.text('Detail Produk'), findsOneWidget);
      expect(find.text('INDOMIE GORENG 85G'), findsOneWidget);
      expect(find.text('Tersedia di Toko Terdekat'), findsOneWidget);
      expect(find.text('Riwayat Harga'), findsOneWidget);
      expect(find.text('30 Hari'), findsOneWidget);
      expect(find.text('3 Bulan'), findsOneWidget);
      expect(find.text('Semua Toko'), findsOneWidget);
    });

    testWidgets('UnifiedProductPriceDetailPage renders across narrow mobile viewports without overflow', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockProduct = RecommendedProduct(
        id: 'prod-001',
        nama: 'AIR MINERAL 600 ML',
        kategori: 'Minuman',
        harga: 2900.0,
        ukuran: 600.0,
        satuan: 'ml',
        namaToko: 'Super Indo Maguwoharjo',
        jarakKm: 0.289,
        updatedAt: '2026-08-11T18:33:00Z',
      );

      final viewports = [
        const Size(320, 640),
        const Size(360, 800),
        const Size(390, 844),
        const Size(430, 932),
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: UnifiedProductPriceDetailPage(product: mockProduct),
          ),
        );
        await tester.pump();

        expect(find.text('Detail Produk'), findsOneWidget);
        expect(find.text('Tersedia di Toko Terdekat'), findsOneWidget);
        expect(find.text('Riwayat Harga'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('UnifiedProductPriceDetailPage prioritizes network photo over local asset when fotoUrl is provided', (tester) async {
      final mockProductWithPhoto = RecommendedProduct(
        id: 'prod-001',
        nama: 'INDOMIE MI GORENG', // has local brand asset
        kategori: 'Makanan Instan',
        harga: 3100.0,
        namaToko: 'Indomaret Babarsari 1',
        updatedAt: '2026-08-11T18:33:00Z',
        fotoUrl: 'https://pzymqamrmudqrvvysjly.supabase.co/storage/v1/object/public/product-photos/indomie.jpg',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedProductPriceDetailPage(product: mockProductWithPhoto),
        ),
      );
      await tester.pump();

      // Should render Image.network for the photo, not the placeholder
      expect(find.byType(Image), findsWidgets);
      final images = tester.widgetList<Image>(find.byType(Image));
      final networkImages = images.where((img) => img.image is NetworkImage).toList();
      expect(networkImages.isNotEmpty, isTrue);
      expect((networkImages.first.image as NetworkImage).url, contains('product-photos/indomie.jpg'));
    });

    testWidgets('UnifiedProductPriceDetailPage renders local asset when fotoUrl is empty but name matches brand', (tester) async {
      final mockProductLocalOnly = RecommendedProduct(
        id: 'prod-002',
        nama: 'INDOMIE MI GORENG',
        kategori: 'Makanan Instan',
        harga: 3100.0,
        namaToko: 'Indomaret Babarsari 1',
        updatedAt: '2026-08-11T18:33:00Z',
        fotoUrl: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedProductPriceDetailPage(product: mockProductLocalOnly),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsWidgets);
      final images = tester.widgetList<Image>(find.byType(Image));
      final assetImages = images.where((img) => img.image is AssetImage).toList();
      expect(assetImages.isNotEmpty, isTrue);
      expect((assetImages.first.image as AssetImage).assetName, contains('indomie.png'));
    });

    testWidgets('UnifiedProductPriceDetailPage renders fallback icon when neither fotoUrl nor brand asset is available', (tester) async {
      final mockProductNoAssetNoPhoto = RecommendedProduct(
        id: 'prod-003',
        nama: 'PRODUK RANDOM TIDAK TERKENAL',
        kategori: 'Lainnya',
        harga: 15000.0,
        namaToko: 'Toko Kelontong',
        updatedAt: '2026-08-11T18:33:00Z',
        fotoUrl: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedProductPriceDetailPage(product: mockProductNoAssetNoPhoto),
        ),
      );
      await tester.pump();

      // Displays fallback shopping bag icon
      expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
    });

    testWidgets('PriceCheckCatalogPage renders PriceFreshnessLabel for stale products and omits for fresh ones', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/products')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'stale-1',
                'nama': 'Minyak Goreng Sawit 2L',
                'kategori': 'Makanan Pokok',
                'harga_terendah': 34000.0,
                'nama_toko_terendah': 'Indomaret',
                'jumlah_toko': 2,
                'updated_at': '2026-01-10T00:00:00Z',
                'stale': true,
              },
              {
                'id': 'fresh-1',
                'nama': 'Beras Premium 5kg',
                'kategori': 'Makanan Pokok',
                'harga_terendah': 68000.0,
                'nama_toko_terendah': 'Alfamart',
                'jumlah_toko': 1,
                'updated_at': '2026-10-10T00:00:00Z',
                'stale': false,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PriceCheckCatalogPage(
            baseUrl: 'http://localhost:8000',
            httpClient: mockClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that PriceFreshnessLabel appears for the stale item
      expect(find.byType(PriceFreshnessLabel), findsOneWidget);
      expect(find.text('Harga per 10 Jan 2026'), findsOneWidget);

      // Verify that both products render
      expect(find.text('Minyak Goreng Sawit 2L'), findsOneWidget);
      expect(find.text('Beras Premium 5kg'), findsOneWidget);
    });

    test('PriceCompareItem.fromJson parses stale and tanggal_update, missing stale = false', () {
      final stale = PriceCompareItem.fromJson({
        'store_id': 's1',
        'nama_toko': 'Toko A',
        'harga_terbaru': 3000,
        'tanggal_update': '2026-01-10T00:00:00Z',
        'stale': true,
      });
      expect(stale.stale, isTrue);
      expect(stale.tanggalUpdate, '2026-01-10T00:00:00Z');
      expect(PriceCompareItem.fromJson({'store_id': 's2'}).stale, isFalse);
    });

    testWidgets('UnifiedProductPriceDetailPage shows PriceFreshnessLabel only for stale compare rows', (tester) async {
      final mockClient = MockClient((request) async {
        final headers = {'content-type': 'application/json'};
        if (request.url.path.contains('/price/compare/')) {
          return http.Response(
            jsonEncode({
              'product_id': 'prod-001',
              'nama_produk': 'Indomie',
              'comparison': [
                {
                  'store_id': 's1',
                  'nama_toko': 'Toko Lama',
                  'jarak_km': 1.0,
                  'harga_terbaru': 3000,
                  'tanggal_update': '2026-01-10T00:00:00Z',
                  'stale': true,
                },
                {
                  'store_id': 's2',
                  'nama_toko': 'Toko Baru',
                  'jarak_km': 2.0,
                  'harga_terbaru': 3200,
                  'tanggal_update': '2026-10-10T00:00:00Z',
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
              nama: 'Indomie',
              kategori: 'Makanan Instan',
              harga: 3000.0,
              ukuran: 85.0,
              satuan: 'g',
              namaToko: 'Toko Lama',
              jarakKm: 1.0,
              updatedAt: '2026-01-10T00:00:00Z',
            ),
            baseUrl: 'http://localhost:8000',
            httpClient: mockClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PriceFreshnessLabel, skipOffstage: false), findsOneWidget);
      expect(find.text('Harga per 10 Jan 2026', skipOffstage: false), findsOneWidget);
    });
  });
}
