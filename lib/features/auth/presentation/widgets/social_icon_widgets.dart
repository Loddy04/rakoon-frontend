import 'package:flutter/material.dart';

/// Clean vector rendering of the Google 4-color 'G' icon.
class GoogleLogoWidget extends StatelessWidget {
  final double size;

  const GoogleLogoWidget({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;
    final strokeWidth = radius * 0.44;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    // Red (top arc)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.4, 1.8, false, paint);

    // Blue (upper right arc)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.6, 1.2, false, paint);

    // Green (bottom arc)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.6, 1.2, false, paint);

    // Yellow (left arc)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 1.8, 1.4, false, paint);

    // Blue horizontal center bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final barRect = Rect.fromLTWH(
      center.dx - 1,
      center.dy - strokeWidth / 2,
      radius + 1,
      strokeWidth,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Facebook circle 'f' icon
class FacebookLogoWidget extends StatelessWidget {
  final double size;

  const FacebookLogoWidget({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF1877F2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        'f',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'sans-serif',
          height: 1.0,
        ),
      ),
    );
  }
}
