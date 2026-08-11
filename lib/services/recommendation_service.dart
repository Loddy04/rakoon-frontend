import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

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

class RecommendationResponse {
  final int totalEvaluated;
  final int totalValid;
  final int totalExcluded;
  final RankedProductItem? bestValue;
  final List<RankedProductItem> rankedItems;
  final List<ExcludedProductItem> excludedItems;

  RecommendationResponse({
    required this.totalEvaluated,
    required this.totalValid,
    required this.totalExcluded,
    this.bestValue,
    required this.rankedItems,
    required this.excludedItems,
  });

  factory RecommendationResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rankedJson = json['ranked_items'] ?? [];
    final List<dynamic> excludedJson = json['excluded_items'] ?? [];

    return RecommendationResponse(
      totalEvaluated: json['total_evaluated'] ?? 0,
      totalValid: json['total_valid'] ?? 0,
      totalExcluded: json['total_excluded'] ?? 0,
      bestValue: json['best_value'] != null
          ? RankedProductItem.fromJson(json['best_value'])
          : null,
      rankedItems: rankedJson.map((e) => RankedProductItem.fromJson(e)).toList(),
      excludedItems: excludedJson.map((e) => ExcludedProductItem.fromJson(e)).toList(),
    );
  }
}

class RecommendationService {
  static String defaultBaseUrl = 'http://10.0.2.2:8000';

  /// Sends product candidates to POST /recommendation/evaluate
  static Future<RecommendationResponse> evaluateRecommendation({
    required List<RecommendationCandidate> candidates,
    String? category,
    String? baseUrl,
  }) async {
    final String activeBaseUrl = baseUrl ?? defaultBaseUrl;
    final uri = Uri.parse('$activeBaseUrl/recommendation/evaluate');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'category': category,
          'items': candidates.map((e) => e.toJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return RecommendationResponse.fromJson(data);
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        final String detail = errorData['detail'] ?? 'Gagal memproses rekomendasi.';
        throw Exception(detail);
      }
    } on SocketException {
      throw const SocketException(
          'Tidak dapat terhubung ke server FastAPI. Periksa koneksi atau Base URL backend.');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Terjadi kesalahan rekomendasi: $e');
    }
  }
}
