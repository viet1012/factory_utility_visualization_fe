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
        ? 0.90
        : 0.68;

    final glowColor = hasAlarm ? Colors.redAccent : color;

    final borderColor = hasAlarm
        ? const Color(0xFFFF5252)
        : selected
        ? Colors.amberAccent
        : Colors.black.withOpacity(.78);

    final activeEffectColor = hasAlarm ? const Color(0xFFFF7043) : effectColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,

      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(
              hasAlarm
                  ? .55 * blinkValue
                  : selected
                  ? .28
                  : .10,
            ),

            // giảm glow để frame nhìn ốm hơn
            blurRadius: hasAlarm
                ? 14
                : selected
                ? 8
                : 4,

            spreadRadius: hasAlarm ? 1 : 0,

            offset: const Offset(0, 1),
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
