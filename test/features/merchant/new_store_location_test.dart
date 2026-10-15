import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rakoon_frontend/features/merchant/presentation/pages/merchant_dashboard_page.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/widgets/rakoon_location_map.dart';

PickedFileData _file(String name) => PickedFileData(name: name, sizeInBytes: 1024, bytes: Uint8List(1024));

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

  group('RakoonLocationMap point selection', () {
    testWidgets('tapping the map reports the tapped coordinates', (tester) async {
      await mockNetworkImagesFor(() async {
        final picked = <List<double>>[];
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: RakoonLocationMap(
              userLat: 3.5952,
              userLng: 98.6722,
              mapController: MapController(),
              onPointSelected: (lat, lng) => picked.add([lat, lng]),
            ),
          ),
        ));
        await tester.pump();
        await tester.tap(find.byType(FlutterMap));
        await tester.pump(const Duration(milliseconds: 400)); // flutter_map waits to rule out a double tap

        expect(picked, hasLength(1));
        expect(picked.single[0], closeTo(3.5952, 0.01));
        expect(picked.single[1], closeTo(98.6722, 0.01));
      });
    });

    testWidgets('a picked point is drawn as a pin', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: RakoonLocationMap(
              userLat: 3.5952,
              userLng: 98.6722,
              mapController: MapController(),
              pickedPoint: const LatLng(3.5952, 98.6722),
            ),
          ),
        ));
        await tester.pump();
        expect(find.byKey(const Key('picked_point_pin')), findsOneWidget);
      });
    });

    testWidgets('without a picked point there is no pin', (tester) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: RakoonLocationMap(userLat: 3.5952, userLng: 98.6722, mapController: MapController()),
          ),
        ));
        await tester.pump();
        expect(find.byKey(const Key('picked_point_pin')), findsNothing);
      });
    });
  });

  group('New store form location', () {
    Map<String, dynamic>? submitted;
    int submitCalls = 0;

    MockClient backend() => MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/ads/my-store')) {
            return http.Response(jsonEncode({'is_claimed': false, 'claim_status': null, 'campaigns': []}), 200);
          }
          if (path.endsWith('/stores/nearby')) return http.Response(jsonEncode({'stores': []}), 200);
          if (path.endsWith('/ads/my-submissions')) return http.Response('[]', 200);
          if (path.endsWith('/ads/upload-claim-document')) {
            return http.Response(jsonEncode({'document_path': 'documents/d.pdf'}), 200);
          }
          if (path.endsWith('/ads/upload-claim-photo')) {
            return http.Response(jsonEncode({'photo_path': 'photos/p.png'}), 200);
          }
          if (path.endsWith('/ads/submit-new-store') && request.method == 'POST') {
            submitCalls++;
            submitted = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({'id': 's1', 'submission_type': 'new_store', 'store_name': 'Warung', 'status': 'pending', 'created_at': ''}),
              201,
            );
          }
          return http.Response('{}', 200);
        });

    Future<void> fillForm(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MerchantDashboardPage(
          baseUrl: 'https://api.test',
          httpClient: backend(),
          documentPicker: ({required allowedExtensions}) async => _file('nib.pdf'),
          photoPicker: ({required allowedExtensions}) async => _file('depan.png'),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_submit_new_store')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('new_store_name_input')), 'Warung Baru');
      await tester.enterText(find.byKey(const Key('new_store_address_input')), 'Jl. Gatot Subroto No. 5, Medan');
      await tester.enterText(find.byKey(const Key('new_store_applicant_name_input')), 'Ahmad Sutanto');
      await tester.enterText(find.byKey(const Key('new_store_applicant_phone_input')), '081233445566');
      for (final key in ['btn_pick_claim_document', 'btn_pick_store_photo']) {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }
    }

    setUp(() {
      submitted = null;
      submitCalls = 0;
    });

    testWidgets('submitting without a chosen map point is blocked with a clear message', (tester) async {
      await mockNetworkImagesFor(() async {
        await fillForm(tester);
        final submit = find.byKey(const Key('btn_confirm_submit_new_store'));
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();

        expect(find.text('Pilih lokasi toko di peta terlebih dahulu.'), findsOneWidget);
        expect(submitCalls, 0);
      });
    });

    testWidgets('after choosing a point the request carries latitude/longitude and no category', (tester) async {
      await mockNetworkImagesFor(() async {
        await fillForm(tester);
        final map = find.byKey(const Key('new_store_location_map'));
        await tester.ensureVisible(map);
        await tester.tap(map);
        await tester.pump(const Duration(milliseconds: 400)); // flutter_map waits to rule out a double tap
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('picked_point_pin')), findsOneWidget);
        expect(find.textContaining('Titik dipilih'), findsOneWidget);

        final submit = find.byKey(const Key('btn_confirm_submit_new_store'));
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();

        expect(submitCalls, 1);
        expect(submitted?['latitude'], isA<num>());
        expect(submitted?['longitude'], isA<num>());
        expect((submitted!['latitude'] as num).abs(), lessThanOrEqualTo(90));
        expect((submitted!['longitude'] as num).abs(), lessThanOrEqualTo(180));
        expect(submitted!.containsKey('store_category'), isFalse);
      });
    });
  });
}
