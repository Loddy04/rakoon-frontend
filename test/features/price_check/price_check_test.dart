import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/features/price_check/data/models/product_catalog_model.dart';
import 'package:rakoon_frontend/features/price_check/presentation/pages/price_check_catalog_page.dart';
import 'package:rakoon_frontend/features/price_check/presentation/pages/unified_product_price_detail_page.dart';
import 'package:rakoon_frontend/features/price_check/presentation/providers/price_check_provider.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';

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

      expect(find.text('CEK HARGA'), findsOneWidget);
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

        expect(find.text('CEK HARGA'), findsOneWidget);
        expect(find.text('Grafik Tren Fluktuasi Harga'), findsOneWidget);
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

      expect(find.text('DETAIL HARGA PRODUK'), findsOneWidget);
      expect(find.text('INDOMIE GORENG 85G'), findsOneWidget);
      expect(find.text('TREN FLUKTUASI HARGA'), findsOneWidget);
      expect(find.text('PERBANDINGAN DI TOKO TERDEKAT'), findsOneWidget);
      expect(find.text('1M'), findsOneWidget);
      expect(find.text('3M'), findsOneWidget);
      expect(find.text('6M'), findsOneWidget);
      expect(find.text('Semua'), findsOneWidget);
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

        expect(find.text('PERBANDINGAN DI TOKO TERDEKAT'), findsOneWidget);
        expect(find.text('Lihat di Peta'), findsOneWidget);
        expect(find.text('DETAIL HARGA PRODUK'), findsOneWidget);
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
  });
}
