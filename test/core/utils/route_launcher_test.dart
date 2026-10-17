import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rakoon_frontend/core/utils/route_launcher.dart';
import 'package:rakoon_frontend/services/location_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../helpers/fake_geolocator.dart';

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
    setMockRouteUrlLauncher(null);
    GeolocatorPlatform.instance = original;
    LocationService.testUsePlatform = false;
    LocationService.clearCache();
    LocationService.testOutcome = null;
    LocationService.testFreshPosition = null;
    LocationService.testFreshPositionNull = false;
    LocationService.testGetFreshPosition = null;
  });

  Position createPos(double lat, double lng) => Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

  group('launchStoreRoute URL construction tests', () {
    testWidgets('posisi tersedia: URL berisi origin, destination, dan travelmode=driving', (tester) async {
      Uri? launchedUri;
      setMockRouteUrlLauncher((uri, {mode = LaunchMode.platformDefault}) async {
        launchedUri = uri;
        return true;
      });

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => launchStoreRoute(
              context,
              lat: -7.7712,
              lng: 110.4089,
              storeName: 'Toko A',
              origin: createPos(-7.7800, 110.4100),
            ),
            child: const Text('Go'),
          ),
        ),
      ));

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(launchedUri, isNotNull);
      expect(
        launchedUri.toString(),
        'https://www.google.com/maps/dir/?api=1&origin=-7.78,110.41&destination=-7.7712,110.4089&travelmode=driving',
      );
    });

    testWidgets('posisi null: URL tanpa origin, hanya destination dan travelmode', (tester) async {
      Uri? launchedUri;
      setMockRouteUrlLauncher((uri, {mode = LaunchMode.platformDefault}) async {
        launchedUri = uri;
        return true;
      });

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => launchStoreRoute(
              context,
              lat: -7.7712,
              lng: 110.4089,
              storeName: 'Toko A',
              origin: null,
            ),
            child: const Text('Go'),
          ),
        ),
      ));

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(launchedUri, isNotNull);
      expect(
        launchedUri.toString(),
        'https://www.google.com/maps/dir/?api=1&destination=-7.7712,110.4089&travelmode=driving',
      );
      expect(launchedUri!.queryParameters.containsKey('origin'), isFalse);
    });

    testWidgets('di kDebugMode mencetak URL akhir ke debugPrint', (tester) async {
      setMockRouteUrlLauncher((uri, {mode = LaunchMode.platformDefault}) async => true);
      final printed = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) printed.add(message);
      };

      try {
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => launchStoreRoute(
                context,
                lat: -7.77,
                lng: 110.40,
                storeName: 'Toko B',
                origin: createPos(-7.78, 110.41),
              ),
              child: const Text('Go'),
            ),
          ),
        ));

        await tester.tap(find.text('Go'));
        await tester.pumpAndSettle();

        expect(
          printed,
          contains('https://www.google.com/maps/dir/?api=1&origin=-7.78,110.41&destination=-7.77,110.4&travelmode=driving'),
        );
      } finally {
        debugPrint = originalDebugPrint;
      }
    });
  });

  group('StoreRouteButton integrated tests', () {
    testWidgets('posisi tersedia: URL berisi origin dan destination yang benar, tanpa requestPermission', (tester) async {
      fake.permission = LocationPermission.whileInUse;
      fake.serviceEnabled = true;

      Uri? launchedUri;
      setMockRouteUrlLauncher((uri, {mode = LaunchMode.platformDefault}) async {
        launchedUri = uri;
        return true;
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StoreRouteButton(
            lat: -7.7712,
            lng: 110.4089,
            storeName: 'Super Indo Seturan',
          ),
        ),
      ));

      await tester.tap(find.text('Rute'));
      await tester.pumpAndSettle();

      expect(launchedUri, isNotNull);
      expect(launchedUri.toString(), contains('origin=-6.2088,106.8456'));
      expect(launchedUri.toString(), contains('destination=-7.7712,110.4089'));
      expect(launchedUri.toString(), contains('travelmode=driving'));
      expect(fake.requestCount, 0, reason: 'TIDAK boleh memanggil requestPermission');
    });

    testWidgets('posisi null: URL tanpa origin, tidak meminta izin', (tester) async {
      fake.permission = LocationPermission.denied;
      fake.serviceEnabled = true;

      Uri? launchedUri;
      setMockRouteUrlLauncher((uri, {mode = LaunchMode.platformDefault}) async {
        launchedUri = uri;
        return true;
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StoreRouteButton(
            lat: -7.7712,
            lng: 110.4089,
            storeName: 'Super Indo Seturan',
          ),
        ),
      ));

      await tester.tap(find.text('Rute'));
      await tester.pumpAndSettle();

      expect(launchedUri, isNotNull);
      expect(launchedUri!.queryParameters.containsKey('origin'), isFalse);
      expect(launchedUri.toString(), contains('destination=-7.7712,110.4089'));
      expect(fake.requestCount, 0, reason: 'TIDAK boleh memanggil requestPermission');
    });

    testWidgets('dua toko berbeda: destination berbeda, origin sama', (tester) async {
      fake.permission = LocationPermission.whileInUse;
      fake.serviceEnabled = true;

      final launchedUris = <Uri>[];
      setMockRouteUrlLauncher((uri, {mode = LaunchMode.platformDefault}) async {
        launchedUris.add(uri);
        return true;
      });

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              StoreRouteButton(
                buttonKey: const Key('btn_store_1'),
                lat: -7.7712,
                lng: 110.4089,
                storeName: 'Toko 1',
              ),
              StoreRouteButton(
                buttonKey: const Key('btn_store_2'),
                lat: -7.7801,
                lng: 110.4123,
                storeName: 'Toko 2',
              ),
            ],
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('btn_store_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_store_2')));
      await tester.pumpAndSettle();

      expect(launchedUris.length, 2);
      expect(launchedUris[0].queryParameters['origin'], '-6.2088,106.8456');
      expect(launchedUris[1].queryParameters['origin'], '-6.2088,106.8456');
      expect(launchedUris[0].queryParameters['destination'], '-7.7712,110.4089');
      expect(launchedUris[1].queryParameters['destination'], '-7.7801,110.4123');
      expect(launchedUris[0].queryParameters['destination'], isNot(equals(launchedUris[1].queryParameters['destination'])));
    });

    testWidgets('tap ganda: hanya memicu satu pemanggilan (cegah tap ganda) dan tampilkan indikator', (tester) async {
      fake.permission = LocationPermission.whileInUse;
      fake.serviceEnabled = true;

      int launchCallCount = 0;
      setMockRouteUrlLauncher((uri, {mode = LaunchMode.platformDefault}) async {
        launchCallCount++;
        return true;
      });

      final completer = Completer<Position?>();
      LocationService.testGetFreshPosition = ({timeout = const Duration(seconds: 4)}) => completer.future;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StoreRouteButton(
            lat: -7.7712,
            lng: 110.4089,
            storeName: 'Super Indo Seturan',
          ),
        ),
      ));

      final button = find.text('Rute');
      await tester.tap(button);
      await tester.pump(); // frame 1: loading state on

      // Indikator muncul
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Tap kedua saat masih loading
      await tester.tap(button);
      await tester.pump();

      // Selesaikan future posisi
      completer.complete(createPos(-6.2088, 106.8456));
      await tester.pumpAndSettle();

      expect(launchCallCount, 1, reason: 'Tap ganda hanya boleh memicu launchStoreRoute 1 kali');
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('timeout: tetap membuka Maps tanpa origin', (tester) async {
      fake.permission = LocationPermission.whileInUse;
      fake.serviceEnabled = true;

      Uri? launchedUri;
      setMockRouteUrlLauncher((uri, {mode = LaunchMode.platformDefault}) async {
        launchedUri = uri;
        return true;
      });

      LocationService.testGetFreshPosition = ({timeout = const Duration(seconds: 4)}) async {
        return null; // simulasi timeout / gagal
      };

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StoreRouteButton(
            lat: -7.7712,
            lng: 110.4089,
            storeName: 'Super Indo Seturan',
          ),
        ),
      ));

      await tester.tap(find.text('Rute'));
      await tester.pumpAndSettle();

      expect(launchedUri, isNotNull);
      expect(launchedUri!.queryParameters.containsKey('origin'), isFalse);
      expect(launchedUri.toString(), contains('destination=-7.7712,110.4089'));
      expect(launchedUri.toString(), contains('travelmode=driving'));
    });
  });
}
