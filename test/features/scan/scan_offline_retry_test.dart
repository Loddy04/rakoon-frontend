import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';
import 'package:rakoon_frontend/services/api_error_messages.dart';
import 'package:rakoon_frontend/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _CountingPicker extends ImagePicker {
  final XFile file;
  int picks = 0;
  _CountingPicker(this.file);

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    picks++;
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
    tempDir = Directory.systemTemp.createTempSync('scan_retry');
    photo = File('${tempDir.path}/shelf.jpg')..writeAsBytesSync([1, 2, 3]);
    AuthService.mockSession = Session(
      accessToken: 'test-token',
      tokenType: 'bearer',
      user: User(
        id: 'user-1',
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

  for (final failure in <String, Object Function()>{
    'SocketException': () => const SocketException('Failed host lookup'),
    'TimeoutException': () => TimeoutException('slow'),
  }.entries) {
    testWidgets('${failure.key}: shows the offline message and retries the same photo without re-picking', (tester) async {
      var scanCalls = 0;
      final client = MockClient((request) async {
        scanCalls++;
        throw failure.value();
      });
      final picker = _CountingPicker(XFile(photo.path));

      await tester.pumpWidget(MaterialApp(
        home: ScanCameraScreen(baseUrl: 'http://localhost:8000', httpClient: client, imagePicker: picker),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gallery_picker_fallback_btn')));
      await tester.pumpAndSettle();

      expect(find.text(noConnectionMessage), findsOneWidget);
      expect(find.byKey(const Key('retry_scan_button')), findsOneWidget);
      expect(scanCalls, 1);

      await tester.tap(find.byKey(const Key('retry_scan_button')));
      await tester.pumpAndSettle();

      expect(scanCalls, 2); // resent the kept photo
      expect(picker.picks, 1); // never asked for a new one
      expect(find.text(noConnectionMessage), findsOneWidget);
      expect(photo.existsSync(), isTrue);
    });
  }

  testWidgets('HTTP 503 shows the server message with the retry button', (tester) async {
    final client = MockClient((_) async => http.Response('psycopg2 secret', 503));
    await tester.pumpWidget(MaterialApp(
      home: ScanCameraScreen(
        baseUrl: 'http://localhost:8000',
        httpClient: client,
        imagePicker: _CountingPicker(XFile(photo.path)),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gallery_picker_fallback_btn')));
    await tester.pumpAndSettle();

    expect(find.text(serverErrorMessage), findsOneWidget);
    expect(find.textContaining('psycopg2'), findsNothing);
    expect(find.byKey(const Key('retry_scan_button')), findsOneWidget);
  });
}
