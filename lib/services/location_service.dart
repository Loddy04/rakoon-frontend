import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

export 'package:geolocator/geolocator.dart' show LocationPermission;

/// Hasil permintaan lokasi, dipakai layar yang harus membedakan penyebab kegagalan.
enum LocationOutcome { granted, denied, deniedForever, serviceDisabled, failed }

class LocationResult {
  final LocationOutcome outcome;
  final Position? position;

  const LocationResult(this.outcome, [this.position]);
}

/// Service that manages device location permissions and fetches current GPS coordinates.
class LocationService {
  static Position? _lastKnownPosition;
  static DateTime? _lastKnownPositionTime;

  /// Masa berlaku cache lokasi dalam memori (10 menit).
  static const Duration locationCacheTtl = Duration(minutes: 10);

  /// Mengembalikan posisi terakhir yang tersimpan jika masih dalam masa berlaku.
  static Position? get cachedPosition {
    if (_lastKnownPosition == null || _lastKnownPositionTime == null) return null;
    if (DateTime.now().difference(_lastKnownPositionTime!) > locationCacheTtl) {
      _lastKnownPosition = null;
      _lastKnownPositionTime = null;
      return null;
    }
    return _lastKnownPosition;
  }

  static void cachePosition(Position position) {
    _lastKnownPosition = position;
    _lastKnownPositionTime = DateTime.now();
  }

  static void clearCache() {
    _lastKnownPosition = null;
    _lastKnownPositionTime = null;
  }

  /// Test override for checking if location service is enabled (for unit/widget tests).
  static bool? testIsLocationServiceEnabled;

  /// Test override: paksa hasil [resolveLocation] selain granted (null = perilaku normal).
  static LocationOutcome? testOutcome;

  /// Test hooks: jumlah panggilan [resolveLocation] dan jumlah permintaan izin (dialog) yang akan muncul.
  static int testResolveCalls = 0;
  static int testPermissionRequests = 0;

  /// Test hook: bila diisi, [resolveLocation] menunggu future ini (mensimulasikan dialog izin yang terbuka).
  static Future<void>? testGate;

  /// Test hook: jalankan jalur Geolocator sungguhan (dengan GeolocatorPlatform palsu) meski di FLUTTER_TEST.
  static bool testUsePlatform = false;

  // Satu permintaan izin pada satu waktu: pemanggil lain (mis. Home saat resume) memakai hasil yang sama,
  // supaya plugin tidak menerima requestPermission ganda (galat "request in progress", dialog ganda).
  static Future<LocationPermission>? _pendingPermission;

  static Future<LocationPermission> _requestPermissionOnce() {
    return _pendingPermission ??= Geolocator.requestPermission().whenComplete(() => _pendingPermission = null);
  }

  /// Meminta izin lokasi dengan pengaman permintaan tunggal (_requestPermissionOnce).
  /// Mencegah dialog izin ganda dan tidak memanggil requestPermission lagi jika sudah ditolak permanen.
  static Future<LocationPermission> requestPermission() async {
    if (_pendingPermission != null) {
      return await _pendingPermission!;
    }
    if (Platform.environment.containsKey('FLUTTER_TEST') &&
        !testUsePlatform &&
        GeolocatorPlatform.instance.runtimeType.toString() == 'MethodChannelGeolocator') {
      if (testOutcome == LocationOutcome.deniedForever) return LocationPermission.deniedForever;
      if (testOutcome == LocationOutcome.denied) return LocationPermission.denied;
      return LocationPermission.whileInUse;
    }
    final permission = await Geolocator.checkPermission().timeout(_statusTimeout);
    if (permission == LocationPermission.denied) {
      return await _requestPermissionOnce();
    }
    return permission;
  }


  // Batas waktu pemeriksaan status (bukan dialog izin): panggilan platform yang macet tidak boleh
  // membuat layar menunggu selamanya.
  static const Duration _statusTimeout = Duration(seconds: 5);

  /// Batas waktu pengambilan posisi setelah izin diberikan.
  static const Duration _positionTimeout = Duration(seconds: 6);

  /// Test callback when openLocationSettings is invoked.
  static void Function()? onOpenLocationSettings;

  /// Test callback when openAppSettings is invoked.
  static void Function()? onOpenAppSettings;

