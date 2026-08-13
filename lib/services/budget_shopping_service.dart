import 'dart:convert';
import 'package:http/http.dart' as http;

class BudgetItemInput {
  final String productId;
  final int qty;

  BudgetItemInput({
    required this.productId,
    required this.qty,
  });

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'qty': qty,
      };
}

class BudgetRecommendRequest {
  final double budget;
  final List<BudgetItemInput> items;

  BudgetRecommendRequest({
    required this.budget,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'budget': budget,
        'items': items.map((i) => i.toJson()).toList(),
      };
}

class BudgetItemResult {
  final String productId;
  final String namaProduk;
  final int qty;
  final double hargaSatuan;
  final double subtotal;

  BudgetItemResult({
    required this.productId,
    required this.namaProduk,
    required this.qty,
    required this.hargaSatuan,
    required this.subtotal,
  });

  factory BudgetItemResult.fromJson(Map<String, dynamic> json) {
    return BudgetItemResult(
      productId: json['product_id'] as String? ?? '',
      namaProduk: json['nama_produk'] as String? ?? 'Produk',
      qty: json['qty'] as int? ?? 1,
      hargaSatuan: (json['harga_satuan'] as num? ?? 0).toDouble(),
      subtotal: (json['subtotal'] as num? ?? 0).toDouble(),
    );
  }
}

class StoreInfoOutput {
  final String storeId;
  final String nama;
  final String? alamat;
  final double? lat;
  final double? lng;

  StoreInfoOutput({
    required this.storeId,
    required this.nama,
    this.alamat,
    this.lat,
    this.lng,
  });

  factory StoreInfoOutput.fromJson(Map<String, dynamic> json) {
    return StoreInfoOutput(
      storeId: json['store_id'] as String? ?? '',
      nama: json['nama'] as String? ?? 'Toko',
      alamat: json['alamat'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }
}

class ProductAvailability {
  final String productId;
  final String namaProduk;
  final bool isAvailable;
  final double? hargaTerendah;
  final String? tokoTerendah;

  ProductAvailability({
    required this.productId,
    required this.namaProduk,
    required this.isAvailable,
    this.hargaTerendah,
    this.tokoTerendah,
  });

  factory ProductAvailability.fromJson(Map<String, dynamic> json) {
    return ProductAvailability(
      productId: json['product_id'] as String? ?? '',
      namaProduk: json['nama_produk'] as String? ?? 'Produk',
      isAvailable: json['is_available'] as bool? ?? false,
      hargaTerendah: (json['harga_terendah'] as num?)?.toDouble(),
      tokoTerendah: json['toko_terendah'] as String?,
    );
  }
}

class AlternativeStoreOutput {
  final StoreInfoOutput storeInfo;
  final double totalCost;
  final double remainingBudget;
  final bool isFullMatch;
  final int matchedProductsCount;
  final List<BudgetItemResult> items;

  AlternativeStoreOutput({
    required this.storeInfo,
    required this.totalCost,
    required this.remainingBudget,
    required this.isFullMatch,
    required this.matchedProductsCount,
    required this.items,
  });

  factory AlternativeStoreOutput.fromJson(Map<String, dynamic> json) {
    return AlternativeStoreOutput(
      storeInfo: StoreInfoOutput.fromJson(json['store_info'] as Map<String, dynamic>),
      totalCost: (json['total_cost'] as num? ?? 0).toDouble(),
      remainingBudget: (json['remaining_budget'] as num? ?? 0).toDouble(),
      isFullMatch: json['is_full_match'] as bool? ?? false,
      matchedProductsCount: json['matched_products_count'] as int? ?? 0,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => BudgetItemResult.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class BudgetRecommendResponse {
  final double budget;
  final double totalCost;
  final double remainingBudget;
  final bool isFullMatch;
  final StoreInfoOutput? recommendedStore;
  final List<BudgetItemResult> items;
  final String explanation;
  final List<ProductAvailability>? productAvailabilities;
  final List<AlternativeStoreOutput>? storeAlternatives;

  BudgetRecommendResponse({
    required this.budget,
    required this.totalCost,
    required this.remainingBudget,
    required this.isFullMatch,
    this.recommendedStore,
    required this.items,
    required this.explanation,
    this.productAvailabilities,
    this.storeAlternatives,
  });

  factory BudgetRecommendResponse.fromJson(Map<String, dynamic> json) {
    return BudgetRecommendResponse(
      budget: (json['budget'] as num? ?? 0).toDouble(),
      totalCost: (json['total_cost'] as num? ?? 0).toDouble(),
      remainingBudget: (json['remaining_budget'] as num? ?? 0).toDouble(),
      isFullMatch: json['is_full_match'] as bool? ?? false,
      recommendedStore: json['recommended_store'] != null
          ? StoreInfoOutput.fromJson(json['recommended_store'] as Map<String, dynamic>)
          : null,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => BudgetItemResult.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      explanation: json['explanation'] as String? ?? '',
      productAvailabilities: (json['product_availabilities'] as List<dynamic>?)
          ?.map((e) => ProductAvailability.fromJson(e as Map<String, dynamic>))
          .toList(),
      storeAlternatives: (json['store_alternatives'] as List<dynamic>?)
          ?.map((e) => AlternativeStoreOutput.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BudgetShoppingService {
  static Future<BudgetRecommendResponse> evaluateBudgetShopping({
    required String baseUrl,
    required BudgetRecommendRequest request,
  }) async {
    final cleanUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final Uri url = Uri.parse('$cleanUrl/budget-shopping/recommend');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return BudgetRecommendResponse.fromJson(json);
      } else {
        throw Exception('Gagal mendapatkan rekomendasi budget (HTTP ${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('Gagal menghubungi server backend: $e');
    }
  }
}
