import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnimatedActionButton extends StatefulWidget {
  final IconData? icon;
  final String? image;
  final VoidCallback? onTap;
  final bool isFat3D;
  final bool isSquare;
  final Widget? child;
  final double? width;
  final double? height;
  final Color? color;
  final Color? pressedColor;
  final Color borderColor;
  final Color iconColor;
  final double borderWidth;
  final double? borderRadius;
  final Offset shadowOffset;
  final Duration animationDuration;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? customShadows;
  final Curve curve;
  final bool forcePressed;
  final AlignmentGeometry alignment;

  const AnimatedActionButton({
    super.key,
    this.icon,
    this.image,
    this.onTap,
    this.isFat3D = false,
    this.isSquare = false,
    this.child,
    this.width,
    this.height,
    this.color,
    this.pressedColor,
    this.borderColor = Colors.black,
    this.iconColor = Colors.black,
    this.borderWidth = 2.0,
    this.borderRadius,
    this.shadowOffset = const Offset(4, 4),
    this.animationDuration = const Duration(milliseconds: 50),
    this.padding,
    this.margin,
    this.customShadows,
    this.curve = Curves.linear,
    this.forcePressed = false,
    this.alignment = Alignment.center,
  });

  @override
  State<AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<AnimatedActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius =
        widget.borderRadius ?? (widget.isSquare ? 12 : (widget.isFat3D ? 24 : 14));

    double? effectiveWidth = widget.width;
    double? effectiveHeight = widget.height;
    if (widget.child == null && widget.width == null && widget.height == null) {
      effectiveWidth = 44;
      effectiveHeight = 44;
    }

    final isPressedState = _isPressed || widget.forcePressed;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () async {
        if (widget.onTap == null) return;
        await HapticFeedback.mediumImpact();
        setState(() => _isPressed = true);
        await Future.delayed(const Duration(milliseconds: 50));
        if (!mounted) return;
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      child: AnimatedContainer(
        duration: widget.animationDuration,
        curve: widget.curve,
        width: effectiveWidth,
        height: effectiveHeight,
        padding: widget.padding,
        margin: widget.margin,
        transform: Matrix4.translationValues(
          isPressedState ? widget.shadowOffset.dx : 0,
          isPressedState ? widget.shadowOffset.dy : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: isPressedState
              ? (widget.pressedColor ?? widget.color ?? Colors.white)
              : (widget.color ?? Colors.white),
          borderRadius: BorderRadius.circular(effectiveBorderRadius),
          border: Border.all(color: widget.borderColor, width: widget.borderWidth),
          boxShadow: widget.customShadows ??
              [
                BoxShadow(
                  color: Colors.black,
                  blurRadius: 0,
                  offset: isPressedState ? Offset.zero : widget.shadowOffset,
                ),
              ],
        ),
        alignment: widget.alignment,
        child: widget.child ??
            (widget.image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(widget.isSquare ? 10 : 12),
                    child: Image.network(
                      widget.image!,
                      fit: BoxFit.cover,
                      width: effectiveWidth ?? 44,
                      height: effectiveHeight ?? 44,
                    ),
                  )
                : Icon(widget.icon, color: widget.iconColor, size: 22)),
      ),
    );
  }
}

