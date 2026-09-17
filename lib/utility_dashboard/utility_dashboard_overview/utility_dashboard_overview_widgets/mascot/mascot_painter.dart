part of '../monitoring_mascot.dart';

// _RobotPainter
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

class _RobotPainter extends CustomPainter {
  final Color accentColor;
  final _MascotPose pose;
  final double eyeTrackX;
  final double eyeTrackY;
  final double antennaScale;

  double get blinkScale => pose.blinkScale;
  double get armSwingL => pose.armSwingLeft;
  double get armSwingR => pose.armSwingRight;
  double get foreSwing => pose.forearmSwing;
  double get legSwingL => pose.legSwingLeft;
  double get legSwingR => pose.legSwingRight;
  double get kneeBendL => pose.kneeBendLeft;
  double get kneeBendR => pose.kneeBendRight;
  double get footLiftL => pose.footLiftLeft;
  double get footLiftR => pose.footLiftRight;
  double get hairOffset => pose.hairOffset;
  double get walkStrength => pose.walkStrength;
  bool get isWalking => pose.isWalking;
  double get walkPhase => pose.walkPhase;
  double get facing => pose.facing;

  static const _headBg = Color(0xFF161B22);
  static const _bodyBg = Color(0xFF164EA6);
  static const _neckBg = Color(0xFF21262D);
  static const _headRim = Color(0xFF30363D);
  static const _visorBg = Color(0xFF0D1117);
  static const _limbUp = Color(0xFF164EA6);
  static const _limbMid = Color(0xFF8B949E);
  static const _limbLow = Color(0xFF6E7681);
  static const _joint = Color(0xFF484F58);
  static const _jointRim = Color(0xFF6E7681);
  static const _footBg = Color(0xFF30363D);
  static const _footRim = Color(0xFF484F58);
  static const _cheek = Color(0xFFF97583);
  static const _hairBase = Color(0xFFB0BEC5);
  static const _hairMid = Color(0xFFCFD8DC);
  static const _hairLight = Color(0xFFECEFF1);
  static const _hairDark = Color(0xFF78909C);
  static const _hairShine = Color(0xFFFFFFFF);

