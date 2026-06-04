import 'package:flutter/material.dart';

class ScadaPanelFrame extends StatelessWidget {
  final Widget child;
  final Color color;

  const ScadaPanelFrame({super.key, required this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ScadaFramePainter(color), child: child);
  }
}

class _ScadaFramePainter extends CustomPainter {
  final Color color;

  _ScadaFramePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const cut = 10.0;

    final path = Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, cut)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..lineTo(0, cut)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF081B36).withOpacity(0.92),
            const Color(0xFF050B16).withOpacity(0.96),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final innerRect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);

    final innerPath = Path()
      ..moveTo(innerRect.left + cut, innerRect.top)
      ..lineTo(innerRect.right - cut, innerRect.top)
      ..lineTo(innerRect.right, innerRect.top + cut)
      ..lineTo(innerRect.right, innerRect.bottom - cut)
      ..lineTo(innerRect.right - cut, innerRect.bottom)
      ..lineTo(innerRect.left + cut, innerRect.bottom)
      ..lineTo(innerRect.left, innerRect.bottom - cut)
      ..lineTo(innerRect.left, innerRect.top + cut)
      ..close();

    canvas.drawPath(
      innerPath,
      Paint()
        ..color = color.withOpacity(0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    final linePaint = Paint()
      ..color = color.withOpacity(0.75)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(18, 5), const Offset(80, 5), linePaint);

    canvas.drawLine(
      Offset(size.width - 80, 5),
      Offset(size.width - 18, 5),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScadaFramePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
