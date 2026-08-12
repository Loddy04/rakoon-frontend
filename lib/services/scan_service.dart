import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/services/auth_service.dart';

const List<String> productCategories = [
  'Makanan Pokok',
  'Makanan Instan',
  'Camilan',
  'Minuman',
  'Susu & Olahan',
  'Bumbu & Saus',
  'Perawatan Diri',
  'Produk Rumah Tangga',
  'Kesehatan',
  'Bayi',
  'Lainnya',
];

class ScanResultItem {
  String? namaProduk;
  double? harga;
  double? ukuran;
  String? satuan;
  String? kategori;
  String confidence;
  bool needsVerification;

  ScanResultItem({
    this.namaProduk,
    this.harga,
    this.ukuran,
    this.satuan,
    this.kategori,
    required this.confidence,
    required this.needsVerification,
  });

  factory ScanResultItem.fromJson(Map<String, dynamic> json) {
    return ScanResultItem(
      namaProduk: json['nama_produk'],
      harga: json['harga'] != null ? (json['harga'] as num).toDouble() : null,
      ukuran: json['ukuran'] != null ? (json['ukuran'] as num).toDouble() : null,
      satuan: json['satuan'],
      kategori: json['kategori'] ?? 'Lainnya',
      confidence: json['confidence'] ?? 'rendah',
      needsVerification: json['needs_verification'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nama_produk': namaProduk,
      'harga': harga,
      'ukuran': ukuran,
      'satuan': satuan,
      'kategori': kategori,
      'confidence': confidence,
      'needs_verification': needsVerification,
    };
  }

  Map<String, dynamic> toConfirmJson() {
    return {
      'nama_produk': namaProduk ?? '',
      'harga': harga?.toInt() ?? 0,
      'ukuran': ukuran,
      'satuan': satuan,
      'kategori': kategori ?? 'Lainnya',
    };
  }
}

class ScanService {
  // Default Base URL for Android Emulator
  static String defaultBaseUrl = 'http://10.0.2.2:8000';

  /// Sends the photo file to the POST /scan/ endpoint
  static Future<List<ScanResultItem>> scanPhoto(File imageFile, {String? baseUrl}) async {
    final String activeBaseUrl = baseUrl ?? defaultBaseUrl;
    final uri = Uri.parse('$activeBaseUrl/scan/');
    
    // Create multipart request
    final request = http.MultipartRequest('POST', uri);
    
    // Attach the photo file
    final stream = http.ByteStream(imageFile.openRead());
    final length = await imageFile.length();
    final multipartFile = http.MultipartFile(
      'file',
      stream,
      length,
      filename: imageFile.path.split('/').last,
    );
    request.files.add(multipartFile);

    // Send request
    try {
      final streamedResponse = await request.send().timeout(const Duration(seconds: 35));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // Handle empty detection with message
        final List<dynamic> detectedJson = data['detected'] ?? [];
        if (detectedJson.isEmpty && data.containsKey('message') && data['message'] != null) {
          throw Exception(data['message']);
        }
        
        return detectedJson.map((item) => ScanResultItem.fromJson(item)).toList();
      } else {
        throw Exception('Server mengembalikan error (HTTP ${response.statusCode})');
      }
    } on SocketException {
      throw const SocketException('Tidak dapat terhubung ke server. Silakan periksa koneksi internet Anda atau Base URL backend.');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Gagal memproses gambar: $e');
    }
  }

  /// Sends the confirmed items to the POST /scan/confirm endpoint
  static Future<Map<String, dynamic>> confirmScan({
    required String storeId,
    required String userId,
    required List<ScanResultItem> items,
    String? baseUrl,
  }) async {
    final String activeBaseUrl = baseUrl ?? defaultBaseUrl;
    final uri = Uri.parse('$activeBaseUrl/scan/confirm');
    
    // Get authenticated session token
    final session = AuthService.currentSession;
    if (session == null) {
      throw Exception('Silakan login terlebih dahulu untuk menyimpan konfirmasi scan.');
    }
    final token = session.accessToken;

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'store_id': storeId,
          'user_id': userId,
          'items': items.map((e) => e.toConfirmJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        final String errorDetail = errorData['detail'] ?? 'Gagal menyimpan konfirmasi';
        throw Exception(errorDetail);
      }
    } on SocketException {
      throw const SocketException('Tidak dapat terhubung ke server. Periksa koneksi internet atau server backend Anda.');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Gagal menyimpan konfirmasi: $e');
    }
  }
}
