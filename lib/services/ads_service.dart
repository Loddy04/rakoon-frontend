import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rakoon_frontend/core/config/app_config.dart';
import 'package:rakoon_frontend/services/api_error_messages.dart';
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
    this.pricePaid = 0, // tidak dikirim backend pada respons publik
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

  /// Memeriksa apakah URL invoice valid dan aman (skema HTTPS).
  bool get hasValidCheckoutUrl {
    if (invoiceUrl == null || invoiceUrl!.trim().isEmpty) return false;
    final uri = Uri.tryParse(invoiceUrl!.trim());
    return uri != null && uri.hasScheme && uri.scheme.toLowerCase() == 'https';
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
    this.currency = 'IDR',
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

  /// Memeriksa apakah URL invoice valid dan aman (skema HTTPS).
  bool get hasValidCheckoutUrl {
    if (invoiceUrl == null || invoiceUrl!.trim().isEmpty) return false;
    final uri = Uri.tryParse(invoiceUrl!.trim());
    return uri != null && uri.hasScheme && uri.scheme.toLowerCase() == 'https';
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
  final String? submissionId;
  final String claimType; // "claim" atau "new_store"
  final String? applicantName;
  final String? applicantPhone;
  final String? applicantRole;
  final String? businessEntityName;
  final String? storeCategory;
  final double? latitude;
  final double? longitude;
  final String? documentUrl;
  final String? storePhotoUrl;

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
    this.submissionId,
    this.claimType = 'claim',
    this.applicantName,
    this.applicantPhone,
    this.applicantRole,
    this.businessEntityName,
    this.storeCategory,
    this.latitude,
    this.longitude,
    this.documentUrl,
    this.storePhotoUrl,
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
      submissionId: json['submission_id'] as String?,
      claimType: json['claim_type'] as String? ?? 'claim',
      applicantName: json['applicant_name'] as String?,
      applicantPhone: json['applicant_phone'] as String?,
      applicantRole: json['applicant_role'] as String?,
      businessEntityName: json['business_entity_name'] as String?,
      storeCategory: json['store_category'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      documentUrl: json['document_url'] as String?,
      storePhotoUrl: json['store_photo_url'] as String?,
    );
  }
}

class UserSubmissionData {
  final String id;
  final String submissionType; // "claim" atau "new_store"
  final String? storeId;
  final String storeName;
  final String? storeAddress;
  final String? storeCategory;
  final String? businessEntityName;
  final String? applicantName;
  final String? applicantPhone;
  final String? applicantRole;
  final String? documentUrl;
  final String? storePhotoUrl;
  final String status; // "pending", "under_review", "verified", "rejected"
  final String? rejectionReason;
  final String createdAt;

  const UserSubmissionData({
    required this.id,
    required this.submissionType,
    this.storeId,
    required this.storeName,
    this.storeAddress,
    this.storeCategory,
    this.businessEntityName,
    this.applicantName,
    this.applicantPhone,
    this.applicantRole,
    this.documentUrl,
    this.storePhotoUrl,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
  });

