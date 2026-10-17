import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:rakoon_frontend/core/utils/route_launcher.dart';
import 'package:rakoon_frontend/features/nearby/nearby_stores_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      anonKey: 'mock-anon-key-here', // ignore: deprecated_member_use
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
      ),
    );
  });

  tearDown(() {
    setMockRouteUrlLauncher(null);
  });

  MockClient buildMockClient() {
    return MockClient((request) async {
      if (request.url.path.endsWith('/stores/nearby')) {
        return http.Response(
          jsonEncode({
            "source": "osm",
            "stores": [
              {
                "store_id": "store-1-uuid",
                "nama": "Super Indo Seturan",
                "alamat": "Jl. Seturan Raya No. 1",
                "lat": -7.7712,
                "lng": 110.4089,
                "jarak_km": 0.6,
              },
              {
                "store_id": "store-2-uuid",
                "nama": "Indomaret Babarsari",
                "alamat": "Jl. Babarsari No. 10",
                "lat": -7.7801,
                "lng": 110.4123,
                "jarak_km": 1.2,
              },
            ],
            "message": null,
          }),
          200,
        );
      }
      return http.Response('[]', 200);
    });
  }

  group('NearbyStoresScreen - Route Button & Navigation Tests', () {
    testWidgets('each store item displays Rute button with >= 48dp touch target and Semantics', (
      WidgetTester tester,
    ) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: NearbyStoresScreen(
              baseUrl: 'http://localhost:8000',
              httpClient: buildMockClient(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final routeButtons = find.byKey(const Key('nearby_store_route_button_store-1-uuid'));
        expect(routeButtons, findsOneWidget);

        final size = tester.getSize(routeButtons);
        expect(size.height, greaterThanOrEqualTo(48.0));
        expect(size.width, greaterThanOrEqualTo(48.0));

        final semantics = tester.getSemantics(routeButtons);
        expect(semantics.label, contains('Rute'));
      });
    });

    testWidgets('tapping Rute opens Google Maps with destination coordinates and without origin', (
      WidgetTester tester,
    ) async {
      Uri? launchedUri;
      LaunchMode? usedMode;

      setMockRouteUrlLauncher((uri, {mode = LaunchMode.platformDefault}) async {
        launchedUri = uri;
        usedMode = mode;
        return true;
      });

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: NearbyStoresScreen(
              baseUrl: 'http://localhost:8000',
              httpClient: buildMockClient(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final buttonFinder = find.byKey(const Key('nearby_store_route_button_store-1-uuid'));
        await tester.ensureVisible(buttonFinder);
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        expect(launchedUri, isNotNull);
        expect(launchedUri.toString(), 'https://www.google.com/maps/dir/?api=1&destination=-7.7712,110.4089');
        expect(launchedUri!.queryParameters.containsKey('origin'), isFalse);
        expect(usedMode, equals(LaunchMode.externalApplication));
      });
    });

    testWidgets('when launcher fails, shows friendly SnackBar without raw exception', (
      WidgetTester tester,
    ) async {
      setMockRouteUrlLauncher((uri, {mode = LaunchMode.platformDefault}) async {
        return false;
      });

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: NearbyStoresScreen(
              baseUrl: 'http://localhost:8000',
              httpClient: buildMockClient(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final buttonFinder = find.byKey(const Key('nearby_store_route_button_store-1-uuid'));
        await tester.ensureVisible(buttonFinder);
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        expect(find.text('Tidak dapat membuka rute ke Super Indo Seturan'), findsOneWidget);
      });
    });

    testWidgets('when launcher throws exception, shows friendly SnackBar', (
      WidgetTester tester,
    ) async {
      setMockRouteUrlLauncher((uri, {mode = LaunchMode.platformDefault}) async {
        throw Exception('ActivityNotFoundException: No activity found to handle intent');
      });

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: NearbyStoresScreen(
              baseUrl: 'http://localhost:8000',
              httpClient: buildMockClient(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final buttonFinder = find.byKey(const Key('nearby_store_route_button_store-1-uuid'));
        await tester.ensureVisible(buttonFinder);
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle();

        expect(find.text('Gagal membuka aplikasi navigasi'), findsOneWidget);
        expect(find.textContaining('ActivityNotFoundException'), findsNothing);
      });
    });

    testWidgets('renders cleanly without overflow at 320dp width', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: NearbyStoresScreen(
              baseUrl: 'http://localhost:8000',
              httpClient: buildMockClient(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('nearby_store_route_button_store-1-uuid')), findsOneWidget);
      });
    });
  });
}
