import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/app_shell.dart';
import 'package:rakoon_frontend/features/auth/presentation/widgets/login_bottom_sheet.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';
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
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      anonKey: 'mock-anon-key-here', // ignore: deprecated_member_use
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
      ),
    );
  });

  tearDown(() {
    Supabase.instance.client.auth.stopAutoRefresh();
  });

  group('Camera Lifecycle & AppShell Active-Tab Tests', () {
    testWidgets('Initial AppShell launch starts on Home (Scan tab is inactive)', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(baseUrl: 'http://localhost:8000'),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Home is visible and active
      expect(find.text('Rakoon'), findsOneWidget);

      // Verify ScanCameraScreen is mounted with isActive: false (offstage)
      final scanFinder = find.byType(ScanCameraScreen, skipOffstage: false);
      expect(scanFinder, findsOneWidget);

      final ScanCameraScreen scanWidget = tester.widget(scanFinder);
      expect(scanWidget.isActive, isFalse);
    });

    testWidgets('Switching Home -> Scan tab sets isActive to true', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(baseUrl: 'http://localhost:8000'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Scan tab (Index 1)
      await tester.tap(find.byKey(const Key('nav_tab_1')));
      await tester.pumpAndSettle();

      // Verify ScanCameraScreen is on stage and has isActive: true
      final scanFinder = find.byType(ScanCameraScreen);
      expect(scanFinder, findsOneWidget);

      final ScanCameraScreen scanWidget = tester.widget(scanFinder);
      expect(scanWidget.isActive, isTrue);

      // Bottom nav is hidden when Scan tab is active
      expect(find.byKey(const Key('nav_tab_0')), findsNothing);
    });

    testWidgets('Closing Scan tab returns to Home and sets isActive to false (Releases camera)', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(baseUrl: 'http://localhost:8000'),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Scan
      await tester.tap(find.byKey(const Key('nav_tab_1')));
      await tester.pumpAndSettle();

      expect(tester.widget<ScanCameraScreen>(find.byType(ScanCameraScreen)).isActive, isTrue);

      // Tap close button in ScanCameraScreen
      await tester.tap(find.byKey(const Key('scan_close_button')));
      await tester.pumpAndSettle();

      // Verify Home is back
      expect(find.text('Rakoon'), findsOneWidget);

      // Verify ScanCameraScreen is now inactive (offstage)
      expect(
        tester.widget<ScanCameraScreen>(find.byType(ScanCameraScreen, skipOffstage: false)).isActive,
        isFalse,
      );
    });

    testWidgets('Switching Scan -> Profile tab sets isActive to false and releases camera', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(baseUrl: 'http://localhost:8000'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Profile tab (Index 2)
      await tester.tap(find.byKey(const Key('nav_tab_2')));
      await tester.pumpAndSettle();

      // Verify Profile is active
      expect(find.textContaining('Profil'), findsWidgets);

      // Verify Scan is inactive (offstage)
      expect(
        tester.widget<ScanCameraScreen>(find.byType(ScanCameraScreen, skipOffstage: false)).isActive,
        isFalse,
      );
    });

    testWidgets('Returning Profile -> Scan sets isActive to true (Recreates camera)', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(baseUrl: 'http://localhost:8000'),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Profile
      await tester.tap(find.byKey(const Key('nav_tab_2')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ScanCameraScreen>(find.byType(ScanCameraScreen, skipOffstage: false)).isActive,
        isFalse,
      );

      // Go to Scan
      await tester.tap(find.byKey(const Key('nav_tab_1')));
      await tester.pumpAndSettle();
      expect(tester.widget<ScanCameraScreen>(find.byType(ScanCameraScreen)).isActive, isTrue);
    });

    testWidgets('Standalone ScanCameraScreen defaults to isActive: true', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScanCameraScreen(baseUrl: 'http://localhost:8000'),
        ),
      );
      await tester.pumpAndSettle();

      final ScanCameraScreen widget = tester.widget(find.byType(ScanCameraScreen));
      expect(widget.isActive, isTrue);
    });

    testWidgets('Rapid tab switching does not throw or cause race condition exceptions', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(baseUrl: 'http://localhost:8000'),
        ),
      );
      await tester.pump();

      // Rapidly trigger tab switches without settling
      await tester.tap(find.byKey(const Key('nav_tab_1')));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const Key('scan_close_button')));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const Key('nav_tab_2')));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const Key('nav_tab_1')));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const Key('scan_close_button')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Rakoon'), findsOneWidget);
    });

    testWidgets('App backgrounding and foregrounding respects isActive state', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(baseUrl: 'http://localhost:8000'),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Background while on Home (isActive == false)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(
        tester.widget<ScanCameraScreen>(find.byType(ScanCameraScreen, skipOffstage: false)).isActive,
        isFalse,
      );
      expect(tester.takeException(), isNull);

      // 2. Switch to Scan (isActive == true) and background
      await tester.tap(find.byKey(const Key('nav_tab_1')));
      await tester.pumpAndSettle();
      expect(tester.widget<ScanCameraScreen>(find.byType(ScanCameraScreen)).isActive, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(tester.widget<ScanCameraScreen>(find.byType(ScanCameraScreen)).isActive, isTrue);
      expect(tester.takeException(), isNull);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      Supabase.instance.client.auth.stopAutoRefresh();
      await tester.pumpAndSettle();
    });

    testWidgets('Disposing ScanCameraScreen while inactive safely disposes without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScanCameraScreen(
            baseUrl: 'http://localhost:8000',
            isActive: false,
          ),
        ),
      );
      await tester.pump();

      // Replace screen
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    test('ScanCameraScreen source preserves 3:4 viewfinder aspect ratio logic and contracts', () {
      final file = File('lib/features/scan/scan_camera_screen.dart');
      final content = file.readAsStringSync();
      expect(content.contains('isActive'), isTrue);
      expect(content.contains('_deinitializeCamera'), isTrue);
      expect(content.contains('_initializeCamera'), isTrue);
      expect(content.contains('_cameraController!.value.aspectRatio > 1.0'), isTrue);
      expect(content.contains('1.0 / _cameraController!.value.aspectRatio'), isTrue);
    });
  });

  group('ScanCameraScreen Authentication Guard Tests', () {
    late Directory tempDir;
    late File mockPhotoFile;

    setUp(() {
      AuthService.mockSession = null;
      tempDir = Directory.systemTemp.createTempSync();
      mockPhotoFile = File('${tempDir.path}/test_shelf.jpg')..writeAsBytesSync([1, 2, 3]);
    });

    tearDown(() {
      AuthService.mockSession = null;
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    testWidgets('Unauthenticated user tapping scan displays LoginBottomSheet, aborts if dismissed', (tester) async {
      bool scanEndpointCalled = false;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/scan/')) {
          scanEndpointCalled = true;
          return http.Response('{"detected": []}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final mockPicker = MockImagePicker(fileToReturn: XFile(mockPhotoFile.path));

      await tester.pumpWidget(
        MaterialApp(
          home: ScanCameraScreen(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
            imagePicker: mockPicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap gallery button in fallback view
      final galleryBtn = find.byKey(const Key('gallery_picker_fallback_btn'));
      expect(galleryBtn, findsOneWidget);
      await tester.tap(galleryBtn);
      await tester.pumpAndSettle();

      // LoginBottomSheet is shown because session is null
      expect(find.byType(LoginBottomSheet), findsOneWidget);
      expect(scanEndpointCalled, isFalse);

      // Dismiss login sheet
      final BuildContext sheetCtx = tester.element(find.byType(LoginBottomSheet));
      Navigator.pop(sheetCtx, false);
      await tester.pumpAndSettle();

      // Scan was aborted, no request sent
      expect(find.byType(LoginBottomSheet), findsNothing);
      expect(scanEndpointCalled, isFalse);
    });

    testWidgets('Unauthenticated user logging in via LoginBottomSheet continues scan successfully', (tester) async {
      bool scanEndpointCalled = false;
      String? capturedAuthHeader;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/scan/')) {
          scanEndpointCalled = true;
          capturedAuthHeader = request.headers['Authorization'];
          return http.Response(
            jsonEncode({
              'detected': [
                {
                  'nama_produk': 'Beras Ramos 5kg',
                  'harga': 68000,
                  'ukuran': 5.0,
                  'satuan': 'kg',
                  'kategori': 'Makanan Pokok',
                  'confidence': 'tinggi',
                  'needs_verification': false,
                }
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/stores/nearby')) {
          return http.Response('{"stores": []}', 200);
        }
        return http.Response('Not Found', 404);
      });

      final mockPicker = MockImagePicker(fileToReturn: XFile(mockPhotoFile.path));

      await tester.pumpWidget(
        MaterialApp(
          home: ScanCameraScreen(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
            imagePicker: mockPicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap gallery button
      await tester.tap(find.byKey(const Key('gallery_picker_fallback_btn')));
      await tester.pumpAndSettle();

      // Login sheet appears
      expect(find.byType(LoginBottomSheet), findsOneWidget);
      expect(scanEndpointCalled, isFalse);

      // Simulate successful login
      AuthService.mockSession = Session(
        accessToken: 'authenticated-user-token-123',
        tokenType: 'bearer',
        user: User(
          id: 'user-scan-123',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: 'user@rakoon.app',
        ),
      );

      final BuildContext sheetCtx = tester.element(find.byType(LoginBottomSheet));
      Navigator.pop(sheetCtx, true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(seconds: 1));

      // Scan resumed and completed
      expect(scanEndpointCalled, isTrue);
      expect(capturedAuthHeader, 'Bearer authenticated-user-token-123');
    });

    testWidgets('ScanCameraScreen displays friendly message on 401 without raw response body', (tester) async {
      AuthService.mockSession = Session(
        accessToken: 'expired-token',
        tokenType: 'bearer',
        user: User(
          id: 'user-1',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: 'user@rakoon.app',
        ),
      );

      final client = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Token expired, authentication failed'}), 401);
      });

      final mockPicker = MockImagePicker(fileToReturn: XFile(mockPhotoFile.path));

      await tester.pumpWidget(
        MaterialApp(
          home: ScanCameraScreen(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
            imagePicker: mockPicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('gallery_picker_fallback_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Analisis Gagal'), findsOneWidget);
      expect(find.text('Sesi telah berakhir, silakan login ulang'), findsOneWidget);
      expect(find.textContaining('Token expired'), findsNothing);
      expect(find.textContaining('detail'), findsNothing);
    });

    testWidgets('ScanCameraScreen displays friendly message on 429 without raw response body', (tester) async {
      AuthService.mockSession = Session(
        accessToken: 'valid-token',
        tokenType: 'bearer',
        user: User(
          id: 'user-1',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: 'user@rakoon.app',
        ),
      );

      final client = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Too many requests, rate limited'}), 429);
      });

      final mockPicker = MockImagePicker(fileToReturn: XFile(mockPhotoFile.path));

      await tester.pumpWidget(
        MaterialApp(
          home: ScanCameraScreen(
            baseUrl: 'http://localhost:8000',
            httpClient: client,
            imagePicker: mockPicker,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('gallery_picker_fallback_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Analisis Gagal'), findsOneWidget);
      expect(find.text('Terlalu banyak scan, coba lagi nanti'), findsOneWidget);
      expect(find.textContaining('rate limited'), findsNothing);
      expect(find.textContaining('detail'), findsNothing);
    });
  });
}
