import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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
  final String status;
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
    this.status = 'active',
    this.paymentMethod = 'QRIS',
    this.paymentRef,
    this.paymentStatus = 'unpaid',
  });

  static int _computeDaysLeft(dynamic daysLeftJson, String? expiresAtStr) {
    if (daysLeftJson is int) return daysLeftJson;
    if (expiresAtStr != null && expiresAtStr.isNotEmpty) {
      try {
        final exp = DateTime.parse(expiresAtStr).toUtc();
        final now = DateTime.now().toUtc();
        final diff = exp.difference(now);
        return diff.isNegative ? 0 : (diff.inDays + (diff.inSeconds % 86400 > 0 ? 1 : 0));
      } catch (_) {}
    }
    return 1;
  }

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
      daysLeft: _computeDaysLeft(json['days_left'], json['expires_at'] as String?),
      status: json['status'] as String? ?? 'active',
      paymentMethod: json['payment_method'] as String? ?? 'QRIS',
      paymentRef: json['payment_ref'] as String?,
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
    );
  }
}

class PaymentCheckoutData {
  final String campaignId;
  final String externalId;
  final String? xenditInvoiceId;
  final int amount;
  final String currency;
  final String status;
  final String? invoiceUrl;
  final String? expiryDate;

  const PaymentCheckoutData({
    required this.campaignId,
    required this.externalId,
    this.xenditInvoiceId,
    required this.amount,
    this.currency = 'IDR',
    required this.status,
    this.invoiceUrl,
    this.expiryDate,
  });

  factory PaymentCheckoutData.fromJson(Map<String, dynamic> json) {
    return PaymentCheckoutData(
      campaignId: json['campaign_id'] as String? ?? '',
      externalId: json['external_id'] as String? ?? '',
      xenditInvoiceId: json['xendit_invoice_id'] as String?,
      amount: json['amount'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'IDR',
      status: json['status'] as String? ?? 'PENDING',
      invoiceUrl: json['invoice_url'] as String?,
      expiryDate: json['expiry_date'] as String?,
    );
  }
}

class PaymentStatusData {
  final String campaignId;
  final String campaignStatus;
  final String paymentStatus;
  final String? transactionStatus;
  final String? externalId;
  final String? xenditInvoiceId;
  final String? invoiceUrl;
  final int? amount;
  final String? currency;
  final String? paidAt;
  final String? expiresAt;

  const PaymentStatusData({
    required this.campaignId,
    required this.campaignStatus,
    required this.paymentStatus,
    this.transactionStatus,
    this.externalId,
    this.xenditInvoiceId,
    this.invoiceUrl,
    this.amount,
    this.currency,
    this.paidAt,
    this.expiresAt,
  });

  factory PaymentStatusData.fromJson(Map<String, dynamic> json) {
    return PaymentStatusData(
      campaignId: json['campaign_id'] as String? ?? '',
      campaignStatus: json['campaign_status'] as String? ?? 'pending_payment',
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      transactionStatus: json['transaction_status'] as String?,
      externalId: json['external_id'] as String?,
      xenditInvoiceId: json['xendit_invoice_id'] as String?,
      invoiceUrl: json['invoice_url'] as String?,
      amount: json['amount'] as int?,
      currency: json['currency'] as String? ?? 'IDR',
      paidAt: json['paid_at'] as String?,
      expiresAt: json['expires_at'] as String?,
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

class PendingStoreClaimData {
  final String userId;
  final String storeId;
  final String storeNama;
  final String? storeAlamat;
  final String? userNama;
  final String? userEmail;
  final String status;
  final String createdAt;
  final bool hasVerifiedOwner;

  const PendingStoreClaimData({
    required this.userId,
    required this.storeId,
    required this.storeNama,
    this.storeAlamat,
    this.userNama,
    this.userEmail,
    required this.status,
    required this.createdAt,
    this.hasVerifiedOwner = false,
  });

  factory PendingStoreClaimData.fromJson(Map<String, dynamic> json) {
    return PendingStoreClaimData(
      userId: json['user_id'] as String? ?? '',
      storeId: json['store_id'] as String? ?? '',
      storeNama: json['store_nama'] as String? ?? '',
      storeAlamat: json['store_alamat'] as String?,
      userNama: json['user_nama'] as String?,
      userEmail: json['user_email'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String? ?? '',
      hasVerifiedOwner: json['has_verified_owner'] as bool? ?? false,
    );
  }
}

class MyStoreData {
  final bool isClaimed;
  final String? claimStatus;
  final String? storeId;
  final String? storeNama;
  final String? storeAlamat;
  final double? storeLat;
  final double? storeLng;
  final List<HomePromoBanner> campaigns;

  const MyStoreData({
    required this.isClaimed,
    this.claimStatus,
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
      claimStatus: json['claim_status'] as String?,
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

    final lowerName = filename.toLowerCase();
    MediaType mediaType;
    if (lowerName.endsWith('.png')) {
      mediaType = MediaType('image', 'png');
    } else if (lowerName.endsWith('.webp')) {
      mediaType = MediaType('image', 'webp');
    } else {
      mediaType = MediaType('image', 'jpeg');
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: mediaType,
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

  /// Memulai proses pembayaran kampanye iklan via Xendit Sandbox
  static Future<PaymentCheckoutData> initiatePayment({
    required String campaignId,
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
        Uri.parse('$effectiveBase/ads/campaigns/$campaignId/pay'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return PaymentCheckoutData.fromJson(jsonDecode(response.body));
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['detail'] ?? 'Gagal memulai pembayaran.');
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Memeriksa status verifikasi pembayaran kampanye terkini
  static Future<PaymentStatusData> getPaymentStatus({
    required String campaignId,
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
      final response = await httpClient.get(
        Uri.parse('$effectiveBase/ads/campaigns/$campaignId/payment-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return PaymentStatusData.fromJson(jsonDecode(response.body));
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['detail'] ?? 'Gagal mengambil status pembayaran.');
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
  /// Mengambil daftar klaim toko pending yang membutuhkan verifikasi admin
  static Future<List<PendingStoreClaimData>> getPendingClaims({
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
      final response = await httpClient.get(
        Uri.parse('$effectiveBase/ads/pending-claims'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>? ?? [];
        return list
            .map((e) => PendingStoreClaimData.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['detail'] ?? 'Gagal mengambil daftar klaim pending.');
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Menyetujui klaim toko merchant (Admin only)
  static Future<MyStoreData> verifyStoreClaim({
    required String userId,
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
        Uri.parse('$effectiveBase/ads/verify-claim'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'store_id': storeId,
        }),
      );

      if (response.statusCode == 200) {
        return MyStoreData.fromJson(jsonDecode(response.body));
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['detail'] ?? 'Gagal menyetujui klaim toko.');
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Menolak klaim toko merchant (Admin only)
  static Future<MyStoreData> rejectStoreClaim({
    required String userId,
    required String storeId,
    String? reason,
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
        Uri.parse('$effectiveBase/ads/reject-claim'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'store_id': storeId,
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        }),
      );

      if (response.statusCode == 200) {
        return MyStoreData.fromJson(jsonDecode(response.body));
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['detail'] ?? 'Gagal menolak klaim toko.');
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
}