  /// Checks if location services (GPS) are enabled on the device.
  static Future<bool> isLocationServiceEnabled() async {
    if (testIsLocationServiceEnabled != null) {
      return testIsLocationServiceEnabled!;
    }
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Opens the device's location service settings screen (GPS toggle).
  static Future<bool> openLocationSettings() async {
    onOpenLocationSettings?.call();
    if (Platform.environment.containsKey('FLUTTER_TEST') && !testUsePlatform) {
      return true;
    }
    return await Geolocator.openLocationSettings();
  }

  /// Opens the app's permission settings screen.
  static Future<bool> openAppSettings() async {
    onOpenAppSettings?.call();
    if (Platform.environment.containsKey('FLUTTER_TEST') && !testUsePlatform) {
      return true;
    }
    return await Geolocator.openAppSettings();
  }

  static Position _testPosition() => Position(
        longitude: 106.8456,
        latitude: -6.2088,
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

  /// Mengembalikan posisi, atau penyebab tidak ada posisi (tanpa melempar). Tidak pernah memakai
  /// koordinat bawaan. [askPermission] false = hanya memeriksa status (tanpa dialog izin), dipakai
  /// saat aplikasi resume; izin yang sudah ditolak permanen tidak pernah diminta lagi.
  static Future<LocationResult> resolveLocation({bool askPermission = true}) async {
    testResolveCalls++;
    final forced = testOutcome;
    if (forced == LocationOutcome.denied && askPermission) testPermissionRequests++;
    if (testGate != null) await testGate;
    if (forced != null && forced != LocationOutcome.granted) return LocationResult(forced);
    if (testIsLocationServiceEnabled == false) return const LocationResult(LocationOutcome.serviceDisabled);
    if (Platform.environment.containsKey('FLUTTER_TEST') && !testUsePlatform) {
      final pos = _testPosition();
      cachePosition(pos);
      return LocationResult(LocationOutcome.granted, pos);
    }
    if (!askPermission && cachedPosition != null) {
      return LocationResult(LocationOutcome.granted, cachedPosition);
    }
    // Urutan: layanan aktif? -> izin? -> (ditolak/permanen: berhenti) -> baru ambil posisi.
    try {
      if (!await Geolocator.isLocationServiceEnabled().timeout(_statusTimeout)) {
        clearCache();
        return const LocationResult(LocationOutcome.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission().timeout(_statusTimeout);
      if (permission == LocationPermission.denied && askPermission) {
        permission = await _requestPermissionOnce();
      }
      if (permission == LocationPermission.deniedForever) {
        clearCache();
        return const LocationResult(LocationOutcome.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        clearCache();
        return const LocationResult(LocationOutcome.denied);
      }
      if (permission == LocationPermission.unableToDetermine) {
        return const LocationResult(LocationOutcome.failed);
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: _positionTimeout,
      );
      cachePosition(position);
      return LocationResult(LocationOutcome.granted, position);
    } catch (_) {
      // Galat platform/timeout: jangan melempar; layar menampilkan "Lokasi belum terdeteksi".
      return const LocationResult(LocationOutcome.failed);
    }
  }

  /// Requests GPS permission and returns the current [Position].
  /// Throws a clear user-facing exception on denial or errors.
  static Future<Position> getCurrentLocation() async {
    if (testIsLocationServiceEnabled == false) {
      throw const LocationServiceException(
        'Layanan lokasi (GPS) tidak aktif. Silakan aktifkan GPS pada perangkat Anda.',
      );
    }
    if (Platform.environment.containsKey('FLUTTER_TEST') && !testUsePlatform) {
      final pos = Position(
        longitude: 106.8456,
        latitude: -6.2088,
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
      cachePosition(pos);
      return pos;
    }
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services (GPS) are enabled on the device.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException(
        'Layanan lokasi (GPS) tidak aktif. Silakan aktifkan GPS pada perangkat Anda.',
      );
    }

    // Check existing permission.
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Request permission.
      permission = await _requestPermissionOnce();
      if (permission == LocationPermission.denied) {
        throw const LocationServiceException(
          'Izin akses lokasi ditolak. Izin lokasi diperlukan untuk mendeteksi toko di sekitar Anda.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        'Izin lokasi ditolak secara permanen di pengaturan sistem. Silakan aktifkan izin lokasi secara manual di pengaturan aplikasi.',
      );
    }

    // Fetch current GPS position with high accuracy.
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      cachePosition(pos);
      return pos;
    } catch (e) {
      throw LocationServiceException(
        'Gagal mengambil koordinat lokasi: $e',
      );
    }
  }

  /// Melakukan reverse geocoding dari koordinat GPS ke nama wilayah ringkas (Kelurahan/Kecamatan/Kota).
  static Future<String> getAreaNameFromCoordinates(double lat, double lng) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return 'Babarsari';
    }
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        // Prioritas wilayah ringkas:
        // 1. subLocality (Kelurahan / Dusun)
        if (p.subLocality != null && p.subLocality!.trim().isNotEmpty) {
          return p.subLocality!.trim();
        }
        // 2. locality (Kecamatan / Kota)
        if (p.locality != null && p.locality!.trim().isNotEmpty) {
          return p.locality!.trim();
        }
        // 3. subAdministrativeArea (Kabupaten / Kota Madya)
        if (p.subAdministrativeArea != null && p.subAdministrativeArea!.trim().isNotEmpty) {
          return p.subAdministrativeArea!.trim();
        }
      }
    } catch (_) {
      // Fallback jika platform reverse geocoder native sedang offline/error
    }
    return 'Babarsari';
  }
}

/// A custom exception representing user-facing errors related to device location.
class LocationServiceException implements Exception {
  final String message;

  const LocationServiceException(this.message);

  @override
  String toString() => message;
}
