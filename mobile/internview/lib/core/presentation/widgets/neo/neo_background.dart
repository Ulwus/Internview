import 'package:flutter/material.dart';

import '../penkrowd/dot_background_painter.dart';

class NeoBackground extends StatelessWidget {
  final Widget child;

  const NeoBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFAFAFA), // Off-white background
      child: CustomPaint(
        painter: DotBackgroundPainter(
          color: Colors.black,
          spacing: 26,
          radius: 1.5,
        ),
        child: child,
      ),
    );
  }
}
