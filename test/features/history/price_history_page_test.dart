import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:rakoon_frontend/features/history/data/repositories/price_history_repository.dart';
import 'package:rakoon_frontend/features/history/presentation/pages/price_history_page.dart';
import 'package:rakoon_frontend/features/history/presentation/providers/price_history_notifier.dart';
import 'package:rakoon_frontend/features/history/presentation/widgets/date_range_selector.dart';
import 'package:rakoon_frontend/features/history/presentation/widgets/price_chart.dart';
import 'package:rakoon_frontend/features/history/presentation/widgets/store_history_list_item.dart';

void main() {
  group('PriceHistoryPage Widget Tests', () {
    testWidgets('renders loading indicator when state is loading', (
      widgetTester,
    ) async {
      final completer = Completer<http.Response>();
      final mockClient = MockClient((_) => completer.future);

      final repository = PriceHistoryRepository(client: mockClient);
      final notifier = PriceHistoryNotifier(repository: repository);

      await widgetTester.pumpWidget(
        MaterialApp(home: PriceHistoryPage(notifier: notifier, productId: 1)),
      );

      await widgetTester.pump();

      expect(find.byType(ShimmerPlaceholder), findsAtLeastNWidgets(1));

      completer.complete(
        http.Response('''{
            "product_id": 1,
            "product_name": "Susu UHT 1L",
            "items": [],
            "trend": []
          }''', 200),
      );
      await widgetTester.pumpAndSettle();
    });

    testWidgets('renders product header and store list on success', (
      widgetTester,
    ) async {
      final mockClient = MockClient((_) async {
        return http.Response('''{
            "product_id": 1,
            "product_name": "Susu UHT 1L",
            "items": [
              {"store_id": "10", "store_name": "Indomaret", "price": 18500, "recorded_at": "2026-08-10T12:00:00Z"},
              {"store_id": "11", "store_name": "Alfamart", "price": 19000, "recorded_at": "2026-08-10T12:00:00Z"}
            ],
            "trend": []
          }''', 200);
      });

      final repository = PriceHistoryRepository(client: mockClient);
      final notifier = PriceHistoryNotifier(repository: repository);

      await widgetTester.pumpWidget(
        MaterialApp(home: PriceHistoryPage(notifier: notifier, productId: 1)),
      );

      await widgetTester.pumpAndSettle();

      expect(find.text('Riwayat Harga'), findsOneWidget);
      expect(find.text('Susu UHT 1L'), findsOneWidget);
      expect(find.text('Rp 19.000'), findsWidgets); // latest price is last chronological element
      expect(find.descendant(of: find.byType(StoreHistoryListView), matching: find.text('Indomaret')), findsOneWidget);
      expect(find.descendant(of: find.byType(StoreHistoryListView), matching: find.text('Alfamart')), findsOneWidget);
      expect(find.text('Termurah'), findsOneWidget);
    });

    testWidgets('renders error view on API failure', (widgetTester) async {
      final mockClient = MockClient((_) async {
        return http.Response('{"detail": "Product not found"}', 404);
      });

      final repository = PriceHistoryRepository(client: mockClient);
      final notifier = PriceHistoryNotifier(repository: repository);

      await widgetTester.pumpWidget(
        MaterialApp(home: PriceHistoryPage(notifier: notifier, productId: 99)),
      );

      await widgetTester.pumpAndSettle();

      expect(find.text('Produk tidak ditemukan'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
    });

    testWidgets('renders DateRangeSelector and PriceChart on success', (
      widgetTester,
    ) async {
      final mockClient = MockClient((request) async {
        return http.Response('''{
            "product_id": 1,
            "product_name": "Susu UHT 1L",
            "items": [
              {"store_id": "10", "store_name": "Indomaret", "price": 18500, "recorded_at": "2026-08-10T12:00:00Z"}
            ],
            "trend": [
              {"date": "2026-08-09", "store_id": "10", "price": 18000},
              {"date": "2026-08-10", "store_id": "10", "price": 18500}
            ]
          }''', 200);
      });

      final repository = PriceHistoryRepository(client: mockClient);
      final notifier = PriceHistoryNotifier(repository: repository);

      await widgetTester.pumpWidget(
        MaterialApp(home: PriceHistoryPage(notifier: notifier, productId: 1)),
      );

      await widgetTester.pumpAndSettle();

      expect(find.byType(DateRangeSelector), findsOneWidget);
      expect(find.byType(PriceChart), findsOneWidget);

      expect(find.text('1M'), findsOneWidget);
      expect(find.text('3M'), findsOneWidget);
      expect(find.text('6M'), findsOneWidget);
      expect(find.text('Semua'), findsOneWidget);
    });

    testWidgets('Latest price mapping and dynamic trend calculation - Naik', (
      widgetTester,
    ) async {
      final mockClient = MockClient((_) async {
        return http.Response('''{
            "product_id": 1,
            "product_name": "Susu UHT 1L",
            "items": [
              {"store_id": "10", "store_name": "Indomaret", "price": 10000, "recorded_at": "2026-08-01T12:00:00Z"},
              {"store_id": "10", "store_name": "Indomaret", "price": 12000, "recorded_at": "2026-08-02T12:00:00Z"}
            ],
            "trend": []
          }''', 200);
      });

      final repository = PriceHistoryRepository(client: mockClient);
      final notifier = PriceHistoryNotifier(repository: repository);

      await widgetTester.pumpWidget(
        MaterialApp(home: PriceHistoryPage(notifier: notifier, productId: 1)),
      );
      await widgetTester.pumpAndSettle();

      // Latest price matches last element
      expect(find.text('Rp 12.000'), findsWidgets);
      // Trend shows Naik
      expect(find.text('Harga naik'), findsOneWidget);
    });

    testWidgets('Latest price mapping and dynamic trend calculation - Turun', (
      widgetTester,
    ) async {
      final mockClient = MockClient((_) async {
        return http.Response('''{
            "product_id": 1,
            "product_name": "Susu UHT 1L",
            "items": [
              {"store_id": "10", "store_name": "Indomaret", "price": 12000, "recorded_at": "2026-08-01T12:00:00Z"},
              {"store_id": "10", "store_name": "Indomaret", "price": 10000, "recorded_at": "2026-08-02T12:00:00Z"}
            ],
            "trend": []
          }''', 200);
      });

      final repository = PriceHistoryRepository(client: mockClient);
      final notifier = PriceHistoryNotifier(repository: repository);

      await widgetTester.pumpWidget(
        MaterialApp(home: PriceHistoryPage(notifier: notifier, productId: 1)),
      );
      await widgetTester.pumpAndSettle();

      expect(find.text('Rp 10.000'), findsWidgets);
      expect(find.text('Harga turun'), findsOneWidget);
    });

    testWidgets('Latest price mapping and dynamic trend calculation - Stabil', (
      widgetTester,
    ) async {
      final mockClient = MockClient((_) async {
        return http.Response('''{
            "product_id": 1,
            "product_name": "Susu UHT 1L",
            "items": [
              {"store_id": "10", "store_name": "Indomaret", "price": 10000, "recorded_at": "2026-08-01T12:00:00Z"},
              {"store_id": "10", "store_name": "Indomaret", "price": 10000, "recorded_at": "2026-08-02T12:00:00Z"}
            ],
            "trend": []
          }''', 200);
      });

      final repository = PriceHistoryRepository(client: mockClient);
      final notifier = PriceHistoryNotifier(repository: repository);

      await widgetTester.pumpWidget(
        MaterialApp(home: PriceHistoryPage(notifier: notifier, productId: 1)),
      );
      await widgetTester.pumpAndSettle();

      expect(find.text('Rp 10.000'), findsWidgets);
      expect(find.text('Harga stabil'), findsOneWidget);
    });

    testWidgets('Dynamic trend calculation - Insufficient data', (
      widgetTester,
    ) async {
      final mockClient = MockClient((_) async {
        return http.Response('''{
            "product_id": 1,
            "product_name": "Susu UHT 1L",
            "items": [
              {"store_id": "10", "store_name": "Indomaret", "price": 10000, "recorded_at": "2026-08-01T12:00:00Z"}
            ],
            "trend": []
          }''', 200);
      });

      final repository = PriceHistoryRepository(client: mockClient);
      final notifier = PriceHistoryNotifier(repository: repository);

      await widgetTester.pumpWidget(
        MaterialApp(home: PriceHistoryPage(notifier: notifier, productId: 1)),
      );
      await widgetTester.pumpAndSettle();

      expect(find.text('Belum cukup data'), findsOneWidget);
    });

    testWidgets('Store grouping and cheapest pricing options', (
      widgetTester,
    ) async {
      final mockClient = MockClient((_) async {
        return http.Response('''{
            "product_id": 1,
            "product_name": "Susu UHT 1L",
            "items": [
              {"store_id": "10", "store_name": "Indomaret", "price": 15000, "recorded_at": "2026-08-01T12:00:00Z"},
              {"store_id": "10", "store_name": "Indomaret", "price": 10000, "recorded_at": "2026-08-02T12:00:00Z"},
              {"store_id": "11", "store_name": "Alfamart", "price": 10000, "recorded_at": "2026-08-02T12:00:00Z"}
            ],
            "trend": []
          }''', 200);
      });

      final repository = PriceHistoryRepository(client: mockClient);
      final notifier = PriceHistoryNotifier(repository: repository);

      await widgetTester.pumpWidget(
        MaterialApp(home: PriceHistoryPage(notifier: notifier, productId: 1)),
      );
      await widgetTester.pumpAndSettle();

      // Checks that Store A (Indomaret) was updated to its latest price (10000)
      // and duplicates are grouped. Since both Indomaret and Alfamart have price 10000 (equal lowest),
      // they should both display "Harga sama" instead of "Termurah"
      expect(find.text('Harga sama'), findsNWidgets(2));
      expect(find.text('Termurah'), findsNothing);
    });

    testWidgets('Store filter UI chip selection', (
      widgetTester,
    ) async {
      final mockClient = MockClient((request) async {
        return http.Response('''{
            "product_id": 1,
            "product_name": "Susu UHT 1L",
            "items": [
              {"store_id": "10", "store_name": "Indomaret", "price": 10000, "recorded_at": "2026-08-01T12:00:00Z"},
              {"store_id": "11", "store_name": "Alfamart", "price": 11000, "recorded_at": "2026-08-02T12:00:00Z"}
            ],
            "trend": []
          }''', 200);
      });

      final repository = PriceHistoryRepository(client: mockClient);
      final notifier = PriceHistoryNotifier(repository: repository);

      await widgetTester.pumpWidget(
        MaterialApp(home: PriceHistoryPage(notifier: notifier, productId: 1)),
      );
      await widgetTester.pumpAndSettle();

      // Verify filter selector chips render
      expect(find.byType(StoreFilterSelector), findsOneWidget);
      expect(find.descendant(of: find.byType(StoreFilterSelector), matching: find.text('Semua Toko')), findsOneWidget);
      expect(find.descendant(of: find.byType(StoreFilterSelector), matching: find.text('Indomaret')), findsOneWidget);
      expect(find.descendant(of: find.byType(StoreFilterSelector), matching: find.text('Alfamart')), findsOneWidget);
    });

    testWidgets('Single point rendering in chart', (
      widgetTester,
    ) async {
      final mockClient = MockClient((_) async {
        return http.Response('''{
            "product_id": 1,
            "product_name": "Susu UHT 1L",
            "items": [
              {"store_id": "10", "store_name": "Indomaret", "price": 10000, "recorded_at": "2026-08-01T12:00:00Z"}
            ],
            "trend": [
              {"date": "2026-08-01", "store_id": "10", "price": 10000}
            ]
          }''', 200);
      });

      final repository = PriceHistoryRepository(client: mockClient);
      final notifier = PriceHistoryNotifier(repository: repository);

      await widgetTester.pumpWidget(
        MaterialApp(home: PriceHistoryPage(notifier: notifier, productId: 1)),
      );
      await widgetTester.pumpAndSettle();

      expect(find.byType(PriceChart), findsOneWidget);
    });

    testWidgets('Responsive viewport layout validation', (
      widgetTester,
    ) async {
      final mockClient = MockClient((_) async {
        return http.Response('''{
            "product_id": 1,
            "product_name": "Susu UHT 1L",
            "items": [
              {"store_id": "10", "store_name": "Indomaret Super Sudirman Panjang", "price": 10000, "recorded_at": "2026-08-01T12:00:00Z"}
            ],
            "trend": []
          }''', 200);
      });

      final repository = PriceHistoryRepository(client: mockClient);
      final notifier = PriceHistoryNotifier(repository: repository);

      // 320dp viewport width
      widgetTester.view.physicalSize = const Size(320, 600);
      widgetTester.view.devicePixelRatio = 1.0;

      await widgetTester.pumpWidget(
        MaterialApp(home: PriceHistoryPage(notifier: notifier, productId: 1)),
      );
      await widgetTester.pumpAndSettle();

      // Make sure layout does not throw overflow errors
      expect(widgetTester.takeException(), isNull);

      // Reset physical size after test
      widgetTester.view.resetPhysicalSize();
      widgetTester.view.resetDevicePixelRatio();
    });
  });
}
