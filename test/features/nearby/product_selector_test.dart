import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/home_screen.dart';
import 'package:rakoon_frontend/features/nearby/presentation/widgets/product_selector_bottom_sheet.dart';
import 'package:rakoon_frontend/services/products_service.dart';

void main() {
  group('ProductSelectorBottomSheet Tests', () {
    testWidgets('Renders ProductSelectorBottomSheet with header and search field', (
      WidgetTester tester,
    ) async {
      Product? selectedProduct;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductSelectorBottomSheet(
              baseUrl: 'http://localhost:8000',
              onProductSelected: (prod) {
                selectedProduct = prod;
              },
            ),
          ),
        ),
      );

      // Verify header and description
      expect(
        find.text('Pilih Produk untuk Dibandingkan'),
        findsOneWidget,
      );
      expect(
        find.text('Bandingkan harga produk ini di seluruh toko sekitar Anda.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);

      expect(selectedProduct, isNull);
    });

    testWidgets('Opening product selector from HomeScreen Bandingkan Harga card', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(baseUrl: 'http://localhost:8000'),
        ),
      );
      await tester.pumpAndSettle();

      // Find "Bandingkan Harga" action card
      expect(find.text('Bandingkan Harga'), findsOneWidget);

      // Ensure visible and tap on the card to open product selector modal
      await tester.ensureVisible(find.text('Bandingkan Harga'));
      await tester.tap(find.text('Bandingkan Harga'));
      await tester.pumpAndSettle();

      // Verify bottom sheet modal opened
      expect(find.byType(ProductSelectorBottomSheet), findsOneWidget);
      expect(find.text('Pilih Produk untuk Dibandingkan'), findsOneWidget);
    });
  });
}
