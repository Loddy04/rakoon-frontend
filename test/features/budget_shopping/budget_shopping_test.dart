import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:rakoon_frontend/features/budget_shopping/budget_shopping_screen.dart';
import 'package:rakoon_frontend/features/budget_shopping/budget_result_screen.dart';
import 'package:rakoon_frontend/features/budget_shopping/utils/budget_parser.dart';
import 'package:rakoon_frontend/services/budget_shopping_service.dart';

void main() {
  group('BudgetParser Unit Tests', () {
    test('Currency parser correctly handles Indonesian thousand separators', () {
      expect(BudgetParser.parse('100000'), 100000.0);
      expect(BudgetParser.parse('100.000'), 100000.0);
      expect(BudgetParser.parse('1.000.000'), 1000000.0);
      expect(BudgetParser.parse('Rp 100.000'), 100000.0);
      expect(BudgetParser.parse('Rp100.000'), 100000.0);
      expect(BudgetParser.parse('100.5'), 100.5);
      expect(BudgetParser.parse('100000,50'), 100000.5);
      expect(BudgetParser.parse('1.000.000,50'), 1000000.5);
    });

    test('Currency parser rejects invalid values', () {
      expect(BudgetParser.parse(''), isNull);
      expect(BudgetParser.parse('abc'), isNull);
      expect(BudgetParser.parse('0'), isNull);
      expect(BudgetParser.parse('-100'), isNull);
      expect(BudgetParser.parse('Rp -100'), isNull);
    });
  });

  group('BudgetShoppingScreen Widget Tests - Debounce & Lifecycle', () {
    testWidgets('Rapid typing only triggers search after 300ms', (
      WidgetTester tester,
    ) async {
      int searchCallCount = 0;
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/products/')) {
          searchCallCount++;
          return http.Response('[]', 200);
        }
        return http.Response('[]', 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: BudgetShoppingScreen(baseUrl: 'http://localhost:8000'),
          ),
        );

        final searchFieldFinder = find.byType(TextField).last;

        await tester.enterText(searchFieldFinder, 's');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.enterText(searchFieldFinder, 'su');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.enterText(searchFieldFinder, 'sus');
        await tester.pump(const Duration(milliseconds: 100));

        expect(searchCallCount, 0);

        await tester.pump(const Duration(milliseconds: 250));
        expect(searchCallCount, 1);
      }, () => mockClient);
    });

    testWidgets('Previous debounce is cancelled when typing continues', (
      WidgetTester tester,
    ) async {
      int searchCallCount = 0;
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/products/')) {
          searchCallCount++;
          return http.Response('[]', 200);
        }
        return http.Response('[]', 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: BudgetShoppingScreen(baseUrl: 'http://localhost:8000'),
          ),
        );

        final searchFieldFinder = find.byType(TextField).last;

        await tester.enterText(searchFieldFinder, 's');
        await tester.pump(const Duration(milliseconds: 200));

        await tester.enterText(searchFieldFinder, 'su');
        await tester.pump(const Duration(milliseconds: 200));

        expect(searchCallCount, 0);

        await tester.pump(const Duration(milliseconds: 150));
        expect(searchCallCount, 1);
      }, () => mockClient);
    });

    testWidgets('Stale search response cannot overwrite newer results', (
      WidgetTester tester,
    ) async {
      final controller1 = Completer<http.Response>();
      final controller2 = Completer<http.Response>();
      int requestIndex = 0;

      final mockClient = MockClient((request) async {
        requestIndex++;
        if (requestIndex == 1) {
          return controller1.future;
        } else {
          return controller2.future;
        }
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: BudgetShoppingScreen(baseUrl: 'http://localhost:8000'),
          ),
        );

        final searchFieldFinder = find.byType(TextField).last;

        await tester.enterText(searchFieldFinder, 'susu');
        await tester.pump(const Duration(milliseconds: 350));

        await tester.enterText(searchFieldFinder, 'roti');
        await tester.pump(const Duration(milliseconds: 350));

        controller2.complete(http.Response(jsonEncode([
          {
            'id': '2',
            'nama': 'Roti Tawar',
            'kategori': 'Makanan',
            'ukuran': 1.0,
            'satuan': 'pcs'
          }
        ]), 200));
        await tester.pumpAndSettle();

        expect(find.text('Roti Tawar'), findsOneWidget);

        controller1.complete(http.Response(jsonEncode([
          {
            'id': '1',
            'nama': 'Susu Bubuk',
            'kategori': 'Susu',
            'ukuran': 400.0,
            'satuan': 'g'
          }
        ]), 200));
        await tester.pumpAndSettle();

        expect(find.text('Roti Tawar'), findsOneWidget);
        expect(find.text('Susu Bubuk'), findsNothing);
      }, () => mockClient);
    });

    testWidgets('Search after widget disposal does not call setState', (
      WidgetTester tester,
    ) async {
      final completer = Completer<http.Response>();
      final mockClient = MockClient((request) => completer.future);

      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: BudgetShoppingScreen(baseUrl: 'http://localhost:8000'),
          ),
        );

        final searchFieldFinder = find.byType(TextField).last;
        await tester.enterText(searchFieldFinder, 'susu');
        await tester.pump(const Duration(milliseconds: 350));

        await tester.pumpWidget(Container());

        completer.complete(http.Response('[]', 200));
        await tester.pump();

        expect(tester.takeException(), isNull);
      }, () => mockClient);
    });

    testWidgets('Budget submission uses normalized parsed value', (
      WidgetTester tester,
    ) async {
      double? capturedBudget;

      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: BudgetShoppingScreen(baseUrl: 'http://localhost:8000'),
          ),
        );

        final budgetFieldFinder = find.byType(TextField).first;
        await tester.enterText(budgetFieldFinder, '250.000');

        final searchFieldFinder = find.byType(TextField).last;
        await tester.enterText(searchFieldFinder, 'susu');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ListTile));
        await tester.pumpAndSettle();

        await tester.tap(find.text('🏆 Hitung Rekomendasi Belanja'));
        await tester.pumpAndSettle();
      }, () => MockClient((request) async {
        if (request.url.path.contains('/products/')) {
          return http.Response(jsonEncode([
            {
              'id': '1',
              'nama': 'Susu UHT 1L',
              'kategori': 'Susu',
              'ukuran': 1000.0,
              'satuan': 'ml'
            }
          ]), 200);
        }
        if (request.url.path.endsWith('/budget-shopping/recommend')) {
          final body = jsonDecode(request.body);
          capturedBudget = (body['budget'] as num?)?.toDouble();
          return http.Response('''{
            "budget": 250000.0,
            "total_cost": 85000.0,
            "remaining_budget": 165000.0,
            "is_full_match": true,
            "recommended_store": {
              "store_id": "1",
              "nama": "Toko A"
            },
            "items": [],
            "explanation": "Success"
          }''', 200);
        }
        return http.Response('[]', 200);
      }));

      expect(capturedBudget, 250000.0);
    });
  });

  group('BudgetResultScreen Widget Tests - Warning States', () {
    testWidgets('Over-budget response renders shortfall and itemized details', (
      WidgetTester tester,
    ) async {
      final response = BudgetRecommendResponse(
        budget: 10000.0,
        totalCost: 15000.0,
        remainingBudget: -5000.0,
        isFullMatch: true,
        recommendedStore: StoreInfoOutput(storeId: '10', nama: 'Indomaret Gatsu'),
        items: [
          BudgetItemResult(
            productId: 'c111',
            namaProduk: 'Susu UHT 1L',
            qty: 1,
            hargaSatuan: 15000.0,
            subtotal: 15000.0,
          ),
        ],
        explanation: 'Budget tidak mencukupi.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BudgetResultScreen(result: response),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Kekurangan Budget'), findsOneWidget);
      expect(find.text('Indomaret Gatsu'), findsWidgets);
      expect(find.text('Rp 15.000'), findsWidgets);
      expect(find.text('Rp 5.000'), findsOneWidget);
      expect(find.text('Susu UHT 1L'), findsOneWidget);
    });

    testWidgets('No-full-match response renders available and unavailable products', (
      WidgetTester tester,
    ) async {
      final response = BudgetRecommendResponse(
        budget: 50000.0,
        totalCost: 0.0,
        remainingBudget: 50000.0,
        isFullMatch: false,
        recommendedStore: null,
        items: [],
        explanation: 'Tidak ditemukan toko lengkap.',
        productAvailabilities: [
          ProductAvailability(
            productId: 'c111',
            namaProduk: 'Susu UHT 1L',
            isAvailable: true,
            hargaTerendah: 15000.0,
            tokoTerendah: 'Alfamart Gatsu',
          ),
          ProductAvailability(
            productId: 'c222',
            namaProduk: 'Roti Tawar',
            isAvailable: false,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BudgetResultScreen(result: response),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tidak Ditemukan Toko'), findsOneWidget);
      expect(find.text('📋 Status Ketersediaan Barang'), findsOneWidget);
      expect(find.text('Susu UHT 1L'), findsOneWidget);
      expect(find.text('Tersedia terendah di Alfamart Gatsu'), findsOneWidget);
      expect(find.text('Rp 15.000'), findsOneWidget);
      expect(find.text('Roti Tawar'), findsOneWidget);
      expect(find.text('Tidak tersedia di toko mana pun'), findsOneWidget);
    });
  });

  group('BudgetResultScreen Widget Tests - Store Alternatives', () {
    testWidgets('Primary and alternatives render sorted by total cost with price differences', (
      WidgetTester tester,
    ) async {
      final response = BudgetRecommendResponse(
        budget: 100000.0,
        totalCost: 60000.0,
        remainingBudget: 40000.0,
        isFullMatch: true,
        recommendedStore: StoreInfoOutput(storeId: '1', nama: 'Store A'),
        items: [],
        explanation: 'Sukses',
        storeAlternatives: [
          AlternativeStoreOutput(
            storeInfo: StoreInfoOutput(storeId: '2', nama: 'Store B'),
            totalCost: 75000.0,
            remainingBudget: 25000.0,
            isFullMatch: true,
            matchedProductsCount: 2,
            items: [],
          ),
          AlternativeStoreOutput(
            storeInfo: StoreInfoOutput(storeId: '3', nama: 'Store C'),
            totalCost: 90000.0,
            remainingBudget: 10000.0,
            isFullMatch: true,
            matchedProductsCount: 2,
            items: [],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BudgetResultScreen(result: response),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Store A'), findsNWidgets(2));
      expect(find.text('Rp 60.000'), findsWidgets);

      expect(find.text('🏪 Alternatif Toko Lainnya'), findsOneWidget);

      expect(find.text('Store B'), findsOneWidget);
      expect(find.text('Sisa Budget: Rp 25.000'), findsOneWidget);
      expect(find.text('+Rp 15.000'), findsOneWidget);

      expect(find.text('Store C'), findsOneWidget);
      expect(find.text('Sisa Budget: Rp 10.000'), findsOneWidget);
      expect(find.text('+Rp 30.000'), findsOneWidget);
    });
  });

  group('BudgetShopping Responsive UI/UX Hardening - Phase 3.2.4 Widget Tests', () {
    testWidgets('320dp budget screen renders without overflow', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockClient = MockClient((request) async => http.Response('[]', 200));

      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: BudgetShoppingScreen(baseUrl: 'http://localhost:8000'),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(BudgetShoppingScreen), findsOneWidget);
      }, () => mockClient);
    });

    testWidgets('320dp result screen renders without overflow', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final response = BudgetRecommendResponse(
        budget: 100000.0,
        totalCost: 60000.0,
        remainingBudget: 40000.0,
        isFullMatch: true,
        recommendedStore: StoreInfoOutput(storeId: '1', nama: 'Store A'),
        items: [],
        explanation: 'Sukses',
        storeAlternatives: [
          AlternativeStoreOutput(
            storeInfo: StoreInfoOutput(storeId: '2', nama: 'Store B'),
            totalCost: 75000.0,
            remainingBudget: 25000.0,
            isFullMatch: true,
            matchedProductsCount: 2,
            items: [],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BudgetResultScreen(result: response),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(BudgetResultScreen), findsOneWidget);
    });

    testWidgets('360dp result screen renders without overflow', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final response = BudgetRecommendResponse(
        budget: 100000.0,
        totalCost: 60000.0,
        remainingBudget: 40000.0,
        isFullMatch: true,
        recommendedStore: StoreInfoOutput(storeId: '1', nama: 'Store A'),
        items: [],
        explanation: 'Sukses',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BudgetResultScreen(result: response),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Long product name and store name do not overflow', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final response = BudgetRecommendResponse(
        budget: 100000.0,
        totalCost: 60000.0,
        remainingBudget: 40000.0,
        isFullMatch: true,
        recommendedStore: StoreInfoOutput(
          storeId: '1',
          nama: 'Toko Serba Ada Abadi Makmur Jaya Sentosa Cabang Raya Jakarta Selatan Barat',
          alamat: 'Jalan Raya Menteng Central Jakarta Nomor 45 RT 02 RW 03 Indonesia',
        ),
        items: [
          BudgetItemResult(
            productId: 'c111',
            namaProduk: 'Susu Formula Bayi Rasa Madu Paling Gurih Dan Enak Sekali Merk Rakoon Jaya Abadi',
            qty: 1,
            hargaSatuan: 60000.0,
            subtotal: 60000.0,
          )
        ],
        explanation: 'Sukses dengan toko yang memiliki nama terpanjang di database.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BudgetResultScreen(result: response),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Toko Serba Ada'), findsWidgets);
      expect(find.textContaining('Susu Formula Bayi'), findsOneWidget);
    });

    testWidgets('Quantity controls remain usable on narrow screens', (WidgetTester tester) async {
      final handle = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/products/')) {
          return http.Response(jsonEncode([
            {
              'id': '1',
              'nama': 'Susu UHT 1L',
              'kategori': 'Susu',
              'ukuran': 1000.0,
              'satuan': 'ml'
            }
          ]), 200);
        }
        return http.Response('[]', 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: BudgetShoppingScreen(baseUrl: 'http://localhost:8000'),
          ),
        );
        await tester.pumpAndSettle();

        final searchField = find.byType(TextField).last;
        await tester.enterText(searchField, 'susu');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ListTile));
        await tester.pumpAndSettle();

        // Increment button check
        final incrementButton = find.bySemanticsLabel(RegExp(r'^Tambah kuantitas Susu UHT 1L'));
        expect(incrementButton, findsOneWidget);
        await tester.tap(incrementButton);
        await tester.pumpAndSettle();

        expect(find.text('2'), findsOneWidget);

        // Decrement button check
        final decrementButton = find.bySemanticsLabel(RegExp(r'^Kurangi kuantitas Susu UHT 1L'));
        expect(decrementButton, findsOneWidget);
        await tester.tap(decrementButton);
        await tester.pumpAndSettle();

        expect(find.text('1'), findsOneWidget);

        // Minimum limit check: tapping decrement again at qty = 1 should keep it at 1
        await tester.tap(decrementButton);
        await tester.pumpAndSettle();
        expect(find.text('1'), findsOneWidget);

        // Explicit deletion check
        final deleteButton = find.bySemanticsLabel(RegExp(r'^Hapus barang Susu UHT 1L'));
        expect(deleteButton, findsOneWidget);
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        expect(find.text('1'), findsNothing);
      }, () => mockClient);

      handle.dispose();
    });

    testWidgets('Empty search state renders correctly', (WidgetTester tester) async {
      final mockClient = MockClient((request) async => http.Response('[]', 200));

      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: BudgetShoppingScreen(baseUrl: 'http://localhost:8000'),
          ),
        );

        final searchField = find.byType(TextField).last;
        await tester.enterText(searchField, 'tidakada');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(find.text('Tidak ada produk yang ditemukan untuk "tidakada"'), findsOneWidget);
      }, () => mockClient);
    });

    testWidgets('Error state renders correctly', (WidgetTester tester) async {
      final mockClient = MockClient((request) async => http.Response('Server Error', 500));

      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: BudgetShoppingScreen(baseUrl: 'http://localhost:8000'),
          ),
        );

        final searchField = find.byType(TextField).last;
        await tester.enterText(searchField, 'susu');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(find.textContaining('Gagal mencari produk'), findsOneWidget);
      }, () => mockClient);
    });

    testWidgets('Accessibility semantics exist for critical controls', (WidgetTester tester) async {
      final handle = tester.ensureSemantics();
      final mockClient = MockClient((request) async => http.Response('[]', 200));

      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: BudgetShoppingScreen(baseUrl: 'http://localhost:8000'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel(RegExp(r'^Kolom input budget belanja')), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'^Kolom pencarian barang kebutuhan')), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'^Hitung rekomendasi belanja')), findsOneWidget);
      }, () => mockClient);

      handle.dispose();
    });
  });
}
