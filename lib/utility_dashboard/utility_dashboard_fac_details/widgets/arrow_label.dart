import 'package:flutter/material.dart';

import '../models/group_frame_types.dart';
import 'arrow_painter.dart';
import 'flow_effect_painter.dart';

class ArrowLabel extends StatelessWidget {
  final Color color;
  final Color effectColor;
  final double blinkValue;
  final bool selected;
  final bool hasAlarm;
  final ArrowDirection direction;
  final EdgeInsets padding;
  final BoxConstraints constraints;
  final Widget child;
  final GroupFrameEffect effect;
  final double effectValue;

  const ArrowLabel({
    super.key,
    required this.color,
    required this.effectColor,
    required this.blinkValue,
    required this.selected,
    required this.hasAlarm,
    required this.direction,
    required this.padding,
    required this.constraints,
    required this.child,
    required this.effect,
    required this.effectValue,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = hasAlarm
        ? blinkValue
        : selected
        ? 0.88
        : 0.58;

    final glowColor = hasAlarm ? Colors.redAccent : color;

    final borderColor = hasAlarm
        ? const Color(0xFFFF5252)
        : selected
        ? Colors.amberAccent
        : Colors.black.withOpacity(0.85);

    final activeEffectColor = hasAlarm ? const Color(0xFFFF7043) : effectColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(
              hasAlarm
                  ? 0.75 * blinkValue
                  : selected
                  ? 0.45
                  : 0.22,
            ),
            blurRadius: hasAlarm
                ? 28
                : selected
                ? 16
                : 10,
            spreadRadius: hasAlarm
                ? 3
                : selected
                ? 1
                : 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: CustomPaint(
        painter: ArrowPainter(
          color: color.withOpacity(opacity),
          borderColor: borderColor,
          direction: direction,
        ),

        foregroundPainter: FlowEffectPainter(
          direction: direction,
          effect: effect,
          progress: effectValue,
          color: activeEffectColor,
        ),

        child: Container(
          padding: padding,
          constraints: constraints,
          child: IntrinsicWidth(child: child),
        ),
      ),
    );
  }
}
