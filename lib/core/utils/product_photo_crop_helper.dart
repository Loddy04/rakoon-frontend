import 'dart:math';
import 'dart:ui';

/// Computes a square cropping rectangle in pixel coordinates on the source image.
///
/// [imageWidth] and [imageHeight] are the dimensions of the source image.
/// [zoom] is clamped between 1.0 and 1.5.
/// The side of the square equals `max(imageWidth, imageHeight) / zoom`.
/// The square is centered at the center of the image.
Rect computeCenterZoomRect(double imageWidth, double imageHeight, double zoom) {
  final clampedZoom = zoom.clamp(1.0, 1.5);
  final maxDim = max(imageWidth, imageHeight);
  final side = maxDim / clampedZoom;

  final centerX = imageWidth / 2.0;
  final centerY = imageHeight / 2.0;

  final left = centerX - (side / 2.0);
  final top = centerY - (side / 2.0);

  return Rect.fromLTWH(left, top, side, side);
}
