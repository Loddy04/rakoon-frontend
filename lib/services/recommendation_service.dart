import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/services/api_error_messages.dart';

class RecommendationCandidate {
  final String? productId;
  final String? namaProduk;
  final double? harga;
  final double? ukuran;
  final String? satuan;
  final String? kategori;

  RecommendationCandidate({
    this.productId,
    this.namaProduk,
    this.harga,
    this.ukuran,
    this.satuan,
    this.kategori,
  });

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'nama_produk': namaProduk,
      'harga': harga,
      'ukuran': ukuran,
      'satuan': satuan,
      'kategori': kategori,
    };
  }
}

class RankedProductItem {
  final String? productId;
  final String namaProduk;
  final double harga;
  final double ukuranOriginal;
  final String satuanOriginal;
  final double normalizedUkuran;
  final String baseUnit;
  final double hargaPerUnit;
  final String unitPriceLabel;
  final int rank;
  final bool isBestValue;
  final String? badge;
  final String explanation;

  RankedProductItem({
    this.productId,
    required this.namaProduk,
    required this.harga,
    required this.ukuranOriginal,
    required this.satuanOriginal,
    required this.normalizedUkuran,
    required this.baseUnit,
    required this.hargaPerUnit,
    required this.unitPriceLabel,
    required this.rank,
    required this.isBestValue,
    this.badge,
    required this.explanation,
  });

  factory RankedProductItem.fromJson(Map<String, dynamic> json) {
    return RankedProductItem(
      productId: json['product_id']?.toString(),
      namaProduk: json['nama_produk'] ?? 'Tanpa Nama',
      harga: (json['harga'] as num).toDouble(),
      ukuranOriginal: (json['ukuran_original'] as num).toDouble(),
      satuanOriginal: json['satuan_original'] ?? '',
      normalizedUkuran: (json['normalized_ukuran'] as num).toDouble(),
      baseUnit: json['base_unit'] ?? '',
      hargaPerUnit: (json['harga_per_unit'] as num).toDouble(),
      unitPriceLabel: json['unit_price_label'] ?? '',
      rank: json['rank'] ?? 1,
      isBestValue: json['is_best_value'] ?? false,
      badge: json['badge'],
      explanation: json['explanation'] ?? '',
    );
  }
}

class ExcludedProductItem {
  final String? productId;
  final String? namaProduk;
  final double? harga;
  final double? ukuran;
  final String? satuan;
  final String reason;

  ExcludedProductItem({
    this.productId,
    this.namaProduk,
    this.harga,
    this.ukuran,
    this.satuan,
    required this.reason,
  });

  factory ExcludedProductItem.fromJson(Map<String, dynamic> json) {
    return ExcludedProductItem(
      productId: json['product_id']?.toString(),
      namaProduk: json['nama_produk'],
      harga: json['harga'] != null ? (json['harga'] as num).toDouble() : null,
      ukuran: json['ukuran'] != null ? (json['ukuran'] as num).toDouble() : null,
      satuan: json['satuan'],
      reason: json['reason'] ?? 'Produk tidak memenuhi syarat perbandingan.',
    );
  }
}

class DimensionRecommendationGroup {
  final String dimension;
  final String dimensionLabel;
  final String baseUnit;
  final bool isComparable;
  final String? message;
  final RankedProductItem? bestValue;
  final List<RankedProductItem> rankedItems;

  DimensionRecommendationGroup({
    required this.dimension,
    required this.dimensionLabel,
    required this.baseUnit,
    required this.isComparable,
    this.message,
    this.bestValue,
    required this.rankedItems,
  });

  factory DimensionRecommendationGroup.fromJson(Map<String, dynamic> json) {
    final List<dynamic> itemsJson = json['ranked_items'] ?? [];
    return DimensionRecommendationGroup(
      dimension: json['dimension'] ?? '',
      dimensionLabel: json['dimension_label'] ?? '',
      baseUnit: json['base_unit'] ?? '',
      isComparable: json['is_comparable'] ?? false,
      message: json['message'],
      bestValue: json['best_value'] != null
          ? RankedProductItem.fromJson(json['best_value'])
          : null,
      rankedItems: itemsJson.map((e) => RankedProductItem.fromJson(e)).toList(),
    );
  }
}

class CategoryRecommendationGroup {
  final String kategori;
  final List<DimensionRecommendationGroup> dimensionGroups;

  CategoryRecommendationGroup({
    required this.kategori,
    required this.dimensionGroups,
  });

  factory CategoryRecommendationGroup.fromJson(Map<String, dynamic> json) {
    final List<dynamic> dimsJson = json['dimension_groups'] ?? [];
    return CategoryRecommendationGroup(
      kategori: json['kategori'] ?? 'Lainnya',
      dimensionGroups: dimsJson.map((e) => DimensionRecommendationGroup.fromJson(e)).toList(),
    );
  }
}

