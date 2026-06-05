import 'package:flutter/material.dart';

class ScadaTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final double height;
  final double minWidth;

  const ScadaTabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = const Color(0xFF00C2FF),
    this.height = 34,
    this.minWidth = 72,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: CustomPaint(
          painter: _ScadaTabPainter(color: color, selected: selected),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minWidth,
              maxWidth: 140,
              minHeight: height,
              maxHeight: height,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Colors.white.withOpacity(0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScadaTabPainter extends CustomPainter {
  final Color color;
  final bool selected;

  const _ScadaTabPainter({required this.color, required this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    const cut = 8.0;

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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: selected
              ? [
                  color.withOpacity(0.34),
                  const Color(0xFF071A33).withOpacity(0.96),
                ]
              : [
                  const Color(0xFF0B1730).withOpacity(0.92),
                  const Color(0xFF060D1D).withOpacity(0.96),
                ],
        ).createShader(Offset.zero & size),
    );

    if (selected) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? color.withOpacity(0.95)
            : Colors.white.withOpacity(0.13)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.4 : 1,
    );

    final topLine = Paint()
      ..color = selected
          ? color.withOpacity(0.9)
          : Colors.white.withOpacity(0.12)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(cut + 8, 3),
      Offset(size.width - cut - 8, 3),
      topLine,
    );
  }

  @override
  bool shouldRepaint(covariant _ScadaTabPainter oldDelegate) {
    return oldDelegate.selected != selected || oldDelegate.color != color;
  }
}
