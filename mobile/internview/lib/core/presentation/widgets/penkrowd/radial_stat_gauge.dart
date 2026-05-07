import 'dart:math' as math;

import 'package:flutter/material.dart';

class RadialStatGauge extends StatelessWidget {
  const RadialStatGauge({
    super.key,
    required this.value,
    required this.max,
    required this.label,
    this.size = 82,
    this.trackColor = const Color(0xFFFFFFFF),
    this.borderColor = Colors.black,
    this.accentColor = const Color(0xFF00E5FF),
  });

  final double? value;
  final double max;
  final String label;
  final double size;
  final Color trackColor;
  final Color borderColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = (value == null) ? null : value!.clamp(0, max);
    final progress = (v == null || max <= 0) ? 0.0 : (v / max).clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GaugePainter(
          progress: progress,
          trackColor: trackColor,
          borderColor: borderColor,
          accentColor: v == null ? Colors.black.withValues(alpha: 0.25) : accentColor,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                v == null ? '—' : v.toStringAsFixed(v >= 10 ? 0 : 1),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.black.withValues(alpha: 0.7),
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.progress,
    required this.trackColor,
    required this.borderColor,
    required this.accentColor,
  });

  final double progress;
  final Color trackColor;
  final Color borderColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final center = Offset(size.width / 2, size.height / 2);

    final base = Paint()
      ..style = PaintingStyle.fill
      ..color = trackColor;
    canvas.drawCircle(center, r, base);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = borderColor;
    canvas.drawCircle(center, r - 1.5, border);

    final arcRect = Rect.fromCircle(center: center, radius: r - 10);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: 0.18);
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2, false, track);

    final prog = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = accentColor;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * progress, false, prog);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return progress != oldDelegate.progress ||
        trackColor != oldDelegate.trackColor ||
        borderColor != oldDelegate.borderColor ||
        accentColor != oldDelegate.accentColor;
  }
}

