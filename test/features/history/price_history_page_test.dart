import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:rakoon_frontend/features/history/data/repositories/price_history_repository.dart';
import 'package:rakoon_frontend/features/history/presentation/pages/price_history_page.dart';
import 'package:rakoon_frontend/features/history/presentation/providers/price_history_notifier.dart';

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

      // Trigger frame to run postFrameCallback
      await widgetTester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete HTTP request to clean up pending futures
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
              {"store_id": 10, "store_name": "Indomaret", "price": 18500, "recorded_at": "2026-08-10T12:00:00Z"},
              {"store_id": 11, "store_name": "Alfamart", "price": 19000, "recorded_at": "2026-08-10T12:00:00Z"}
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
      expect(find.text('Rp 18.500'), findsWidgets);
      expect(find.text('Indomaret'), findsOneWidget);
      expect(find.text('Alfamart'), findsOneWidget);
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
  });
}
