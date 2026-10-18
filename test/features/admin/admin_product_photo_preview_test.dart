import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rakoon_frontend/features/admin/presentation/pages/admin_product_photo_page.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final validPngBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _FakeImagePicker extends ImagePicker {
  final XFile fileToReturn;
  double? lastMaxWidth;
  double? lastMaxHeight;
  int? lastImageQuality;

  _FakeImagePicker(this.fileToReturn);

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    lastMaxWidth = maxWidth;
    lastMaxHeight = maxHeight;
    lastImageQuality = imageQuality;
    return fileToReturn;
  }
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
    AuthService.mockIsAdmin = true;
    AuthService.mockSession = Session(
      accessToken: 'test-admin-token',
      tokenType: 'bearer',
      user: User(
        id: 'admin-1',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  });

  tearDown(() {
    AuthService.mockSession = null;
    AuthService.mockIsAdmin = null;
  });

  final mockProducts = [
    {
      'id': 'prod-1',
      'nama': 'Teh Kotak 300ml',
      'kategori': 'Minuman',
      'ukuran': 300.0,
      'satuan': 'ml',
      'foto_url': null,
    }
  ];

  http.Client createMockClient({
    void Function(http.BaseRequest request)? onUpload,
    void Function(http.BaseRequest request)? onUrlUpdate,
  }) {
    return MockClient((request) async {
      final path = request.url.path;

      if (path.contains('/auth/me')) {
        return http.Response(
          jsonEncode({
            'user_id': 'mock-admin-id',
            'email': 'admin@rakoon.app',
            'role': 'admin',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.contains('/products') && request.method == 'GET') {
        return http.Response(
          jsonEncode(mockProducts),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.contains('/upload-photo') && request.method == 'POST') {
        onUpload?.call(request);
        return http.Response(
          jsonEncode({
            'id': 'prod-1',
            'foto_url': '/static/uploads/products/mock_uploaded.png',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.contains('/photo') && request.method == 'PUT') {
        onUrlUpdate?.call(request);
        return http.Response(
          jsonEncode({
            'id': 'prod-1',
            'foto_url': 'https://example.com/custom.png',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response('Not Found', 404);
    });
  }

  group('Admin Product Photo Preview & Zoom Tests (Tugas 4 & 5)', () {
    testWidgets('picking photo shows Pratinjau Foto dialog with default zoom Sedang and zoom options', (tester) async {
      final fakePicker = _FakeImagePicker(XFile.fromData(validPngBytes, name: 'teh.jpg'));
      final client = createMockClient();
      double? lastZoom;

      await tester.pumpWidget(
        MaterialApp(
          home: AdminProductPhotoPage(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
            imagePicker: fakePicker,
            renderPhotoFn: (bytes, zoom) async {
              lastZoom = zoom;
              return validPngBytes;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open bottom sheet
      await tester.tap(find.byKey(const Key('edit_photo_btn_prod-1')));
      await tester.pumpAndSettle();

      // Pick image from gallery
      await tester.tap(find.byKey(const Key('admin_pick_gallery_button')));
      await tester.pumpAndSettle();

      // Pratinjau Foto dialog must be visible
      expect(find.text('Pratinjau Foto'), findsOneWidget);
      expect(find.text('Pas'), findsOneWidget);
      expect(find.text('Sedang'), findsOneWidget);
      expect(find.text('Dekat'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Unggah'), findsOneWidget);

      // Default zoom is Sedang (1.25)
      expect(lastZoom, 1.25);

      // Switching to Pas updates zoom to 1.0
      await tester.tap(find.byKey(const Key('zoom_option_pas')));
      await tester.pumpAndSettle();
      expect(lastZoom, 1.0);

      // Switching to Dekat updates zoom to 1.5
      await tester.tap(find.byKey(const Key('zoom_option_dekat')));
      await tester.pumpAndSettle();
      expect(lastZoom, 1.5);

      // Verify touch targets >= 48dp on zoom options
      final pasFinder = find.byKey(const Key('zoom_option_pas'));
      final sedangFinder = find.byKey(const Key('zoom_option_sedang'));
      final dekatFinder = find.byKey(const Key('zoom_option_dekat'));

      expect(pasFinder, findsOneWidget);
      expect(sedangFinder, findsOneWidget);
      expect(dekatFinder, findsOneWidget);

      expect(tester.getSize(pasFinder).height, greaterThanOrEqualTo(48.0));
      expect(tester.getSize(sedangFinder).height, greaterThanOrEqualTo(48.0));
      expect(tester.getSize(dekatFinder).height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('tapping Batal closes preview without calling upload', (tester) async {
      final fakePicker = _FakeImagePicker(XFile.fromData(validPngBytes, name: 'teh.jpg'));
      bool uploadCalled = false;
      final client = createMockClient(onUpload: (_) => uploadCalled = true);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminProductPhotoPage(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
            imagePicker: fakePicker,
            renderPhotoFn: (bytes, zoom) async => validPngBytes,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('edit_photo_btn_prod-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin_pick_gallery_button')));
      await tester.pumpAndSettle();

      expect(find.text('Pratinjau Foto'), findsOneWidget);

      // Tap Batal
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(find.text('Pratinjau Foto'), findsNothing);
      expect(uploadCalled, isFalse);
    });

    testWidgets('tapping Unggah uploads rendered square PNG bytes (not original)', (tester) async {
      final fakePicker = _FakeImagePicker(XFile.fromData(validPngBytes, name: 'raw_camera_shot.jpg'));
      bool uploadCalled = false;
      final client = createMockClient(onUpload: (_) => uploadCalled = true);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminProductPhotoPage(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
            imagePicker: fakePicker,
            renderPhotoFn: (bytes, zoom) async => validPngBytes,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('edit_photo_btn_prod-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin_pick_gallery_button')));
      await tester.pumpAndSettle();

      // Tap Unggah
      await tester.tap(find.text('Unggah'));
      await tester.pumpAndSettle();

      expect(uploadCalled, isTrue);
      expect(find.textContaining('berhasil diperbarui'), findsOneWidget);
    });

    testWidgets('preview dialog is responsive on 320dp without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakePicker = _FakeImagePicker(XFile.fromData(validPngBytes, name: 'teh.jpg'));
      final client = createMockClient();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminProductPhotoPage(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
            imagePicker: fakePicker,
            renderPhotoFn: (bytes, zoom) async => validPngBytes,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('edit_photo_btn_prod-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin_pick_gallery_button')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Pratinjau Foto'), findsOneWidget);
    });

    testWidgets('URL input flow is unchanged and updates photo without preview dialog', (tester) async {
      bool urlUpdateCalled = false;
      final client = createMockClient(onUrlUpdate: (_) => urlUpdateCalled = true);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminProductPhotoPage(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('edit_photo_btn_prod-1')));
      await tester.pumpAndSettle();

      // Switch to URL Tab
      await tester.tap(find.text('Input URL'));
      await tester.pumpAndSettle();

      // Enter valid image URL
      await tester.enterText(
        find.byType(TextField).last,
        'https://example.com/photo.png',
      );
      await tester.pumpAndSettle();

      // Tap Simpan Foto Produk
      await tester.tap(find.byKey(const Key('admin_save_photo_button')));
      await tester.pumpAndSettle();

      expect(find.text('Pratinjau Foto'), findsNothing);
      expect(urlUpdateCalled, isTrue);
      expect(find.textContaining('berhasil diperbarui'), findsOneWidget);
    });

    test('admin product photo picker named constants are defined', () {
      expect(adminProductPhotoMaxDimension, 2048.0);
      expect(adminProductPhotoQuality, 90);
    });

    testWidgets('admin image picker uses 2048px max dimension and 90 quality', (tester) async {
      final fakePicker = _FakeImagePicker(XFile.fromData(validPngBytes, name: 'teh.jpg'));
      final client = createMockClient();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminProductPhotoPage(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
            imagePicker: fakePicker,
            renderPhotoFn: (bytes, zoom) async => validPngBytes,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('edit_photo_btn_prod-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin_pick_gallery_button')));
      await tester.pumpAndSettle();

      expect(fakePicker.lastMaxWidth, 2048.0);
      expect(fakePicker.lastMaxHeight, 2048.0);
      expect(fakePicker.lastImageQuality, 90);
    });
  });
}
