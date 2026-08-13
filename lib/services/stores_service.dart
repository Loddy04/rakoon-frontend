import 'dart:convert';
import 'package:http/http.dart' as http;

/// Dart representation of a nearby store item.
class StoreNearby {
  final String storeId;
  final String nama;
  final double lat;
  final double lng;
  final double jarakKm;
  
  /// The data source ("osm" or "local_fallback"), mapped from root response.
  final String source;

  StoreNearby({
    required this.storeId,
    required this.nama,
    required this.lat,
    required this.lng,
    required this.jarakKm,
    required this.source,
  });

  /// Factory constructor to parse JSON data combined with root source information.
  factory StoreNearby.fromJson(Map<String, dynamic> json, String source) {
    return StoreNearby(
      storeId: json['store_id'] as String? ?? '',
      nama: json['nama'] as String? ?? 'Toko Kelontong',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      jarakKm: (json['jarak_km'] as num?)?.toDouble() ?? 0.0,
      source: source,
    );
  }
}

/// Root response containing data source, list of stores, and optional limits warning.
class NearbyStoresResponse {
  final String source;
  final List<StoreNearby> stores;
  final String? message;

  NearbyStoresResponse({
    required this.source,
    required this.stores,
    this.message,
  });

  factory NearbyStoresResponse.fromJson(Map<String, dynamic> json) {
    final String src = json['source'] as String? ?? 'local_fallback';
    final rawStores = json['stores'] as List<dynamic>? ?? [];
    
    final List<StoreNearby> parsedStores = rawStores
        .map((e) => StoreNearby.fromJson(e as Map<String, dynamic>, src))
        .toList();

    return NearbyStoresResponse(
      source: src,
      stores: parsedStores,
      message: json['message'] as String?,
    );
  }
}

/// Service that queries store coordinates and listings from backend FastAPI.
class StoresService {
  /// Fetches nearby stores using lat, lng, and optional radius.
  static Future<NearbyStoresResponse> getNearbyStores({
    required double lat,
    required double lng,
    double radiusKm = 5.0,
    required String baseUrl,
  }) async {
    // Clean base URL to remove trailing slashes if present
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final uri = Uri.parse('$cleanBaseUrl/stores/nearby').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radius_km': radiusKm.toString(),
      },
    );

    try {
      final response = await http.get(uri).timeout(
        const Duration(seconds: 12),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return NearbyStoresResponse.fromJson(decoded);
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: Gagal menghubungi server backend.',
        );
      }
    } catch (e) {
      throw Exception(
        'Gagal memuat toko terdekat. Pastikan server backend Anda berjalan ($cleanBaseUrl). Detail: $e',
      );
    }
  }

  /// Fetches price comparison details for a given product_id across nearby stores.
  static Future<PriceCompareResponse> getPriceComparison({
    required String productId,
    required double lat,
    required double lng,
    double radiusKm = 5.0,
    required String baseUrl,
  }) async {
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final uri = Uri.parse('$cleanBaseUrl/price/compare/$productId').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radius_km': radiusKm.toString(),
      },
    );

    try {
      final response = await http.get(uri).timeout(
        const Duration(seconds: 12),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return PriceCompareResponse.fromJson(decoded);
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: Gagal mengambil data perbandingan harga.',
        );
      }
    } catch (e) {
      throw Exception(
        'Gagal memuat perbandingan harga produk. Detail: $e',
      );
    }
  }
}

/// Dart representation of a single price comparison row for a store.
class PriceCompareItem {
  final String storeId;
  final String namaToko;
  final double lat;
  final double lng;
  final double jarakKm;
  final int? hargaTerbaru;
  final String? tanggalUpdate;
  final String? statusVerifikasi;
  final String? pesan;

  PriceCompareItem({
    required this.storeId,
    required this.namaToko,
    required this.lat,
    required this.lng,
    required this.jarakKm,
    this.hargaTerbaru,
    this.tanggalUpdate,
    this.statusVerifikasi,
    this.pesan,
  });

  factory PriceCompareItem.fromJson(Map<String, dynamic> json) {
    return PriceCompareItem(
      storeId: json['store_id'] as String? ?? '',
      namaToko: json['nama_toko'] as String? ?? 'Toko Kelontong',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      jarakKm: (json['jarak_km'] as num?)?.toDouble() ?? 0.0,
      hargaTerbaru: json['harga_terbaru'] as int?,
      tanggalUpdate: json['tanggal_update'] as String?,
      statusVerifikasi: json['status_verifikasi'] as String?,
      pesan: json['pesan'] as String?,
    );
  }
}


/// Root comparison response for a specific product.
class PriceCompareResponse {
  final String productId;
  final String namaProduk;
  final List<PriceCompareItem> comparison;

  PriceCompareResponse({
    required this.productId,
    required this.namaProduk,
    required this.comparison,
  });

  factory PriceCompareResponse.fromJson(Map<String, dynamic> json) {
    final rawComp = json['comparison'] as List<dynamic>? ?? [];
    final List<PriceCompareItem> parsedComp = rawComp
        .map((e) => PriceCompareItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return PriceCompareResponse(
      productId: (json['product_id'] ?? '').toString(),
      namaProduk: json['nama_produk'] as String? ?? 'Produk',
      comparison: parsedComp,
    );
  }
}

