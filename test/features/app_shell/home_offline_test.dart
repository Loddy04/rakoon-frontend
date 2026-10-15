import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/home_screen.dart';
import 'package:rakoon_frontend/features/recommendation/presentation/providers/recommendation_provider.dart';
import 'package:rakoon_frontend/services/api_error_messages.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  tearDown(() => AuthService.mockSession = null);

  group('RecommendationProvider', () {
    for (final failure in <String, Object Function()>{
      'SocketException': () => const SocketException('Failed host lookup: secret.host'),
      'TimeoutException': () => TimeoutException('slow'),
    }.entries) {
      test('${failure.key}: error message is the offline message, no raw detail', () async {
        final provider = RecommendationProvider();
        await provider.fetchRecommendedProducts(
          baseUrl: 'http://localhost:8000',
          client: MockClient((_) async => throw failure.value()),
        );
        expect(provider.isError, isTrue);
        expect(provider.errorMessage, noConnectionMessage);
      });
    }

    test('HTTP 503 gives the server message', () async {
      final provider = RecommendationProvider();
      await provider.fetchRecommendedProducts(
        baseUrl: 'http://localhost:8000',
        client: MockClient((_) async => http.Response('psycopg2 secret', 503)),
      );
      expect(provider.errorMessage, serverErrorMessage);
    });
  });

  group('HomeScreen offline', () {
    testWidgets('catalog failure shows the offline message with Coba lagi that retries', (tester) async {
      await mockNetworkImagesFor(() async {
        var online = false;
        var catalogCalls = 0;
        final client = MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/products/catalog')) {
            catalogCalls++;
            if (!online) throw const SocketException('Failed host lookup');
            return http.Response(
              jsonEncode([
                {'id': 'p1', 'nama': 'Produk Satu', 'kategori': 'Makanan Pokok', 'harga_terendah': 1000.0, 'jumlah_toko': 1},
              ]),
              200,
            );
          }
          if (path.endsWith('/scan/recent')) return http.Response('[]', 200);
          return http.Response('{"stores": []}', 200);
        });

        await tester.pumpWidget(MaterialApp(home: HomeScreen(baseUrl: 'http://localhost:8000', httpClient: client)));
        await tester.pumpAndSettle();

        expect(find.text(noConnectionMessage), findsOneWidget);
        expect(find.text('Belum Ada Produk Tersedia'), findsNothing);
        final retry = find.byKey(const Key('retry_home_catalog_button'));
        await tester.ensureVisible(retry);

        online = true;
        final before = catalogCalls;
        await tester.tap(retry);
        await tester.pumpAndSettle();

        expect(catalogCalls, greaterThan(before));
        expect(find.text(noConnectionMessage), findsNothing);
        expect(find.textContaining('Produk Satu'), findsWidgets);
      });
    });

    testWidgets('recent scans failure shows the offline message and the retry button', (tester) async {
      await mockNetworkImagesFor(() async {
        final client = MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/scan/recent')) throw TimeoutException('slow');
          if (path.endsWith('/products/catalog')) return http.Response('[]', 200);
          return http.Response('{"stores": []}', 200);
        });

        await tester.pumpWidget(MaterialApp(home: HomeScreen(baseUrl: 'http://localhost:8000', httpClient: client)));
        await tester.pumpAndSettle();

        final box = find.byKey(const Key('recent_scans_error'));
        await tester.ensureVisible(box);
        expect(find.descendant(of: box, matching: find.text(noConnectionMessage)), findsOneWidget);
        expect(find.byKey(const Key('retry_recent_scans_button')), findsOneWidget);
      });
    });
  });
}
