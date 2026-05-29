import 'package:flutter/material.dart';

import '../models/group_frame_types.dart';

class ArrowPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final ArrowDirection direction;

  const ArrowPainter({
    required this.color,
    required this.borderColor,
    required this.direction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _arrowPath(size);

    canvas
      ..drawPath(path, Paint()..color = color)
      ..drawPath(
        path,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
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
  bool shouldRepaint(covariant ArrowPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.direction != direction;
  }
}
