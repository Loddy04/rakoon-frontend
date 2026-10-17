import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rakoon_frontend/services/location_service.dart';

import '../helpers/fake_geolocator.dart';

void main() {
  late FakeGeolocator fake;
  late GeolocatorPlatform original;

  setUp(() {
    original = GeolocatorPlatform.instance;
    fake = FakeGeolocator();
    GeolocatorPlatform.instance = fake;
    LocationService.testUsePlatform = true;
    LocationService.clearCache();
    LocationService.testOutcome = null;
    LocationService.testFreshPosition = null;
    LocationService.testFreshPositionNull = false;
    LocationService.testGetFreshPosition = null;
  });

  tearDown(() {
    GeolocatorPlatform.instance = original;
    LocationService.testUsePlatform = false;
    LocationService.clearCache();
    LocationService.testOutcome = null;
    LocationService.testFreshPosition = null;
    LocationService.testFreshPositionNull = false;
    LocationService.testGetFreshPosition = null;
  });

  group('LocationService.getFreshPosition Tests', () {
    test('posisi tersedia saat izin granted: mengembalikan koordinat baru', () async {
      fake.permission = LocationPermission.whileInUse;
      fake.serviceEnabled = true;

      final pos = await LocationService.getFreshPosition();

      expect(pos, isNotNull);
      expect(pos!.latitude, -6.2088);
      expect(pos.longitude, 106.8456);
      expect(fake.requestCount, 0, reason: 'TIDAK boleh meminta izin');
      expect(fake.positionCount, 1);
    });

    test('izin denied: mengembalikan null dan TIDAK meminta izin (no requestPermission)', () async {
      fake.permission = LocationPermission.denied;
      fake.serviceEnabled = true;

      final pos = await LocationService.getFreshPosition();

      expect(pos, isNull);
      expect(fake.requestCount, 0, reason: 'TIDAK boleh memanggil requestPermission');
      expect(fake.positionCount, 0);
    });

    test('layanan GPS mati: mengembalikan null', () async {
      fake.permission = LocationPermission.whileInUse;
      fake.serviceEnabled = false;

      final pos = await LocationService.getFreshPosition();

      expect(pos, isNull);
      expect(fake.requestCount, 0);
      expect(fake.positionCount, 0);
    });

    test('timeout / galat saat mengambil posisi: mengembalikan null', () async {
      fake.permission = LocationPermission.whileInUse;
      fake.serviceEnabled = true;
      fake.positionError = TimeoutException('GPS timeout');

      final pos = await LocationService.getFreshPosition(timeout: const Duration(milliseconds: 100));

      expect(pos, isNull);
      expect(fake.requestCount, 0);
    });

    test('tidak memakai cache lama', () async {
      fake.permission = LocationPermission.denied;
      LocationService.cachePosition(Position(
        longitude: 99.99,
        latitude: -9.99,
        timestamp: DateTime.now(),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ));

      final pos = await LocationService.getFreshPosition();

      expect(pos, isNull, reason: 'Cache lama tidak boleh digunakan saat izin denied');
    });
  });
}
