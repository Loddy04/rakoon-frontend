import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    testWidgets('Opening product selector as bottom sheet modal and interacting with it', (
      WidgetTester tester,
    ) async {
      Product? selectedProduct;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) => ProductSelectorBottomSheet(
                      baseUrl: 'http://localhost:8000',
                      onProductSelected: (prod) {
                        selectedProduct = prod;
                      },
                    ),
                  );
                },
                child: const Text('Buka Selector'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap button to open modal
      await tester.tap(find.text('Buka Selector'));
      await tester.pumpAndSettle();

      // Verify bottom sheet modal opened
      expect(find.byType(ProductSelectorBottomSheet), findsOneWidget);
      expect(find.text('Pilih Produk untuk Dibandingkan'), findsOneWidget);
      expect(selectedProduct, isNull);
    });
  });
}
