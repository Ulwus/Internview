import 'package:flutter/material.dart';

class NeoButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color? color;
  final double borderWidth;
  final Offset shadowOffset;
  final Color shadowColor;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const NeoButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color,
    this.borderWidth = 3.0,
    this.shadowOffset = const Offset(4, 4),
    this.shadowColor = Colors.black,
    this.borderRadius,
    this.padding,
    this.width,
    this.height,
  });

  @override
  State<NeoButton> createState() => _NeoButtonState();
}

class _NeoButtonState extends State<NeoButton> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onPressed();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentOffset = _isPressed ? const Offset(0, 0) : widget.shadowOffset;
    final translateOffset = _isPressed ? widget.shadowOffset : const Offset(0, 0);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: Transform.translate(
        offset: translateOffset,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.color ?? Colors.white,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: widget.borderWidth),
            boxShadow: [
              BoxShadow(
                color: widget.shadowColor,
                offset: currentOffset,
                blurRadius: 0,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
