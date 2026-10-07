import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:rakoon_frontend/core/config/app_config.dart';
import 'package:rakoon_frontend/services/auth_service.dart';

class AdminProductService {
  /// Memperbarui URL foto produk secara langsung (admin only)
  static Future<String> updateProductPhotoUrl({
    required String productId,
    required String photoUrl,
    String? baseUrl,
    http.Client? client,
  }) async {
    final effectiveBaseUrl = baseUrl ?? AppConfig.apiBaseUrl;
    final httpClient = client ?? http.Client();
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
        final errorData = jsonDecode(response.body);
        final detail = errorData is Map ? errorData['detail'] : null;
        throw Exception(detail ?? 'Gagal memperbarui foto produk (${response.statusCode})');
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

    final streamedResponse = client != null
        ? await client.send(request)
        : await request.send();

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final photoUrl = data['foto_url'] as String?;
      if (photoUrl == null || photoUrl.isEmpty) {
        throw Exception('Server tidak mengembalikan URL foto yang valid.');
      }
      return photoUrl;
    } else {
      try {
        final errorData = jsonDecode(response.body);
        final detail = errorData is Map ? errorData['detail'] : null;
        throw Exception(detail ?? 'Gagal mengunggah foto produk (${response.statusCode})');
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) rethrow;
        throw Exception('Gagal mengunggah foto produk (${response.statusCode})');
      }
    }
  }
}
