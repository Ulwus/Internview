import 'package:flutter/material.dart';

class DotBackgroundPainter extends CustomPainter {
  final Color color;
  final double spacing;
  final double radius;

  DotBackgroundPainter({
    this.color = Colors.black,
    this.spacing = 24.0,
    this.radius = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotBackgroundPainter oldDelegate) =>
      color != oldDelegate.color || spacing != oldDelegate.spacing || radius != oldDelegate.radius;
}

