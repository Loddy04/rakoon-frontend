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

const _docPath = 'documents/0123456789abcdef0123456789abcdef0123456789abcdef.pdf';
const _photoPath = 'photos/0123456789abcdef0123456789abcdef0123456789abcdef.png';

PickedFileData _file(String name, {int size = 2048}) =>
    PickedFileData(name: name, sizeInBytes: size, bytes: Uint8List(size));

class _Backend {
  int claimCalls = 0;
  int uploadCalls = 0;
  Map<String, dynamic>? claimBody;
  int uploadStatus = 200;
  int claimStatus = 200;

  MockClient get client => MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/ads/my-store')) {
          return http.Response(jsonEncode({'is_claimed': false, 'claim_status': null, 'campaigns': []}), 200);
        }
        if (path.endsWith('/stores/nearby')) {
          return http.Response(
            jsonEncode({
              'source': 'live',
              'stores': [
                {'store_id': 'store-1', 'nama': 'Pamela 6 Supermarket', 'alamat': 'Jl. Raya Condongcatur'}
              ]
            }),
            200,
          );
        }
        if (path.endsWith('/ads/my-submissions')) return http.Response('[]', 200);
        if (path.endsWith('/ads/upload-claim-document') || path.endsWith('/ads/upload-claim-photo')) {
          uploadCalls++;
          if (uploadStatus != 200) return http.Response(jsonEncode({'detail': 'psycopg2 secret'}), uploadStatus);
          final isDoc = path.endsWith('document');
          return http.Response(jsonEncode(isDoc ? {'document_path': _docPath} : {'photo_path': _photoPath}), 200);
        }
        if (path.endsWith('/ads/claim-store') && request.method == 'POST') {
          claimCalls++;
          claimBody = jsonDecode(request.body) as Map<String, dynamic>;
          if (claimStatus != 200) return http.Response(jsonEncode({'detail': 'Klaim Anda untuk toko ini sedang diproses.'}), claimStatus);
          return http.Response(jsonEncode({'is_claimed': false, 'claim_status': 'pending', 'store_id': 'store-1', 'campaigns': []}), 200);
        }
        return http.Response('{}', 200);
      });
}

Future<void> _openForm(
  WidgetTester tester,
  _Backend backend, {
  PickedFileData? doc,
  PickedFileData? photo,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: MerchantDashboardPage(
      baseUrl: 'https://api.test',
      httpClient: backend.client,
      documentPicker: ({required allowedExtensions}) async => doc ?? _file('nib.pdf'),
      photoPicker: ({required allowedExtensions}) async => photo ?? _file('depan.png'),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Klaim & Kelola Toko Ini'));
  await tester.pumpAndSettle();
}

ElevatedButton _submit(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byKey(const Key('claim_form_submit')));

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _fillText(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('claim_form_name')), 'Budi Santoso');
  await tester.enterText(find.byKey(const Key('claim_form_phone')), '081234567890');
  await tester.pump();
}

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

  group('Claim form', () {
    testWidgets('tapping the claim button opens the form instead of sending a claim', (tester) async {
      await mockNetworkImagesFor(() async {
        final backend = _Backend();
        await _openForm(tester, backend);
        expect(find.byKey(const Key('claim_form_submit')), findsOneWidget);
        expect(backend.claimCalls, 0);
      });
    });

    testWidgets('submit stays disabled until name, phone, document and photo are all provided', (tester) async {
      await mockNetworkImagesFor(() async {
        final backend = _Backend();
        await _openForm(tester, backend);
        expect(_submit(tester).onPressed, isNull);

        await _fillText(tester);
        expect(_submit(tester).onPressed, isNull);

        await _tapKey(tester, 'claim_form_pick_document');
        expect(find.textContaining('Dokumen terunggah'), findsOneWidget);
        expect(_submit(tester).onPressed, isNull);

        await _tapKey(tester, 'claim_form_pick_photo');
        expect(find.textContaining('Foto terunggah'), findsOneWidget);
        expect(_submit(tester).onPressed, isNotNull);

        await tester.enterText(find.byKey(const Key('claim_form_phone')), '');
        await tester.pump();
        expect(_submit(tester).onPressed, isNull);
      });
    });

    testWidgets('wrong extensions and oversized files are rejected on the client without uploading', (tester) async {
      await mockNetworkImagesFor(() async {
        final backend = _Backend();
        await _openForm(tester, backend, doc: _file('nib.png'), photo: _file('depan.webp'));
        await _tapKey(tester, 'claim_form_pick_document');
        expect(find.text('Dokumen harus berformat PDF atau JPEG.'), findsOneWidget);
        await _tapKey(tester, 'claim_form_pick_photo');
        expect(find.text('Foto harus berformat JPEG atau PNG.'), findsOneWidget);
        expect(backend.uploadCalls, 0);
      });

      await mockNetworkImagesFor(() async {
        final backend = _Backend();
        await _openForm(tester, backend, doc: _file('besar.pdf', size: 5 * 1024 * 1024 + 1));
        await _tapKey(tester, 'claim_form_pick_document');
        expect(find.textContaining('maksimum 5 MB'), findsOneWidget);
        expect(backend.uploadCalls, 0);
      });
    });

    testWidgets('a complete form sends the uploaded paths with name and phone', (tester) async {
      await mockNetworkImagesFor(() async {
        final backend = _Backend();
        await _openForm(tester, backend);
        await _fillText(tester);
        await _tapKey(tester, 'claim_form_pick_document');
        await _tapKey(tester, 'claim_form_pick_photo');
        await _tapKey(tester, 'claim_form_submit');

        expect(backend.claimCalls, 1);
        expect(backend.claimBody?['store_id'], 'store-1');
        expect(backend.claimBody?['applicant_name'], 'Budi Santoso');
        expect(backend.claimBody?['applicant_phone'], '081234567890');
        expect(backend.claimBody?['document_url'], _docPath);
        expect(backend.claimBody?['store_photo_url'], _photoPath);
        expect(find.byKey(const Key('claim_form_submit')), findsNothing); // form closed
      });
    });

    testWidgets('upload failure shows a friendly message and keeps submit disabled', (tester) async {
      await mockNetworkImagesFor(() async {
        final backend = _Backend()..uploadStatus = 503;
        await _openForm(tester, backend);
        await _fillText(tester);
        await _tapKey(tester, 'claim_form_pick_document');
        expect(find.text('Penyimpanan belum tersedia, coba lagi nanti'), findsOneWidget);
        expect(find.textContaining('psycopg2'), findsNothing);
        expect(_submit(tester).onPressed, isNull);
      });
    });

    testWidgets('409 on submit shows the friendly conflict message and keeps the form open', (tester) async {
      await mockNetworkImagesFor(() async {
        final backend = _Backend()..claimStatus = 409;
        await _openForm(tester, backend);
        await _fillText(tester);
        await _tapKey(tester, 'claim_form_pick_document');
        await _tapKey(tester, 'claim_form_pick_photo');
        await _tapKey(tester, 'claim_form_submit');

        expect(backend.claimCalls, 1);
        expect(find.text('Klaim untuk toko ini sudah ada'), findsOneWidget);
        expect(find.byKey(const Key('claim_form_submit')), findsOneWidget);
      });
    });
  });
}
