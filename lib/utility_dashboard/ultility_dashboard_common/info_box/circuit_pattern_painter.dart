import 'package:flutter/material.dart';

class CircuitPatternPainter extends CustomPainter {
  final Color color;
  final double animationValue;

  CircuitPatternPainter({required this.color, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.2 * animationValue)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.3);
    path.lineTo(size.width * 0.3, size.height * 0.3);
    path.lineTo(size.width * 0.3, size.height * 0.5);
    path.lineTo(size.width, size.height * 0.5);
    path.moveTo(size.width * 0.7, size.height * 0.2);
    path.lineTo(size.width, size.height * 0.2);
    path.moveTo(0, size.height * 0.8);
    path.lineTo(size.width * 0.5, size.height * 0.8);
    path.lineTo(size.width * 0.5, size.height);

    canvas.drawPath(path, paint);
    canvas.drawPath(path, glowPaint);

    final nodePaint = Paint()
      ..color = color.withOpacity(0.3 * animationValue)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.3),
      3,
      nodePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.5),
      3,
      nodePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.2),
      3,
      nodePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.8),
      3,
      nodePaint,
    );
  }

  @override
  bool shouldRepaint(CircuitPatternPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
