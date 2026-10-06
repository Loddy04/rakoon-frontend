import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/core/config/app_config.dart';
import 'package:rakoon_frontend/services/auth_service.dart';

class HomePromoBanner {
  final String id;
  final String storeId;
  final String storeNama;
  final String? storeAlamat;
  final double? storeLat;
  final double? storeLng;
  final String title;
  final String bannerUrl;
  final int durationDays;
  final int pricePaid;
  final double distanceKm;
  final String expiresAt;
  final int daysLeft;
  final String paymentMethod;
  final String? paymentRef;
  final String paymentStatus;

  const HomePromoBanner({
    required this.id,
    required this.storeId,
    required this.storeNama,
    this.storeAlamat,
    this.storeLat,
    this.storeLng,
    required this.title,
    required this.bannerUrl,
    required this.durationDays,
    required this.pricePaid,
    required this.distanceKm,
    required this.expiresAt,
    required this.daysLeft,
    this.paymentMethod = 'QRIS',
    this.paymentRef,
    this.paymentStatus = 'paid',
  });

  factory HomePromoBanner.fromJson(Map<String, dynamic> json) {
    return HomePromoBanner(
      id: json['id'] as String? ?? '',
      storeId: json['store_id'] as String? ?? '',
      storeNama: json['store_nama'] as String? ?? 'Toko Ritel',
      storeAlamat: json['store_alamat'] as String?,
      storeLat: (json['store_lat'] as num?)?.toDouble(),
      storeLng: (json['store_lng'] as num?)?.toDouble(),
      title: json['title'] as String? ?? '',
      bannerUrl: json['banner_url'] as String? ?? '',
      durationDays: json['duration_days'] as int? ?? 3,
      pricePaid: json['price_paid'] as int? ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      expiresAt: json['expires_at'] as String? ?? '',
      daysLeft: json['days_left'] as int? ?? 1,
      paymentMethod: json['payment_method'] as String? ?? 'QRIS',
      paymentRef: json['payment_ref'] as String?,
      paymentStatus: json['payment_status'] as String? ?? 'paid',
    );
  }
}

class AdPricingPackage {
  final int durationDays;
  final String name;
  final int price;
  final String description;

  const AdPricingPackage({
    required this.durationDays,
    required this.name,
    required this.price,
    required this.description,
  });

  factory AdPricingPackage.fromJson(Map<String, dynamic> json) {
    return AdPricingPackage(
      durationDays: json['duration_days'] as int? ?? 3,
      name: json['name'] as String? ?? '',
      price: json['price'] as int? ?? 0,
      description: json['description'] as String? ?? '',
    );
  }
}

class MyStoreData {
  final bool isClaimed;
  final String? storeId;
  final String? storeNama;
  final String? storeAlamat;
  final double? storeLat;
  final double? storeLng;
  final List<HomePromoBanner> campaigns;

  const MyStoreData({
    required this.isClaimed,
    this.storeId,
    this.storeNama,
    this.storeAlamat,
    this.storeLat,
    this.storeLng,
    this.campaigns = const [],
  });

  factory MyStoreData.fromJson(Map<String, dynamic> json) {
    final list = json['campaigns'] as List<dynamic>? ?? [];
    return MyStoreData(
      isClaimed: json['is_claimed'] as bool? ?? false,
      storeId: json['store_id'] as String?,
      storeNama: json['store_nama'] as String?,
      storeAlamat: json['store_alamat'] as String?,
      storeLat: (json['store_lat'] as num?)?.toDouble(),
      storeLng: (json['store_lng'] as num?)?.toDouble(),
      campaigns: list
          .map((e) => HomePromoBanner.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AdsService {
  static String _resolveBaseUrl(String? baseUrl) {
    return baseUrl ?? AppConfig.apiBaseUrl;
  }

  /// Mengambil banner promo aktif di sekitar pengguna (Yogyakarta)
  static Future<List<HomePromoBanner>> getHomeBanners({
    String? baseUrl,
    http.Client? client,
    double lat = -7.7829,
    double lng = 110.4083,
    double radiusKm = 15.0,
  }) async {
    final effectiveBase = _resolveBaseUrl(baseUrl);
    final httpClient = client ?? http.Client();
    final uri = Uri.parse('$effectiveBase/ads/home-banners').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radius_km': radiusKm.toString(),
      },
    );

    try {
      final response = await httpClient.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((item) => HomePromoBanner.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Mengambil paket harga durasi iklan
  static Future<List<AdPricingPackage>> getPricingPackages({
    String? baseUrl,
    http.Client? client,
  }) async {
    final effectiveBase = _resolveBaseUrl(baseUrl);
    final httpClient = client ?? http.Client();

    try {
      final response = await httpClient.get(
        Uri.parse('$effectiveBase/ads/pricing-packages'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((item) => AdPricingPackage.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Mengambil toko dan kampanye iklan milik pengguna yang sedang login
  static Future<MyStoreData> getMyStore({
    String? baseUrl,
    http.Client? client,
  }) async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) {
      return const MyStoreData(isClaimed: false);
    }

    final effectiveBase = _resolveBaseUrl(baseUrl);
    final httpClient = client ?? http.Client();

    try {
      final response = await httpClient.get(
        Uri.parse('$effectiveBase/ads/my-store'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return MyStoreData.fromJson(jsonDecode(response.body));
      }
      return const MyStoreData(isClaimed: false);
    } catch (_) {
      return const MyStoreData(isClaimed: false);
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Mengklaim toko yang dipilih oleh pemilik toko
  static Future<MyStoreData> claimStore({
    required String storeId,
    String? baseUrl,
    http.Client? client,
  }) async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Silakan masuk akun terlebih dahulu.');
    }

    final effectiveBase = _resolveBaseUrl(baseUrl);
    final httpClient = client ?? http.Client();

    try {
      final response = await httpClient.post(
        Uri.parse('$effectiveBase/ads/claim-store'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'store_id': storeId}),
      );

      if (response.statusCode == 200) {
        return MyStoreData.fromJson(jsonDecode(response.body));
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['detail'] ?? 'Gagal mengklaim toko.');
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Mengunggah gambar flyer iklan ke Supabase Storage via Backend
  static Future<String> uploadBannerImage({
    required Uint8List bytes,
    required String filename,
    String? baseUrl,
    http.Client? client,
  }) async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Silakan masuk akun terlebih dahulu.');
    }

    final effectiveBase = _resolveBaseUrl(baseUrl);
    final uri = Uri.parse('$effectiveBase/ads/upload-banner');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ),
    );

    final streamedResponse = await (client ?? http.Client()).send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['banner_url'] as String;
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Gagal mengunggah foto iklan.');
    }
  }

  /// Membuat kampanye iklan flyer offline baru
  static Future<HomePromoBanner> createCampaign({
    required String storeId,
    required String title,
    required String bannerUrl,
    required int durationDays,
    String paymentMethod = 'QRIS',
    String? paymentRef,
    String? baseUrl,
    http.Client? client,
  }) async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Silakan masuk akun terlebih dahulu.');
    }

    final effectiveBase = _resolveBaseUrl(baseUrl);
    final httpClient = client ?? http.Client();

    try {
      final response = await httpClient.post(
        Uri.parse('$effectiveBase/ads/campaigns'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'store_id': storeId,
          'title': title,
          'banner_url': bannerUrl,
          'duration_days': durationDays,
          'payment_method': paymentMethod,
          'payment_ref':? paymentRef,
        }),
      );

      if (response.statusCode == 201) {
        return HomePromoBanner.fromJson(jsonDecode(response.body));
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['detail'] ?? 'Gagal membuat kampanye iklan.');
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
}
