import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/widgets/price_freshness_label.dart';
import 'package:rakoon_frontend/widgets/product_card.dart';

void main() {
  group('ProductCard Unit & Formatter Tests', () {
    test('formatDistance formats meters when < 1.0 km and KM when >= 1.0 km', () {
      expect(ProductCard.formatDistance(0.35), '± 350 m');
      expect(ProductCard.formatDistance(0.5), '± 500 m');
      expect(ProductCard.formatDistance(0.6), '± 600 m');
      expect(ProductCard.formatDistance(0.85), '± 850 m');
      expect(ProductCard.formatDistance(0.05), '± 50 m');
      expect(ProductCard.formatDistance(1.0), '± 1,0 km');
      expect(ProductCard.formatDistance(1.2), '± 1,2 km');
      expect(ProductCard.formatDistance(1.25), '± 1,3 km');
      expect(ProductCard.formatDistance(2.0), '± 2,0 km');
      expect(ProductCard.formatDistance(null), isNull);
    });

    testWidgets('ProductCard never displays upload timestamps or just now text', (
      WidgetTester tester,
    ) async {
      final product = RecommendedProduct(
        id: 'test-3',
        nama: 'INDOMIE GORENG 85G',
        kategori: 'Makanan Instan',
        harga: 3100,
        namaToko: 'MANNA KAMPUS BABARSARI',
        jarakKm: 1.5,
        updatedAt: '2026-10-15T10:00:00Z',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ProductCard(product: product),
            ),
          ),
        ),
      );

      expect(find.text('just now'), findsNothing);
      expect(find.textContaining('ago'), findsNothing);
      expect(find.text('± 1,5 km'), findsOneWidget);
    });

    testWidgets('ProductCard renders distance and metadata without overflow at 320dp', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final product = RecommendedProduct(
        id: 'test-1',
        nama: 'INDOMIE GORENG 85G',
        kategori: 'Makanan Instan',
        harga: 3100,
        ukuran: 85,
        satuan: 'g',
        namaToko: 'MANNA KAMPUS BABARSARI',
        jarakKm: 0.8,
        updatedAt: '15 mnt lalu',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ProductCard(product: product),
            ),
          ),
        ),
      );

      expect(find.text('± 800 m'), findsOneWidget);
      expect(find.text(' · '), findsOneWidget);
      expect(find.text('15m ago'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ProductCard hides distance and separator when jarakKm is null', (
      WidgetTester tester,
    ) async {
      final product = RecommendedProduct(
        id: 'test-2',
        nama: 'INDOMIE GORENG 85G',
        kategori: 'Makanan Instan',
        harga: 3100,
        namaToko: 'MANNA KAMPUS BABARSARI',
        jarakKm: null,
        updatedAt: '15 mnt lalu',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ProductCard(product: product),
            ),
          ),
        ),
      );

      expect(find.text('± 800 m'), findsNothing);
      expect(find.text(' · '), findsNothing);
      expect(find.text('MANNA KAMPUS BABARSARI'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('RecommendedProduct.fromJson parses stale, missing = false', () {
      final base = {'id': 'p1', 'nama': 'Beras', 'harga': 68000, 'updated_at': '2026-01-10T00:00:00Z'};
      expect(RecommendedProduct.fromJson({...base, 'stale': true}).stale, isTrue);
      expect(RecommendedProduct.fromJson(base).stale, isFalse);
    });

    testWidgets('ProductCard shows PriceFreshnessLabel only when stale', (tester) async {
      RecommendedProduct build(bool stale) => RecommendedProduct(
            id: 'p1',
            nama: 'Beras',
            kategori: 'Makanan Pokok',
            harga: 68000,
            namaToko: 'Toko A',
            updatedAt: '2026-01-10T00:00:00Z',
            stale: stale,
          );

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: ProductCard(product: build(true))))),
      );
      expect(find.text('Harga per 10 Jan 2026'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: ProductCard(product: build(false))))),
      );
      expect(find.byType(PriceFreshnessLabel), findsNothing);
    });
  });
}
