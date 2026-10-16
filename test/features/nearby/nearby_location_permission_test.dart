import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:rakoon_frontend/features/nearby/nearby_stores_screen.dart';
import 'package:rakoon_frontend/services/location_service.dart';

// Koordinat bawaan Yogyakarta yang dulu dipakai sebagai fallback.
const _defaultLat = -7.7829;

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

Future<void> _open(WidgetTester tester, _Api api) async {
  await tester.pumpWidget(MaterialApp(
    home: NearbyStoresScreen(
      baseUrl: 'http://localhost:8000',
      // Home meneruskan koordinat bawaan saat lokasi belum terdeteksi; layar ini tidak boleh memakainya.
      initialLat: _defaultLat,
      initialLng: 110.4083,
      httpClient: api.client,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    LocationService.testResolveCalls = 0;
    LocationService.testPermissionRequests = 0;
  });

  tearDown(() {
    LocationService.testGate = null;
    LocationService.testOutcome = null;
    LocationService.onOpenAppSettings = null;
  });

  testWidgets('izin ditolak: pesan ramah + "Izinkan lokasi", tanpa panggilan toko dan tanpa daftar', (tester) async {
    LocationService.testOutcome = LocationOutcome.denied;
    await mockNetworkImagesFor(() async {
      final api = _Api();
      await _open(tester, api);

      expect(find.text('Izin lokasi diperlukan untuk melihat toko terdekat'), findsOneWidget);
      expect(find.text('Izinkan lokasi'), findsOneWidget);
      expect(api.nearby, isEmpty);
      expect(find.text('Toko Satu'), findsNothing);
      expect(find.byKey(const Key('nearby_user_marker')), findsNothing);
    });
  });

  testWidgets('"Izinkan lokasi" meminta ulang; setelah diberikan toko dimuat dengan koordinat nyata', (tester) async {
    LocationService.testOutcome = LocationOutcome.denied;
    await mockNetworkImagesFor(() async {
      final api = _Api();
      await _open(tester, api);
      expect(api.nearby, isEmpty);

      LocationService.testOutcome = null; // pengguna mengizinkan
      await tester.tap(find.text('Izinkan lokasi'));
      await tester.pumpAndSettle();

      expect(api.nearby, hasLength(1));
      expect(api.nearby.single.queryParameters['lat'], '-6.2088');
      expect(api.nearby.single.queryParameters['lng'], '106.8456');
      expect(api.nearby.any((u) => u.queryParameters['lat'] == _defaultLat.toString()), isFalse);
      expect(find.text('Izin lokasi diperlukan untuk melihat toko terdekat'), findsNothing);
    });
  });

  testWidgets('ditolak permanen: tombol "Buka pengaturan" membuka pengaturan aplikasi', (tester) async {
    LocationService.testOutcome = LocationOutcome.deniedForever;
    var opened = 0;
    LocationService.onOpenAppSettings = () => opened++;
    await mockNetworkImagesFor(() async {
      final api = _Api();
      await _open(tester, api);

      expect(find.text('Buka pengaturan'), findsOneWidget);
      expect(find.text('Izinkan lokasi'), findsNothing);
      expect(api.nearby, isEmpty);

      await tester.tap(find.text('Buka pengaturan'));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });
  });

  testWidgets('kembali dari pengaturan (resume) memuat ulang toko bila izin sudah diberikan', (tester) async {
    LocationService.testOutcome = LocationOutcome.deniedForever;
    await mockNetworkImagesFor(() async {
      final api = _Api();
      await _open(tester, api);
      expect(api.nearby, isEmpty);

      LocationService.testOutcome = null;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(api.nearby, hasLength(1));
      expect(api.nearby.single.queryParameters['lat'], '-6.2088');
    });
  });

  testWidgets('layanan lokasi mati: pesan + "Buka pengaturan lokasi", tanpa panggilan toko', (tester) async {
    LocationService.testOutcome = LocationOutcome.serviceDisabled;
    await mockNetworkImagesFor(() async {
      final api = _Api();
      await _open(tester, api);

      expect(find.text('Layanan lokasi mati. Aktifkan lokasi di pengaturan.'), findsOneWidget);
      expect(find.text('Buka pengaturan lokasi'), findsOneWidget);
      expect(find.text('Coba lagi'), findsNothing);
      expect(api.nearby, isEmpty);
      expect(find.text('Toko Satu'), findsNothing);
    });
  });

  testWidgets('izin diberikan sejak awal: toko dimuat dengan koordinat nyata, bukan koordinat dari pemanggil', (tester) async {
    await mockNetworkImagesFor(() async {
      final api = _Api();
      await _open(tester, api);

      expect(api.nearby, hasLength(1));
      expect(api.nearby.single.queryParameters['lat'], '-6.2088');
      expect(find.text('Toko Satu'), findsWidgets);
    });
  });

  Future<void> resumeApp(WidgetTester tester, {bool settle = true}) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    // Saat permintaan berjalan ada spinner: pumpAndSettle tidak akan selesai.
    settle ? await tester.pumpAndSettle() : await tester.pump();
  }

  group('tanpa loop resume/izin', () {
    testWidgets('ditolak + resume berulang: izin diminta sekali (saat dibuka), tanpa panggilan toko', (tester) async {
      LocationService.testOutcome = LocationOutcome.denied;
      await mockNetworkImagesFor(() async {
        final api = _Api();
        await _open(tester, api);
        expect(LocationService.testPermissionRequests, 1);

        for (var i = 0; i < 5; i++) {
          await resumeApp(tester);
        }

        expect(LocationService.testPermissionRequests, 1);
        expect(api.nearby, isEmpty);
        expect(find.text('Izinkan lokasi'), findsOneWidget);
      });
    });

    testWidgets('ditolak, diberikan di pengaturan, lalu resume berulang: toko dimuat sekali', (tester) async {
      LocationService.testOutcome = LocationOutcome.denied;
      await mockNetworkImagesFor(() async {
        final api = _Api();
        await _open(tester, api);

        LocationService.testOutcome = null;
        await resumeApp(tester);
        await resumeApp(tester);
        await resumeApp(tester);

        expect(api.nearby, hasLength(1));
        expect(LocationService.testPermissionRequests, 1);
      });
    });

    testWidgets('tombol "Izinkan lokasi" saat sedang meminta diabaikan', (tester) async {
      LocationService.testOutcome = LocationOutcome.denied;
      await mockNetworkImagesFor(() async {
        final api = _Api();
        await _open(tester, api);
        expect(LocationService.testPermissionRequests, 1);

        final gate = Completer<void>();
        LocationService.testGate = gate.future;
        await tester.tap(find.text('Izinkan lokasi'));
        await tester.tap(find.text('Izinkan lokasi'), warnIfMissed: false);
        gate.complete();
        await tester.pumpAndSettle();

        expect(LocationService.testPermissionRequests, 2);
        expect(api.nearby, isEmpty);
      });
    });

    testWidgets('resume saat permintaan berjalan diabaikan', (tester) async {
      LocationService.testOutcome = LocationOutcome.denied;
      await mockNetworkImagesFor(() async {
        final api = _Api();
        await _open(tester, api);

        final gate = Completer<void>();
        LocationService.testGate = gate.future;
        await tester.tap(find.text('Izinkan lokasi'));
        await tester.pump();
        final before = LocationService.testResolveCalls;
        await resumeApp(tester, settle: false);
        expect(LocationService.testResolveCalls, before);
        gate.complete();
        await tester.pumpAndSettle();
      });
    });

    testWidgets('ditolak permanen + resume berulang: tidak pernah meminta izin lagi', (tester) async {
      LocationService.testOutcome = LocationOutcome.deniedForever;
      await mockNetworkImagesFor(() async {
        final api = _Api();
        await _open(tester, api);
        for (var i = 0; i < 5; i++) {
          await resumeApp(tester);
        }

        expect(LocationService.testPermissionRequests, 0);
        expect(api.nearby, isEmpty);
        expect(find.text('Buka pengaturan'), findsOneWidget);
      });
    });
  });
}
