import 'package:geolocator/geolocator.dart';

/// Service that manages device location permissions and fetches current GPS coordinates.
class LocationService {
  /// Requests GPS permission and returns the current [Position].
  /// Throws a clear user-facing exception on denial or errors.
  static Future<Position> getCurrentLocation() async {
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
      permission = await Geolocator.requestPermission();
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
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (e) {
      throw LocationServiceException(
        'Gagal mengambil koordinat lokasi: $e',
      );
    }
  }
}

/// A custom exception representing user-facing errors related to device location.
class LocationServiceException implements Exception {
  final String message;

  const LocationServiceException(this.message);

  @override
  String toString() => message;
}
