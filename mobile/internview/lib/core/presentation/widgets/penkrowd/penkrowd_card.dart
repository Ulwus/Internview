import 'package:flutter/material.dart';

import 'animated_action_button.dart';

class PenkrowdCard extends StatelessWidget {
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final Offset shadowOffset;

  final Color? accentColor;
  final double accentWidth;

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const PenkrowdCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.backgroundColor = Colors.white,
    this.borderColor = Colors.black,
    this.borderWidth = 3,
    this.borderRadius = 16,
    this.shadowOffset = const Offset(4, 4),
    this.accentColor,
    this.accentWidth = 12,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding.resolve(Directionality.of(context));
    final accentInset = accentColor != null ? accentWidth : 0.0;

    return AnimatedActionButton(
      onTap: onTap,
      width: double.infinity,
      color: backgroundColor,
      pressedColor: backgroundColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
      borderRadius: borderRadius,
      shadowOffset: shadowOffset,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 2),
        child: Stack(
          children: [
            if (accentColor != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: accentWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accentColor,
                    border: Border(
                      right: BorderSide(
                        color: borderColor,
                        width: borderWidth - 1,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                resolvedPadding.left + accentInset,
                resolvedPadding.top,
                resolvedPadding.right,
                resolvedPadding.bottom,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DefaultTextStyle.merge(
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                          child: title,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 6),
                          DefaultTextStyle.merge(
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black.withValues(alpha: 0.75),
                            ),
                            child: subtitle!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
