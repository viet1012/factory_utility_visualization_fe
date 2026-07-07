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
        painter: _UtilityPatternPainter(color: color, type: type),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xff030712),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [const Color(0xff262930), color.withOpacity(.02)],
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
                        blurRadius: 40,
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
    switch (type) {
      case UtilityGlowType.electricity:
        _paintElectricity(canvas, size);
        break;
      case UtilityGlowType.water:
        _paintWater(canvas, size);
        break;
      case UtilityGlowType.air:
        _paintAir(canvas, size);
        break;
    }
  }

  // ---------------------------------------------------------------------
  // ELECTRICITY — a transmission pylon + a rising bar/trend chart.
  // ---------------------------------------------------------------------
  void _paintElectricity(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color.withOpacity(.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;

    final faintPaint = Paint()
      ..color = color.withOpacity(.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05;

    // -- Pylon --------------------------------------------------------
    final baseY = size.height * .92;
    final topY = size.height * .12;
    final cx = size.width * .62;
    final halfBase = size.width * .085;

    final pylon = Path()
      ..moveTo(cx, topY)
      ..lineTo(cx - halfBase, baseY)
      ..moveTo(cx, topY)
      ..lineTo(cx + halfBase, baseY);
    canvas.drawPath(pylon, linePaint);

    // Cross braces, narrowing towards the top.
    for (int i = 1; i <= 4; i++) {
      final t = i / 5;
      final y = topY + (baseY - topY) * t;
      final spread = halfBase * t;
      canvas.drawLine(
        Offset(cx - spread, y),
        Offset(cx + spread, y),
        faintPaint,
      );
      // diagonal braces
      canvas.drawLine(
        Offset(cx - spread, y),
        Offset(cx + spread * .5, y - (baseY - topY) / 10),
        faintPaint,
      );
      canvas.drawLine(
        Offset(cx + spread, y),
        Offset(cx - spread * .5, y - (baseY - topY) / 10),
        faintPaint,
      );
    }

    // Insulator caps on top.
    canvas.drawCircle(
      Offset(cx, topY),
      2.6,
      Paint()..color = color.withOpacity(.5),
    );

    // -- Rising bars, bottom-right --------------------------------------
    final barPaint = Paint()
      ..color = color.withOpacity(.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;

    const barCount = 6;
    final barAreaLeft = size.width * .72;
    final barAreaRight = size.width * .98;
    final barWidth = (barAreaRight - barAreaLeft) / (barCount * 1.6);

    for (int i = 0; i < barCount; i++) {
      final h = size.height * (.12 + i * .06);
      final x = barAreaLeft + i * barWidth * 1.6;
      canvas.drawRect(Rect.fromLTWH(x, baseY - h, barWidth, h), barPaint);
    }

    // -- Wavy trend line with dots, connecting pylon area to bars --------
    final trendPaint = Paint()
      ..color = color.withOpacity(.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()..color = color.withOpacity(1);

    final haloPaint = Paint()
      ..color = color.withOpacity(.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final trend = Path();
    final startY = size.height * .58;
    trend.moveTo(size.width * .06, startY);

    for (int i = 0; i < 6; i++) {
      final x1 = size.width * (.14 + i * .1);
      final y1 = startY - sin(i * 1.05) * 16 - i * 3;
      final x2 = size.width * (.20 + i * .1);
      final y2 = startY - sin((i + 1) * 1.05) * 20 - (i + 1) * 3;
      trend.quadraticBezierTo(x1, y1, x2, y2);
    }
    canvas.drawPath(trend, trendPaint);

    for (int i = 0; i < 6; i++) {
      final x = size.width * (.12 + i * .1);
      final y = startY - sin(i * 1.05) * 18 - i * 3;
      canvas.drawCircle(Offset(x, y), 5.5, haloPaint);
      canvas.drawCircle(Offset(x, y), 2.3, dotPaint);
    }
  }

  // ---------------------------------------------------------------------
  // WATER — layered flowing waves + rising bubbles.
  // ---------------------------------------------------------------------
  void _paintWater(Canvas canvas, Size size) {
    final baselines = [.42, .55, .68, .80];
    final amplitudes = [10.0, 16.0, 12.0, 8.0];
    final opacities = [.16, .3, .2, .12];

    for (int i = 0; i < baselines.length; i++) {
      final path = Path();
      final baseY = size.height * baselines[i];
      final amp = amplitudes[i];
      path.moveTo(0, baseY);

      const steps = 26;
      for (int s = 0; s <= steps; s++) {
        final x = size.width * (s / steps);
        final y = baseY + sin((s / steps) * pi * 2.4 + i) * amp;
        path.lineTo(x, y);
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(opacities[i])
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    // Small bright dots riding the main wave.
    final dotPaint = Paint()..color = color.withOpacity(.9);
    final haloPaint = Paint()..color = color.withOpacity(.16);
    final mainBaseY = size.height * .55;
    for (int i = 0; i < 6; i++) {
      final x = size.width * (.08 + i * .16);
      final y = mainBaseY + sin((x / size.width) * pi * 2.4 + 1) * 16;
      canvas.drawCircle(Offset(x, y), 5, haloPaint);
      canvas.drawCircle(Offset(x, y), 2.1, dotPaint);
    }

    // Rising bubbles, upper area.
    final rnd = Random(7);
    final bubblePaint = Paint()
      ..color = color.withOpacity(.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 8; i++) {
      final x = size.width * (.05 + rnd.nextDouble() * .5);
      final y = size.height * (.08 + rnd.nextDouble() * .3);
      final r = 2.5 + rnd.nextDouble() * 5;
      canvas.drawCircle(Offset(x, y), r, bubblePaint);
    }
  }

  // ---------------------------------------------------------------------
  // AIR — swirling airflow ribbons (compressed air / pneumatic feel).
  // ---------------------------------------------------------------------
  void _paintAir(Canvas canvas, Size size) {
    final lanes = [.30, .48, .66, .84];
    final opacities = [.14, .3, .18, .1];

    for (int i = 0; i < lanes.length; i++) {
      final baseY = size.height * lanes[i];
      final path = Path()..moveTo(size.width * .04, baseY);

      path.cubicTo(
        size.width * .22,
        baseY - 26,
        size.width * .30,
        baseY + 26,
        size.width * .50,
        baseY,
      );
      path.cubicTo(
        size.width * .66,
        baseY - 22,
        size.width * .74,
        baseY + 22,
        size.width * .96,
        baseY - 6,
      );

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(opacities[i])
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // A small spiral swirl accent, echoing a wind icon.
    final swirlPaint = Paint()
      ..color = color.withOpacity(.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final swirlCenter = Offset(size.width * .78, size.height * .38);
    final swirl = Path();
    const turns = 2.2;
    const points = 60;
    for (int i = 0; i <= points; i++) {
      final t = i / points;
      final angle = t * turns * 2 * pi;
      final radius = 4 + t * 26;
      final x = swirlCenter.dx + cos(angle) * radius;
      final y = swirlCenter.dy + sin(angle) * radius * .6;
      if (i == 0) {
        swirl.moveTo(x, y);
      } else {
        swirl.lineTo(x, y);
      }
    }
    canvas.drawPath(swirl, swirlPaint);

    // Drifting dots to suggest particles in the air stream.
    final dotPaint = Paint()..color = color.withOpacity(.85);
    final haloPaint = Paint()..color = color.withOpacity(.16);
    for (int i = 0; i < 5; i++) {
      final x = size.width * (.1 + i * .18);
      final y = size.height * .48 + sin((x / size.width) * pi * 2 + .5) * 18;
      canvas.drawCircle(Offset(x, y), 5, haloPaint);
      canvas.drawCircle(Offset(x, y), 2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _UtilityPatternPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.type != type;
  }
}
