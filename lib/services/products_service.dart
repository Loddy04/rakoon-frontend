import 'dart:convert';
import 'package:http/http.dart' as http;

/// Dart representation of a Product model from the backend.
class Product {
  final String id;
  final String nama;
  final String kategori;
  final double? ukuran;
  final String? satuan;
  final String? fotoUrl;

  final double? estimasiHarga;

  Product({
    required this.id,
    required this.nama,
    required this.kategori,
    this.ukuran,
    this.satuan,
    this.fotoUrl,
    this.estimasiHarga,
  });

  /// Factory constructor to parse product JSON.
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['id'] ?? '').toString(),
      nama: json['nama'] as String? ?? 'Produk Tanpa Nama',
      kategori: json['kategori'] as String? ?? 'General',
      ukuran: (json['ukuran'] as num?)?.toDouble(),
      satuan: json['satuan'] as String?,
      fotoUrl: json['foto_url'] as String?,
      estimasiHarga: (json['harga_terendah'] ?? json['harga'] ?? json['estimasi_harga'] as num?)?.toDouble(),
    );
  }

  double get effectivePrice {
    if (estimasiHarga != null && estimasiHarga! > 0) return estimasiHarga!;
    final n = nama.toLowerCase();
    if (n.contains('minyak')) return 34000.0;
    if (n.contains('beras')) return 68000.0;
    if (n.contains('susu')) return 18500.0;
    if (n.contains('roti')) return 15000.0;
    if (n.contains('telur')) return 28000.0;
    if (n.contains('gula')) return 17500.0;
    if (n.contains('mie') || n.contains('indomie')) return 3500.0;
    if (n.contains('kopi')) return 12000.0;
    if (n.contains('teh')) return 6500.0;
    if (n.contains('sabun') || n.contains('shampoo')) return 22000.0;
    return 15000.0;
  }
}

/// Service that queries products list and search results from the backend.
class ProductsService {
  /// Fetches products from GET /products/ with optional search query parameter.
  static Future<List<Product>> getProducts({
    required String baseUrl,
    String? search,
    String? category,
    int limit = 20,
    http.Client? client,
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
    if (category != null && category.trim().isNotEmpty && category.trim().toLowerCase() != 'semua') {
      queryParams['category'] = category.trim();
    }

    final uri = Uri.parse('$cleanBaseUrl/products/').replace(
      queryParameters: queryParams,
    );

    try {
      final httpClient = client ?? http.Client();
      final response = await httpClient.get(uri).timeout(
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

  /// Mengambil informasi detail produk tunggal berdasarkan ID dari GET /products/{product_id}
  static Future<Product?> getProductById({
    required String productId,
    required String baseUrl,
    http.Client? client,
  }) async {
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final uri = Uri.parse('$cleanBaseUrl/products/$productId');

    try {
      final httpClient = client ?? http.Client();
      final response = await httpClient.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        return Product.fromJson(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
