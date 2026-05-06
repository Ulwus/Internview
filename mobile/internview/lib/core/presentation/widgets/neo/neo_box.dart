import 'package:flutter/material.dart';

class NeoBox extends StatelessWidget {
  final Widget child;
  final Color? color;
  final double borderWidth;
  final Offset shadowOffset;
  final Color shadowColor;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  const NeoBox({
    super.key,
    required this.child,
    this.color,
    this.borderWidth = 3.0,
    this.shadowOffset = const Offset(4, 4),
    this.shadowColor = Colors.black,
    this.borderRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: shadowOffset,
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }
}
