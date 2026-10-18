import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakoon_frontend/core/utils/product_photo_crop_helper.dart';

void main() {
  group('computeCenterZoomRect tests (Tugas 2)', () {
    test('portrait 3:4 (600x800) at zoom 1.0 covers full height with horizontal extension', () {
      final rect = computeCenterZoomRect(600, 800, 1.0);
      expect(rect.width, 800.0);
      expect(rect.height, 800.0);
      expect(rect.left, -100.0);
      expect(rect.top, 0.0);
      expect(rect.center, const Offset(300.0, 400.0));
    });

    test('portrait 3:4 (600x800) at zoom 1.25', () {
      final rect = computeCenterZoomRect(600, 800, 1.25);
      expect(rect.width, 640.0);
      expect(rect.height, 640.0);
      expect(rect.left, -20.0);
      expect(rect.top, 80.0);
      expect(rect.center, const Offset(300.0, 400.0));
    });

    test('portrait 3:4 (600x800) at zoom 1.5', () {
      final rect = computeCenterZoomRect(600, 800, 1.5);
      expect(rect.width, closeTo(533.333, 0.001));
      expect(rect.height, closeTo(533.333, 0.001));
      expect(rect.left, closeTo(33.333, 0.001));
      expect(rect.top, closeTo(133.333, 0.001));
      expect(rect.center.dx, closeTo(300.0, 0.001));
      expect(rect.center.dy, closeTo(400.0, 0.001));
    });

    test('landscape (800x600) at zoom 1.0 covers full width with vertical extension', () {
      final rect = computeCenterZoomRect(800, 600, 1.0);
      expect(rect.width, 800.0);
      expect(rect.height, 800.0);
      expect(rect.left, 0.0);
      expect(rect.top, -100.0);
      expect(rect.center, const Offset(400.0, 300.0));
    });

    test('square (500x500) at zoom 1.0 matches image bounds', () {
      final rect = computeCenterZoomRect(500, 500, 1.0);
      expect(rect, const Rect.fromLTWH(0, 0, 500, 500));
    });

    test('very small image (10x20) at zoom 1.0', () {
      final rect = computeCenterZoomRect(10, 20, 1.0);
      expect(rect.width, 20.0);
      expect(rect.height, 20.0);
      expect(rect.left, -5.0);
      expect(rect.top, 0.0);
      expect(rect.center, const Offset(5.0, 10.0));
    });

    test('zoom below 1.0 is clamped to 1.0', () {
      final rectClampedLow = computeCenterZoomRect(600, 800, 0.5);
      final rectAt1 = computeCenterZoomRect(600, 800, 1.0);
      expect(rectClampedLow, rectAt1);
    });

    test('zoom above 1.5 is clamped to 1.5', () {
      final rectClampedHigh = computeCenterZoomRect(600, 800, 2.5);
      final rectAt15 = computeCenterZoomRect(600, 800, 1.5);
      expect(rectClampedHigh, rectAt15);
    });
  });
}
