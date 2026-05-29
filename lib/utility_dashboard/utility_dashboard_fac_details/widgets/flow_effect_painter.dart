import 'package:flutter/material.dart';

import '../models/group_frame_types.dart';

class FlowEffectPainter extends CustomPainter {
  final ArrowDirection direction;
  final GroupFrameEffect effect;
  final double progress;
  final Color color;

  const FlowEffectPainter({
    required this.direction,
    required this.effect,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (effect == GroupFrameEffect.none) return;

    final path = _arrowPath(size);
    final metric = path.computeMetrics().first;
    final length = metric.length;

    final segmentLength = effect == GroupFrameEffect.water ? 42.0 : 26.0;
    final start = (progress * length) % length;
    final end = (start + segmentLength).clamp(0.0, length);

    final effectPath = metric.extractPath(start, end);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = effect == GroupFrameEffect.water ? 3.2 : 2.4
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(
        effect == GroupFrameEffect.water ? 0.75 : 0.95,
      )
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        effect == GroupFrameEffect.water ? 4 : 3,
      );

    canvas.drawPath(effectPath, paint);

    if (effect == GroupFrameEffect.electric) {
      final sparkPaint = Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;

      final tangent = metric.getTangentForOffset(start);
      if (tangent != null) {
        final p = tangent.position;
        canvas.drawLine(
          p + const Offset(-4, -3),
          p + const Offset(4, 3),
          sparkPaint,
        );
      }
    }
  }

  Path _arrowPath(Size size) {
    const tip = 10.0;
    const neck = 6.0;

    switch (direction) {
      case ArrowDirection.right:
        return Path()
          ..moveTo(0, neck)
          ..lineTo(size.width - tip, neck)
          ..lineTo(size.width - tip, 0)
          ..lineTo(size.width, size.height / 2)
          ..lineTo(size.width - tip, size.height)
          ..lineTo(size.width - tip, size.height - neck)
          ..lineTo(0, size.height - neck)
          ..close();

      case ArrowDirection.left:
        return Path()
          ..moveTo(tip, 0)
          ..lineTo(tip, neck)
          ..lineTo(size.width, neck)
          ..lineTo(size.width, size.height - neck)
          ..lineTo(tip, size.height - neck)
          ..lineTo(tip, size.height)
          ..lineTo(0, size.height / 2)
          ..close();

      case ArrowDirection.up:
        return Path()
          ..moveTo(neck, tip)
          ..lineTo(size.width / 2 - neck, tip)
          ..lineTo(size.width / 2, 0)
          ..lineTo(size.width / 2 + neck, tip)
          ..lineTo(size.width - neck, tip)
          ..lineTo(size.width - neck, size.height)
          ..lineTo(neck, size.height)
          ..close();

      case ArrowDirection.down:
        return Path()
          ..moveTo(neck, 0)
          ..lineTo(size.width - neck, 0)
          ..lineTo(size.width - neck, size.height - tip)
          ..lineTo(size.width / 2 + neck, size.height - tip)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(size.width / 2 - neck, size.height - tip)
          ..lineTo(neck, size.height - tip)
          ..close();
    }
  }

  @override
  bool shouldRepaint(covariant FlowEffectPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.effect != effect ||
        oldDelegate.color != color ||
        oldDelegate.direction != direction;
  }
}
