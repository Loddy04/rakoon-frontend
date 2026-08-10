class PriceHistoryItem {
  final String id;
  final String productId;
  final String storeId;
  final String storeName;
  final double price;
  final DateTime recordedAt;
  final String statusVerifikasi;

  const PriceHistoryItem({
    required this.id,
    required this.productId,
    required this.storeId,
    required this.storeName,
    required this.price,
    required this.recordedAt,
    this.statusVerifikasi = 'pending',
  });

  factory PriceHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawStoreId = json['store_id']?.toString() ?? '';
    final rawStoreName =
        json['store_name'] as String? ??
        (rawStoreId.isNotEmpty
            ? 'Toko ${rawStoreId.length > 8 ? rawStoreId.substring(0, 8) : rawStoreId}'
            : 'Toko');
    final num priceNum = (json['harga'] ?? json['price'] ?? 0) as num;
    final String dateStr =
        (json['recorded_at'] ??
                json['timestamp'] ??
                DateTime.now().toIso8601String())
            as String;

    return PriceHistoryItem(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      storeId: rawStoreId,
      storeName: rawStoreName,
      price: priceNum.toDouble(),
      recordedAt: DateTime.tryParse(dateStr) ?? DateTime.now(),
      statusVerifikasi: json['status_verifikasi'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'store_id': storeId,
      'store_name': storeName,
      'harga': price.toInt(),
      'recorded_at': recordedAt.toIso8601String(),
      'status_verifikasi': statusVerifikasi,
    };
  }
}

class PriceTrendPoint {
  final String date;
  final String? storeId;
  final double price;

  const PriceTrendPoint({
    required this.date,
    this.storeId,
    required this.price,
  });

  factory PriceTrendPoint.fromJson(Map<String, dynamic> json) {
    return PriceTrendPoint(
      date: json['date'] as String? ?? '',
      storeId: json['store_id']?.toString(),
      price: ((json['price'] ?? 0) as num).toDouble(),
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
  final String productId;
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
    final rawProdId = json['product_id']?.toString() ?? '';
    final rawProdName = json['product_name'] as String?;

    return PriceHistoryResponse(
      productId: rawProdId,
      productName: (rawProdName != null && rawProdName.isNotEmpty)
          ? rawProdName
          : 'Produk #${rawProdId.length > 8 ? rawProdId.substring(0, 8) : rawProdId}',
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