  factory UserSubmissionData.fromJson(Map<String, dynamic> json) {
    return UserSubmissionData(
      id: json['id'] as String? ?? '',
      submissionType: json['submission_type'] as String? ?? 'claim',
      storeId: json['store_id'] as String?,
      storeName: json['store_name'] as String? ?? '',
      storeAddress: json['store_address'] as String?,
      storeCategory: json['store_category'] as String?,
      businessEntityName: json['business_entity_name'] as String?,
      applicantName: json['applicant_name'] as String?,
      applicantPhone: json['applicant_phone'] as String?,
      applicantRole: json['applicant_role'] as String?,
      documentUrl: json['document_url'] as String?,
      storePhotoUrl: json['store_photo_url'] as String?,
      status: json['status'] as String? ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: json['created_at'] as String? ?? '',
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
  final String? rejectionReason;
  final String? applicantName;
  final String? applicantRole;
  final String? documentUrl;
  final String? storePhotoUrl;
  final List<HomePromoBanner> campaigns;

  const MyStoreData({
    required this.isClaimed,
    this.claimStatus,
    this.storeId,
    this.storeNama,
    this.storeAlamat,
    this.storeLat,
    this.storeLng,
    this.rejectionReason,
    this.applicantName,
    this.applicantRole,
    this.documentUrl,
    this.storePhotoUrl,
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
      rejectionReason: json['rejection_reason'] as String?,
      applicantName: json['applicant_name'] as String?,
      applicantRole: json['applicant_role'] as String?,
      documentUrl: json['document_url'] as String?,
      storePhotoUrl: json['store_photo_url'] as String?,
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
    bool includeDemo = false,
  }) async {
    final effectiveBase = _resolveBaseUrl(baseUrl);
    final httpClient = FriendlyHttpClient(client ?? http.Client());
    final queryParams = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radius_km': radiusKm.toString(),
    };
    if (includeDemo) {
      queryParams['include_demo'] = 'true';
    }

    final uri = Uri.parse('$effectiveBase/ads/home-banners').replace(
      queryParameters: queryParams,
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
      throw http.ClientException('Gagal memuat promo (HTTP ${response.statusCode})');
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
    final httpClient = FriendlyHttpClient(client ?? http.Client());

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
    final httpClient = FriendlyHttpClient(client ?? http.Client());

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

  /// Mengklaim toko yang dipilih oleh pemilik toko (Jalur A: Klaim Toko Terdaftar)
  static Future<MyStoreData> claimStore({
    required String storeId,
    String? applicantName,
    String? applicantPhone,
    String? applicantRole,
    String? documentUrl,
    String? storePhotoUrl,
    String? baseUrl,
    http.Client? client,
  }) async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Silakan masuk akun terlebih dahulu.');
    }

    final effectiveBase = _resolveBaseUrl(baseUrl);
    final httpClient = FriendlyHttpClient(client ?? http.Client());

    try {
      final response = await httpClient.post(
        Uri.parse('$effectiveBase/ads/claim-store'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'store_id': storeId,
          if (applicantName != null && applicantName.trim().isNotEmpty) 'applicant_name': applicantName.trim(),
          if (applicantPhone != null && applicantPhone.trim().isNotEmpty) 'applicant_phone': applicantPhone.trim(),
          if (applicantRole != null && applicantRole.trim().isNotEmpty) 'applicant_role': applicantRole.trim(),
          if (documentUrl != null && documentUrl.trim().isNotEmpty) 'document_url': documentUrl.trim(),
          if (storePhotoUrl != null && storePhotoUrl.trim().isNotEmpty) 'store_photo_url': storePhotoUrl.trim(),
        }),
      );

      if (response.statusCode == 200) {
        return MyStoreData.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(_evidenceErrorMessage(
          response,
          fallback: 'Gagal mengklaim toko.',
          conflictMessage: 'Klaim untuk toko ini sudah ada',
        ));
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Mengajukan pendaftaran toko baru (Jalur B: Pengajuan Toko Baru)
  static Future<UserSubmissionData> submitNewStore({
    required String storeName,
    required String storeAddress,
    required String applicantName,
    required String applicantPhone,
    required String applicantRole,
    String? businessEntityName,
    double? latitude,
    double? longitude,
    String? documentUrl,
    String? storePhotoUrl,
    String? baseUrl,
    http.Client? client,
  }) async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Silakan masuk akun terlebih dahulu.');
    }

    final effectiveBase = _resolveBaseUrl(baseUrl);
    final httpClient = FriendlyHttpClient(client ?? http.Client());

    try {
      final response = await httpClient.post(
        Uri.parse('$effectiveBase/ads/submit-new-store'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'store_name': storeName.trim(),
          'store_address': storeAddress.trim(),
          'applicant_name': applicantName.trim(),
          'applicant_phone': applicantPhone.trim(),
          'applicant_role': applicantRole.trim(),
          if (businessEntityName != null && businessEntityName.trim().isNotEmpty)
            'business_entity_name': businessEntityName.trim(),
          'latitude': ?latitude,
          'longitude': ?longitude,
          if (documentUrl != null && documentUrl.trim().isNotEmpty)
            'document_url': documentUrl.trim(),
          if (storePhotoUrl != null && storePhotoUrl.trim().isNotEmpty)
            'store_photo_url': storePhotoUrl.trim(),
        }),
      );

      if (response.statusCode == 201) {
        return UserSubmissionData.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(_evidenceErrorMessage(response, fallback: 'Gagal mengajukan toko baru.'));
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Mengambil daftar seluruh riwayat pengajuan kepemilikan dan pendaftaran toko milik pengguna
  static Future<List<UserSubmissionData>> getMySubmissions({
    String? baseUrl,
    http.Client? client,
  }) async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) {
      return [];
    }

    final effectiveBase = _resolveBaseUrl(baseUrl);
    final httpClient = FriendlyHttpClient(client ?? http.Client());

    try {
      final response = await httpClient.get(
        Uri.parse('$effectiveBase/ads/my-submissions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((e) => UserSubmissionData.fromJson(e as Map<String, dynamic>)).toList();
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

  /// Mengunggah berkas dokumen legalitas usaha (NIB, dsb) secara aman ke private storage backend
  static Future<String> uploadClaimDocument({
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
    final uri = Uri.parse('$effectiveBase/ads/upload-claim-document');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token';

    final lowerName = filename.toLowerCase();
    MediaType mediaType;
    if (lowerName.endsWith('.pdf')) {
      mediaType = MediaType('application', 'pdf');
    } else if (lowerName.endsWith('.png')) {
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

    final streamedResponse = await FriendlyHttpClient(client ?? http.Client()).send(request);
    final response = await mapNetworkErrors(() => http.Response.fromStream(streamedResponse));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['document_path'] as String;
    } else {
      throw Exception(_evidenceErrorMessage(response, fallback: 'Gagal mengunggah dokumen legalitas.'));
    }
  }

  /// Mengunggah foto tampak depan toko yang memperlihatkan papan nama
  static Future<String> uploadClaimPhoto({
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
    final uri = Uri.parse('$effectiveBase/ads/upload-claim-photo');

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

    final streamedResponse = await FriendlyHttpClient(client ?? http.Client()).send(request);
    final response = await mapNetworkErrors(() => http.Response.fromStream(streamedResponse));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['photo_path'] as String;
    } else {
      throw Exception(_evidenceErrorMessage(response, fallback: 'Gagal mengunggah foto toko.'));
    }
  }

  /// Admin: URL bertanda tangan (berlaku sekitar 5 menit) untuk membuka satu bukti klaim.
  static Future<String> getClaimEvidenceUrl({
    required String path,
    String? baseUrl,
    http.Client? client,
  }) async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Silakan masuk akun terlebih dahulu.');
    }

    final effectiveBase = _resolveBaseUrl(baseUrl);
    final httpClient = FriendlyHttpClient(client ?? http.Client());

    try {
      final response = await httpClient.get(
        Uri.parse('$effectiveBase/ads/claim-evidence-url').replace(queryParameters: {'path': path}),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['url'] as String;
      }
      throw Exception(_evidenceErrorMessage(response, fallback: 'Gagal membuka bukti klaim.'));
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

    final streamedResponse = await FriendlyHttpClient(client ?? http.Client()).send(request);
    final response = await mapNetworkErrors(() => http.Response.fromStream(streamedResponse));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['banner_url'] as String;
    } else {
      throw Exception(extractErrorMessage(response, fallbackMessage: 'Gagal mengunggah foto iklan.'));
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
    final httpClient = FriendlyHttpClient(client ?? http.Client());

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
        throw Exception(extractErrorMessage(response, fallbackMessage: 'Gagal membuat kampanye iklan.'));
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Mengubah judul atau banner URL kampanye iklan yang masih aktif
  static Future<HomePromoBanner> updateCampaign({
    required String campaignId,
    String? title,
    String? bannerUrl,
    String? baseUrl,
    http.Client? client,
  }) async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Silakan masuk akun terlebih dahulu.');
    }

    final effectiveBase = _resolveBaseUrl(baseUrl);
    final httpClient = FriendlyHttpClient(client ?? http.Client());

    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (bannerUrl != null) body['banner_url'] = bannerUrl;

      final response = await httpClient.patch(
        Uri.parse('$effectiveBase/ads/campaigns/$campaignId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return HomePromoBanner.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(extractErrorMessage(response, fallbackMessage: 'Gagal memperbarui materi iklan.'));
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Memperbarui langganan kampanye iklan kedaluwarsa dengan sistem pembayaran yang sudah ada
  static Future<PaymentCheckoutData> renewCampaign({
    required String campaignId,
    int? durationDays,
    String? baseUrl,
    http.Client? client,
  }) async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Silakan masuk akun terlebih dahulu.');
    }

    final effectiveBase = _resolveBaseUrl(baseUrl);
    final httpClient = FriendlyHttpClient(client ?? http.Client());

    try {
      final body = <String, dynamic>{};
      if (durationDays != null) body['duration_days'] = durationDays;

      final response = await httpClient.post(
        Uri.parse('$effectiveBase/ads/campaigns/$campaignId/renew'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return PaymentCheckoutData.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(extractErrorMessage(response, fallbackMessage: 'Gagal memperbarui langganan iklan.'));
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Menghapus kampanye iklan promo milik toko mitra (non-refundable)
  static Future<bool> deleteCampaign({
    required String campaignId,
    String? baseUrl,
    http.Client? client,
  }) async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Silakan masuk akun terlebih dahulu.');
    }

    final effectiveBase = _resolveBaseUrl(baseUrl);
    final httpClient = FriendlyHttpClient(client ?? http.Client());

    try {
      final response = await httpClient.delete(
        Uri.parse('$effectiveBase/ads/campaigns/$campaignId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(extractErrorMessage(response, fallbackMessage: 'Gagal menghapus kampanye iklan.'));
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
    final httpClient = FriendlyHttpClient(client ?? http.Client());

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
      } else if (response.statusCode == 409) {
        throw Exception('Pembayaran sedang diproses, coba lagi sebentar');
      } else if (response.statusCode == 503) {
        throw Exception('Pembayaran belum tersedia, coba lagi nanti');
      } else {
        throw Exception(extractErrorMessage(response, fallbackMessage: 'Gagal memulai checkout pembayaran.'));
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
    final httpClient = FriendlyHttpClient(client ?? http.Client());

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
        throw Exception(extractErrorMessage(response, fallbackMessage: 'Gagal mengambil status pembayaran.'));
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Merekonsiliasi status verifikasi pembayaran kampanye terkini dengan Xendit
  static Future<PaymentStatusData> reconcileCampaignPayment({
    required String campaignId,
    String? baseUrl,
    http.Client? client,
  }) async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Silakan masuk akun terlebih dahulu.');
    }

    final effectiveBase = _resolveBaseUrl(baseUrl);
    final httpClient = FriendlyHttpClient(client ?? http.Client());

    try {
      final response = await httpClient.post(
        Uri.parse('$effectiveBase/ads/campaigns/$campaignId/reconcile-payment'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return PaymentStatusData.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(extractErrorMessage(response, fallbackMessage: 'Gagal merekonsiliasi status pembayaran.'));
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Merekonsiliasi pembayaran kampanye toko milik pengguna dengan Xendit
  static Future<MyStoreData> reconcileMyStorePayments({
    String? baseUrl,
    http.Client? client,
  }) async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) {
      return const MyStoreData(isClaimed: false);
    }

    final effectiveBase = _resolveBaseUrl(baseUrl);
    final httpClient = FriendlyHttpClient(client ?? http.Client());

    try {
      final response = await httpClient.post(
        Uri.parse('$effectiveBase/ads/my-store/reconcile-payments'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return MyStoreData.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(extractErrorMessage(response, fallbackMessage: 'Gagal merekonsiliasi pembayaran toko.'));
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
    final httpClient = FriendlyHttpClient(client ?? http.Client());

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
        throw Exception(extractErrorMessage(response, fallbackMessage: 'Gagal mengambil daftar klaim pending.'));
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
    final httpClient = FriendlyHttpClient(client ?? http.Client());

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
        throw Exception(extractErrorMessage(response, fallbackMessage: 'Gagal menyetujui klaim toko.'));
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
    final httpClient = FriendlyHttpClient(client ?? http.Client());

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
        throw Exception(extractErrorMessage(response, fallbackMessage: 'Gagal menolak klaim toko.'));
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Menyetujui pengajuan toko baru (Admin only)
  /// [latitude]/[longitude] = koreksi titik oleh admin; keduanya dikirim bersamaan atau tidak sama sekali.
  static Future<Map<String, dynamic>> verifyNewStore({
    required String submissionId,
    double? latitude,
    double? longitude,
    String? baseUrl,
    http.Client? client,
  }) async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Silakan masuk akun terlebih dahulu.');
    }

    final effectiveBase = _resolveBaseUrl(baseUrl);
    final httpClient = FriendlyHttpClient(client ?? http.Client());

    try {
      final response = await httpClient.post(
        Uri.parse('$effectiveBase/ads/verify-new-store'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'submission_id': submissionId,
          if (latitude != null && longitude != null) ...{
            'latitude': latitude,
            'longitude': longitude,
          },
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(extractErrorMessage(response, fallbackMessage: 'Gagal menyetujui pengajuan toko baru.'));
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Menolak pengajuan toko baru (Admin only)
  static Future<Map<String, dynamic>> rejectNewStore({
    required String submissionId,
    String? reason,
    String? baseUrl,
    http.Client? client,
  }) async {
    final token = AuthService.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Silakan masuk akun terlebih dahulu.');
    }

    final effectiveBase = _resolveBaseUrl(baseUrl);
    final httpClient = FriendlyHttpClient(client ?? http.Client());

    try {
      final response = await httpClient.post(
        Uri.parse('$effectiveBase/ads/reject-new-store'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'submission_id': submissionId,
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(extractErrorMessage(response, fallbackMessage: 'Gagal menolak pengajuan toko baru.'));
      }
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Ekstraksi pesan error yang tangguh untuk respons HTTP non-200.
  /// Mencegah FormatException pada respons non-JSON (500 text/plain, 502 HTML, dsb)
  /// dan menyaring internal exception traceback tanpa memaparkannya ke pengguna.
  static String extractErrorMessage(
    http.Response response, {
    String fallbackMessage = 'Terjadi kesalahan pada sistem.',
  }) {
    return extractErrorMessageFromBody(
      response.body,
      response.statusCode,
      fallbackMessage: fallbackMessage,
    );
  }

  /// Pesan ramah untuk alur bukti klaim, klaim, dan pengajuan toko. Tidak pernah memuat body mentah:
  /// `detail` hanya dipakai bila berupa teks biasa (400/409), bukan daftar validasi.
  static String _evidenceErrorMessage(
    http.Response response, {
    required String fallback,
    String? conflictMessage,
  }) {
    String? plainDetail() {
      try {
        final decoded = jsonDecode(response.body);
        final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
        if (detail is String && detail.trim().isNotEmpty && userMessage(detail) != genericErrorMessage) {
          return detail.trim();
        }
      } catch (_) {}
      return null;
    }

    switch (response.statusCode) {
      case 400:
        return plainDetail() ?? 'Berkas atau data tidak valid. Periksa lalu coba lagi.';
      case 409:
        return conflictMessage ?? plainDetail() ?? 'Data bertentangan dengan data yang sudah ada.';
      case 413:
        return 'Ukuran berkas terlalu besar (maksimum 5 MB).';
      case 422:
        return 'Data belum lengkap. Periksa isian Anda lalu coba lagi.';
      case 503:
        return 'Penyimpanan belum tersedia, coba lagi nanti';
    }
    return extractErrorMessage(response, fallbackMessage: fallback);
  }

  static String extractErrorMessageFromBody(
    String responseBody,
    int statusCode, {
    String fallbackMessage = 'Terjadi kesalahan pada sistem.',
  }) {
    // Catat log diagnostik untuk developer tanpa membocorkan ke pengguna
    if (kDebugMode) {
      debugPrint('[AdsService Error $statusCode]');
    }

    // 1. Coba parsing JSON terstruktur terlebih dahulu
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'] ?? decoded['message'] ?? decoded['error'];
        if (detail != null && detail.toString().trim().isNotEmpty) {
          final detailStr = detail.toString().trim();
          // Filter internal database / server error messages yang tidak sengaja terbawa
          if (detailStr.toLowerCase().contains('psycopg2') ||
              detailStr.toLowerCase().contains('syntax error') ||
              detailStr.toLowerCase().contains('traceback') ||
              detailStr.toLowerCase().contains('internal server error')) {
            return serverErrorMessage;
          }
          if (statusCode == 422 || detail is List || detailStr.startsWith('[{')) {
            return 'Alasan penolakan tidak valid atau belum diisi dengan benar.';
          }
          return userMessage(detailStr) == genericErrorMessage ? fallbackMessage : detailStr;
        }
      }
    } catch (_) {
      // Body adalah plain text atau HTML non-JSON
    }

    // 2. Respons server error (5xx) non-JSON
    if (statusCode >= 500) {
      return serverErrorMessage;
    }

    if (statusCode == 422) {
      return 'Alasan penolakan tidak valid atau belum diisi dengan benar.';
    }

    if (statusCode == 401) {
      return 'Silakan masuk akun terlebih dahulu.';
    }
    if (statusCode == 403) {
      return 'Anda tidak memiliki izin untuk melakukan tindakan ini.';
    }
    if (statusCode == 404) {
      return 'Data yang dipilih tidak ditemukan.';
    }

    return fallbackMessage;
  }

  /// Membuka URL checkout Xendit di browser eksternal setelah memvalidasi skema HTTPS.
  static Future<bool> launchCheckoutUrl(
    String? rawUrl, {
    Future<bool> Function(Uri, {LaunchMode mode})? customLauncher,
  }) async {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return false;
    }
    final trimmed = rawUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.scheme.toLowerCase() != 'https') {
      return false;
    }
    try {
      final launcher = customLauncher ?? launchUrl;
      return await launcher(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
