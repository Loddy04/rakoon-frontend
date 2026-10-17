import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';
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
    tempDir = Directory.systemTemp.createTempSync('scan_quality_test');
    photo = File('${tempDir.path}/shelf.jpg')..writeAsBytesSync([1, 2, 3, 4, 5]);
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
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Tugas 1: scanCameraPreset constant and ResolutionPreset', () {
    test('scanCameraPreset is ResolutionPreset.veryHigh', () {
      expect(scanCameraPreset, ResolutionPreset.veryHigh);
    });
  });

  group('Tugas 2: Gallery options and named constants', () {
    test('galleryMaxDimension is 2048 and galleryImageQuality is 90', () {
      expect(galleryMaxDimension, 2048.0);
      expect(galleryImageQuality, 90);
    });

    testWidgets('Gallery picker uses galleryMaxDimension (2048) and galleryImageQuality (90)', (tester) async {
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

      expect(picker.recordedMaxWidth, 2048.0);
      expect(picker.recordedMaxHeight, 2048.0);
      expect(picker.recordedImageQuality, 90);
    });
  });

  group('Tugas 3: 413 Payload Too Large handling', () {
    const expected413Message = 'Foto terlalu besar. Coba ambil lebih dekat atau pilih dari galeri.';

    test('ScanService.scanPhoto maps 413 to friendly message without raw response body', () async {
      final client413 = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Request entity too large: 15728640 bytes exceeds limit of 10485760'}), 413);
      });

      expect(
        () => ScanService.scanPhoto(
          photo,
          baseUrl: 'http://localhost:8000',
          client: client413,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'toString',
          'Exception: $expected413Message',
        )),
      );
    });

    testWidgets('UI handles 413: shows friendly text, retains photo, displays Coba lagi and Foto Baru buttons', (tester) async {
      final client = MockClient((request) async {
        return http.Response('{"detail": "File too large"}', 413);
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

      // Verify friendly message without raw body
      expect(find.text(expected413Message), findsOneWidget);
      expect(find.textContaining('File too large'), findsNothing);

      // Verify photo file still exists on disk and is retained
      expect(photo.existsSync(), isTrue);

      // Verify both "Coba lagi" and "Foto Baru" buttons are present
      expect(find.byKey(const Key('retry_scan_button')), findsOneWidget);
      expect(find.byKey(const Key('retake_button')), findsOneWidget);
    });
  });
}
