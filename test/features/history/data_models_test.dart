import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/features/history/data/models/price_history_item.dart';

void main() {
  group('PriceHistoryItem & PriceTrendPoint & PriceHistoryResponse Models', () {
    test('should parse fromJson and convert toJson correctly', () {
      final jsonInput = {
        "product_id": 1,
        "product_name": "Susu UHT Full Cream 1L",
        "items": [
          {
            "store_id": 10,
            "store_name": "Indomaret",
            "price": 18500,
            "recorded_at": "2026-08-10T12:00:00.000Z",
          },
        ],
        "trend": [
          {"date": "2026-08-10", "store_id": 10, "price": 18500},
        ],
      };

      final response = PriceHistoryResponse.fromJson(jsonInput);

      expect(response.productId, '1');
      expect(response.productName, "Susu UHT Full Cream 1L");
      expect(response.items.length, 1);
      expect(response.items.first.storeId, '10');
      expect(response.items.first.storeName, "Indomaret");
      expect(response.items.first.price, 18500.0);
      expect(
        response.items.first.recordedAt,
        DateTime.parse("2026-08-10T12:00:00.000Z"),
      );

      expect(response.trend.length, 1);
      expect(response.trend.first.date, "2026-08-10");
      expect(response.trend.first.storeId, '10');
      expect(response.trend.first.price, 18500.0);

      final toJsonResult = response.toJson();
      expect(toJsonResult['product_id'], '1');
      expect(toJsonResult['product_name'], "Susu UHT Full Cream 1L");
      expect((toJsonResult['items'] as List).length, 1);
      expect((toJsonResult['trend'] as List).length, 1);
    });

    test('should handle empty items and trend arrays', () {
      final emptyJson = {
        "product_id": 99,
        "product_name": "Produk Tanpa Histori",
        "items": [],
        "trend": [],
      };

      final response = PriceHistoryResponse.fromJson(emptyJson);

      expect(response.productId, '99');
      expect(response.items, isEmpty);
      expect(response.trend, isEmpty);
    });
  });
}
