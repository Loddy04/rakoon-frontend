import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/widgets/product_card.dart';

void main() {
  group('ProductCard Unit & Formatter Tests', () {
    test('formatDistance formats meters when < 1.0 km and KM when >= 1.0 km', () {
      expect(ProductCard.formatDistance(0.35), '350 M');
      expect(ProductCard.formatDistance(0.5), '500 M');
      expect(ProductCard.formatDistance(0.85), '850 M');
      expect(ProductCard.formatDistance(0.05), '50 M');
      expect(ProductCard.formatDistance(1.0), '1.0 KM');
      expect(ProductCard.formatDistance(1.2), '1.2 KM');
      expect(ProductCard.formatDistance(1.25), '1.3 KM');
      expect(ProductCard.formatDistance(2.0), '2.0 KM');
      expect(ProductCard.formatDistance(null), '800 M');
    });

    test('formatTimeAgo parses ISO strings and relative strings dynamically', () {
      final now = DateTime.now();
      final min15Ago = now.subtract(const Duration(minutes: 15)).toIso8601String();
      final hour2Ago = now.subtract(const Duration(hours: 2)).toIso8601String();
      final day3Ago = now.subtract(const Duration(days: 3)).toIso8601String();
      final week1Ago = now.subtract(const Duration(days: 7)).toIso8601String();

      expect(ProductCard.formatTimeAgo(min15Ago), '15m ago');
      expect(ProductCard.formatTimeAgo(hour2Ago), '2h ago');
      expect(ProductCard.formatTimeAgo(day3Ago), '3d ago');
      expect(ProductCard.formatTimeAgo(week1Ago), '1w ago');

      // Test relative fallback strings
      expect(ProductCard.formatTimeAgo('15 mnt lalu'), '15m ago');
      expect(ProductCard.formatTimeAgo('1 jam lalu'), '1h ago');
      expect(ProductCard.formatTimeAgo('2 jam lalu'), '2h ago');
      expect(ProductCard.formatTimeAgo('3 hari lalu'), '3d ago');
      expect(ProductCard.formatTimeAgo('1 minggu lalu'), '1w ago');
      expect(ProductCard.formatTimeAgo('Baru saja'), 'just now');
      expect(ProductCard.formatTimeAgo(null), 'just now');
    });

    testWidgets('ProductCard renders distance and time ago without overflow at 320dp', (
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

      expect(find.text('800 M'), findsOneWidget);
      expect(find.text('15m ago'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
