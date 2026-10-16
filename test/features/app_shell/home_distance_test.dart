import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/home_screen.dart';
import 'package:rakoon_frontend/features/price_check/presentation/pages/price_check_catalog_page.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _base = 'http://localhost:8000';

Map<String, dynamic> _catalogItem({double? jarakKm}) => {
      'id': 'p1',
      'nama': 'Susu Murah',
      'kategori': 'Minuman',
      'harga_terendah': 12000.0,
      'nama_toko_terendah': 'Toko Murah',
      'jumlah_toko': 2,
      'jarak_km': jarakKm,
    };

/// Records every request; serves a catalog item whose jarak_km is [jarakKm].
class _Api {
  final List<Uri> catalog = [];
  final List<Uri> recommended = [];
  final double? jarakKm;
  _Api({this.jarakKm});

  MockClient get client => MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/products/catalog')) {
          catalog.add(request.url);
          return http.Response(jsonEncode([_catalogItem(jarakKm: jarakKm)]), 200,
              headers: {'content-type': 'application/json'});
        }
        if (path.endsWith('/recommended-products')) {
          recommended.add(request.url);
          return http.Response('[]', 200);
        }
        if (path.endsWith('/scan/recent')) return http.Response('[]', 200);
        return http.Response('{"stores": []}', 200);
      });
}

bool _hasCoords(Uri u) => u.queryParameters.containsKey('lat') || u.queryParameters.containsKey('lng');

void main() {
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
  });
  tearDown(() {
    AuthService.mockSession = null;
    LocationService.testIsLocationServiceEnabled = null;
  });

  group('HomeScreen distance', () {
    testWidgets('with location: lat/lng are sent and the store row shows "Nama · 800 m"', (tester) async {
      await mockNetworkImagesFor(() async {
        final api = _Api(jarakKm: 0.8);
        await tester.pumpWidget(MaterialApp(home: HomeScreen(baseUrl: _base, httpClient: api.client)));
        await tester.pumpAndSettle();

        expect(_hasCoords(api.catalog.last), isTrue);
        expect(api.catalog.last.queryParameters['lat'], isNotEmpty);
        expect(api.catalog.last.queryParameters['lng'], isNotEmpty);
        expect(_hasCoords(api.recommended.last), isTrue);
        expect(find.text('Toko Murah'), findsOneWidget);
        expect(find.text(' · '), findsOneWidget);
        expect(find.text('800 m'), findsOneWidget);
      });
    });

    testWidgets('location denied: no lat/lng anywhere, no distance, no separator', (tester) async {
      LocationService.testIsLocationServiceEnabled = false;
      await mockNetworkImagesFor(() async {
        final api = _Api(jarakKm: null);
        await tester.pumpWidget(MaterialApp(home: HomeScreen(baseUrl: _base, httpClient: api.client)));
        await tester.pumpAndSettle();

        expect(api.catalog, isNotEmpty);
        expect(api.catalog.any(_hasCoords), isFalse);
        expect(api.recommended.any(_hasCoords), isFalse);
        expect(find.text('Toko Murah'), findsOneWidget);
        expect(find.text(' · '), findsNothing);
        expect(find.text('800 m'), findsNothing);
      });
    });

    testWidgets('detecting the location reloads the data with the new lat/lng', (tester) async {
      await mockNetworkImagesFor(() async {
        final api = _Api(jarakKm: 0.8);
        await tester.pumpWidget(MaterialApp(home: HomeScreen(baseUrl: _base, httpClient: api.client)));
        await tester.pumpAndSettle();

        expect(api.catalog.length, greaterThanOrEqualTo(2));
        expect(_hasCoords(api.catalog.first), isFalse);
        expect(_hasCoords(api.catalog.last), isTrue);
      });
    });
  });

  group('PriceCheckCatalogPage distance', () {
    testWidgets('hasUserLocation: sends lat/lng and shows the distance', (tester) async {
      await mockNetworkImagesFor(() async {
        final api = _Api(jarakKm: 0.8);
        await tester.pumpWidget(MaterialApp(
          home: PriceCheckCatalogPage(
            baseUrl: _base,
            httpClient: api.client,
            hasUserLocation: true,
            userLat: -7.78,
            userLng: 110.4,
          ),
        ));
        await tester.pumpAndSettle();

        expect(api.catalog.first.queryParameters['lat'], '-7.78');
        expect(api.catalog.first.queryParameters['lng'], '110.4');
        expect(find.text('800 m'), findsOneWidget);
        expect(find.text(' · '), findsOneWidget);
      });
    });

    testWidgets('no location (default): no lat/lng and no distance', (tester) async {
      await mockNetworkImagesFor(() async {
        final api = _Api(jarakKm: null);
        await tester.pumpWidget(MaterialApp(home: PriceCheckCatalogPage(baseUrl: _base, httpClient: api.client)));
        await tester.pumpAndSettle();

        expect(api.catalog.any(_hasCoords), isFalse);
        expect(find.text('Toko Murah'), findsOneWidget);
        expect(find.text(' · '), findsNothing);
        expect(find.text('800 m'), findsNothing);
      });
    });
  });
}
