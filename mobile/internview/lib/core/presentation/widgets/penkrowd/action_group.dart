import 'package:flutter/material.dart';

import 'animated_action_button.dart';

class ActionGroup extends StatelessWidget {
  const ActionGroup({
    super.key,
    required this.primary,
    this.secondary = const [],
  });

  final ActionSpec primary;
  final List<ActionSpec> secondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActionButton(spec: primary, isPrimary: true),
        if (secondary.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final s in secondary) ...[
            _ActionButton(spec: s, isPrimary: false),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.spec, required this.isPrimary});

  final ActionSpec spec;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final c = spec.color ?? (isPrimary ? const Color(0xFF00E5FF) : Colors.white);
    return AnimatedActionButton(
      onTap: spec.onTap,
      width: double.infinity,
      height: isPrimary ? 48 : 46,
      color: c,
      pressedColor: c,
      borderColor: Colors.black,
      borderWidth: 3,
      borderRadius: 14,
      shadowOffset: const Offset(4, 4),
      child: Center(
        child: Text(
          spec.label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: isPrimary ? 16 : 14,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class ActionSpec {
  const ActionSpec({
    required this.label,
    required this.onTap,
    this.color,
  });

  final String label;
  final VoidCallback? onTap;
  final Color? color;
}

// Public factory helpers (keeps call-sites clean)
ActionSpec primaryAction({required String label, required VoidCallback? onTap, Color? color}) =>
    ActionSpec(label: label, onTap: onTap, color: color);

ActionSpec secondaryAction({required String label, required VoidCallback? onTap, Color? color}) =>
    ActionSpec(label: label, onTap: onTap, color: color);

