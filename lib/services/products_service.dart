import 'dart:convert';
import 'package:http/http.dart' as http;

/// Dart representation of a Product model from the backend.
class Product {
  final String id;
  final String nama;
  final String kategori;
  final double? ukuran;
  final String? satuan;

  Product({
    required this.id,
    required this.nama,
    required this.kategori,
    this.ukuran,
    this.satuan,
  });

  /// Factory constructor to parse product JSON.
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['id'] ?? '').toString(),
      nama: json['nama'] as String? ?? 'Produk Tanpa Nama',
      kategori: json['kategori'] as String? ?? 'General',
      ukuran: (json['ukuran'] as num?)?.toDouble(),
      satuan: json['satuan'] as String?,
    );
  }
}

/// Service that queries products list and search results from the backend.
class ProductsService {
  /// Fetches products from GET /products/ with optional search query parameter.
  static Future<List<Product>> getProducts({
    required String baseUrl,
    String? search,
    int limit = 20,
  }) async {
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final queryParams = {
      'limit': limit.toString(),
    };
    
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final uri = Uri.parse('$cleanBaseUrl/products/').replace(
      queryParameters: queryParams,
    );

    try {
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body) as List<dynamic>;
        return decoded
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: Gagal mengambil daftar produk.',
        );
      }
    } catch (e) {
      throw Exception(
        'Gagal memuat daftar produk. Detail: $e',
      );
    }
  }
}
