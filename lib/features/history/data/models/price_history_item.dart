class PriceHistoryItem {
  final int storeId;
  final String storeName;
  final double price;
  final DateTime recordedAt;

  const PriceHistoryItem({
    required this.storeId,
    required this.storeName,
    required this.price,
    required this.recordedAt,
  });

  factory PriceHistoryItem.fromJson(Map<String, dynamic> json) {
    return PriceHistoryItem(
      storeId: json['store_id'] as int,
      storeName: json['store_name'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'store_id': storeId,
      'store_name': storeName,
      'price': price,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }
}

class PriceTrendPoint {
  final String date;
  final int? storeId;
  final double price;

  const PriceTrendPoint({
    required this.date,
    this.storeId,
    required this.price,
  });

  factory PriceTrendPoint.fromJson(Map<String, dynamic> json) {
    return PriceTrendPoint(
      date: json['date'] as String,
      storeId: json['store_id'] as int?,
      price: (json['price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      if (storeId != null) 'store_id': storeId,
      'price': price,
    };
  }
}

class PriceHistoryResponse {
  final int productId;
  final String productName;
  final List<PriceHistoryItem> items;
  final List<PriceTrendPoint> trend;

  const PriceHistoryResponse({
    required this.productId,
    required this.productName,
    required this.items,
    required this.trend,
  });

  factory PriceHistoryResponse.fromJson(Map<String, dynamic> json) {
    return PriceHistoryResponse(
      productId: json['product_id'] as int,
      productName: json['product_name'] as String? ?? '',
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => PriceHistoryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      trend:
          (json['trend'] as List<dynamic>?)
              ?.map((e) => PriceTrendPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'items': items.map((e) => e.toJson()).toList(),
      'trend': trend.map((e) => e.toJson()).toList(),
    };
  }
}
