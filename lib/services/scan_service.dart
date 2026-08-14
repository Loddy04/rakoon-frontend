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
    http.Client? client,
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
      final httpClient = client ?? http.Client();
      final response = await httpClient.post(
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

  /// Fetches recent scans for the authenticated user from GET /scan/recent
  static Future<List<RecentScan>> getRecentScans({
    String? baseUrl,
    http.Client? client,
    int limit = 10,
  }) async {
    final String activeBaseUrl = baseUrl ?? defaultBaseUrl;
    final uri = Uri.parse('$activeBaseUrl/scan/recent').replace(
      queryParameters: {'limit': limit.toString()},
    );

    final session = AuthService.currentSession;
    if (session == null) {
      return [];
    }
    final token = session.accessToken;

    try {
      final httpClient = client ?? http.Client();
      final response = await httpClient.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((item) => RecentScan.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('HTTP ${response.statusCode}: Gagal memuat riwayat scan.');
      }
    } on SocketException {
      throw const SocketException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Gagal memuat riwayat scan: $e');
    }
  }

  /// Fetches the full scan session detail from GET /scan/session/{session_id}
  static Future<ScanSessionDetail> getScanSessionDetail({
    required String sessionId,
    String? baseUrl,
    http.Client? client,
  }) async {
    final String activeBaseUrl = baseUrl ?? defaultBaseUrl;
    final uri = Uri.parse('$activeBaseUrl/scan/session/$sessionId');

    final session = AuthService.currentSession;
    if (session == null) {
      throw Exception('Autentikasi diperlukan untuk melihat detail sesi scan.');
    }
    final token = session.accessToken;

    try {
      final httpClient = client ?? http.Client();
      final response = await httpClient.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        return ScanSessionDetail.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('Sesi scan tidak ditemukan atau Anda tidak memiliki akses.');
      } else {
        throw Exception('HTTP ${response.statusCode}: Gagal memuat detail sesi scan.');
      }
    } on SocketException {
      throw const SocketException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Gagal memuat detail sesi scan: $e');
    }
  }
}

DateTime parseScanTimestamp(dynamic raw) {
  if (raw == null) return DateTime.now();
  final str = raw.toString().trim();
  if (str.isEmpty) return DateTime.now();

  final parsed = DateTime.tryParse(str);
  if (parsed == null) return DateTime.now();

  // If timestamp is already UTC (e.g. ISO-8601 with Z or +00:00), convert to local
  if (parsed.isUtc) {
    return parsed.toLocal();
  }

  // If string contains explicit offset (e.g. "+07:00" or offset minus at the end)
  if (str.contains('+') || (str.lastIndexOf('-') > 10)) {
    return parsed.toLocal();
  }

  // If it's a legacy naive UTC string without offset (e.g. "2026-08-14T16:15:00"),
  // treat as UTC and convert to device local time so it does not lag:
  final utcParsed = DateTime.tryParse('${str}Z');
  if (utcParsed != null) {
    return utcParsed.toLocal();
  }

  return parsed.toLocal();
}

class RecentScan {
  final String id;
  final String storeId;
  final String? storeName;
  final DateTime timestamp;
  final int productCount;

  RecentScan({
    required this.id,
    required this.storeId,
    this.storeName,
    required this.timestamp,
    required this.productCount,
  });

  factory RecentScan.fromJson(Map<String, dynamic> json) {
    final rawCount = json['product_count'];
    final int count = rawCount is int
        ? rawCount
        : (rawCount is num ? rawCount.toInt() : (int.tryParse(rawCount?.toString() ?? '') ?? 0));

    return RecentScan(
      id: (json['id'] ?? '').toString(),
      storeId: (json['store_id'] ?? '').toString(),
      storeName: json['store_name'] as String?,
      timestamp: parseScanTimestamp(json['timestamp']),
      productCount: count,
    );
  }
}

class ScanSessionProductItem {
  final String productId;
  final String namaProduk;
  final String kategori;
  final double? ukuran;
  final String? satuan;
  final int harga;

  ScanSessionProductItem({
    required this.productId,
    required this.namaProduk,
    required this.kategori,
    this.ukuran,
    this.satuan,
    required this.harga,
  });

  factory ScanSessionProductItem.fromJson(Map<String, dynamic> json) {
    return ScanSessionProductItem(
      productId: (json['product_id'] ?? '').toString(),
      namaProduk: (json['nama_produk'] ?? 'Produk').toString(),
      kategori: (json['kategori'] ?? 'Lainnya').toString(),
      ukuran: (json['ukuran'] as num?)?.toDouble(),
      satuan: json['satuan'] as String?,
      harga: (json['harga'] as num?)?.toInt() ?? 0,
    );
  }
}

class ScanSessionDetail {
  final String id;
  final String storeId;
  final String? storeName;
  final DateTime timestamp;
  final int productCount;
  final List<ScanSessionProductItem> items;

  ScanSessionDetail({
    required this.id,
    required this.storeId,
    this.storeName,
    required this.timestamp,
    required this.productCount,
    required this.items,
  });

  factory ScanSessionDetail.fromJson(Map<String, dynamic> json) {
    final rawCount = json['product_count'];
    final int count = rawCount is int
        ? rawCount
        : (rawCount is num ? rawCount.toInt() : (int.tryParse(rawCount?.toString() ?? '') ?? 0));

    final rawItems = json['items'] as List<dynamic>? ?? [];
    final List<ScanSessionProductItem> parsedItems = rawItems
        .map((e) => ScanSessionProductItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return ScanSessionDetail(
      id: (json['id'] ?? '').toString(),
      storeId: (json['store_id'] ?? '').toString(),
      storeName: json['store_name'] as String?,
      timestamp: parseScanTimestamp(json['timestamp']),
      productCount: count,
      items: parsedItems,
    );
  }
}



