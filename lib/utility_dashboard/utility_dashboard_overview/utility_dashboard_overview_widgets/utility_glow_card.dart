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
    final startX = size.width * .54;
    final endX = size.width + 12;
    final patternWidth = endX - startX;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // =========================
    // LARGE WATER DROP
    // =========================
    final dropCenter = Offset(size.width * .79, size.height * .32);

    final dropWidth = size.width * .10;
    final dropHeight = size.height * .22;

    final dropPath = Path()
      ..moveTo(dropCenter.dx, dropCenter.dy - dropHeight * .55)
      ..cubicTo(
        dropCenter.dx - dropWidth * .12,
        dropCenter.dy - dropHeight * .28,
        dropCenter.dx - dropWidth * .48,
        dropCenter.dy + dropHeight * .02,
        dropCenter.dx - dropWidth * .48,
        dropCenter.dy + dropHeight * .20,
      )
      ..cubicTo(
        dropCenter.dx - dropWidth * .48,
        dropCenter.dy + dropHeight * .48,
        dropCenter.dx - dropWidth * .22,
        dropCenter.dy + dropHeight * .62,
        dropCenter.dx,
        dropCenter.dy + dropHeight * .62,
      )
      ..cubicTo(
        dropCenter.dx + dropWidth * .22,
        dropCenter.dy + dropHeight * .62,
        dropCenter.dx + dropWidth * .48,
        dropCenter.dy + dropHeight * .48,
        dropCenter.dx + dropWidth * .48,
        dropCenter.dy + dropHeight * .20,
      )
      ..cubicTo(
        dropCenter.dx + dropWidth * .48,
        dropCenter.dy + dropHeight * .02,
        dropCenter.dx + dropWidth * .12,
        dropCenter.dy - dropHeight * .28,
        dropCenter.dx,
        dropCenter.dy - dropHeight * .55,
      )
      ..close();

    final dropGlowPaint = Paint()
      ..color = color.withOpacity(.075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    final dropPaint = Paint()
      ..color = color.withOpacity(.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(dropPath, dropGlowPaint);
    canvas.drawPath(dropPath, dropPaint);

    // Highlight inside water drop.
    final highlight = Path()
      ..moveTo(
        dropCenter.dx - dropWidth * .18,
        dropCenter.dy + dropHeight * .06,
      )
      ..cubicTo(
        dropCenter.dx - dropWidth * .28,
        dropCenter.dy + dropHeight * .18,
        dropCenter.dx - dropWidth * .20,
        dropCenter.dy + dropHeight * .32,
        dropCenter.dx - dropWidth * .06,
        dropCenter.dy + dropHeight * .37,
      );

    final highlightPaint = Paint()
      ..color = color.withOpacity(.17)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(highlight, highlightPaint);

    // =========================
    // LAYERED WATER WAVES
    // =========================
    final waveConfigs = [
      (
        y: size.height * .58,
        amplitude: size.height * .045,
        opacity: .15,
        strokeWidth: .85,
        phase: 0.0,
      ),
      (
        y: size.height * .68,
        amplitude: size.height * .055,
        opacity: .27,
        strokeWidth: 1.15,
        phase: .65,
      ),
      (
        y: size.height * .79,
        amplitude: size.height * .038,
        opacity: .18,
        strokeWidth: .9,
        phase: 1.3,
      ),
    ];

    for (int waveIndex = 0; waveIndex < waveConfigs.length; waveIndex++) {
      final config = waveConfigs[waveIndex];

      final wavePath = Path();
      const segments = 44;

      for (int i = 0; i <= segments; i++) {
        final progress = i / segments;
        final x = startX + patternWidth * progress;

        final fade = sin(progress * pi);
        final y =
            config.y +
            sin(progress * pi * 3.4 + config.phase) *
                config.amplitude *
                (.55 + fade * .45);

        if (i == 0) {
          wavePath.moveTo(x, y);
        } else {
          wavePath.lineTo(x, y);
        }
      }

      if (waveIndex == 1) {
        final waveGlow = Paint()
          ..color = color.withOpacity(.055)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

        canvas.drawPath(wavePath, waveGlow);
      }

      final wavePaint = Paint()
        ..color = color.withOpacity(config.opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = config.strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(wavePath, wavePaint);
    }

    // =========================
    // BUBBLES
    // =========================
    final bubbles = [
      (offset: Offset(size.width * .61, size.height * .28), radius: 3.2),
      (offset: Offset(size.width * .67, size.height * .20), radius: 5.0),
      (offset: Offset(size.width * .90, size.height * .26), radius: 3.8),
      (offset: Offset(size.width * .94, size.height * .43), radius: 6.0),
      (offset: Offset(size.width * .57, size.height * .46), radius: 2.5),
    ];

    final bubblePaint = Paint()
      ..color = color.withOpacity(.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9;

    final bubbleDotPaint = Paint()
      ..color = color.withOpacity(.24)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < bubbles.length; i++) {
      final bubble = bubbles[i];

      canvas.drawCircle(bubble.offset, bubble.radius, bubblePaint);

      if (i.isEven) {
        canvas.drawCircle(
          bubble.offset.translate(-bubble.radius * .25, -bubble.radius * .25),
          .8,
          bubbleDotPaint,
        );
      }
    }

    canvas.restore();
  }

  void _drawAir(Canvas canvas, Size size, Paint paint, Paint glowPaint) {
    final startX = size.width * .53;
    final endX = size.width + 18;
    final patternWidth = endX - startX;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // =========================
    // PRESSURE / AIR SWIRL
    // =========================
    final swirlCenter = Offset(size.width * .82, size.height * .43);

    final swirlGlowPaint = Paint()
      ..color = color.withOpacity(.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final swirlPaint = Paint()
      ..color = color.withOpacity(.27)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05
      ..strokeCap = StrokeCap.round;

    final swirlPath = Path();

    const swirlPoints = 76;

    for (int i = 0; i <= swirlPoints; i++) {
      final progress = i / swirlPoints;
      final angle = progress * pi * 3.8;
      final radius = 2.5 + progress * size.height * .15;

      final x = swirlCenter.dx + cos(angle) * radius;
      final y = swirlCenter.dy + sin(angle) * radius * .56;

      if (i == 0) {
        swirlPath.moveTo(x, y);
      } else {
        swirlPath.lineTo(x, y);
      }
    }

    canvas.drawPath(swirlPath, swirlGlowPaint);
    canvas.drawPath(swirlPath, swirlPaint);

    // Center pressure dot.
    final centerGlowPaint = Paint()
      ..color = color.withOpacity(.10)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final centerPaint = Paint()
      ..color = color.withOpacity(.40)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(swirlCenter, 5.5, centerGlowPaint);
    canvas.drawCircle(swirlCenter, 1.8, centerPaint);

    // =========================
    // AIR FLOW STREAMS
    // =========================
    final streams = [
      (
        y: size.height * .28,
        amplitude: size.height * .037,
        opacity: .15,
        strokeWidth: .85,
        phase: .15,
        length: .77,
      ),
      (
        y: size.height * .52,
        amplitude: size.height * .050,
        opacity: .28,
        strokeWidth: 1.15,
        phase: .80,
        length: 1.00,
      ),
      (
        y: size.height * .69,
        amplitude: size.height * .032,
        opacity: .20,
        strokeWidth: .95,
        phase: 1.45,
        length: .90,
      ),
      (
        y: size.height * .80,
        amplitude: size.height * .022,
        opacity: .12,
        strokeWidth: .75,
        phase: 2.10,
        length: .68,
      ),
    ];

    for (int streamIndex = 0; streamIndex < streams.length; streamIndex++) {
      final stream = streams[streamIndex];
      final streamPath = Path();

      const segments = 48;

      for (int i = 0; i <= segments; i++) {
        final progress = i / segments;
        final x = startX + patternWidth * stream.length * progress;

        final envelope = sin(progress * pi);
        final y =
            stream.y +
            sin(progress * pi * 2.3 + stream.phase) *
                stream.amplitude *
                envelope;

        if (i == 0) {
          streamPath.moveTo(x, y);
        } else {
          streamPath.lineTo(x, y);
        }
      }

      if (streamIndex == 1) {
        final streamGlow = Paint()
          ..color = color.withOpacity(.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

        canvas.drawPath(streamPath, streamGlow);
      }

      final streamPaint = Paint()
        ..color = color.withOpacity(stream.opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stream.strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(streamPath, streamPaint);

      // Small airflow head.
      if (streamIndex < 3) {
        final arrowProgress = stream.length;
        final arrowX = startX + patternWidth * arrowProgress;
        final arrowY = stream.y;

        final arrowPaint = Paint()
          ..color = color.withOpacity(stream.opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stream.strokeWidth
          ..strokeCap = StrokeCap.round;

        final arrowPath = Path()
          ..moveTo(arrowX - 7, arrowY - 3)
          ..lineTo(arrowX, arrowY)
          ..lineTo(arrowX - 7, arrowY + 3);

        canvas.drawPath(arrowPath, arrowPaint);
      }
    }

    // =========================
    // COMPRESSED AIR PARTICLES
    // =========================
    final particles = [
      (
        offset: Offset(size.width * .59, size.height * .20),
        radius: 1.5,
        opacity: .25,
      ),
      (
        offset: Offset(size.width * .66, size.height * .37),
        radius: 2.2,
        opacity: .18,
      ),
      (
        offset: Offset(size.width * .72, size.height * .22),
        radius: 1.3,
        opacity: .28,
      ),
      (
        offset: Offset(size.width * .91, size.height * .30),
        radius: 1.8,
        opacity: .22,
      ),
      (
        offset: Offset(size.width * .95, size.height * .57),
        radius: 2.4,
        opacity: .16,
      ),
      (
        offset: Offset(size.width * .67, size.height * .76),
        radius: 1.4,
        opacity: .20,
      ),
    ];

    for (final particle in particles) {
      final particlePaint = Paint()
        ..color = color.withOpacity(particle.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(particle.offset, particle.radius, particlePaint);
    }

    // Small pressure rings.
    final ringPaint = Paint()
      ..color = color.withOpacity(.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .75;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .92, size.height * .72),
        width: 22,
        height: 10,
      ),
      ringPaint,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .92, size.height * .72),
        width: 34,
        height: 16,
      ),
      ringPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _UtilityPatternPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.type != type;
  }
}
