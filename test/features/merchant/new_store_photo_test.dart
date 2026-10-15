import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rakoon_frontend/features/merchant/presentation/pages/merchant_dashboard_page.dart';
import 'package:rakoon_frontend/services/auth_service.dart';

PickedFileData _file(String name, {int size = 1024}) => PickedFileData(name: name, sizeInBytes: size, bytes: Uint8List(size));

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

  int photoUploads = 0;
  int photoStatus = 200;
  Map<String, dynamic>? submitted;

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
          photoUploads++;
          if (photoStatus != 200) return http.Response(jsonEncode({'detail': 'psycopg2 secret'}), photoStatus);
          return http.Response(jsonEncode({'photo_path': 'photos/p.png'}), 200);
        }
        if (path.endsWith('/ads/submit-new-store') && request.method == 'POST') {
          submitted = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'id': 's1', 'submission_type': 'new_store', 'store_name': 'Warung', 'status': 'pending', 'created_at': ''}),
            201,
          );
        }
        return http.Response('{}', 200);
      });

  Future<void> openForm(WidgetTester tester, PickedFileData photo) async {
    await tester.pumpWidget(MaterialApp(
      home: MerchantDashboardPage(
        baseUrl: 'https://api.test',
        httpClient: backend(),
        documentPicker: ({required allowedExtensions}) async => _file('nib.pdf'),
        photoPicker: ({required allowedExtensions}) async => photo,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn_submit_new_store')));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  setUp(() {
    photoUploads = 0;
    photoStatus = 200;
    submitted = null;
  });

  testWidgets('a WebP photo is rejected on the client with a friendly message', (tester) async {
    await mockNetworkImagesFor(() async {
      await openForm(tester, _file('depan.webp'));
      await tapKey(tester, 'btn_pick_store_photo');
      expect(find.text('Foto harus berformat JPEG atau PNG.'), findsOneWidget);
      expect(find.byKey(const Key('selected_photo_name')), findsNothing);
      expect(photoUploads, 0);
    });
  });

  testWidgets('an oversized photo is rejected on the client', (tester) async {
    await mockNetworkImagesFor(() async {
      await openForm(tester, _file('depan.png', size: 5 * 1024 * 1024 + 1));
      await tapKey(tester, 'btn_pick_store_photo');
      expect(find.textContaining('5 MB'), findsWidgets);
      expect(find.byKey(const Key('selected_photo_name')), findsNothing);
    });
  });

  for (final name in ['depan.jpg', 'depan.JPEG', 'depan.png']) {
    testWidgets('$name is accepted as a store photo', (tester) async {
      await mockNetworkImagesFor(() async {
        await openForm(tester, _file(name));
        await tapKey(tester, 'btn_pick_store_photo');
        expect(find.byKey(const Key('selected_photo_name')), findsOneWidget);
        expect(find.text('Foto harus berformat JPEG atau PNG.'), findsNothing);
      });
    });
  }

  testWidgets('the uploaded photo_path is sent as store_photo_url', (tester) async {
    await mockNetworkImagesFor(() async {
      await openForm(tester, _file('depan.png'));
      await tester.enterText(find.byKey(const Key('new_store_name_input')), 'Warung Baru');
      await tester.enterText(find.byKey(const Key('new_store_address_input')), 'Jl. Gatot Subroto No. 5, Medan');
      await tester.enterText(find.byKey(const Key('new_store_applicant_name_input')), 'Ahmad Sutanto');
      await tester.enterText(find.byKey(const Key('new_store_applicant_phone_input')), '081233445566');
      await tapKey(tester, 'btn_pick_claim_document');
      await tapKey(tester, 'btn_pick_store_photo');
      final map = find.byKey(const Key('new_store_location_map'));
      await tester.ensureVisible(map);
      await tester.tap(map);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tapKey(tester, 'btn_confirm_submit_new_store');

      expect(photoUploads, 1);
      expect(submitted?['store_photo_url'], 'photos/p.png');
      expect(submitted?['document_url'], 'documents/d.pdf');
    });
  });

  testWidgets('photo upload failure (503) shows the friendly storage message, never the raw body', (tester) async {
    await mockNetworkImagesFor(() async {
      photoStatus = 503;
      await openForm(tester, _file('depan.png'));
      await tester.enterText(find.byKey(const Key('new_store_name_input')), 'Warung Baru');
      await tester.enterText(find.byKey(const Key('new_store_address_input')), 'Jl. Gatot Subroto No. 5, Medan');
      await tester.enterText(find.byKey(const Key('new_store_applicant_name_input')), 'Ahmad Sutanto');
      await tester.enterText(find.byKey(const Key('new_store_applicant_phone_input')), '081233445566');
      await tapKey(tester, 'btn_pick_claim_document');
      await tapKey(tester, 'btn_pick_store_photo');
      final map = find.byKey(const Key('new_store_location_map'));
      await tester.ensureVisible(map);
      await tester.tap(map);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tapKey(tester, 'btn_confirm_submit_new_store');

      expect(find.textContaining('Penyimpanan belum tersedia, coba lagi nanti'), findsWidgets);
      expect(find.textContaining('psycopg2'), findsNothing);
      expect(submitted, isNull);
    });
  });
}
