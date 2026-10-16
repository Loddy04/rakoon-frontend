import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/features/history/data/models/price_history_item.dart';
import 'package:rakoon_frontend/features/price_check/data/models/product_catalog_model.dart';
import 'package:rakoon_frontend/services/api_error_messages.dart';
import 'package:rakoon_frontend/services/stores_service.dart';

class PriceCheckService {
  static const String defaultBaseUrl = 'http://10.0.2.2:8000';

  static Future<List<CatalogProduct>> getCatalogProducts({
    String? search,
    String? category,
    int limit = 100,
    int offset = 0,
    double? lat,
    double? lng,
    String? baseUrl,
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
      if (offset > 0) 'offset': offset.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (category != null && category.trim().isNotEmpty && category.trim().toLowerCase() != 'semua') {
      queryParams['category'] = category.trim();
    }

    // Backend menolak lat tanpa lng (422): kirim hanya sebagai pasangan.
    if (lat != null && lng != null) {
      queryParams['lat'] = lat.toString();
      queryParams['lng'] = lng.toString();
    }

    final uri = Uri.parse('$cleanBaseUrl/products/catalog')
        .replace(queryParameters: queryParams);
    final httpClient = client ?? http.Client();

    try {
      final response = await mapNetworkErrors(() => httpClient.get(uri).timeout(const Duration(seconds: 10)));

      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body) as List<dynamic>;
        return decoded
            .map((e) => CatalogProduct.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throwIfServerError(response);
      // A failure must never look like an empty catalog / "no more pages".
      throw Exception('catalog failed: ${response.statusCode}');
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<PriceHistoryResponse?> getPriceHistory({
    required String productId,
    String range = 'all',
    String? baseUrl,
    http.Client? client,
  }) async {
    final String activeBaseUrl = (baseUrl != null && baseUrl.isNotEmpty)
        ? baseUrl
        : defaultBaseUrl;
    final cleanBaseUrl = activeBaseUrl.endsWith('/')
        ? activeBaseUrl.substring(0, activeBaseUrl.length - 1)
        : activeBaseUrl;

    final uri = Uri.parse('$cleanBaseUrl/price/api/v1/products/$productId/price-history')
        .replace(queryParameters: {'range': range});
    final httpClient = client ?? http.Client();

    try {
      final response = await mapNetworkErrors(() => httpClient.get(uri).timeout(const Duration(seconds: 10)));
      throwIfServerError(response);

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return PriceHistoryResponse.fromJson(decoded);
      }
    } catch (e) {
      // Offline / server errors surface to the caller; anything else (e.g. no history) is null.
      if (friendlyApiError(e) != null) rethrow;
    } finally {
      if (client == null) httpClient.close();
    }

    return null;
  }

  static Future<PriceCompareResponse?> getPriceComparison({
    required String productId,
    required double lat,
    required double lng,
    double radiusKm = 5.0,
    String? baseUrl,
    http.Client? client,
  }) async {
    final String activeBaseUrl = (baseUrl != null && baseUrl.isNotEmpty)
        ? baseUrl
        : defaultBaseUrl;
    final cleanBaseUrl = activeBaseUrl.endsWith('/')
        ? activeBaseUrl.substring(0, activeBaseUrl.length - 1)
        : activeBaseUrl;

    final uri = Uri.parse('$cleanBaseUrl/price/compare/$productId').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radius_km': radiusKm.toString(),
      },
    );
    final httpClient = client ?? http.Client();

    try {
      final response = await mapNetworkErrors(() => httpClient.get(uri).timeout(const Duration(seconds: 10)));

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return PriceCompareResponse.fromJson(decoded);
      } else {
        throwIfServerError(response);
        throw Exception('Gagal memuat perbandingan harga (HTTP ${response.statusCode})');
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
}
