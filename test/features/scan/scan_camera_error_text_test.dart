import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';

class ThrowingPicker extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    throw Exception('PlatformException: photo_access_denied_internal');
  }
}

class ThrowingCameraController extends CameraController {
  ThrowingCameraController()
      : super(
          const CameraDescription(
            name: 'mock',
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

  @override
  Future<XFile> takePicture() async {
    throw Exception('Native hardware shutter failure: code 500');
  }
}

void main() {
  testWidgets('gallery error shows friendly message without raw exception', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScanCameraScreen(
          baseUrl: 'http://localhost:8000',
          imagePicker: ThrowingPicker(),
          initialCameraPermissionDenied: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('gallery_picker_fallback_btn')));
    await tester.pumpAndSettle();

    expect(find.textContaining('photo_access_denied_internal'), findsNothing);
    expect(find.text('Tidak dapat membuka galeri. Periksa izin akses foto.'), findsOneWidget);
  });

  testWidgets('camera capture error shows friendly message without raw exception', (tester) async {
    final controller = ThrowingCameraController();
    await tester.pumpWidget(
      MaterialApp(
        home: ScanCameraScreen(
          baseUrl: 'http://localhost:8000',
          customCameraController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('capture_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Native hardware shutter failure'), findsNothing);
    expect(find.text('Gagal mengambil gambar. Coba lagi.'), findsOneWidget);
  });
}