class RecommendationResponse {
  final int totalEvaluated;
  final int totalValid;
  final int totalExcluded;
  final List<CategoryRecommendationGroup> categories;
  final List<ExcludedProductItem> excludedItems;

  RecommendationResponse({
    required this.totalEvaluated,
    required this.totalValid,
    required this.totalExcluded,
    required this.categories,
    required this.excludedItems,
  });

  factory RecommendationResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> categoriesJson = json['categories'] ?? [];
    final List<dynamic> excludedJson = json['excluded_items'] ?? [];

    return RecommendationResponse(
      totalEvaluated: json['total_evaluated'] ?? 0,
      totalValid: json['total_valid'] ?? 0,
      totalExcluded: json['total_excluded'] ?? 0,
      categories: categoriesJson.map((e) => CategoryRecommendationGroup.fromJson(e)).toList(),
      excludedItems: excludedJson.map((e) => ExcludedProductItem.fromJson(e)).toList(),
    );
  }
}

class RecommendedProduct {
  final String id;
  final String nama;
  final String kategori;
  final double harga;
  final double? ukuran;
  final String? satuan;
  final String namaToko;
  final double? jarakKm;
  final String updatedAt;
  final String? fotoUrl;
  final bool stale;

  RecommendedProduct({
    required this.id,
    required this.nama,
    required this.kategori,
    required this.harga,
    this.ukuran,
    this.satuan,
    required this.namaToko,
    this.jarakKm,
    required this.updatedAt,
    this.fotoUrl,
    this.stale = false,
  });

  factory RecommendedProduct.fromJson(Map<String, dynamic> json) {
    return RecommendedProduct(
      id: (json['id'] ?? '').toString(),
      nama: json['nama'] as String? ?? 'Tanpa Nama',
      kategori: json['kategori'] as String? ?? 'General',
      harga: (json['harga'] as num?)?.toDouble() ?? 0.0,
      ukuran: (json['ukuran'] as num?)?.toDouble(),
      satuan: json['satuan'] as String?,
      namaToko: json['nama_toko'] as String? ?? 'Toko Terdekat',
      jarakKm: (json['jarak_km'] as num?)?.toDouble(),
      updatedAt: json['updated_at'] as String? ?? 'Baru saja',
      fotoUrl: json['foto_url'] as String?,
      stale: json['stale'] as bool? ?? false,
    );
  }
}

class RecommendationService {
  static String defaultBaseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://rakoon-backend.onrender.com',
  );

  /// Sends product candidates to POST /recommendation/evaluate
  static Future<RecommendationResponse> evaluateRecommendation({
    required List<RecommendationCandidate> candidates,
    String? baseUrl,
    http.Client? client,
  }) async {
    final String activeBaseUrl = baseUrl ?? defaultBaseUrl;
    final uri = Uri.parse('$activeBaseUrl/recommendation/evaluate');
    final httpClient = client ?? http.Client();

    try {
      final response = await mapNetworkErrors(() => httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'items': candidates.map((e) => e.toJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 15)));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return RecommendationResponse.fromJson(data);
      } else {
        throwIfServerError(response);
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        final String detail = errorData['detail'] ?? 'Gagal memproses rekomendasi.';
        throw Exception(detail);
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Terjadi kesalahan rekomendasi: $e');
    }
  }

  /// Fetches recommended products from GET /recommendation/recommended-products
  static Future<List<RecommendedProduct>> getRecommendedProducts({
    String? baseUrl,
    double? lat,
    double? lng,
    double radiusKm = 1.0,
    int limit = 10,
    http.Client? client,
  }) async {
    final String activeBaseUrl = (baseUrl != null && baseUrl.isNotEmpty)
        ? baseUrl
        : defaultBaseUrl;
    final cleanBaseUrl = activeBaseUrl.endsWith('/')
        ? activeBaseUrl.substring(0, activeBaseUrl.length - 1)
        : activeBaseUrl;

    final Map<String, String> queryParams = {
      'limit': limit.toString(),
      'radius_km': radiusKm.toString(),
    };
    if (lat != null) queryParams['lat'] = lat.toString();
    if (lng != null) queryParams['lng'] = lng.toString();

    final uri = Uri.parse('$cleanBaseUrl/recommendation/recommended-products')
        .replace(queryParameters: queryParams);
    final httpClient = client ?? http.Client();

    try {
      final response = await mapNetworkErrors(() => httpClient.get(uri).timeout(const Duration(seconds: 10)));

      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body) as List<dynamic>;
        return decoded
            .map((e) => RecommendedProduct.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throwIfInvalidRequest(response);
      throwIfServerError(response);
      throw Exception('recommended products failed: ${response.statusCode}');
    } finally {
      if (client == null) httpClient.close();
    }
  }
}
