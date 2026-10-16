import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/onboarding_screen.dart';
import 'package:rakoon_frontend/features/merchant/presentation/pages/merchant_dashboard_page.dart';
import 'package:rakoon_frontend/features/scan/scan_result_screen.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/services/location_service.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_geolocator.dart';

PickedFileData _file(String name) => PickedFileData(name: name, sizeInBytes: 1024, bytes: Uint8List(1024));

void main() {
  late FakeGeolocator fake;
  late GeolocatorPlatform original;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      anonKey: 'mock-anon-key-here', // ignore: deprecated_member_use
      authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage()),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    original = GeolocatorPlatform.instance;
    fake = FakeGeolocator();
    GeolocatorPlatform.instance = fake;
    LocationService.testUsePlatform = true;
    LocationService.clearCache();

    AuthService.mockSession = Session(
      accessToken: 'test-token',
      tokenType: 'bearer',
      user: User(
        id: 'user-1',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'u@example.com',
      ),
    );
  });

  tearDown(() {
    AuthService.mockSession = null;
    GeolocatorPlatform.instance = original;
    LocationService.testUsePlatform = false;
    LocationService.testOutcome = null;
    LocationService.clearCache();
  });

  group('LocationService.requestPermission deduplication and deniedForever', () {
    test('satu permintaan saja untuk dua pemanggil bersamaan', () async {
      fake.permission = LocationPermission.denied;
      fake.afterRequest = LocationPermission.whileInUse;
      fake.requestGate = Completer<LocationPermission>();

      final a = LocationService.requestPermission();
      final b = LocationService.requestPermission();

      fake.requestGate!.complete(LocationPermission.whileInUse);
      final results = await Future.wait([a, b]);

      expect(results[0], LocationPermission.whileInUse);
      expect(results[1], LocationPermission.whileInUse);
      expect(fake.requestCount, 1);
    });

    test('denied permanen tidak memanggil requestPermission lagi', () async {
      fake.permission = LocationPermission.deniedForever;

      final result = await LocationService.requestPermission();

      expect(result, LocationPermission.deniedForever);
      expect(fake.requestCount, 0);
    });
  });

  group('OnboardingScreen deniedForever flow', () {
    testWidgets('denied permanen tidak memanggil requestPermission dan spinner berhenti dengan opsi pengaturan', (tester) async {
      fake.permission = LocationPermission.deniedForever;

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      expect(find.text('Izinkan'), findsOneWidget);
      await tester.tap(find.text('Izinkan'));
      await tester.pumpAndSettle();

      expect(fake.requestCount, 0);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('ditolak permanen'), findsOneWidget);
      expect(find.text('Pengaturan'), findsOneWidget);

      await tester.tap(find.text('Pengaturan'));
      await tester.pumpAndSettle();
      expect(fake.openAppSettingsCount, 1);
    });
  });

  group('ScanResultScreen deniedForever flow', () {
    testWidgets('denied permanen tidak memanggil requestPermission dan menampilkan tombol buka pengaturan', (tester) async {
      fake.permission = LocationPermission.deniedForever;

      final mockItems = [
        ScanResultItem(
          namaProduk: 'Minyak Filma 2L',
          harga: 36000.0,
          ukuran: 2.0,
          satuan: 'l',
          kategori: 'Makanan Pokok',
          confidence: 'tinggi',
          needsVerification: false,
        ),
      ];

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'stores': []}), 200);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ScanResultScreen(
            detectedItems: mockItems,
            baseUrl: 'https://mock.backend.local',
            httpClient: mockClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fake.requestCount, 0);
      expect(find.textContaining('ditolak permanen'), findsOneWidget);
      expect(find.byKey(const Key('btn_open_app_settings_scan')), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_open_app_settings_scan')));
      await tester.pumpAndSettle();
      expect(fake.openAppSettingsCount, 1);
    });
  });

  group('MerchantDashboardPage deniedForever flow', () {
    testWidgets('denied permanen tidak memanggil requestPermission dan menghentikan spinner dengan tombol buka pengaturan', (tester) async {
      fake.permission = LocationPermission.deniedForever;

      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/ads/my-store')) {
          return http.Response(jsonEncode({'is_claimed': false, 'claim_status': null, 'campaigns': []}), 200);
        }
        if (path.endsWith('/stores/nearby')) return http.Response(jsonEncode({'stores': []}), 200);
        if (path.endsWith('/ads/my-submissions')) return http.Response('[]', 200);
        return http.Response('{}', 200);
      });

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: MerchantDashboardPage(
              baseUrl: 'https://api.test',
              httpClient: mockClient,
              documentPicker: ({required allowedExtensions}) async => _file('nib.pdf'),
              photoPicker: ({required allowedExtensions}) async => _file('depan.png'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btn_submit_new_store')));
        await tester.pumpAndSettle();

        expect(fake.requestCount, 0);
        expect(find.textContaining('dinonaktifkan di pengaturan sistem'), findsOneWidget);
        expect(find.byKey(const Key('btn_open_app_settings_merchant')), findsOneWidget);

        await tester.ensureVisible(find.byKey(const Key('btn_open_app_settings_merchant')));
        await tester.tap(find.byKey(const Key('btn_open_app_settings_merchant')));
        await tester.pumpAndSettle();
        expect(fake.openAppSettingsCount, 1);
      });
    });
  });
}
