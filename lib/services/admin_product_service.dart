import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:rakoon_frontend/core/config/app_config.dart';
import 'package:rakoon_frontend/services/api_error_messages.dart';
import 'package:rakoon_frontend/services/auth_service.dart';

class AdminProductService {
  /// Pesan ramah per status; `detail` dipakai hanya bila berupa teks biasa non-teknis.
  static String _errorMessage(http.Response response, String fallback) {
    switch (response.statusCode) {
      case 401:
        return 'Silakan masuk akun terlebih dahulu.';
      case 403:
        return 'Anda tidak memiliki izin untuk melakukan tindakan ini.';
      case 404:
        return 'Produk tidak ditemukan.';
      case 413:
        return 'Ukuran berkas terlalu besar (maksimum 5 MB).';
      case 422:
        return 'Data belum lengkap. Periksa isian Anda lalu coba lagi.';
      case 429:
        return 'Terlalu banyak permintaan, coba lagi nanti';
    }
    if (response.statusCode >= 500) return serverErrorMessage;
    try {
      final decoded = jsonDecode(response.body);
      final detail = decoded is Map ? decoded['detail'] : null;
      if (detail is String && detail.trim().isNotEmpty && userMessage(detail) != genericErrorMessage) {
        return detail.trim();
      }
    } catch (_) {}
    return fallback;
  }

  /// Memperbarui URL foto produk secara langsung (admin only)
  static Future<String> updateProductPhotoUrl({
    required String productId,
    required String photoUrl,
    String? baseUrl,
    http.Client? client,
  }) async {
    final effectiveBaseUrl = baseUrl ?? AppConfig.apiBaseUrl;
    final httpClient = FriendlyHttpClient(client ?? http.Client());
    final token = AuthService.currentSession?.accessToken;

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await httpClient.put(
        Uri.parse('$effectiveBaseUrl/products/$productId/photo'),
        headers: headers,
        body: jsonEncode({'foto_url': photoUrl.trim()}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['foto_url'] as String?) ?? photoUrl;
      } else {
        throw Exception(_errorMessage(response, 'Gagal memperbarui foto produk.'));
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Helper untuk menentukan MediaType yang tepat berdasarkan mimeType atau ekstensi nama file
  static MediaType resolveMediaType({String? mimeType, String? fileName, String? filePath}) {
    if (mimeType != null && mimeType.isNotEmpty && mimeType.contains('/')) {
      try {
        return MediaType.parse(mimeType);
      } catch (_) {}
    }
    final target = (fileName ?? filePath ?? '').toLowerCase();
    if (target.endsWith('.png')) {
      return MediaType('image', 'png');
    } else if (target.endsWith('.webp')) {
      return MediaType('image', 'webp');
    } else {
      return MediaType('image', 'jpeg');
    }
  }

  /// Helper untuk memastikan nama file valid beserta ekstensinya
  static String resolveFileName({String? fileName, String? filePath, required MediaType mediaType}) {
    String name = (fileName != null && fileName.trim().isNotEmpty)
        ? fileName.trim()
        : (filePath != null && filePath.trim().isNotEmpty
            ? filePath.split(RegExp(r'[/\\]')).last
            : 'product_photo');

    if (!name.contains('.')) {
      if (mediaType.subtype == 'png') {
        name = '$name.png';
      } else if (mediaType.subtype == 'webp') {
        name = '$name.webp';
      } else {
        name = '$name.jpg';
      }
    }
    return name;
  }

  /// Mengunggah berkas foto produk ke Supabase Storage (admin only)
  static Future<String> uploadProductPhotoFile({
    required String productId,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
    String? contentType,
    String? baseUrl,
    http.Client? client,
  }) async {
    final effectiveBaseUrl = baseUrl ?? AppConfig.apiBaseUrl;
    final token = AuthService.currentSession?.accessToken;

    final uri = Uri.parse('$effectiveBaseUrl/products/$productId/upload-photo');
    final request = http.MultipartRequest('POST', uri);

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final mediaType = resolveMediaType(
      mimeType: contentType,
      fileName: fileName,
      filePath: filePath,
    );
    final resolvedName = resolveFileName(
      fileName: fileName,
      filePath: filePath,
      mediaType: mediaType,
    );

    if (fileBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: resolvedName,
          contentType: mediaType,
        ),
      );
    } else if (filePath != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: resolvedName,
          contentType: mediaType,
        ),
      );
    } else {
      throw ArgumentError('Salah satu dari filePath atau fileBytes harus disediakan.');
    }

    final httpClient = FriendlyHttpClient(client ?? http.Client());
    final http.Response response;
    try {
      final streamedResponse = await httpClient.send(request);
      response = await mapNetworkErrors(() => http.Response.fromStream(streamedResponse));
    } finally {
      if (client == null) httpClient.close();
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final photoUrl = data['foto_url'] as String?;
      if (photoUrl == null || photoUrl.isEmpty) {
        throw Exception('Server tidak mengembalikan URL foto yang valid.');
      }
      return photoUrl;
    } else {
      throw Exception(_errorMessage(response, 'Gagal mengunggah foto produk.'));
    }
  }
}
