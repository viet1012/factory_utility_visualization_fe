import 'dart:math';

import 'package:flutter/cupertino.dart';

/// Which utility this card represents — drives the default color and the
/// decorative background art painted behind the card's content.
enum UtilityGlowType { electricity, water, air }

class UtilityGlowCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final UtilityGlowType type;

  const UtilityGlowCard({
    super.key,
    required this.child,
    required this.color,
    required this.type,
  });

  /// Amber card with a pylon + rising trend line, like the ELECTRICITY row.
  const UtilityGlowCard.electricity({
    super.key,
    required this.child,
    this.color = const Color(0xfffacc15),
  }) : type = UtilityGlowType.electricity;

  /// Cyan card with flowing waves + bubbles, like the WATER row.
  const UtilityGlowCard.water({
    super.key,
    required this.child,
    this.color = const Color(0xff22d3ee),
  }) : type = UtilityGlowType.water;

  /// Purple/violet card with swirling airflow lines, like the AIR row.
  const UtilityGlowCard.air({
    super.key,
    required this.child,
    this.color = const Color(0xff8b5cf6),
  }) : type = UtilityGlowType.air;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: CustomPaint(
        foregroundPainter: _UtilityPatternPainter(color: color, type: type),
        child: Container(
          decoration: BoxDecoration(
            // color: const Color(0xff030712),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                const Color(0xff151d2d),
                const Color(0xff111827),
                const Color(0xff0f172a),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(.12),
                blurRadius: 18,
                spreadRadius: -12,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Soft glow blob behind the icon, top-left.
              Positioned(
                left: -30,
                top: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(.05),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(.18),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: .06,
                    child: GridPaper(
                      color: color,
                      interval: 28,
                      divisions: 1,
                      subdivisions: 1,
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _UtilityPatternPainter extends CustomPainter {
  final Color color;
  final UtilityGlowType type;

  _UtilityPatternPainter({required this.color, required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(.32)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withOpacity(.06)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    switch (type) {
      case UtilityGlowType.electricity:
        _drawElectric(canvas, size, paint, glowPaint);
        break;
      case UtilityGlowType.water:
        _drawWater(canvas, size, paint, glowPaint);
        break;
      case UtilityGlowType.air:
        _drawAir(canvas, size, paint, glowPaint);
        break;
    }
  }

  void _drawElectric(Canvas canvas, Size size, Paint paint, Paint glowPaint) {
    final baseY = size.height * .76;
    final startX = size.width * .58;

    final tower = Path()
      ..moveTo(startX + 34, size.height * .22)
      ..lineTo(startX + 8, baseY)
      ..moveTo(startX + 34, size.height * .22)
      ..lineTo(startX + 60, baseY)
      ..moveTo(startX + 20, size.height * .43)
      ..lineTo(startX + 48, size.height * .43)
      ..moveTo(startX + 14, size.height * .58)
      ..lineTo(startX + 54, size.height * .58)
      ..moveTo(startX + 8, baseY)
      ..lineTo(startX + 60, baseY);

    canvas.drawPath(tower, glowPaint);
    canvas.drawPath(tower, paint);

    for (int i = 0; i < 4; i++) {
      final x = startX + 82 + i * 18;
      final h = 18.0 + i * 10;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, baseY - h, 10, h),
        const Radius.circular(3),
      );

      canvas.drawRRect(rect, paint);
    }

    final trend = Path()
      ..moveTo(startX - 8, baseY - 18)
      ..cubicTo(
        startX + 24,
        baseY - 58,
        startX + 58,
        baseY - 6,
        startX + 105,
        baseY - 70,
      );

    canvas.drawPath(trend, glowPaint);
    canvas.drawPath(trend, paint);

    final dotPaint = Paint()..color = color.withOpacity(.6);
    for (final p in [
      Offset(startX - 8, baseY - 18),
      Offset(startX + 38, baseY - 38),
      Offset(startX + 105, baseY - 70),
    ]) {
      canvas.drawCircle(p, 3, dotPaint);
    }
  }

  void _drawWater(Canvas canvas, Size size, Paint paint, Paint glowPaint) {
    final startX = size.width * .55;

    for (int i = 0; i < 4; i++) {
      final baseY = size.height * (.36 + i * .13);

      final path = Path()..moveTo(startX, baseY);

      path.cubicTo(
        startX + 28,
        baseY - 22,
        startX + 54,
        baseY + 22,
        startX + 84,
        baseY,
      );

      path.cubicTo(
        startX + 110,
        baseY - 20,
        startX + 138,
        baseY + 18,
        startX + 170,
        baseY - 2,
      );

      canvas.drawPath(path, i == 1 ? glowPaint : paint);
      canvas.drawPath(path, paint);
    }

    final bubblePaint = Paint()
      ..color = color.withOpacity(.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9;

    final bubbles = [
      Offset(startX + 18, size.height * .23),
      Offset(startX + 62, size.height * .18),
      Offset(startX + 118, size.height * .27),
      Offset(startX + 145, size.height * .16),
    ];

    for (int i = 0; i < bubbles.length; i++) {
      canvas.drawCircle(bubbles[i], 4.0 + i, bubblePaint);
    }
  }

  void _drawAir(Canvas canvas, Size size, Paint paint, Paint glowPaint) {
    final startX = size.width * .54;

    for (int i = 0; i < 4; i++) {
      final y = size.height * (.30 + i * .14);

      final path = Path()..moveTo(startX, y);

      path.cubicTo(startX + 36, y - 24, startX + 70, y + 24, startX + 108, y);

      path.cubicTo(
        startX + 136,
        y - 18,
        startX + 158,
        y + 16,
        startX + 184,
        y - 4,
      );

      canvas.drawPath(path, i == 1 ? glowPaint : paint);
      canvas.drawPath(path, paint);
    }

    final center = Offset(size.width * .79, size.height * .42);
    final swirl = Path();

    for (int i = 0; i <= 54; i++) {
      final t = i / 54;
      final angle = t * 2.4 * pi;
      final r = 5 + t * 24;

      final x = center.dx + cos(angle) * r;
      final y = center.dy + sin(angle) * r * .62;

      if (i == 0) {
        swirl.moveTo(x, y);
      } else {
        swirl.lineTo(x, y);
      }
    }

    final swirlPaint = Paint()
      ..color = color.withOpacity(.28)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(swirl, glowPaint);
    canvas.drawPath(swirl, swirlPaint);
  }

  @override
  bool shouldRepaint(covariant _UtilityPatternPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.type != type;
  }
}
