import 'dart:ui';

import 'package:flutter/material.dart';

class ScadaChartPanel extends StatelessWidget {
  final Widget child;
  final Color color;
  final double width;
  final double height;

  const ScadaChartPanel({
    super.key,
    required this.child,
    required this.color,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _ScadaChartPanelPainter(color),
        child: ClipPath(
          clipper: _ScadaChartPanelClipper(),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
            child: Container(padding: const EdgeInsets.all(1), child: child),
          ),
        ),
      ),
    );
  }
}

class _ScadaChartPanelClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const cut = 12.0;
    const notchW = 52.0;
    const notchH = 10.0;

    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width * .52, 0)
      ..lineTo(size.width * .52 + notchW, notchH)
      ..lineTo(size.width - cut, notchH)
      ..lineTo(size.width, cut + notchH)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..lineTo(0, cut)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ScadaChartPanelPainter extends CustomPainter {
  final Color color;

  const _ScadaChartPanelPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const cut = 12.0;
    const notchW = 52.0;
    const notchH = 10.0;

    final path = Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width * .52, 0)
      ..lineTo(size.width * .52 + notchW, notchH)
      ..lineTo(size.width - cut, notchH)
      ..lineTo(size.width, cut + notchH)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..lineTo(0, cut)
      ..close();

    // ✅ 1. BODY FILL — đậm hơn, sâu hơn
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF062244).withOpacity(0.85), // Xanh đậm hơn
            const Color(0xFF041830).withOpacity(0.90), // Mid tông
            const Color(0xFF010810).withOpacity(0.96), // Đen xanh sâu
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Offset.zero & size),
    );

    // // ✅ 2. OUTER GLOW — rộng hơn, sáng hơn
    // canvas.drawPath(
    //   path,
    //   Paint()
    //     ..color = color.withOpacity(0.35)
    //     ..style = PaintingStyle.stroke
    //     ..strokeWidth = 14
    //     ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    // );

    // ✅ 3. MAIN BORDER — dày hơn, rõ hơn
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // ✅ 4. INNER BORDER — sáng hơn
    final inner = Rect.fromLTWH(5, 5, size.width - 10, size.height - 10);
    final innerPath = Path()
      ..moveTo(inner.left + cut, inner.top)
      ..lineTo(inner.right - cut, inner.top)
      ..lineTo(inner.right, inner.top + cut)
      ..lineTo(inner.right, inner.bottom - cut)
      ..lineTo(inner.right - cut, inner.bottom)
      ..lineTo(inner.left + cut, inner.bottom)
      ..lineTo(inner.left, inner.bottom - cut)
      ..lineTo(inner.left, inner.top + cut)
      ..close();

    canvas.drawPath(
      innerPath,
      Paint()
        ..color = color.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );

    // ✅ 5. TOP STRIP — đậm hơn
    final topStrip = Path()
      ..moveTo(8, 10)
      ..lineTo(size.width - 8, 10)
      ..lineTo(size.width - 18, 30)
      ..lineTo(8, 30)
      ..close();

    canvas.drawPath(
      topStrip,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withOpacity(0.38), color.withOpacity(0.06)],
        ).createShader(Offset.zero & size),
    );

    // ✅ 6. CORNER ACCENT DOTS — góc trên trái, điểm nhấn
    final dotPaint = Paint()
      ..color = color.withOpacity(0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawCircle(const Offset(10, 10), 2.5, dotPaint);
    canvas.drawCircle(Offset(size.width - 10, notchH + cut), 2.5, dotPaint);

    // ✅ 7. SCAN BARS — đậm hơn, thêm 1 bar
    final barPaint = Paint()
      ..color = color.withOpacity(0.82)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 10; i++) {
      final x = size.width * .58 + i * 8.0;
      if (x + 5 > size.width - 10) break;
      canvas.drawLine(Offset(x, 17), Offset(x + 5, 17), barPaint);
    }

    // ✅ 8. BOTTOM GLOW LINE — viền đáy phát sáng
    canvas.drawLine(
      Offset(cut + 4, size.height - 1),
      Offset(size.width - cut - 4, size.height - 1),
      Paint()
        ..color = color.withOpacity(0.4)
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // ✅ 9. LEFT EDGE ACCENT — vạch dọc trái
    canvas.drawLine(
      const Offset(1, cut + 6),
      Offset(1, size.height - cut - 6),
      Paint()
        ..color = color.withOpacity(0.50)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ScadaChartPanelPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
