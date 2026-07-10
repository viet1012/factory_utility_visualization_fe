import 'dart:math' as math;
import 'dart:math';

import 'package:flutter/material.dart';

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
            // color: const Color(0xff030712).withOpacity(.4),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                const Color(0xff111827).withOpacity(.7),
                const Color(0xff151d2d).withOpacity(.2),
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
                    color: Colors.black.withOpacity(.05),
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
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // ============================================================
    // KÍCH THƯỚC VÀ VỊ TRÍ THÁP
    // ============================================================

    // Giới hạn cả theo height và width để tháp không bị quá bè
    // hoặc bị cắt cross-arm khi card hẹp.
    final towerHeight = math.min(size.height * .72, size.width * .58);

    final towerWidth = towerHeight * .42;

    final center = Offset(size.width * .82, size.height * .50);

    final base = Offset(center.dx, center.dy + towerHeight * .42);

    final top = Offset(base.dx, base.dy - towerHeight);

    final bottomLeft = Offset(base.dx - towerWidth * .46, base.dy);

    final bottomRight = Offset(base.dx + towerWidth * .46, base.dy);

    // Paint chi tiết nhẹ hơn thân chính.
    final detailPaint = Paint()
      ..color = color.withOpacity(.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .85
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final detailGlowPaint = Paint()
      ..color = color.withOpacity(.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final wirePaint = Paint()
      ..color = color.withOpacity(.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .85
      ..strokeCap = StrokeCap.round;

    final wireGlowPaint = Paint()
      ..color = color.withOpacity(.025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // ============================================================
    // 1. HALO NHẸ PHÍA SAU THÁP
    // ============================================================

    final haloCenter = Offset(center.dx, center.dy - towerHeight * .08);

    final haloPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              color.withOpacity(.10),
              color.withOpacity(.025),
              Colors.transparent,
            ],
            stops: const [0, .45, 1],
          ).createShader(
            Rect.fromCircle(center: haloCenter, radius: towerHeight * .58),
          );

    canvas.drawCircle(haloCenter, towerHeight * .58, haloPaint);

    // ============================================================
    // 2. VỊ TRÍ CÁC CROSS-ARM
    // ============================================================

    final armProgresses = <double>[.18, .32, .48];

    final armWidthFactors = <double>[1.18, 1.45, 1.05];

    final insulatorLength = math.max(10.0, towerHeight * .055);

    // ============================================================
    // 3. DÂY ĐIỆN VÕNG PHÍA SAU THÁP
    // ============================================================

    for (int i = 0; i < armProgresses.length; i++) {
      final armY = top.dy + towerHeight * armProgresses[i];
      final armWidth = towerWidth * armWidthFactors[i];

      final anchor = Offset(base.dx - armWidth / 2, armY + insulatorLength);

      final startY = anchor.dy + (i - 1) * 9;

      final cablePath = Path()
        ..moveTo(-40, startY)
        ..cubicTo(
          size.width * .20,
          startY - 14,
          size.width * .56,
          anchor.dy + 15,
          anchor.dx,
          anchor.dy,
        );

      canvas.drawPath(cablePath, wireGlowPaint);
      canvas.drawPath(cablePath, wirePaint);
    }

    // ============================================================
    // 4. HAI CHÂN CHÍNH CỦA THÁP
    // ============================================================

    final towerOutline = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..moveTo(top.dx, top.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..moveTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy);

    canvas.drawPath(towerOutline, glowPaint);
    canvas.drawPath(towerOutline, paint);

    // ============================================================
    // 5. TRỤC GIỮA
    // ============================================================

    final centerSpine = Path()
      ..moveTo(top.dx, top.dy + towerHeight * .07)
      ..lineTo(base.dx, base.dy - towerHeight * .04);

    canvas.drawPath(centerSpine, detailGlowPaint);
    canvas.drawPath(centerSpine, detailPaint);

    // ============================================================
    // 6. GIÀN NGANG VÀ GIẰNG CHỮ X
    // ============================================================

    final levels = <double>[.10, .22, .42, .62, .82, 1.0];

    Offset leftAt(double progress) {
      return Offset(
        base.dx - towerWidth * .46 * progress,
        top.dy + towerHeight * progress,
      );
    }

    Offset rightAt(double progress) {
      return Offset(
        base.dx + towerWidth * .46 * progress,
        top.dy + towerHeight * progress,
      );
    }

    final latticePath = Path();

    for (int i = 0; i < levels.length; i++) {
      final progress = levels[i];

      final left = leftAt(progress);
      final right = rightAt(progress);

      // Thanh ngang.
      latticePath
        ..moveTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy);

      if (i < levels.length - 1) {
        final nextProgress = levels[i + 1];

        final nextLeft = leftAt(nextProgress);
        final nextRight = rightAt(nextProgress);

        // Hai thanh giằng chéo tạo chữ X.
        latticePath
          ..moveTo(left.dx, left.dy)
          ..lineTo(nextRight.dx, nextRight.dy)
          ..moveTo(right.dx, right.dy)
          ..lineTo(nextLeft.dx, nextLeft.dy);
      }
    }

    canvas.drawPath(latticePath, detailGlowPaint);
    canvas.drawPath(latticePath, detailPaint);

    // ============================================================
    // 7. CROSS-ARM VÀ CHUỖI SỨ
    // ============================================================

    for (int i = 0; i < armProgresses.length; i++) {
      final progress = armProgresses[i];
      final armY = top.dy + towerHeight * progress;
      final armWidth = towerWidth * armWidthFactors[i];

      final halfBodyWidth = towerWidth * .46 * progress;

      final leftBody = Offset(base.dx - halfBodyWidth, armY);

      final rightBody = Offset(base.dx + halfBodyWidth, armY);

      final leftTip = Offset(base.dx - armWidth / 2, armY);

      final rightTip = Offset(base.dx + armWidth / 2, armY);

      final supportDrop = math.min(14.0, towerHeight * .06);

      final armPath = Path()
        // Thanh ngang chính.
        ..moveTo(leftTip.dx, leftTip.dy)
        ..lineTo(rightTip.dx, rightTip.dy)
        // Nối cross-arm vào thân tháp.
        ..moveTo(leftBody.dx, leftBody.dy)
        ..lineTo(leftTip.dx, leftTip.dy)
        ..moveTo(rightBody.dx, rightBody.dy)
        ..lineTo(rightTip.dx, rightTip.dy)
        // Hai thanh chống xiên.
        ..moveTo(base.dx - armWidth * .26, armY)
        ..lineTo(base.dx, armY + supportDrop)
        ..moveTo(base.dx + armWidth * .26, armY)
        ..lineTo(base.dx, armY + supportDrop);

      canvas.drawPath(armPath, glowPaint);
      canvas.drawPath(armPath, paint);

      _drawElectricInsulator(
        canvas,
        start: leftTip,
        length: insulatorLength,
        paint: detailPaint,
        glowPaint: detailGlowPaint,
      );

      _drawElectricInsulator(
        canvas,
        start: rightTip,
        length: insulatorLength,
        paint: detailPaint,
        glowPaint: detailGlowPaint,
      );
    }

    // ============================================================
    // 8. ĐỈNH THÁP
    // ============================================================

    final mastTop = Offset(top.dx, top.dy - towerHeight * .055);

    final mastPath = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(mastTop.dx, mastTop.dy);

    canvas.drawPath(mastPath, glowPaint);
    canvas.drawPath(mastPath, paint);

    final mastGlowPaint = Paint()
      ..color = color.withOpacity(.12)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final mastDotPaint = Paint()
      ..color = color.withOpacity(.58)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(mastTop, 5, mastGlowPaint);

    canvas.drawCircle(mastTop, 1.6, mastDotPaint);

    // ============================================================
    // 9. NODE Ở CÁC TẦNG GIÀN
    // ============================================================

    final nodePaint = Paint()
      ..color = color.withOpacity(.30)
      ..style = PaintingStyle.fill;

    for (final progress in levels.skip(1)) {
      final left = leftAt(progress);
      final right = rightAt(progress);
      final middle = Offset(base.dx, top.dy + towerHeight * progress);

      canvas.drawCircle(left, 1.2, nodePaint);
      canvas.drawCircle(right, 1.2, nodePaint);
      canvas.drawCircle(middle, 1.0, nodePaint);
    }

    // ============================================================
    // 10. CHÂN MÓNG
    // ============================================================

    final footingPaint = Paint()
      ..color = color.withOpacity(.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    final footingGlowPaint = Paint()
      ..color = color.withOpacity(.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final footingPath = Path()
      ..moveTo(bottomLeft.dx - towerWidth * .10, bottomLeft.dy + 2)
      ..lineTo(bottomLeft.dx + towerWidth * .10, bottomLeft.dy + 2)
      ..moveTo(bottomRight.dx - towerWidth * .10, bottomRight.dy + 2)
      ..lineTo(bottomRight.dx + towerWidth * .10, bottomRight.dy + 2);

    canvas.drawPath(footingPath, footingGlowPaint);
    canvas.drawPath(footingPath, footingPaint);

    canvas.restore();
  }

  void _drawElectricInsulator(
    Canvas canvas, {
    required Offset start,
    required double length,
    required Paint paint,
    required Paint glowPaint,
  }) {
    final end = Offset(start.dx, start.dy + length);

    final stringPath = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);

    canvas.drawPath(stringPath, glowPaint);
    canvas.drawPath(stringPath, paint);

    const discCount = 4;

    final discPaint = Paint()
      ..color = color.withOpacity(.34)
      ..style = PaintingStyle.fill;

    final discGlowPaint = Paint()
      ..color = color.withOpacity(.035)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (int i = 0; i < discCount; i++) {
      final progress = (i + 1) / (discCount + 1);

      final center = Offset(start.dx, start.dy + length * progress);

      final discRect = Rect.fromCenter(center: center, width: 6.5, height: 2.2);

      canvas.drawOval(discRect.inflate(1.5), discGlowPaint);

      canvas.drawOval(discRect, discPaint);
    }

    canvas.drawCircle(
      end,
      1.4,
      Paint()
        ..color = color.withOpacity(.46)
        ..style = PaintingStyle.fill,
    );
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
      ..color = color.withOpacity(.45)
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
      ..color = color.withOpacity(.47)
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
        opacity: .25,
        strokeWidth: .85,
        phase: 0.0,
      ),
      (
        y: size.height * .68,
        amplitude: size.height * .055,
        opacity: .37,
        strokeWidth: 1.15,
        phase: .65,
      ),
      (
        y: size.height * .79,
        amplitude: size.height * .038,
        opacity: .38,
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
      ..color = color.withOpacity(.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9;

    final bubbleDotPaint = Paint()
      ..color = color.withOpacity(.34)
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
      ..color = color.withOpacity(.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final swirlPaint = Paint()
      ..color = color.withOpacity(.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
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
      ..color = color.withOpacity(.9)
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
        opacity: .28,
        strokeWidth: 1.15,
        phase: .15,
        length: .77,
      ),
      (
        y: size.height * .52,
        amplitude: size.height * .050,
        opacity: .55,
        strokeWidth: 1.7,
        phase: .80,
        length: 1.00,
      ),
      (
        y: size.height * .69,
        amplitude: size.height * .032,
        opacity: .40,
        strokeWidth: 1.35,
        phase: 1.45,
        length: .90,
      ),
      (
        y: size.height * .80,
        amplitude: size.height * .022,
        opacity: .25,
        strokeWidth: 1.0,
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
          ..color = color.withOpacity(.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

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
