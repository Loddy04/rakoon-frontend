import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/core/utils/brand_assets.dart';
import 'package:rakoon_frontend/services/recommendation_service.dart';
import 'package:rakoon_frontend/widgets/product_card.dart';

void main() {
  group('BrandAssets.getProductAsset strict keyword & word boundary matching (Tugas 2)', () {
    test('Hilo Milo is a Hilo product and must NOT match Milo asset (falls back to icon)', () {
      expect(BrandAssets.getProductAsset('Hilo Milo'), isNull);
    });

    test('Milo confectionery, bundled, or non-can variants fall back to icon (null)', () {
      expect(BrandAssets.getProductAsset('Milo Drink Bottled'), isNull);
      expect(BrandAssets.getProductAsset('Milo Small Box'), isNull);
      expect(BrandAssets.getProductAsset('Milo Bar'), isNull);
      expect(BrandAssets.getProductAsset('Milo Chocolate Bar'), isNull);
      expect(BrandAssets.getProductAsset('Milo Multibuy Bundle'), isNull);
    });

    test('Milo core products match Milo Calcium can asset', () {
      expect(BrandAssets.getProductAsset('Milo'), BrandAssets.miloCalcium);
      expect(BrandAssets.getProductAsset('Milo Calcium'), BrandAssets.miloCalcium);
    });

    test('Ultra Milk Cokelat matches Ultra Milk asset, NOT Milo asset (removed loose cokelat keyword)', () {
      expect(BrandAssets.getProductAsset('Ultra Milk Cokelat'), BrandAssets.ultramilk);
      expect(BrandAssets.getProductAsset('Ultra Milk Cokelat'), isNot(BrandAssets.miloCalcium));
    });

    test('Ultra Milk variants match Ultra Milk asset', () {
      expect(BrandAssets.getProductAsset('Ultra Milk Strawberry'), BrandAssets.ultramilk);
      expect(BrandAssets.getProductAsset('Ultra Milk Sachet'), BrandAssets.ultramilk);
    });

    test('Other specified brand products match their respective assets on word boundaries', () {
      expect(BrandAssets.getProductAsset('Indomie Mi Goreng'), BrandAssets.indomie);
      expect(BrandAssets.getProductAsset('Teh Pucuk Harum'), BrandAssets.pucukHarum);
      expect(BrandAssets.getProductAsset('Citro Green Tea'), BrandAssets.citroGreenTea);
      expect(BrandAssets.getProductAsset('Air Mineral'), BrandAssets.airMineral);
      expect(BrandAssets.getProductAsset('Bimoli Minyak Goreng 2L'), BrandAssets.bimoli);
      expect(BrandAssets.getProductAsset('Greenfields Ladoo'), BrandAssets.greenfields);
    });
  });

  group('ProductCard photo priority (Tugas 3)', () {
    testWidgets('foto_url always takes precedence over default brand asset', (tester) async {
      final productWithPhoto = RecommendedProduct(
        id: 'prod-photo-1',
        nama: 'Milo',
        kategori: 'Minuman',
        harga: 12000,
        namaToko: 'Toko Berkah',
        updatedAt: '2026-10-18T10:00:00Z',
        fotoUrl: 'https://example.com/custom_milo.png',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductCard(product: productWithPhoto),
          ),
        ),
      );

      // Network image should be present with the resolved photo_url
      final networkImageFinder = find.byType(Image);
      expect(networkImageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(networkImageFinder);
      expect(imageWidget.image, isA<NetworkImage>());
      final networkImage = imageWidget.image as NetworkImage;
      expect(networkImage.url, 'https://example.com/custom_milo.png');
    });

    testWidgets('default brand asset is used when foto_url is null and matches brand', (tester) async {
      final productWithoutPhoto = RecommendedProduct(
        id: 'prod-photo-2',
        nama: 'Milo',
        kategori: 'Minuman',
        harga: 12000,
        namaToko: 'Toko Berkah',
        updatedAt: '2026-10-18T10:00:00Z',
        fotoUrl: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductCard(product: productWithoutPhoto),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<AssetImage>());
      final assetImage = imageWidget.image as AssetImage;
      expect(assetImage.assetName, BrandAssets.miloCalcium);
    });

    testWidgets('fallback icon is used when foto_url is null and variant does not match brand asset', (tester) async {
      final productVariant = RecommendedProduct(
        id: 'prod-photo-3',
        nama: 'Milo Bar',
        kategori: 'Makanan Ringan',
        harga: 8000,
        namaToko: 'Toko Berkah',
        updatedAt: '2026-10-18T10:00:00Z',
        fotoUrl: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductCard(product: productVariant),
          ),
        ),
      );

      // No Image widget should be rendered, fallback icon container should be rendered
      expect(find.byType(Image), findsNothing);
      expect(find.byType(Icon), findsWidgets);
    });
  });
}
