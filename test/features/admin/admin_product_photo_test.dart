// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rakoon_frontend/features/admin/presentation/pages/admin_product_photo_page.dart';
import 'package:rakoon_frontend/features/profile/presentation/pages/profile_page.dart';
import 'package:rakoon_frontend/services/admin_product_service.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockImagePicker extends ImagePicker {
  final XFile? fileToReturn;
  MockImagePicker({this.fileToReturn});

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    return fileToReturn;
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'https://mock.supabase.co',
        anonKey: 'mock-anon-key',
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
        ),
      );
    } catch (_) {
      // Already initialized
    }
  });

  tearDown(() {
    AuthService.mockSession = null;
    AuthService.mockIsAdmin = null;
  });

  final mockProducts = [
    {
      'id': 'prod-1',
      'nama': 'Susu UHT Cokelat 1L',
      'kategori': 'Minuman',
      'ukuran': 1.0,
      'satuan': 'l',
      'foto_url': null,
    },
    {
      'id': 'prod-2',
      'nama': 'Minyak Goreng 2L',
      'kategori': 'Makanan Pokok',
      'ukuran': 2.0,
      'satuan': 'l',
      'foto_url': 'https://example.com/minyak.jpg',
    },
  ];

  http.Client createMockClient() {
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

      if (path.contains('/products/') && request.method == 'GET') {
        final query = request.url.queryParameters['search'];
        var filtered = mockProducts;
        if (query != null && query.isNotEmpty) {
          filtered = mockProducts
              .where((p) => (p['nama'] as String).toLowerCase().contains(query.toLowerCase()))
              .toList();
        }
        return http.Response(
          jsonEncode(filtered),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.contains('/photo') && request.method == 'PUT') {
        final body = jsonDecode(request.body);
        return http.Response(
          jsonEncode({
            'id': 'prod-1',
            'nama': 'Susu UHT Cokelat 1L',
            'kategori': 'Minuman',
            'ukuran': 1.0,
            'satuan': 'l',
            'foto_url': body['foto_url'],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.contains('/upload-photo') && request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'id': 'prod-1',
            'nama': 'Susu UHT Cokelat 1L',
            'kategori': 'Minuman',
            'ukuran': 1.0,
            'satuan': 'l',
            'foto_url': '/static/uploads/products/mock_uploaded.png',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response('Not Found', 404);
    });
  }

  group('Admin Role & AuthService Tests', () {
    test('AuthService.isAdmin respects mockIsAdmin property', () {
      AuthService.mockIsAdmin = true;
      expect(AuthService.isAdmin, isTrue);

      AuthService.mockIsAdmin = false;
      expect(AuthService.isAdmin, isFalse);
    });

    test('AuthService.checkAdminStatus calls /auth/me and detects admin', () async {
      AuthService.mockSession = Session(
        accessToken: 'mock-access-token',
        tokenType: 'bearer',
        user: const User(
          id: 'mock-admin-id',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01',
        ),
      );

      final client = createMockClient();
      final isAdmin = await AuthService.checkAdminStatus(
        baseUrl: 'http://localhost:8000',
        client: client,
      );
      expect(isAdmin, isTrue);
    });
  });

  group('ProfilePage Admin Badge & Navigation Tests', () {
    testWidgets('ProfilePage displays Admin Rakoon badge and Kelola Foto Produk tile for Admin', (tester) async {
      AuthService.mockSession = Session(
        accessToken: 'mock-token',
        tokenType: 'bearer',
        user: const User(
          id: 'mock-admin-user',
          email: 'admin@rakoon.app',
          appMetadata: {'role': 'admin'},
          userMetadata: {'role': 'admin', 'name': 'Super Admin'},
          aud: 'authenticated',
          createdAt: '2026-01-01',
        ),
      );
      AuthService.mockIsAdmin = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: ProfilePage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_admin_badge')), findsOneWidget);
      expect(find.text('Admin Rakoon'), findsOneWidget);
      expect(find.byKey(const Key('admin_panel_tile')), findsOneWidget);
      expect(find.text('Kelola Foto Produk'), findsOneWidget);
    });

    testWidgets('ProfilePage hides Admin badge and Kelola Foto Produk tile for regular user', (tester) async {
      AuthService.mockSession = Session(
        accessToken: 'mock-token',
        tokenType: 'bearer',
        user: const User(
          id: 'mock-regular-user',
          email: 'user@gmail.com',
          appMetadata: {},
          userMetadata: {'name': 'Budi'},
          aud: 'authenticated',
          createdAt: '2026-01-01',
        ),
      );
      AuthService.mockIsAdmin = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: ProfilePage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_admin_badge')), findsNothing);
      expect(find.byKey(const Key('admin_panel_tile')), findsNothing);
    });
  });

  group('AdminProductPhotoPage Widget Tests', () {
    testWidgets('Renders product list with search bar and categories', (tester) async {
      final client = createMockClient();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminProductPhotoPage(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('KELOLA FOTO PRODUK'), findsOneWidget);
      expect(find.text('Panel Administrator'), findsOneWidget);
      expect(find.byKey(const Key('admin_product_search_input')), findsOneWidget);
      expect(find.text('Susu UHT Cokelat 1L'), findsOneWidget);
      expect(find.text('Minyak Goreng 2L'), findsOneWidget);
      expect(find.byKey(const Key('edit_photo_btn_prod-1')), findsOneWidget);
    });

    testWidgets('Tapping edit photo opens bottom sheet and updates photo via URL', (tester) async {
      final client = createMockClient();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminProductPhotoPage(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Upload" / "Ubah" on prod-1
      await tester.tap(find.byKey(const Key('edit_photo_btn_prod-1')));
      await tester.pumpAndSettle();

      expect(find.text('Ubah Foto Produk'), findsOneWidget);
      expect(find.text('Input URL'), findsOneWidget);

      // Switch to URL tab
      await tester.tap(find.text('Input URL'));
      await tester.pumpAndSettle();

      // Enter valid image URL
      await tester.enterText(
        find.byKey(const Key('admin_photo_url_input')),
        'https://example.com/susu-baru.png',
      );
      await tester.pumpAndSettle();

      // Tap Simpan Foto Produk
      await tester.tap(find.byKey(const Key('admin_save_photo_button')));
      await tester.pumpAndSettle();

      // Bottom sheet closes and snackbar appears
      expect(find.textContaining('berhasil diperbarui'), findsOneWidget);
    });

    testWidgets('Uploads photo file using ImagePicker mock and displays success', (tester) async {
      final client = createMockClient();
      final validPngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);
      final mockPicker = MockImagePicker(
        fileToReturn: XFile.fromData(
          validPngBytes,
          name: 'susu.png',
          mimeType: 'image/png',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminProductPhotoPage(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
            imagePicker: mockPicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap edit on prod-1
      await tester.tap(find.byKey(const Key('edit_photo_btn_prod-1')));
      await tester.pumpAndSettle();

      // Pick image from gallery
      await tester.tap(find.byKey(const Key('admin_pick_gallery_button')));
      await tester.pumpAndSettle();

      // Tap Simpan Foto Produk
      await tester.tap(find.byKey(const Key('admin_save_photo_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('berhasil diperbarui'), findsOneWidget);
    });
  });

  group('AdminProductService Unit Tests', () {
    test('updateProductPhotoUrl sends PUT request and returns updated URL', () async {
      final client = createMockClient();
      final url = await AdminProductService.updateProductPhotoUrl(
        productId: 'prod-1',
        photoUrl: 'https://example.com/test.jpg',
        baseUrl: 'http://localhost:8000',
        client: client,
      );
      expect(url, 'https://example.com/test.jpg');
    });

    test('uploadProductPhotoFile sends multipart request and returns static URL', () async {
      final client = createMockClient();
      final url = await AdminProductService.uploadProductPhotoFile(
        productId: 'prod-1',
        fileBytes: Uint8List.fromList([10, 20, 30]),
        fileName: 'mock.png',
        baseUrl: 'http://localhost:8000',
        client: client,
      );
      expect(url, '/static/uploads/products/mock_uploaded.png');
    });
  });
}
