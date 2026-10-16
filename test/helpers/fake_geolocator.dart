import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Geolocator palsu: jalur nyata LocationService (servis -> izin -> requestPermission -> posisi).
class FakeGeolocator extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.denied;
  LocationPermission afterRequest = LocationPermission.denied;
  Object? checkError;
  Completer<LocationPermission>? requestGate;
  Object? positionError;
  int openLocationSettingsCount = 0;

  final calls = <String>[];
  int get requestCount => calls.where((c) => c == 'requestPermission').length;
  int get positionCount => calls.where((c) => c == 'getCurrentPosition').length;

  @override
  Future<bool> isLocationServiceEnabled() async {
    calls.add('isLocationServiceEnabled');
    return serviceEnabled;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    calls.add('checkPermission');
    if (checkError != null) throw checkError!;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    calls.add('requestPermission');
    if (requestGate != null) return requestGate!.future;
    permission = afterRequest;
    return permission;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    calls.add('getCurrentPosition');
    if (positionError != null) throw positionError!;
    return Position(
      longitude: 106.8456,
      latitude: -6.2088,
      timestamp: DateTime.now(),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCount++;
    return true;
  }

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async {
    calls.add('getLastKnownPosition');
    return null;
  }
}
