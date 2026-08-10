import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../models/price_history_item.dart';

class ProductNotFoundException implements Exception {
  final String message;
  const ProductNotFoundException([this.message = 'Produk tidak ditemukan']);

  @override
  String toString() => message;
}

class PriceHistoryNetworkException implements Exception {
  final String message;
  const PriceHistoryNetworkException([
    this.message = 'Gagal terhubung ke server',
  ]);

  @override
  String toString() => message;
}

class PriceHistoryApiException implements Exception {
  final int statusCode;
  final String message;
  const PriceHistoryApiException(
    this.statusCode, [
    this.message = 'Terjadi kesalahan pada server',
  ]);

  @override
  String toString() => 'API Error ($statusCode): $message';
}

class PriceHistoryRepository {
  final http.Client client;
  final String baseUrl;

  PriceHistoryRepository({
    http.Client? client,
    this.baseUrl = 'http://10.0.2.2:8000',
  }) : client = client ?? http.Client();

  Future<PriceHistoryResponse> getPriceHistory({
    required int productId,
    int? storeId,
    String? range,
  }) async {
    final queryParams = <String, String>{};
    if (storeId != null) {
      queryParams['store_id'] = storeId.toString();
    }
    if (range != null && range.isNotEmpty) {
      queryParams['range'] = range;
    }

    final uri = Uri.parse(
      '$baseUrl/api/v1/products/$productId/price-history',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    try {
      final response = await client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body =
            jsonDecode(response.body) as Map<String, dynamic>;
        return PriceHistoryResponse.fromJson(body);
      } else if (response.statusCode == 404) {
        throw const ProductNotFoundException('Produk tidak ditemukan');
      } else {
        throw PriceHistoryApiException(
          response.statusCode,
          'Gagal mengambil riwayat harga (HTTP ${response.statusCode})',
        );
      }
    } on ProductNotFoundException {
      rethrow;
    } on PriceHistoryApiException {
      rethrow;
    } on TimeoutException {
      throw const PriceHistoryNetworkException(
        'Koneksi internet lambat / timeout',
      );
    } catch (e) {
      if (e is SocketException || e.toString().contains('SocketException')) {
        throw const PriceHistoryNetworkException(
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
        );
      }
      throw PriceHistoryNetworkException('Error koneksi: $e');
    }
  }
}
