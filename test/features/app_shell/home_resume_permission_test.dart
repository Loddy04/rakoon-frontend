import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/home_screen.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_geolocator.dart';

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
    original = GeolocatorPlatform.instance;
    fake = FakeGeolocator();
    GeolocatorPlatform.instance = fake;
    LocationService.testUsePlatform = true;
  });

  tearDown(() {
    AuthService.mockSession = null;
    GeolocatorPlatform.instance = original;
    LocationService.testUsePlatform = false;
  });

  final client = MockClient((request) async {
    if (request.url.path.endsWith('/products/catalog')) return http.Response('[]', 200);
    if (request.url.path.endsWith('/scan/recent')) return http.Response('[]', 200);
    return http.Response('{"stores": []}', 200);
  });

  // Langsung ke State Home: lifecycle global juga menyalakan timer auto-refresh Supabase (tidak relevan di sini).
  Future<void> resumeApp(WidgetTester tester) async {
    tester.state<HomeScreenState>(find.byType(HomeScreen)).didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  testWidgets('izin ditolak + resume berulang: Home tidak meminta izin lagi', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(MaterialApp(home: HomeScreen(baseUrl: 'http://localhost:8000', httpClient: client)));
      await tester.pumpAndSettle();
      final afterLaunch = fake.requestCount;
      expect(afterLaunch, lessThanOrEqualTo(1)); // satu permintaan saat Home dibuka

      for (var i = 0; i < 5; i++) {
        await resumeApp(tester);
      }

      expect(fake.requestCount, afterLaunch);
      expect(fake.positionCount, 0);
    });
  });

  testWidgets('izin diberikan di pengaturan lalu resume: lokasi terdeteksi tanpa dialog', (tester) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(MaterialApp(home: HomeScreen(baseUrl: 'http://localhost:8000', httpClient: client)));
      await tester.pumpAndSettle();
      final afterLaunch = fake.requestCount;
      expect(find.text('Babarsari'), findsNothing);

      fake.permission = LocationPermission.whileInUse;
      await resumeApp(tester);

      expect(fake.requestCount, afterLaunch);
      expect(fake.positionCount, greaterThanOrEqualTo(1));
      expect(find.text('Babarsari'), findsWidgets);
    });
  });
}
