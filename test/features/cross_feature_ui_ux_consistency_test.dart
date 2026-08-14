import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/core/utils/currency_formatter.dart';
import 'package:rakoon_frontend/features/budget_shopping/budget_result_screen.dart';
import 'package:rakoon_frontend/features/history/presentation/pages/product_history_list_page.dart';
import 'package:rakoon_frontend/features/recommendation/recommendation_screen.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/services/budget_shopping_service.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';
import 'package:rakoon_frontend/widgets/status_badge.dart';

void main() {
  setUp(() {
    AuthService.mockSession = null;
  });

  tearDown(() {
    AuthService.mockSession = null;
  });

  group('Cross-Feature UI/UX Consistency Tests', () {
    test('Currency Formatter formats numbers consistently with standard Indonesian convention', () {
      expect(formatRp(0), 'Rp 0');
      expect(formatRp(500), 'Rp 500');
      expect(formatRp(1000), 'Rp 1.000');
      expect(formatRp(18500), 'Rp 18.500');
      expect(formatRp(1500000), 'Rp 1.500.000');
    });

    testWidgets('StatusBadge handles multiple status keywords properly with design tokens', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Column(
              children: [
                StatusBadge(status: 'Termurah'),
                StatusBadge(status: 'Best Value'),
                StatusBadge(status: 'Harga stabil'),
                StatusBadge(status: 'Harga naik'),
                StatusBadge(status: 'Warning'),
                StatusBadge(status: 'Info Lain'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Termurah'), findsOneWidget);
      expect(find.text('Best Value'), findsOneWidget);
      expect(find.text('Harga stabil'), findsOneWidget);
      expect(find.text('Harga naik'), findsOneWidget);
      expect(find.text('Warning'), findsOneWidget);
      expect(find.text('Info Lain'), findsOneWidget);
    });

    testWidgets('ProductHistoryListPage renders with correct appbar title and search hint without overflow across 320dp to 430dp', (tester) async {
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
            theme: AppTheme.light,
            home: const ProductHistoryListPage(baseUrl: 'http://127.0.0.1:8000'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Riwayat Produk Pindai'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('BudgetResultScreen renders across viewports (320dp, 360dp, 390dp, 430dp) with zero overflows', (tester) async {
      final dummyResponse = BudgetRecommendResponse(
        budget: 100000,
        totalCost: 85000,
        remainingBudget: 15000,
        isFullMatch: true,
        explanation: 'Ditemukan toko terbaik dengan total harga paling efisien.',
        recommendedStore: StoreInfoOutput(
          storeId: 'store-1',
          nama: 'Superindo Sudirman',
          alamat: 'Jl. Jend. Sudirman No. 45',
          lat: -6.2088,
          lng: 106.8456,
        ),
        items: [
          BudgetItemResult(
            productId: 'p-1',
            namaProduk: 'Minyak Goreng 2L',
            qty: 2,
            hargaSatuan: 32000,
            subtotal: 64000,
          ),
          BudgetItemResult(
            productId: 'p-2',
            namaProduk: 'Gula Pasir 1kg',
            qty: 1,
            hargaSatuan: 21000,
            subtotal: 21000,
          ),
        ],
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
            theme: AppTheme.light,
            home: BudgetResultScreen(result: dummyResponse),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Rekomendasi Belanja'), findsOneWidget);
        expect(find.text('Superindo Sudirman'), findsWidgets);
        expect(find.text('Minyak Goreng 2L'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('RecommendationScreen renders empty and evaluated states without overflow across viewports', (tester) async {
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
            theme: AppTheme.light,
            home: const RecommendationScreen(
              baseUrl: 'http://127.0.0.1:8000',
              initialCandidates: [],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Best Value Recommendation'), findsOneWidget);
        expect(find.text('Tidak ada produk valid yang dapat dibandingkan.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