  _RobotPainter({
    required this.accentColor,
    required this.pose,
    required this.eyeTrackX,
    required this.eyeTrackY,
    required this.antennaScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final headW = w * 0.6;
    final headH = h * 0.22;
    final bodyW = w * 0.56;
    final bodyH = h * 0.3;
    final headX = (w - headW) / 2;
    final headY = h * 0.15;
    final bodyX = (w - bodyW) / 2;
    final bodyY = headY + headH + h * 0.032;
    final cx = w / 2;

    _drawArm(
      canvas: canvas,
      shoulder: Offset(bodyX + 2, bodyY + bodyH * 0.20),
      swing: armSwingL,
      foreSwing: foreSwing,
      isLeft: true,
    );
    _drawArm(
      canvas: canvas,
      shoulder: Offset(bodyX + bodyW - 2, bodyY + bodyH * 0.20),
      swing: armSwingR,
      foreSwing: -foreSwing,
      isLeft: false,
    );
    // ===== SHADOW =====
    final shadowPhase = math.cos(walkPhase).abs();

    final shadowWidth = isWalking
        ? (44 - shadowPhase * 10 * walkStrength)
        : 42.0;

    final shadowOpacity = isWalking
        ? (0.22 - shadowPhase * 0.08 * walkStrength)
        : 0.22;

    final shadowCenter = Offset(w / 2, h * 0.90);

    canvas.drawOval(
      Rect.fromCenter(center: shadowCenter, width: shadowWidth, height: 10),
      Paint()
        ..color = Colors.black.withValues(
          alpha: shadowOpacity.clamp(0.08, 0.22),
        ),
    );

    // ===== LEGS =====

    _drawLeg(
      canvas: canvas,
      hip: Offset(bodyX + bodyW * 0.33, bodyY + bodyH - 1),
      swing: legSwingL,
      kneeBend: kneeBendL,
      footLift: footLiftL,
      isLeft: true,
    );
    _drawLeg(
      canvas: canvas,
      hip: Offset(bodyX + bodyW * 0.67, bodyY + bodyH - 1),
      swing: legSwingR,
      kneeBend: kneeBendR,
      footLift: footLiftR,
      isLeft: false,
    );

    final neckRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 7, headY + headH - 2, 14, h * 0.045),
      const Radius.circular(4),
    );
    canvas.drawRRect(neckRect, Paint()..color = _neckBg);
    canvas.drawRRect(
      neckRect,
      Paint()
        ..color = _headRim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bodyX, bodyY, bodyW, bodyH),
      const Radius.circular(8),
    );
    // Cyber Glow
    canvas.drawRRect(
      bodyRect.inflate(12),
      Paint()
        ..color = accentColor.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    canvas.drawRRect(
      bodyRect.inflate(4),
      Paint()..color = accentColor.withValues(alpha: 0.08),
    );

    canvas.drawRRect(bodyRect, Paint()..color = _bodyBg);
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = accentColor.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    _drawHair(
      canvas: canvas,
      headX: headX,
      headY: headY,
      headW: headW,
      headH: headH,
      offset: hairOffset,
    );

    final headRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(headX, headY, headW, headH),
      const Radius.circular(22),
    );

    canvas.drawRRect(
      headRRect.inflate(10),
      Paint()
        ..color = accentColor.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    canvas.drawRRect(
      headRRect.inflate(4),
      Paint()..color = accentColor.withValues(alpha: 0.08),
    );

    canvas.drawRRect(headRRect, Paint()..color = _headBg);
    canvas.drawRRect(
      headRRect,
      Paint()
        ..color = accentColor.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(headX + 3, headY + 3, headW - 6, headH - 6),
        const Radius.circular(19),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final visorW = headW - 28;
    const visorH = 10.0;
    final visorX = headX + 14;
    final visorY = headY + 11;
    final visorRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(visorX, visorY, visorW, visorH),
      const Radius.circular(visorH / 2),
    );
    canvas.drawRRect(visorRect, Paint()..color = _visorBg);
    canvas.drawRRect(
      visorRect,
      Paint()
        ..color = accentColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(visorX + 2, visorY + 2, visorW - 4, 5),
        const Radius.circular(3),
      ),
      Paint()..color = accentColor.withValues(alpha: 0.65),
    );

    // ===== VISOR SCAN =====

    final scanProgress =
        ((DateTime.now().millisecondsSinceEpoch % 1800) / 1800);

    final scanX = visorX + (visorW - 6) * scanProgress;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(scanX, visorY, 6, visorH),
        const Radius.circular(3),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    final eyeY = headY + headH * 0.57;
    final leftEyeX = headX + headW * 0.32;
    final rightEyeX = headX + headW * 0.68;
    _drawEye(canvas, Offset(leftEyeX, eyeY));
    _drawEye(canvas, Offset(rightEyeX, eyeY));

    final cheekPaint = Paint()..color = _cheek.withValues(alpha: 0.22);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(leftEyeX - 14, eyeY + 9),
        width: 14,
        height: 8,
      ),
      cheekPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(rightEyeX + 14, eyeY + 9),
        width: 14,
        height: 8,
      ),
      cheekPaint,
    );

    final mouthCenter = Offset(cx, headY + headH * 0.80);

    _drawMouth(canvas: canvas, center: mouthCenter);
    _drawMustache(canvas: canvas, center: mouthCenter);
    canvas.save();
    canvas.translate(cx, headY - 14 + hairOffset * 0.6);
    canvas.scale(antennaScale, antennaScale);
    _glowCircle(canvas, Offset.zero, 4, accentColor);

    canvas.restore();

    _drawHairFringe(
      canvas: canvas,
      headX: headX,
      headY: headY,
      headW: headW,
      offset: hairOffset,
    );
  }

  void _drawHair({
    required Canvas canvas,
    required double headX,
    required double headY,
    required double headW,
    required double headH,
    required double offset,
  }) {
    final dy = offset;

    _drawHairPuffs(canvas, headX, headY, headW, headH, dy);

    final curlPaint = Paint()
      ..color = _hairMid
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final coilPaint = Paint()
      ..color = _hairBase
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final shinePaint = Paint()..color = _hairShine.withValues(alpha: 0.55);

    for (final c in _buildTopCurls(headX, headY, headW, dy)) {
      _drawCurlArc(canvas, c, curlPaint);
    }

    for (final c in _buildSideCurls(
      headX: headX,
      headY: headY,
      headW: headW,
      headH: headH,
      dy: dy,
      isLeft: true,
    )) {
      _drawCurlArc(canvas, c, curlPaint);
    }

    for (final c in _buildSideCurls(
      headX: headX,
      headY: headY,
      headW: headW,
      headH: headH,
      dy: dy,
      isLeft: false,
    )) {
      _drawCurlArc(canvas, c, curlPaint);
    }

    for (final c in _buildCoils(headX, headY, headW, headH, dy)) {
      _drawSpringCoil(canvas, c, coilPaint);
    }

    for (final s in _buildShines(headX, headY, headW, headH, dy)) {
      _drawShine(canvas, s, shinePaint);
    }
  }

  void _drawHairPuffs(
    Canvas canvas,
    double headX,
    double headY,
    double headW,
    double headH,
    double dy,
  ) {
    final puffPaint = Paint()..color = _hairDark;

    final puffCenters = <Offset>[
      Offset(headX + 13, headY + headH * 0.28 + dy),
      Offset(headX + headW - 13, headY + headH * 0.28 + dy),
    ];

    for (final center in puffCenters) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1, 1.4);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 30, height: 22),
        puffPaint,
      );
      canvas.restore();
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headX + headW / 2, headY - 4 + dy),
        width: 54,
        height: 34,
      ),
      puffPaint,
    );
  }

  List<_CurlSpec> _buildTopCurls(
    double headX,
    double headY,
    double headW,
    double dy,
  ) {
    return [
      _CurlSpec(
        cx: headX + headW * 0.26,
        cy: headY + 2 + dy,
        rx: 11,
        ry: 10,
        startAngle: -math.pi * 0.95,
        sweep: math.pi * 1.85,
        thickness: 5.4,
      ),
      _CurlSpec(
        cx: headX + headW * 0.50,
        cy: headY - 6 + dy,
        rx: 13,
        ry: 11,
        startAngle: -math.pi * 0.85,
        sweep: math.pi * 1.75,
        thickness: 5.8,
      ),
      _CurlSpec(
        cx: headX + headW * 0.74,
        cy: headY + 2 + dy,
        rx: 11,
        ry: 10,
        startAngle: -math.pi * 0.95,
        sweep: math.pi * 1.85,
        thickness: 5.4,
      ),
    ];
  }

  List<_CurlSpec> _buildSideCurls({
    required double headX,
    required double headY,
    required double headW,
    required double headH,
    required double dy,
    required bool isLeft,
  }) {
    final x1 = isLeft ? headX + 8 : headX + headW - 8;
    final x2 = isLeft ? headX + 6 : headX + headW - 6;
    final x3 = isLeft ? headX + 8 : headX + headW - 8;

    final sweep1 = isLeft ? math.pi * 1.65 : -math.pi * 1.65;
    final sweep2 = isLeft ? math.pi * 1.50 : -math.pi * 1.50;
    final sweep3 = isLeft ? math.pi * 1.35 : -math.pi * 1.35;

    return [
      _CurlSpec(
        cx: x1,
        cy: headY + headH * 0.14 + dy,
        rx: 8.5,
        ry: 12,
        startAngle: -math.pi * 0.55,
        sweep: sweep1,
        thickness: 4.8,
      ),
      _CurlSpec(
        cx: x2,
        cy: headY + headH * 0.42 + dy,
        rx: 7.5,
        ry: 10.5,
        startAngle: -math.pi * 0.42,
        sweep: sweep2,
        thickness: 4.2,
      ),
      _CurlSpec(
        cx: x3,
        cy: headY + headH * 0.67 + dy,
        rx: 7.5,
        ry: 8.5,
        startAngle: -math.pi * 0.32,
        sweep: sweep3,
        thickness: 3.8,
      ),
    ];
  }

  List<_CoilSpec> _buildCoils(
    double headX,
    double headY,
    double headW,
    double headH,
    double dy,
  ) {
    return [
      _CoilSpec(
        cx: headX + headW * 0.20,
        cy: headY - 1 + dy,
        rx: 5.2,
        ry: 6.6,
        loops: 1.8,
        thickness: 3.4,
      ),
      _CoilSpec(
        cx: headX + headW * 0.35,
        cy: headY - 5 + dy,
        rx: 5.4,
        ry: 7.4,
        loops: 1.9,
        thickness: 3.6,
      ),
      _CoilSpec(
        cx: headX + headW * 0.50,
        cy: headY - 10 + dy,
        rx: 6.2,
        ry: 8.8,
        loops: 2.1,
        thickness: 4.0,
      ),
      _CoilSpec(
        cx: headX + headW * 0.65,
        cy: headY - 5 + dy,
        rx: 5.4,
        ry: 7.4,
        loops: 1.9,
        thickness: 3.6,
      ),
      _CoilSpec(
        cx: headX + headW * 0.80,
        cy: headY - 1 + dy,
        rx: 5.2,
        ry: 6.6,
        loops: 1.8,
        thickness: 3.4,
      ),
      _CoilSpec(
        cx: headX + 2,
        cy: headY + headH * 0.52 + dy,
        rx: 4.3,
        ry: 6.4,
        loops: 1.5,
        thickness: 3.0,
      ),
      _CoilSpec(
        cx: headX + headW - 2,
        cy: headY + headH * 0.52 + dy,
        rx: 4.3,
        ry: 6.4,
        loops: 1.5,
        thickness: 3.0,
      ),
    ];
  }

  List<_ShineSpec> _buildShines(
    double headX,
    double headY,
    double headW,
    double headH,
    double dy,
  ) {
    return [
      _ShineSpec(
        cx: headX + headW * 0.28,
        cy: headY - 2 + dy,
        rx: 3.0,
        ry: 2.5,
        angle: -0.4,
      ),
      _ShineSpec(
        cx: headX + headW * 0.50,
        cy: headY - 7 + dy,
        rx: 4.0,
        ry: 3.0,
        angle: 0.0,
      ),
      _ShineSpec(
        cx: headX + headW * 0.72,
        cy: headY - 2 + dy,
        rx: 3.0,
        ry: 2.5,
        angle: 0.4,
      ),
      _ShineSpec(
        cx: headX + 10,
        cy: headY + headH * 0.18 + dy,
        rx: 2.5,
        ry: 2.0,
        angle: -0.5,
      ),
      _ShineSpec(
        cx: headX + headW - 10,
        cy: headY + headH * 0.18 + dy,
        rx: 2.5,
        ry: 2.0,
        angle: 0.5,
      ),
    ];
  }

  void _drawShine(Canvas canvas, _ShineSpec s, Paint paint) {
    canvas.save();
    canvas.translate(s.cx, s.cy);
    canvas.rotate(s.angle);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: s.rx * 2, height: s.ry * 2),
      paint,
    );
    canvas.restore();
  }

  void _drawHairFringe({
    required Canvas canvas,
    required double headX,
    required double headY,
    required double headW,
    required double offset,
  }) {
    final fringeY = headY + 9 + offset;
    final fringe = [
      _CurlSpec(
        cx: headX + headW * 0.20,
        cy: fringeY,
        rx: 5,
        ry: 6,
        startAngle: -math.pi * 0.7,
        sweep: math.pi * 1.2,
        thickness: 3.0,
      ),
      _CurlSpec(
        cx: headX + headW * 0.37,
        cy: fringeY - 3,
        rx: 5,
        ry: 7,
        startAngle: -math.pi * 0.7,
        sweep: math.pi * 1.3,
        thickness: 3.2,
      ),
      _CurlSpec(
        cx: headX + headW * 0.54,
        cy: fringeY - 4,
        rx: 5,
        ry: 7,
        startAngle: -math.pi * 0.7,
        sweep: math.pi * 1.3,
        thickness: 3.2,
      ),
      _CurlSpec(
        cx: headX + headW * 0.72,
        cy: fringeY - 2,
        rx: 5,
        ry: 6,
        startAngle: -math.pi * 0.7,
        sweep: math.pi * 1.2,
        thickness: 3.0,
      ),
    ];
    final paint = Paint()
      ..color = _hairLight
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final c in fringe) {
      _drawCurlArc(canvas, c, paint);
    }
  }

  void _drawCurlArc(Canvas canvas, _CurlSpec c, Paint basePaint) {
    const steps = 20;
    final path = Path();
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final angle = c.startAngle + c.sweep * t;
      final x = c.cx + math.cos(angle) * c.rx;
      final y = c.cy + math.sin(angle) * c.ry;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, basePaint..strokeWidth = c.thickness);
  }

  void _drawSpringCoil(Canvas canvas, _CoilSpec c, Paint basePaint) {
    final steps = (c.loops * 28).round();
    final path = Path();
    for (int i = 0; i <= steps; i++) {
      final prog = i / steps;
      final angle = -math.pi / 2 + prog * math.pi * 2 * c.loops;
      final spiralRx = c.rx * (0.52 + 0.48 * (1 - prog * 0.25));
      final spiralRy = c.ry * (0.52 + 0.48 * (1 - prog * 0.18));
      final x = c.cx + math.cos(angle) * spiralRx;
      final y = c.cy + math.sin(angle) * spiralRy;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, basePaint..strokeWidth = c.thickness);
  }

  void _drawEye(Canvas canvas, Offset center) {
    const ew = 26.0, eh = 14.0;
    final socketRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: ew, height: eh),
      const Radius.circular(99),
    );
    canvas.drawRRect(socketRect, Paint()..color = const Color(0xFF0D1117));
    canvas.drawRRect(
      socketRect,
      Paint()
        ..color = accentColor.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    canvas.save();
    canvas.translate(center.dx + eyeTrackX, center.dy + eyeTrackY);
    canvas.scale(1.0, blinkScale);
    canvas.drawCircle(
      Offset.zero,
      9,
      Paint()..color = accentColor.withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      Offset.zero,
      6.5,
      Paint()..color = accentColor.withValues(alpha: 0.16),
    );
    canvas.drawCircle(Offset.zero, 4.2, Paint()..color = accentColor);
    canvas.drawCircle(
      const Offset(-1.3, -1.3),
      1.4,
      Paint()..color = Colors.white.withValues(alpha: 0.88),
    );
    canvas.restore();
  }

  void _drawMustache({required Canvas canvas, required Offset center}) {
    final hairColor = const Color(0xFFCFD8DC);

    final fillPaint = Paint()
      ..color = hairColor
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFF78909C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = center.dx;
    final cy = center.dy;

    // ===== 1) ria mÃƒÂ©p =====
    final moustacheY = cy - 2.0;
    const gap = 2.8;

    final leftMoustache = Path()
      ..moveTo(cx - gap, moustacheY)
      ..quadraticBezierTo(cx - 8, moustacheY - 4, cx - 12, moustacheY - 1)
      ..quadraticBezierTo(cx - 15, moustacheY + 1.5, cx - 11, moustacheY + 3.5)
      ..quadraticBezierTo(cx - 7, moustacheY + 2.8, cx - gap, moustacheY + 1)
      ..close();

    final rightMoustache = Path()
      ..moveTo(cx + gap, moustacheY)
      ..quadraticBezierTo(cx + 8, moustacheY - 4, cx + 12, moustacheY - 1)
      ..quadraticBezierTo(cx + 15, moustacheY + 1.5, cx + 11, moustacheY + 3.5)
      ..quadraticBezierTo(cx + 7, moustacheY + 2.8, cx + gap, moustacheY + 1)
      ..close();

    // fill
    canvas.drawPath(leftMoustache, fillPaint);
    canvas.drawPath(rightMoustache, fillPaint);

    // viÃ¡Â»Ân
    canvas.drawPath(leftMoustache, strokePaint);
    canvas.drawPath(rightMoustache, strokePaint);

    // highlight mÃƒÂ©p
    canvas.drawPath(
      Path()
        ..moveTo(cx - gap, moustacheY + 0.4)
        ..quadraticBezierTo(
          cx - 7,
          moustacheY - 2.2,
          cx - 10,
          moustacheY - 0.6,
        ),
      highlightPaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(cx + gap, moustacheY + 0.4)
        ..quadraticBezierTo(
          cx + 7,
          moustacheY - 2.2,
          cx + 10,
          moustacheY - 0.6,
        ),
      highlightPaint,
    );

    // highlight cÃ¡ÂºÂ±m
    canvas.drawPath(
      Path()
        ..moveTo(cx - 6, cy + 26)
        ..quadraticBezierTo(cx, cy + 29, cx + 6, cy + 26),
      highlightPaint,
    );
  }

  void _drawMouth({required Canvas canvas, required Offset center}) {
    final path = Path();
    path.moveTo(center.dx - 9, center.dy - 1);
    path.quadraticBezierTo(
      center.dx,
      center.dy + 5,
      center.dx + 9,
      center.dy - 1,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawArm({
    required Canvas canvas,
    required Offset shoulder,
    required double swing,
    required double foreSwing,
    required bool isLeft,
  }) {
    const upperLen = 32.0;
    const foreLen = 24.0;

    final baseUpper = isLeft ? -2.38 : -0.76;
    final upperAngle = baseUpper + swing;
    final foreAngle = upperAngle + (isLeft ? 0.58 : -0.58) + foreSwing;

    final elbow = Offset(
      shoulder.dx + math.cos(upperAngle) * upperLen,
      shoulder.dy + math.sin(upperAngle) * upperLen,
    );

    final wrist = Offset(
      elbow.dx + math.cos(foreAngle) * foreLen,
      elbow.dy + math.sin(foreAngle) * foreLen,
    );

    // ---------------------------
    // paints
    // ---------------------------
    final shoulderGlow = Paint()..color = accentColor.withValues(alpha: 0.10);

    final jointFill = Paint()..color = _joint;

    final jointStroke = Paint()
      ..color = _jointRim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final upperPaint = Paint()
      ..color = _limbUp
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final upperHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final forePaint = Paint()
      ..color = _limbMid
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round;

    final foreHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final handFill = Paint()..color = _limbLow;

    final handStroke = Paint()
      ..color = _joint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    // ---------------------------
    // shoulder
    // ---------------------------
    canvas.drawCircle(shoulder, 8, shoulderGlow);
    canvas.drawCircle(shoulder, 5, jointFill);
    canvas.drawCircle(shoulder, 5, jointStroke);

    // shoulder hub inner
    canvas.drawCircle(
      shoulder,
      2.0,
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );

    // ---------------------------
    // upper arm
    // ---------------------------
    canvas.drawLine(shoulder, elbow, upperPaint);

    // subtle highlight lÃ¡Â»â€¡ch lÃƒÂªn 1 chÃƒÂºt Ã„â€˜Ã¡Â»Æ’ cÃƒÂ³ cÃ¡ÂºÂ£m giÃƒÂ¡c volume
    canvas.drawLine(
      Offset(shoulder.dx + (isLeft ? 0.6 : -0.6), shoulder.dy - 0.8),
      Offset(elbow.dx + (isLeft ? 0.6 : -0.6), elbow.dy - 0.8),
      upperHighlight,
    );

    // ---------------------------
    // elbow
    // ---------------------------
    canvas.drawCircle(
      elbow,
      8,
      Paint()..color = accentColor.withValues(alpha: 0.10),
    );
    canvas.drawCircle(elbow, 5.2, jointFill);
    canvas.drawCircle(elbow, 5.2, jointStroke);

    // cap ring cho cÃ¡ÂºÂ£m giÃƒÂ¡c mechanical hÃ†Â¡n
    canvas.drawCircle(
      elbow,
      7.0,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // ---------------------------
    // forearm
    // ---------------------------
    canvas.drawLine(elbow, wrist, forePaint);

    canvas.drawLine(
      Offset(elbow.dx + (isLeft ? 0.5 : -0.5), elbow.dy - 0.6),
      Offset(wrist.dx + (isLeft ? 0.5 : -0.5), wrist.dy - 0.6),
      foreHighlight,
    );

    // wrist joint
    canvas.drawCircle(
      wrist,
      4.0,
      Paint()..color = accentColor.withValues(alpha: 0.06),
    );
    canvas.drawCircle(wrist, 3.5, Paint()..color = _limbLow);

    // ---------------------------
    // hand
    // ---------------------------
    final handAngle = foreAngle + (isLeft ? -0.08 : 0.08);

    canvas.save();
    canvas.translate(wrist.dx, wrist.dy + 1.6);
    canvas.rotate(handAngle);

    final handRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, 0), width: 12, height: 6.5),
      const Radius.circular(3.2),
    );

    canvas.drawRRect(handRect, handFill);
    canvas.drawRRect(handRect, handStroke);

    // highlight trÃƒÂªn bÃƒÂ n tay
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, -1.1), width: 8.5, height: 1.8),
        const Radius.circular(1),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.10),
    );

    // ngÃƒÂ³n / claw nhÃ¡Â»Â
    final fingerPaint = Paint()
      ..color = _jointRim
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      const Offset(3.5, -0.8),
      const Offset(6.0, -1.6),
      fingerPaint,
    );
    canvas.drawLine(
      const Offset(3.8, 0.8),
      const Offset(6.2, 1.6),
      fingerPaint,
    );

    canvas.restore();
  }

  void _drawLeg({
    required Canvas canvas,
    required Offset hip,
    required double swing,
    required double kneeBend,
    required double footLift,
    required bool isLeft,
  }) {
    const thighLen = 32.0;
    const shinLen = 26.0;

    final thighAngle = 1.57 + swing;

    // cÃ¡ÂºÂ³ng chÃƒÂ¢n co rÃƒÂµ hÃ†Â¡n khi chÃƒÂ¢n Ã„â€˜Ã†Â°Ã¡Â»Â£c nhÃ¡ÂºÂ¥c lÃƒÂªn
    final shinBaseOffset = isLeft ? 0.18 : -0.18;
    final shinAngle = thighAngle + shinBaseOffset + kneeBend;

    final knee = Offset(
      hip.dx + math.cos(thighAngle) * thighLen,
      hip.dy + math.sin(thighAngle) * thighLen,
    );

    final ankle = Offset(
      knee.dx + math.cos(shinAngle) * shinLen,
      knee.dy + math.sin(shinAngle) * shinLen - footLift,
    );

    canvas.drawCircle(hip, 5, Paint()..color = _joint);
    canvas.drawLine(
      hip,
      knee,
      Paint()
        ..color = _limbMid
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(
      knee,
      7,
      Paint()..color = accentColor.withValues(alpha: 0.08),
    );
    canvas.drawCircle(knee, 5.5, Paint()..color = _joint);
    canvas.drawCircle(
      knee,
      5.5,
      Paint()
        ..color = _jointRim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    canvas.drawLine(
      knee,
      ankle,
      Paint()
        ..color = _limbMid
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(ankle, 3.5, Paint()..color = _joint);

    final footOffX = isLeft ? -3.0 : 3.0;
    final footTilt = swing * 0.35;

    canvas.save();
    canvas.translate(ankle.dx + footOffX, ankle.dy + 2.5);
    canvas.rotate(footTilt);

    final footRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 26, height: 10),
      const Radius.circular(5),
    );
    canvas.drawRRect(footRect, Paint()..color = _footBg);
    canvas.drawRRect(
      footRect,
      Paint()
        ..color = _footRim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    final toeCenter = Offset(isLeft ? -7.0 : 7.0, 2.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: toeCenter, width: 9, height: 8),
        const Radius.circular(4),
      ),
      Paint()..color = _footRim,
    );

    canvas.restore();
  }

  void _glowCircle(Canvas canvas, Offset center, double r, Color color) {
    canvas.drawCircle(
      center,
      r + 7,
      Paint()..color = color.withValues(alpha: 0.10),
    );
    canvas.drawCircle(
      center,
      r + 3.5,
      Paint()..color = color.withValues(alpha: 0.20),
    );
    canvas.drawCircle(center, r, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RobotPainter old) {
    return old.accentColor != accentColor ||
        old.pose != pose ||
        old.eyeTrackX != eyeTrackX ||
        old.eyeTrackY != eyeTrackY ||
        old.antennaScale != antennaScale ||
        old.armSwingL != armSwingL ||
        old.armSwingR != armSwingR ||
        old.foreSwing != foreSwing ||
        old.legSwingL != legSwingL ||
        old.legSwingR != legSwingR ||
        old.kneeBendL != kneeBendL ||
        old.kneeBendR != kneeBendR ||
        old.footLiftL != footLiftL ||
        old.footLiftR != footLiftR ||
        old.hairOffset != hairOffset ||
        old.walkStrength != walkStrength ||
        old.isWalking != isWalking ||
        old.walkPhase != walkPhase ||
        old.facing != facing;
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

class _BadgePainter extends CustomPainter {
  final Color accentColor;
  final ui.Image? logoImage;

  const _BadgePainter({required this.accentColor, this.logoImage});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final headH = h * 0.22;
    final bodyW = w * 0.5;
    final bodyH = h * 0.27;
    final bodyX = (w - bodyW) / 2;
    final bodyY = h * 0.15 + headH + h * 0.032;

    _drawSPCOnly(
      canvas: canvas,
      bodyX: bodyX,
      bodyY: bodyY,
      bodyW: bodyW,
      bodyH: bodyH,
    );
  }

  void _drawSPCOnly({
    required Canvas canvas,
    required double bodyX,
    required double bodyY,
    required double bodyW,
    required double bodyH,
  }) {
    final center = Offset(bodyX + bodyW * 0.68, bodyY + bodyH * 0.34);
    final badgeW = bodyW * 0.62;
    final badgeH = bodyH * 0.35;

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: badgeW, height: badgeH),
      Radius.circular(badgeH * 0.16),
    );

    canvas.drawRRect(rect, Paint()..color = Colors.white);

    canvas.drawRRect(
      rect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    final contentRect = Rect.fromLTWH(
      rect.left + badgeH * 0.015,
      rect.top + badgeH * 0.015,
      badgeW - badgeH * 0.03,
      badgeH - badgeH * 0.03,
    );

    if (logoImage != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        logoImage!.width.toDouble(),
        logoImage!.height.toDouble(),
      );

      canvas.drawImageRect(
        logoImage!,
        src,
        contentRect,
        Paint()..filterQuality = FilterQuality.high,
      );
      return;
    }
  }

  @override
  bool shouldRepaint(covariant _BadgePainter oldDelegate) {
    return oldDelegate.accentColor != accentColor ||
        oldDelegate.logoImage != logoImage;
  }
}
