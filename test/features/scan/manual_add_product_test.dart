import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakoon_frontend/features/scan/presentation/widgets/add_product_bottom_sheet.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockActiveCameraController extends CameraController {
  MockActiveCameraController()
      : super(
          const CameraDescription(
            name: 'mock_active',
            lensDirection: CameraLensDirection.back,
            sensorOrientation: 0,
          ),
          ResolutionPreset.low,
        );

  @override
  Future<void> initialize() async {
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(1920, 1080),
    );
  }
}

void main() {
  late MockClient mockHttpClient;

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

  setUp(() {
    AuthService.mockSession = Session(
      accessToken: 'test-token',
      tokenType: 'bearer',
      user: User(
        id: 'user-123',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'user@example.com',
      ),
    );

    mockHttpClient = MockClient((request) async {
      if (request.url.path.endsWith('/stores/nearby')) {
        return http.Response(
          jsonEncode({
            'source': 'osm',
            'stores': [
              {
                'store_id': 'store-1',
                'nama': 'Indomaret Sudirman',
                'lat': -7.7829,
                'lng': 110.4083,
                'jarak_km': 0.5,
              },
            ],
            'message': null,
          }),
          200,
        );
      }
      return http.Response('Not Found', 404);
    });
  });

  tearDown(() {
    AuthService.mockSession = null;
  });

  group('Manual Add Product Feature Tests', () {
    testWidgets('manual add button is present in camera viewfinder and opens AddProductBottomSheet', (tester) async {
      final controller = MockActiveCameraController();

      await tester.pumpWidget(
        MaterialApp(
          home: ScanCameraScreen(
            baseUrl: 'http://localhost:8000',
            customCameraController: controller,
            httpClient: mockHttpClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify manual add button is visible on viewfinder
      final manualAddBtn = find.byKey(const Key('manual_add_button'));
      expect(manualAddBtn, findsOneWidget);

      // Tap manual add button
      await tester.tap(manualAddBtn);
      await tester.pumpAndSettle();

      // Verify bottom sheet form opened
      expect(find.byType(AddProductBottomSheet), findsOneWidget);
      expect(find.text('Tambah Produk Manual'), findsOneWidget);
      expect(find.byKey(const Key('add_name_field')), findsOneWidget);
      expect(find.byKey(const Key('add_price_field')), findsOneWidget);
      expect(find.byKey(const Key('add_size_field')), findsOneWidget);
      expect(find.byKey(const Key('save_add_button')), findsOneWidget);
    });

    testWidgets('adding manual product navigates to ScanResultScreen with newly created item', (tester) async {
      final controller = MockActiveCameraController();

      await tester.pumpWidget(
        MaterialApp(
          home: ScanCameraScreen(
            baseUrl: 'http://localhost:8000',
            customCameraController: controller,
            httpClient: mockHttpClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open manual add bottom sheet
      await tester.tap(find.byKey(const Key('manual_add_button')));
      await tester.pumpAndSettle();

      // Fill in fields
      await tester.enterText(find.byKey(const Key('add_name_field')), 'Minyak Goreng Bimoli 2L');
      await tester.enterText(find.byKey(const Key('add_price_field')), '34000');
      await tester.enterText(find.byKey(const Key('add_size_field')), '2');

      // Submit form
      await tester.ensureVisible(find.byKey(const Key('save_add_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save_add_button')));
      await tester.pumpAndSettle();

      // Modal should be dismissed and ScanResultScreen should be visible
      expect(find.byType(AddProductBottomSheet), findsNothing);
      expect(find.text('Hasil Scan'), findsOneWidget);
      expect(find.text('Minyak Goreng Bimoli 2L'), findsOneWidget);
      expect(find.text('Rp 34.000'), findsOneWidget);
    });

    testWidgets('manual add button is available in camera fallback view (permission denied)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ScanCameraScreen(
            baseUrl: 'http://localhost:8000',
            initialCameraPermissionDenied: true,
            httpClient: mockHttpClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check fallback button
      final fallbackAddBtn = find.byKey(const Key('manual_add_fallback_btn'));
      expect(fallbackAddBtn, findsOneWidget);
      expect(find.text('Tambah Manual'), findsOneWidget);

      // Tap fallback manual add button
      await tester.tap(fallbackAddBtn);
      await tester.pumpAndSettle();

      // Verify bottom sheet opened
      expect(find.byType(AddProductBottomSheet), findsOneWidget);

      // Dismiss by tapping close icon
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Verify modal is closed
      expect(find.byType(AddProductBottomSheet), findsNothing);
      expect(find.byKey(const Key('manual_add_fallback_btn')), findsOneWidget);
    });

    testWidgets('AddProductBottomSheet enforces validation errors on empty submission', (tester) async {
      final controller = MockActiveCameraController();

      await tester.pumpWidget(
        MaterialApp(
          home: ScanCameraScreen(
            baseUrl: 'http://localhost:8000',
            customCameraController: controller,
            httpClient: mockHttpClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('manual_add_button')));
      await tester.pumpAndSettle();

      // Tap save without filling
      await tester.ensureVisible(find.byKey(const Key('save_add_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save_add_button')));
      await tester.pumpAndSettle();

      // Verify validation warning box and errors
      expect(find.byKey(const Key('add_validation_warning_box')), findsOneWidget);
      expect(find.text('Nama produk wajib diisi'), findsOneWidget);
      expect(find.text('Harga wajib diisi (lebih dari Rp 0)'), findsOneWidget);
      expect(find.text('Ukuran wajib diisi'), findsOneWidget);
    });
  });
}
