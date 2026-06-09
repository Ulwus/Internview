import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AnimatedTabBar extends StatefulWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final Color selectedColor;
  final Color unselectedColor;
  final Color selectedTextColor;
  final Color unselectedTextColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final double fontSize;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final Duration animationDuration;
  final Curve animationCurve;
  final Offset shadowOffset;
  final Color shadowColor;

  const AnimatedTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChanged,
    this.selectedColor = Colors.black,
    this.unselectedColor = Colors.white,
    this.selectedTextColor = Colors.white,
    this.unselectedTextColor = Colors.black,
    this.borderColor = Colors.black,
    this.borderWidth = 2.0,
    this.borderRadius = 12.0,
    this.fontSize = 11.0,
    this.padding,
    this.height,
    this.animationDuration = const Duration(milliseconds: 250),
    this.animationCurve = Curves.easeOutCubic,
    this.shadowOffset = const Offset(3, 3),
    this.shadowColor = Colors.black,
  });

  @override
  State<AnimatedTabBar> createState() => _AnimatedTabBarState();
}

class _AnimatedTabBarState extends State<AnimatedTabBar> {
  int? _pressedIndex;
  bool _isContainerPressed = false;

  @override
  Widget build(BuildContext context) {
    final innerPadding = widget.padding is EdgeInsets ? widget.padding as EdgeInsets : const EdgeInsets.all(3);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isContainerPressed = true),
      onTapUp: (_) => setState(() => _isContainerPressed = false),
      onTapCancel: () => setState(() => _isContainerPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        curve: Curves.linear,
        height: widget.height ?? 44,
        padding: innerPadding,
        transform: Matrix4.translationValues(
          _isContainerPressed ? widget.shadowOffset.dx : 0,
          _isContainerPressed ? widget.shadowOffset.dy : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: widget.unselectedColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: widget.borderColor, width: widget.borderWidth),
          boxShadow: [
            BoxShadow(
              color: widget.shadowColor,
              blurRadius: 0,
              offset: _isContainerPressed ? Offset.zero : widget.shadowOffset,
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / widget.tabs.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: widget.animationDuration,
                  curve: widget.animationCurve,
                  left: widget.selectedIndex * tabWidth,
                  top: 0,
                  bottom: 0,
                  width: tabWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.selectedColor,
                      borderRadius: BorderRadius.circular(widget.borderRadius - 2),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(widget.tabs.length, (index) {
                    final isSelected = widget.selectedIndex == index;
                    final isPressed = _pressedIndex == index;

                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => setState(() {
                          _pressedIndex = index;
                          _isContainerPressed = true;
                        }),
                        onTapUp: (_) => setState(() {
                          _pressedIndex = null;
                          _isContainerPressed = false;
                        }),
                        onTapCancel: () => setState(() {
                          _pressedIndex = null;
                          _isContainerPressed = false;
                        }),
                        onTap: () async {
                          await HapticFeedback.mediumImpact();
                          setState(() => _isContainerPressed = true);
                          await Future.delayed(const Duration(milliseconds: 50));
                          if (!mounted) return;
                          setState(() => _isContainerPressed = false);
                          if (widget.selectedIndex != index) widget.onTabChanged(index);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          decoration: BoxDecoration(
                            color: !isSelected && isPressed ? widget.selectedColor.withValues(alpha: 0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(widget.borderRadius - 2),
                          ),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: widget.animationDuration,
                              curve: widget.animationCurve,
                              style: GoogleFonts.nunito(
                                fontSize: widget.fontSize,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? widget.selectedTextColor : widget.unselectedTextColor,
                              ),
                              child: Text(widget.tabs[index]),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

