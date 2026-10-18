import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/core/utils/product_photo_crop_helper.dart';

Future<Uint8List> _createSolidImageBytes(int width, int height, Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()..color = color;
  canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), paint);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('renderSquareZoomedPhoto tests (Tugas 3)', () {
    test('renders square 1024x1024 PNG with transparent empty borders and colored center on portrait 3:4 at zoom 1.0', () async {
      // 600x800 solid blue image
      const sourceColor = Color(0xFF0000FF);
      final sourceBytes = await _createSolidImageBytes(600, 800, sourceColor);

      final renderedBytes = await renderSquareZoomedPhoto(sourceBytes, 1.0);
      expect(renderedBytes.lengthInBytes, lessThan(4.5 * 1024 * 1024));

      final codec = await ui.instantiateImageCodec(renderedBytes);
      final frame = await codec.getNextFrame();
      final renderedImage = frame.image;

      expect(renderedImage.width, 1024);
      expect(renderedImage.height, 1024);

      final rawData = await renderedImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(rawData, isNotNull);

      // Pixel in empty margin area (x: 50, y: 512) must be transparent (alpha 0)
      final emptyIndex = (512 * 1024 + 50) * 4;
      final emptyAlpha = rawData!.getUint8(emptyIndex + 3);
      expect(emptyAlpha, 0, reason: 'Pixel in empty margin should have alpha 0');

      // Center pixel (x: 512, y: 512) must have source color (blue, alpha 255)
      final centerIndex = (512 * 1024 + 512) * 4;
      final r = rawData.getUint8(centerIndex);
      final g = rawData.getUint8(centerIndex + 1);
      final b = rawData.getUint8(centerIndex + 2);
      final a = rawData.getUint8(centerIndex + 3);

      expect(a, 255, reason: 'Center pixel should be fully opaque');
      expect(b, 255, reason: 'Center pixel should match source blue');
      expect(r, 0);
      expect(g, 0);
    });

    test('re-renders at 768px when output would exceed 4.5 MB', () async {
      final sourceBytes = await _createSolidImageBytes(500, 500, Colors.green);

      // We test the threshold fallback parameter
      final renderedBytes = await renderSquareZoomedPhoto(
        sourceBytes,
        1.25,
        maxBytesThreshold: 10, // Force fallback to 768
      );

      final codec = await ui.instantiateImageCodec(renderedBytes);
      final frame = await codec.getNextFrame();
      final renderedImage = frame.image;

      expect(renderedImage.width, 768);
      expect(renderedImage.height, 768);
    });
  });
}
