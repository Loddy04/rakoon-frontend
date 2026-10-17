import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';
import 'package:rakoon_frontend/services/api_error_messages.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:rakoon_frontend/services/scan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RecordingPicker extends ImagePicker {
  final XFile file;
  double? recordedMaxWidth;
  double? recordedMaxHeight;
  int? recordedImageQuality;
  int pickCount = 0;

  _RecordingPicker(this.file);

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    pickCount++;
    recordedMaxWidth = maxWidth;
    recordedMaxHeight = maxHeight;
    recordedImageQuality = imageQuality;
    return file;
  }
}

void main() {
  late Directory tempDir;
  late File photo;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      anonKey: 'mock-anon-key-here', // ignore: deprecated_member_use
      authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage()),
    );
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('scan_diff_test');
    photo = File('${tempDir.path}/shelf.jpg')..writeAsBytesSync([1, 2, 3, 4]);
    AuthService.mockSession = Session(
      accessToken: 'test-token',
      tokenType: 'bearer',
      user: User(
        id: 'user-123',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  });

  tearDown(() {
    AuthService.mockSession = null;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('Differentiated Network Errors in Scan', () {
    test('scanTimeout constant is 90 seconds', () {
      expect(scanTimeout, const Duration(seconds: 90));
    });

    testWidgets('TimeoutException maps to timeout error message (NOT offline message)', (tester) async {
      final client = MockClient((request) async {
        throw TimeoutException('Client request timed out');
      });
      final picker = _RecordingPicker(XFile(photo.path));

      await tester.pumpWidget(MaterialApp(
        home: ScanCameraScreen(
          baseUrl: 'http://localhost:8000',
          httpClient: client,
          imagePicker: picker,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('gallery_picker_fallback_btn')));
      await tester.pumpAndSettle();

      expect(find.text(timeoutErrorMessage), findsOneWidget);
      expect(find.text(noConnectionMessage), findsNothing);
      expect(find.byKey(const Key('retry_scan_button')), findsOneWidget);

      // Verify retry keeps the same photo without re-picking
      await tester.tap(find.byKey(const Key('retry_scan_button')));
      await tester.pumpAndSettle();

      expect(picker.pickCount, 1, reason: 'Retry must not re-pick photo');
      expect(find.text(timeoutErrorMessage), findsOneWidget);
    });

    testWidgets('SocketException maps to offline error message', (tester) async {
      final client = MockClient((request) async {
        throw const SocketException('Network unreachable');
      });
      final picker = _RecordingPicker(XFile(photo.path));

      await tester.pumpWidget(MaterialApp(
        home: ScanCameraScreen(
          baseUrl: 'http://localhost:8000',
          httpClient: client,
          imagePicker: picker,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('gallery_picker_fallback_btn')));
      await tester.pumpAndSettle();

      expect(find.text(noConnectionMessage), findsOneWidget);
      expect(find.text(timeoutErrorMessage), findsNothing);
      expect(find.byKey(const Key('retry_scan_button')), findsOneWidget);
    });

    testWidgets('ClientException "Connection closed" maps to connection closed message', (tester) async {
      final client = MockClient((request) async {
        throw http.ClientException('Connection closed before full header was received');
      });
      final picker = _RecordingPicker(XFile(photo.path));

      await tester.pumpWidget(MaterialApp(
        home: ScanCameraScreen(
          baseUrl: 'http://localhost:8000',
          httpClient: client,
          imagePicker: picker,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('gallery_picker_fallback_btn')));
      await tester.pumpAndSettle();

      expect(find.text(connectionClosedMessage), findsOneWidget);
      expect(find.text(noConnectionMessage), findsNothing);
      expect(find.byKey(const Key('retry_scan_button')), findsOneWidget);
    });

    testWidgets('Slow response succeeds under 90s limit', (tester) async {
      final client = MockClient((request) async {
        // Delay 100ms in fake test
        await Future.delayed(const Duration(milliseconds: 100));
        return http.Response(
          jsonEncode({
            'detected': [
              {
                'nama_produk': 'Susu UHT 1L',
                'harga': 18000,
                'confidence': 'tinggi',
                'needs_verification': false,
              }
            ]
          }),
          200,
        );
      });
      final picker = _RecordingPicker(XFile(photo.path));

      await tester.pumpWidget(MaterialApp(
        home: ScanCameraScreen(
          baseUrl: 'http://localhost:8000',
          httpClient: client,
          imagePicker: picker,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('gallery_picker_fallback_btn')));
      await tester.pump(); // Start scan
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('Hasil Scan'), findsOneWidget);
    });

    testWidgets('Picking image uses maxWidth: 2048, maxHeight: 2048, and imageQuality: 90', (tester) async {
      final client = MockClient((request) async => http.Response('{"detected": []}', 200));
      final picker = _RecordingPicker(XFile(photo.path));

      await tester.pumpWidget(MaterialApp(
        home: ScanCameraScreen(
          baseUrl: 'http://localhost:8000',
          httpClient: client,
          imagePicker: picker,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('gallery_picker_fallback_btn')));
      await tester.pumpAndSettle();

      expect(picker.recordedMaxWidth, galleryMaxDimension);
      expect(picker.recordedMaxHeight, galleryMaxDimension);
      expect(picker.recordedImageQuality, galleryImageQuality);
    });
  });
}
