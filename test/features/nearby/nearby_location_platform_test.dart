import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:rakoon_frontend/features/nearby/nearby_stores_screen.dart';
import 'package:rakoon_frontend/services/location_service.dart';

import '../../helpers/fake_geolocator.dart';

class _Api {
  final List<Uri> nearby = [];
  late final MockClient client = MockClient((request) async {
    if (request.url.path.endsWith('/stores/nearby')) {
      nearby.add(request.url);
      return http.Response(
        jsonEncode({
          'source': 'db',
          'stores': [
            {'store_id': 's1', 'nama': 'Toko Satu', 'lat': -6.21, 'lng': 106.85, 'jarak_km': 0.4},
          ],
          'message': null,
        }),
        200,
      );
    }
    return http.Response('[]', 200);
  });
}

const _deniedTitle = 'Izin lokasi diperlukan untuk melihat toko terdekat';

void main() {
  late FakeGeolocator fake;
  late GeolocatorPlatform original;

  setUp(() {
    original = GeolocatorPlatform.instance;
    fake = FakeGeolocator();
    GeolocatorPlatform.instance = fake;
    LocationService.testUsePlatform = true;
    LocationService.testResolveCalls = 0;
    LocationService.testPermissionRequests = 0;
  });

  tearDown(() {
    GeolocatorPlatform.instance = original;
    LocationService.testUsePlatform = false;
    LocationService.testOutcome = null;
  });

  Future<_Api> open(WidgetTester tester) async {
    final api = _Api();
    await tester.pumpWidget(MaterialApp(
      home: NearbyStoresScreen(baseUrl: 'http://localhost:8000', httpClient: api.client),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return api;
  }

  testWidgets('izin ditolak: keadaan tanpa lokasi muncul seketika, tanpa spinner, posisi tidak diambil', (tester) async {
    await mockNetworkImagesFor(() async {
      final api = await open(tester);

      expect(find.text(_deniedTitle), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(fake.positionCount, 0);
      expect(fake.calls, ['isLocationServiceEnabled', 'checkPermission', 'requestPermission']);
      expect(api.nearby, isEmpty);
    });
  });

  testWidgets('ditolak permanen: berhenti tanpa requestPermission dan tanpa posisi', (tester) async {
    fake.permission = LocationPermission.deniedForever;
    await mockNetworkImagesFor(() async {
      final api = await open(tester);

      expect(find.text('Buka pengaturan'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(fake.requestCount, 0);
      expect(fake.positionCount, 0);
      expect(api.nearby, isEmpty);
    });
  });

  testWidgets('layanan lokasi mati: pesan, tanpa cek izin dan tanpa posisi', (tester) async {
    fake.serviceEnabled = false;
    await mockNetworkImagesFor(() async {
      await open(tester);

      expect(find.text('Layanan lokasi mati. Aktifkan lokasi di pengaturan.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(fake.calls, ['isLocationServiceEnabled']);
    });
  });

  testWidgets('timeout posisi: "Lokasi belum terdeteksi" dan spinner berhenti', (tester) async {
    fake.permission = LocationPermission.whileInUse;
    fake.positionError = TimeoutException('gps');
    await mockNetworkImagesFor(() async {
      final api = await open(tester);

      expect(find.text('Lokasi belum terdeteksi'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(api.nearby, isEmpty);
    });
  });

  testWidgets('galat platform saat cek izin: spinner berhenti dan ada keadaan yang bisa dicoba lagi', (tester) async {
    fake.checkError = Exception('PlatformException(channel-error)');
    await mockNetworkImagesFor(() async {
      await open(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Lokasi belum terdeteksi'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
    });
  });

  testWidgets('izin diberikan: posisi diambil sekali dan toko dimuat dengan koordinat nyata', (tester) async {
    fake.permission = LocationPermission.whileInUse;
    await mockNetworkImagesFor(() async {
      final api = await open(tester);
      await tester.pumpAndSettle();

      expect(fake.positionCount, 1);
      expect(api.nearby.single.queryParameters['lat'], '-6.2088');
    });
  });

  test('permintaan izin bersamaan (layar + Home) dipakai bersama: requestPermission sekali', () async {
    fake.requestGate = Completer<LocationPermission>();
    final a = LocationService.resolveLocation();
    final b = LocationService.getCurrentLocation().then<Object?>((p) => p, onError: (Object e) => e);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    fake.requestGate!.complete(LocationPermission.denied);
    await Future.wait([a, b]);

    expect(fake.requestCount, 1);
    expect(fake.positionCount, 0);
  });

  group('layanan lokasi mati', () {
    Future<void> resumeApp(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    testWidgets('menampilkan "Buka pengaturan lokasi", bukan "Coba lagi"', (tester) async {
      fake.serviceEnabled = false;
      await mockNetworkImagesFor(() async {
        await open(tester);

        expect(find.text('Layanan lokasi mati. Aktifkan lokasi di pengaturan.'), findsOneWidget);
        expect(find.text('Buka pengaturan lokasi'), findsOneWidget);
        expect(find.text('Coba lagi'), findsNothing);
      });
    });

    testWidgets('tombol membuka pengaturan lokasi tepat sekali, tanpa memuat ulang', (tester) async {
      fake.serviceEnabled = false;
      await mockNetworkImagesFor(() async {
        final api = await open(tester);
        final callsBefore = fake.calls.length;

        await tester.tap(find.text('Buka pengaturan lokasi'));
        await tester.pumpAndSettle();

        expect(fake.openLocationSettingsCount, 1);
        expect(fake.calls.length, callsBefore);
        expect(api.nearby, isEmpty);
      });
    });

    testWidgets('mati lalu diaktifkan di pengaturan lalu resume: toko dimuat tepat sekali', (tester) async {
      fake.serviceEnabled = false;
      await mockNetworkImagesFor(() async {
        final api = await open(tester);

        fake.serviceEnabled = true;
        fake.permission = LocationPermission.whileInUse;
        await resumeApp(tester);
        await resumeApp(tester);

        expect(api.nearby, hasLength(1));
        expect(api.nearby.single.queryParameters['lat'], '-6.2088');
        expect(fake.requestCount, 0);
      });
    });

    testWidgets('resume berulang saat masih mati: tanpa panggilan toko dan tanpa requestPermission', (tester) async {
      fake.serviceEnabled = false;
      await mockNetworkImagesFor(() async {
        final api = await open(tester);
        for (var i = 0; i < 4; i++) {
          await resumeApp(tester);
        }

        expect(api.nearby, isEmpty);
        expect(fake.requestCount, 0);
        expect(fake.positionCount, 0);
        expect(find.text('Buka pengaturan lokasi'), findsOneWidget);
      });
    });
  });

  group('denied tanpa dialog = ditolak permanen', () {
    testWidgets('requestPermission kembali denied seketika: "Buka pengaturan", spinner 0, requestPermission 1x', (tester) async {
      await mockNetworkImagesFor(() async {
        final api = await open(tester);

        expect(find.text('Buka pengaturan'), findsOneWidget);
        expect(find.text('Izinkan lokasi'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(fake.requestCount, 1);
        expect(api.nearby, isEmpty);
      });
    });

    testWidgets('denied setelah dialog sempat tampil (lambat): tetap "Izinkan lokasi"; ulangi lalu instan: "Buka pengaturan"', (tester) async {
      await mockNetworkImagesFor(() async {
        fake.requestGate = Completer<LocationPermission>();
        await open(tester);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 450)));
        fake.requestGate!.complete(LocationPermission.denied);
        await tester.pumpAndSettle();

        expect(find.text('Izinkan lokasi'), findsOneWidget);
        expect(fake.requestCount, 1);

        fake.requestGate = null; // permintaan berikutnya kembali seketika (sistem tidak lagi menampilkan dialog)
        await tester.tap(find.text('Izinkan lokasi'));
        await tester.pumpAndSettle();

        expect(find.text('Buka pengaturan'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(fake.requestCount, 2);

        await tester.tap(find.text('Buka pengaturan'));
        await tester.pumpAndSettle();
        expect(fake.requestCount, 2);
      });
    });
  });
}
