import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:rakoon_frontend/features/history/data/models/price_history_item.dart';
import 'package:rakoon_frontend/features/history/data/repositories/price_history_repository.dart';
import 'package:rakoon_frontend/features/history/presentation/providers/price_history_notifier.dart';

void main() {
  group('PriceHistoryNotifier', () {
    test('initial state is correct', () {
      final repository = PriceHistoryRepository(
        client: MockClient((_) async => http.Response('', 200)),
      );
      final notifier = PriceHistoryNotifier(repository: repository);

      expect(notifier.status, PriceHistoryStatus.initial);
      expect(notifier.response, isNull);
      expect(notifier.errorMessage, isNull);
      expect(notifier.selectedRange, 'all');
      expect(notifier.selectedStoreId, isNull);
    });

    test(
      'fetchPriceHistory updates state to success when data returned',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('''{
            "product_id": 1,
            "product_name": "Susu UHT",
            "items": [{"store_id": 10, "store_name": "Indomaret", "price": 18500, "recorded_at": "2026-08-10T12:00:00Z"}],
            "trend": [{"date": "2026-08-10", "store_id": 10, "price": 18500}]
          }''', 200);
        });

        final repository = PriceHistoryRepository(client: mockClient);
        final notifier = PriceHistoryNotifier(repository: repository);

        final future = notifier.fetchPriceHistory(productId: 1);
        expect(notifier.isLoading, isTrue);

        await future;

        expect(notifier.isSuccess, isTrue);
        expect(notifier.response, isNotNull);
        expect(notifier.response!.productName, 'Susu UHT');
        expect(notifier.response!.items.length, 1);
      },
    );

    test(
      'fetchPriceHistory updates state to empty when empty arrays returned',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('''{
            "product_id": 1,
            "product_name": "Produk Kosong",
            "items": [],
            "trend": []
          }''', 200);
        });

        final repository = PriceHistoryRepository(client: mockClient);
        final notifier = PriceHistoryNotifier(repository: repository);

        await notifier.fetchPriceHistory(productId: 1);

        expect(notifier.isEmpty, isTrue);
      },
    );

    test('fetchPriceHistory updates state to error on 404', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"detail": "Product not found"}', 404);
      });

      final repository = PriceHistoryRepository(client: mockClient);
      final notifier = PriceHistoryNotifier(repository: repository);

      await notifier.fetchPriceHistory(productId: 999);

      expect(notifier.isError, isTrue);
      expect(notifier.errorMessage, 'Produk tidak ditemukan');
    });

    test('setRange updates selectedRange and re-fetches data', () async {
      late Uri lastRequestedUrl;
      final mockClient = MockClient((request) async {
        lastRequestedUrl = request.url;
        return http.Response('''{
            "product_id": 1,
            "product_name": "Susu UHT",
            "items": [],
            "trend": []
          }''', 200);
      });

      final repository = PriceHistoryRepository(client: mockClient);
      final notifier = PriceHistoryNotifier(repository: repository);

      notifier.setRange(1, '1m');
      await Future.delayed(Duration.zero);

      expect(notifier.selectedRange, '1m');
      expect(lastRequestedUrl.queryParameters['range'], '1m');
    });
  });
}
