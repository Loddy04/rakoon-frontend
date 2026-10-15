import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:rakoon_frontend/features/admin/presentation/pages/admin_store_claims_page.dart';
import 'package:rakoon_frontend/services/ads_service.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://mock.supabase.co',
        anonKey: 'mock-anon-key', // ignore: deprecated_member_use
        authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage()),
      );
    } catch (_) {}
  });

  setUp(() {
    AuthService.mockSession = Session(
      accessToken: 'mock-admin-token',
      tokenType: 'bearer',
      user: const User(
        id: 'admin-1',
        email: 'admin@rakoon.app',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      ),
    );
    AuthService.mockIsAdmin = true;
    verifyBody = null;
    verifyCalls = 0;
  });
  tearDown(() {
    AuthService.mockSession = null;
    AuthService.mockIsAdmin = null;
  });

  group('AdsService.verifyNewStore', () {
    test('sends the corrected coordinates as a pair', () async {
      final client = MockClient((request) async {
        verifyBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'status': 'success'}), 200);
      });
      await AdsService.verifyNewStore(
        submissionId: 'sub-1',
        latitude: 3.6,
        longitude: 98.7,
        baseUrl: 'https://api.test',
        client: client,
      );
      expect(verifyBody, {'submission_id': 'sub-1', 'latitude': 3.6, 'longitude': 98.7});
    });

    test('omits coordinates when there is no correction', () async {
      final client = MockClient((request) async {
        verifyBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'status': 'success'}), 200);
      });
      await AdsService.verifyNewStore(submissionId: 'sub-1', baseUrl: 'https://api.test', client: client);
      expect(verifyBody, {'submission_id': 'sub-1'});
    });
  });

  group('Admin approve dialog for new-store submissions', () {
    Map<String, dynamic> newStore({double? lat = 3.5952, double? lng = 98.6722}) => {
          'user_id': 'user-2',
          'store_id': '',
          'store_nama': 'Warung Baru',
          'store_alamat': 'Jl. Gatot Subroto No. 5, Medan',
          'status': 'pending',
          'created_at': '2026-10-11T10:00:00Z',
          'submission_id': 'sub-1',
          'claim_type': 'new_store',
          'latitude': lat,
          'longitude': lng,
        };

    Map<String, dynamic> existingClaim() => {
          'user_id': 'user-1',
          'store_id': 'store-1',
          'store_nama': 'Toko Berkah',
          'status': 'pending',
          'created_at': '2026-10-10T10:00:00Z',
          'submission_id': 'claim-1',
          'claim_type': 'claim',
        };

    Future<void> openPage(WidgetTester tester, Map<String, dynamic> row) async {
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/ads/pending-claims')) {
          return http.Response(jsonEncode([row]), 200, headers: {'content-type': 'application/json'});
        }
        if (path.endsWith('/ads/verify-new-store')) {
          verifyCalls++;
          verifyBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'status': 'success'}), 200);
        }
        return http.Response('Not Found', 404);
      });
      await tester.pumpWidget(MaterialApp(home: AdminStoreClaimsPage(baseUrl: 'https://api.test', httpClient: client)));
      await tester.pumpAndSettle();
      final approve = find.byKey(const Key('approve_claim_sub-1'));
      await tester.ensureVisible(approve);
      await tester.tap(approve);
      await tester.pumpAndSettle();
    }

    Future<void> tapMapAt(WidgetTester tester, Offset fromTopLeft) async {
      final map = find.byKey(const Key('approve_location_map'));
      await tester.tapAt(tester.getTopLeft(map) + fromTopLeft);
      await tester.pump(const Duration(milliseconds: 400)); // flutter_map waits to rule out a double tap
      await tester.pumpAndSettle();
    }

    bool approveEnabled(WidgetTester tester) =>
        tester.widget<ElevatedButton>(find.byKey(const Key('confirm_approve_button'))).onPressed != null;

    testWidgets('shows the applicant coordinates and a read-only map', (tester) async {
      await mockNetworkImagesFor(() async {
        await openPage(tester, newStore());
        expect(find.byKey(const Key('approve_location_map')), findsOneWidget);
        expect(find.byKey(const Key('picked_point_pin')), findsOneWidget);
        expect(find.text('Titik toko: 3.59520, 98.67220'), findsOneWidget);

        // Read-only until "Koreksi titik" is pressed: a tap must not move the point.
        await tapMapAt(tester, const Offset(20, 20));
        expect(find.text('Titik toko: 3.59520, 98.67220'), findsOneWidget);
      });
    });

    testWidgets('approving without a correction sends no coordinates', (tester) async {
      await mockNetworkImagesFor(() async {
        await openPage(tester, newStore());
        await tester.tap(find.byKey(const Key('confirm_approve_button')));
        await tester.pumpAndSettle();
        expect(verifyCalls, 1);
        expect(verifyBody, {'submission_id': 'sub-1'});
      });
    });

    testWidgets('correcting the point sends the corrected coordinates', (tester) async {
      await mockNetworkImagesFor(() async {
        await openPage(tester, newStore());
        await tester.tap(find.byKey(const Key('correct_point_button')));
        await tester.pumpAndSettle();
        await tapMapAt(tester, const Offset(20, 20));

        expect(find.text('Titik toko: 3.59520, 98.67220'), findsNothing);
        await tester.tap(find.byKey(const Key('confirm_approve_button')));
        await tester.pumpAndSettle();

        expect(verifyCalls, 1);
        expect(verifyBody?['submission_id'], 'sub-1');
        expect(verifyBody?['latitude'], isA<double>());
        expect(verifyBody?['latitude'], isNot(3.5952));
        expect(verifyBody?['longitude'], isNot(98.6722));
      });
    });

    testWidgets('a legacy submission without coordinates cannot be approved until a point is chosen', (tester) async {
      await mockNetworkImagesFor(() async {
        await openPage(tester, newStore(lat: null, lng: null));
        expect(find.textContaining('belum memiliki koordinat'), findsOneWidget);
        expect(approveEnabled(tester), isFalse);

        await tapMapAt(tester, const Offset(40, 40));
        expect(approveEnabled(tester), isTrue);
        await tester.tap(find.byKey(const Key('confirm_approve_button')));
        await tester.pumpAndSettle();

        expect(verifyCalls, 1);
        expect(verifyBody?['latitude'], isA<double>());
        expect(verifyBody?['longitude'], isA<double>());
      });
    });

    testWidgets('approving an existing-store claim keeps the simple dialog without a map', (tester) async {
      await mockNetworkImagesFor(() async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/ads/pending-claims')) {
            return http.Response(jsonEncode([existingClaim()]), 200, headers: {'content-type': 'application/json'});
          }
          return http.Response('Not Found', 404);
        });
        await tester.pumpWidget(MaterialApp(home: AdminStoreClaimsPage(baseUrl: 'https://api.test', httpClient: client)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('approve_claim_store-1')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('approve_location_map')), findsNothing);
        expect(find.byKey(const Key('confirm_approve_button')), findsOneWidget);
      });
    });
  });
}

Map<String, dynamic>? verifyBody;
int verifyCalls = 0;
