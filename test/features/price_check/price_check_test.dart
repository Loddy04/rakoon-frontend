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
  });
}
