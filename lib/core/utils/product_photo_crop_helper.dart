import 'dart:math';
import 'dart:typed_data';
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

/// Renders a square PNG image of 1024x1024 (or 768px fallback if > 4.5 MB)
/// from [imageBytes] zoomed according to [zoom].
Future<Uint8List> renderSquareZoomedPhoto(
  Uint8List imageBytes,
  double zoom, {
  int maxBytesThreshold = 4718592, // 4.5 MB
}) async {
  final Codec codec = await instantiateImageCodec(imageBytes);
  final FrameInfo frameInfo = await codec.getNextFrame();
  final Image sourceImage = frameInfo.image;

  var bytes = await _renderAtSize(sourceImage, 1024.0, zoom);
  if (bytes.lengthInBytes > maxBytesThreshold) {
    bytes = await _renderAtSize(sourceImage, 768.0, zoom);
  }
  return bytes;
}

Future<Uint8List> _renderAtSize(Image image, double targetSize, double zoom) async {
  final rect = computeCenterZoomRect(image.width.toDouble(), image.height.toDouble(), zoom);
  final scale = targetSize / rect.width;
  final dstX = (0.0 - rect.left) * scale;
  final dstY = (0.0 - rect.top) * scale;
  final dstWidth = image.width.toDouble() * scale;
  final dstHeight = image.height.toDouble() * scale;

  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.clipRect(Rect.fromLTWH(0, 0, targetSize, targetSize));

  final paint = Paint()..filterQuality = FilterQuality.high;
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromLTWH(dstX, dstY, dstWidth, dstHeight),
    paint,
  );

  final picture = recorder.endRecording();
  final rendered = await picture.toImage(targetSize.toInt(), targetSize.toInt());
  final byteData = await rendered.toByteData(format: ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
