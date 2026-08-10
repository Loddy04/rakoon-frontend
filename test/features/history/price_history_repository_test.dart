import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/history/data/repositories/price_history_repository.dart';

void main() {
  group('PriceHistoryRepository', () {
    const String baseUrl = 'http://localhost:8000';

    test('getPriceHistory returns PriceHistoryResponse on 200 OK', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/products/1/price-history');
        expect(request.url.queryParameters['store_id'], '10');
        expect(request.url.queryParameters['range'], '1m');

        final responseBody = {
          "product_id": 1,
          "product_name": "Susu UHT",
          "items": [
            {
              "store_id": 10,
              "store_name": "Indomaret",
              "price": 18500,
              "recorded_at": "2026-08-10T12:00:00Z",
            },
          ],
          "trend": [
            {"date": "2026-08-10", "store_id": 10, "price": 18500},
          ],
        };

        return http.Response(jsonEncode(responseBody), 200);
      });

      final repository = PriceHistoryRepository(
        client: mockClient,
        baseUrl: baseUrl,
      );
      final result = await repository.getPriceHistory(
        productId: 1,
        storeId: 10,
        range: '1m',
      );

      expect(result.productId, 1);
      expect(result.productName, 'Susu UHT');
      expect(result.items.length, 1);
      expect(result.trend.length, 1);
    });

    test('getPriceHistory handles empty arrays on 200 OK', () async {
      final mockClient = MockClient((request) async {
        final responseBody = {
          "product_id": 2,
          "product_name": "Produk Baru",
          "items": [],
          "trend": [],
        };
        return http.Response(jsonEncode(responseBody), 200);
      });

      final repository = PriceHistoryRepository(
        client: mockClient,
        baseUrl: baseUrl,
      );
      final result = await repository.getPriceHistory(productId: 2);

      expect(result.productId, 2);
      expect(result.items, isEmpty);
      expect(result.trend, isEmpty);
    });

    test('getPriceHistory throws ProductNotFoundException on 404', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({"detail": "Product not found"}), 404);
      });

      final repository = PriceHistoryRepository(
        client: mockClient,
        baseUrl: baseUrl,
      );

      expect(
        () async => await repository.getPriceHistory(productId: 999),
        throwsA(isA<ProductNotFoundException>()),
      );
    });

    test('getPriceHistory throws PriceHistoryApiException on 500', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Error', 500);
      });

      final repository = PriceHistoryRepository(
        client: mockClient,
        baseUrl: baseUrl,
      );

      expect(
        () async => await repository.getPriceHistory(productId: 1),
        throwsA(isA<PriceHistoryApiException>()),
      );
    });
  });
}
