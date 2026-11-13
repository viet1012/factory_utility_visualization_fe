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
  static const _joint = Color(0xFF484F58);
  static const _jointRim = Color(0xFF6E7681);
  static const _cheek = Color(0xFFF97583);
  static const _hairBase = Color(0xFFB0BEC5);
  static const _hairMid = Color(0xFFCFD8DC);
  static const _hairLight = Color(0xFFECEFF1);
  static const _hairDark = Color(0xFF78909C);
  static const _hairShine = Color(0xFFFFFFFF);
  static const _bodyTop = Color(0xFF2F6FD6);
  static const _bodyBottom = Color(0xFF0E3478);
  static const _headTop = Color(0xFF2A313B);
  static const _headBottom = Color(0xFF0B0F14);

  // limb lengths, recomputed from the layout on every paint
  double _upperLen = 27;
  double _foreLen = 23;
  double _thighLen = 31;
  double _shinLen = 30;

  _RobotPainter({
    required this.accentColor,
    required this.pose,
    required this.eyeTrackX,
    required this.eyeTrackY,
    required this.antennaScale,
    this.bodyBob = 0,
  });

  /// Vertical bob applied to the upper body only; feet stay planted.
  final double bodyBob;

  @override
  void paint(Canvas canvas, Size size) {
    final l = _MascotLayout.of(size);
    final w = l.w;
    final h = l.h;
    final headW = l.headW;
    final headH = l.headH;
    final bodyW = l.bodyW;
    final bodyH = l.bodyH;
    final headX = l.headX;
    final headY = l.headY;
    final bodyX = l.bodyX;
    final bodyY = l.bodyY;
    final cx = l.cx;

    // limb lengths scale with the mascot; legs end exactly on the ground
    _upperLen = h * 0.115;
    _foreLen = h * 0.10;
    // legs are solved with IK; lengths match the standing height so the
    // legs are straight at rest and only bend when the body dips.
    final ankleGroundY = l.groundY - 7.5;
    final legSpan = ankleGroundY - (bodyY + bodyH - 1);
    _thighLen = (legSpan + 0.5) * 0.5;
    _shinLen = (legSpan + 0.5) * 0.5;

    canvas.save();
    canvas.translate(0, bodyBob);
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
    canvas.restore();

    // ===== SHADOW =====
    final shadowPhase = math.cos(walkPhase).abs();

    final shadowBase = bodyW * 0.80;
    final shadowWidth = isWalking
        ? (shadowBase + 2 - shadowPhase * 10 * walkStrength)
        : shadowBase;

    final shadowOpacity = isWalking
        ? (0.22 - shadowPhase * 0.08 * walkStrength)
        : 0.22;

    final shadowCenter = Offset(w / 2, l.groundY - 1);

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
      hip: Offset(bodyX + bodyW * 0.29, bodyY + bodyH - 1 + bodyBob),
      ankleGroundY: ankleGroundY,
      legSpan: legSpan,
      swing: legSwingL,
      footLift: footLiftL,
      isLeft: true,
    );
    _drawLeg(
      canvas: canvas,
      hip: Offset(bodyX + bodyW * 0.71, bodyY + bodyH - 1 + bodyBob),
      ankleGroundY: ankleGroundY,
      legSpan: legSpan,
      swing: legSwingR,
      footLift: footLiftR,
      isLeft: false,
    );

    // ===== UPPER BODY (bobs) =====
    canvas.save();
    canvas.translate(0, bodyBob);

    final neckRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 7, headY + headH - 2, 14, bodyY - headY - headH + 6),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      neckRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [_neckBg, Color(0xFF3A424D), _neckBg],
        ).createShader(neckRect.outerRect),
    );
    canvas.drawRRect(
      neckRect,
      Paint()
        ..color = _headRim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    // neck segment rings
    final neckR = neckRect.outerRect;
    for (final f in [0.38, 0.68]) {
      final y = neckR.top + neckR.height * f;
      canvas.drawLine(
        Offset(neckR.left + 1.5, y),
        Offset(neckR.right - 1.5, y),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.45)
          ..strokeWidth = 1.0,
      );
    }

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bodyX, bodyY, bodyW, bodyH),
      const Radius.circular(12),
    );
    // Cyber Glow
    canvas.drawRRect(
      bodyRect.inflate(6),
      Paint()
        ..color = accentColor.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    _drawBodyShell(canvas, bodyRect);
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = accentColor.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    _drawCollarAndPads(canvas, bodyRect);

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
      headRRect.inflate(5),
      Paint()
        ..color = accentColor.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    canvas.drawRRect(
      headRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_headTop, _headBg, _headBottom],
          stops: [0.0, 0.55, 1.0],
        ).createShader(headRRect.outerRect),
    );
    _drawHeadGloss(canvas, headRRect);
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

    // ===== FACE SCREEN + EAR MODULES =====
    final screenRRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        headX + 9,
        headY + headH * 0.34,
        headX + headW - 9,
        headY + headH - 5,
      ),
      const Radius.circular(14),
    );
    _drawFaceScreen(canvas, screenRRect);
    _drawEarModules(canvas, headRRect);

    final eyeY = headY + headH * 0.57;
    final leftEyeX = headX + headW * 0.32;
    final rightEyeX = headX + headW * 0.68;
    _drawEye(canvas, Offset(leftEyeX, eyeY));
    _drawEye(canvas, Offset(rightEyeX, eyeY));

    final cheekPaint = Paint()
      ..color = _cheek.withValues(alpha: 0.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
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
    _drawScreenGlare(canvas, screenRRect);

    _drawAntenna(
      canvas,
      base: Offset(cx, headY - 2),
      tip: Offset(cx + hairOffset * 0.4, headY - 30 + hairOffset * 0.6),
    );

    _drawHairFringe(
      canvas: canvas,
      headX: headX,
      headY: headY,
      headW: headW,
      offset: hairOffset,
    );
    canvas.restore();
  }

  void _drawHair({
    required Canvas canvas,
    required double headX,
    required double headY,
    required double headW,
    required double headH,
    required double offset,
  }) {
    // fluffy cloud of silver hair behind the head (top + sides)
    final c = Offset(headX + headW / 2, headY + headH * 0.48 + offset);
    final rx = headW * 0.47;
    final ry = headH * 0.60;
    const n = 9;
    for (int i = 0; i < n; i++) {
      final t = i / (n - 1);
      final a = math.pi * (0.96 + 1.08 * t);
      final p = Offset(c.dx + math.cos(a) * rx, c.dy + math.sin(a) * ry);
      final r = headH * (0.17 + 0.06 * math.sin(t * math.pi));
      _drawPuff(canvas, p, r);
    }
  }

  void _drawPuff(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c + const Offset(0, 1.6),
      r,
      Paint()..color = _hairDark.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 0.95,
          colors: [_hairShine, _hairLight, _hairMid, _hairBase],
          stops: [0.0, 0.35, 0.75, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void _drawHairFringe({
    required Canvas canvas,
    required double headX,
    required double headY,
    required double headW,
    required double offset,
  }) {
    // soft hairline across the top of the head
    const xs = [0.20, 0.35, 0.50, 0.65, 0.80];
    const rs = [6.5, 7.5, 8.5, 7.5, 6.5];
    for (int i = 0; i < xs.length; i++) {
      final lift = math.sin(xs[i] * math.pi) * 3;
      _drawPuff(
        canvas,
        Offset(headX + headW * xs[i], headY + 3 - lift + offset * 0.6),
        rs[i],
      );
    }
  }

  void _drawEye(Canvas canvas, Offset center) {
    canvas.save();
    canvas.translate(center.dx + eyeTrackX, center.dy + eyeTrackY);
    canvas.scale(1.0, blinkScale);

    // bloom
    canvas.drawCircle(
      Offset.zero,
      10,
      Paint()
        ..color = accentColor.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // iris
    const irisR = 6.2;
    final irisRect = Rect.fromCircle(center: Offset.zero, radius: irisR);
    canvas.drawCircle(
      Offset.zero,
      irisR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: [
            Color.lerp(accentColor, Colors.white, 0.6)!,
            accentColor,
            Color.lerp(accentColor, Colors.black, 0.45)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(irisRect),
    );

    // pupil
    canvas.drawCircle(
      const Offset(0.3, 0.4),
      2.5,
      Paint()..color = const Color(0xFF04140A).withValues(alpha: 0.85),
    );

    // sparkles
    canvas.drawCircle(
      const Offset(-2.0, -2.1),
      1.8,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
    canvas.drawCircle(
      const Offset(2.2, 1.8),
      0.9,
      Paint()..color = Colors.white.withValues(alpha: 0.65),
    );
    canvas.restore();
  }

  void _drawFaceScreen(Canvas canvas, RRect screen) {
    final r = screen.outerRect;

    // recessed bezel
    canvas.drawRRect(
      screen.inflate(2.2),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // glass
    canvas.drawRRect(
      screen,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E1A24), Color(0xFF060B10)],
        ).createShader(r),
    );

    canvas.save();
    canvas.clipRRect(screen);

    // inner accent ambience
    canvas.drawRect(
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.2),
          radius: 0.9,
          colors: [
            accentColor.withValues(alpha: 0.12),
            accentColor.withValues(alpha: 0.0),
          ],
        ).createShader(r),
    );

    // CRT scanlines
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 0.6;
    for (double y = r.top + 1.5; y < r.bottom; y += 2.6) {
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), linePaint);
    }

    // moving scan band
    final p = (DateTime.now().millisecondsSinceEpoch % 2600) / 2600;
    final bandY = r.top - 6 + (r.height + 12) * p;
    final band = Rect.fromLTWH(r.left, bandY - 4, r.width, 8);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accentColor.withValues(alpha: 0.0),
            accentColor.withValues(alpha: 0.16),
            accentColor.withValues(alpha: 0.0),
          ],
        ).createShader(band),
    );
    canvas.restore();

    canvas.drawRRect(
      screen,
      Paint()
        ..color = accentColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawScreenGlare(Canvas canvas, RRect screen) {
    final r = screen.outerRect;
    canvas.save();
    canvas.clipRRect(screen);
    final glare = Path()
      ..moveTo(r.left + r.width * 0.06, r.top)
      ..lineTo(r.left + r.width * 0.30, r.top)
      ..lineTo(r.left + r.width * 0.12, r.bottom)
      ..lineTo(r.left - r.width * 0.12, r.bottom)
      ..close();
    canvas.drawPath(
      glare,
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );
    canvas.drawLine(
      Offset(r.left + 10, r.top + 2.2),
      Offset(r.right - 10, r.top + 2.2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _drawEarModules(Canvas canvas, RRect headRRect) {
    final r = headRRect.outerRect;
    final pulse = _pulse;
    for (final left in [true, false]) {
      final c = Offset(left ? r.left + 0.5 : r.right - 0.5, r.top + r.height * 0.58);
      final ear = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 10, height: 22),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        ear,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bodyTop, _bodyBottom],
          ).createShader(ear.outerRect),
      );
      canvas.drawRRect(
        ear,
        Paint()
          ..color = accentColor.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
      canvas.drawLine(
        Offset(c.dx - 2, ear.top + 4),
        Offset(c.dx - 2, ear.bottom - 4),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.22)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        c,
        4.5,
        Paint()
          ..color = accentColor.withValues(alpha: 0.25 + 0.25 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawCircle(c, 1.9, Paint()..color = accentColor);
    }
  }

  void _drawAntenna(
    Canvas canvas, {
    required Offset base,
    required Offset tip,
  }) {
    canvas.drawCircle(base, 3.2, Paint()..color = _joint);
    canvas.drawLine(
      base,
      tip,
      Paint()
        ..color = _limbMid
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      base + const Offset(-0.6, 0),
      tip + const Offset(-0.6, 0),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 0.7
        ..strokeCap = StrokeCap.round,
    );

    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.scale(antennaScale, antennaScale);
    final pulse = _pulse;
    canvas.drawCircle(
      Offset.zero,
      9 + 3 * pulse,
      Paint()
        ..color = accentColor.withValues(alpha: 0.18 + 0.14 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    const ballR = 4.6;
    canvas.drawCircle(
      Offset.zero,
      ballR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [
            Colors.white,
            Color.lerp(accentColor, Colors.white, 0.3)!,
            accentColor,
          ],
          stops: const [0.0, 0.35, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: ballR)),
    );
    canvas.restore();
  }

  void _drawCollarAndPads(Canvas canvas, RRect bodyRect) {
    final r = bodyRect.outerRect;

    // collar
    final collar = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(r.center.dx, r.top + 1.5),
        width: r.width * 0.42,
        height: 8,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      collar,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A424D), _neckBg],
        ).createShader(collar.outerRect),
    );
    canvas.drawRRect(
      collar,
      Paint()
        ..color = accentColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // shoulder pads
    for (final left in [true, false]) {
      final c = Offset(
        left ? r.left + 3 : r.right - 3,
        r.top + r.height * 0.17,
      );
      final pad = Rect.fromCenter(center: c, width: 20, height: 16);
      canvas.drawOval(
        pad.shift(const Offset(0, 1.5)),
        Paint()..color = Colors.black.withValues(alpha: 0.30),
      );
      canvas.drawOval(
        pad,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.5),
            colors: [Color(0xFF5A93EA), _bodyTop, _bodyBottom],
            stops: [0.0, 0.45, 1.0],
          ).createShader(pad),
      );
      canvas.drawOval(
        pad,
        Paint()
          ..color = accentColor.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: c + const Offset(-2, -3.5),
          width: 9,
          height: 3.5,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.30),
      );
    }
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
        ..color = accentColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.lerp(accentColor, Colors.white, 0.25)!
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
    final upperLen = _upperLen;
    final foreLen = _foreLen;

    // relaxed pose: arms hang close to the body, forearms bend slightly in
    final baseUpper = isLeft ? 1.97 : 1.17;
    final upperAngle = baseUpper + swing;
    final foreAngle = upperAngle + (isLeft ? -0.30 : 0.30) + foreSwing;

    final elbow = Offset(
      shoulder.dx + math.cos(upperAngle) * upperLen,
      shoulder.dy + math.sin(upperAngle) * upperLen,
    );
    final wrist = Offset(
      elbow.dx + math.cos(foreAngle) * foreLen,
      elbow.dy + math.sin(foreAngle) * foreLen,
    );

    _drawTube(canvas, shoulder, elbow, 10, _limbUp);
    _drawJoint(canvas, elbow, 4.6);
    _drawTube(canvas, elbow, wrist, 9, _limbMid);
    _drawCuff(canvas, elbow, wrist, 9);

    // round mitten hand
    final hand = wrist + Offset(math.cos(foreAngle), math.sin(foreAngle)) * 3;
    const handR = 6.2;
    canvas.drawCircle(
      hand + const Offset(0, 1.2),
      handR,
      Paint()..color = Colors.black.withValues(alpha: 0.30),
    );
    canvas.drawCircle(
      hand,
      handR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          colors: [Color(0xFFF5F7FA), Color(0xFFCFD8DC), Color(0xFF90A4AE)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: hand, radius: handR)),
    );
  }

  void _drawJoint(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = _joint);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = _jointRim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    canvas.drawCircle(
      c + Offset(-r * 0.3, -r * 0.3),
      r * 0.35,
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  void _drawLeg({
    required Canvas canvas,
    required Offset hip,
    required double ankleGroundY,
    required double legSpan,
    required double swing,
    required double footLift,
    required bool isLeft,
  }) {
    final thighLen = _thighLen;
    final shinLen = _shinLen;
    final reach = thighLen + shinLen;

    // front-view march: feet stay under the hips, lift straight up
    var target = Offset(
      hip.dx - math.sin(swing) * 4,
      ankleGroundY - footLift,
    );

    // front view: a lifted leg is foreshortened (knee comes toward the
    // viewer), so keep the knee between hip and foot with only a tiny
    // outward offset instead of bending sideways.
    var toTarget = target - hip;
    final d = toTarget.distance;
    if (d > reach) {
      target = hip + toTarget / d * reach;
      toTarget = target - hip;
    }
    final slack = (reach - toTarget.distance).clamp(0.0, reach);
    final knee =
        Offset.lerp(hip, target, thighLen / reach)! +
        Offset((isLeft ? -1 : 1) * slack * 0.18, 0);
    final ankle = target;

    _drawTube(canvas, hip, knee, 13, _limbUp);
    _drawJoint(canvas, knee, 5.2);
    _drawTube(canvas, knee, ankle, 11.5, _limbMid);
    _drawCuff(canvas, knee, ankle, 11.5);

    _drawBoot(canvas, ankle + Offset(isLeft ? -1.5 : 1.5, 1.5), footLift);
  }

  /// Front-facing rounded boot: blue dome upper + dark sole.
  void _drawBoot(Canvas canvas, Offset top, double footLift) {
    const bw = 23.0;
    const bh = 12.0;
    final rect = Rect.fromLTWH(top.dx - bw / 2, top.dy - 2, bw, bh);

    // contact shadow shrinks when the foot is lifted
    if (footLift < 1) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(top.dx, rect.bottom),
          width: bw + 4,
          height: 4,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.25),
      );
    }

    final upper = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(10),
      topRight: const Radius.circular(10),
      bottomLeft: const Radius.circular(4),
      bottomRight: const Radius.circular(4),
    );
    canvas.drawRRect(
      upper,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bodyTop, _bodyBg, _bodyBottom],
        ).createShader(rect),
    );

    // sole
    final sole = RRect.fromRectAndRadius(
      Rect.fromLTWH(rect.left - 0.5, rect.bottom - 3.5, bw + 1, 3.5),
      const Radius.circular(2),
    );
    canvas.drawRRect(sole, Paint()..color = const Color(0xFF161B22));
    canvas.drawLine(
      Offset(rect.left + 3, rect.bottom - 3.6),
      Offset(rect.right - 3, rect.bottom - 3.6),
      Paint()
        ..color = accentColor.withValues(alpha: 0.7)
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round,
    );

    // gloss
    canvas.drawOval(
      Rect.fromLTWH(rect.left + 4, rect.top + 1.5, bw * 0.45, 3.5),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
  }

  // ===== SKIN HELPERS =====

  double get _pulse {
    final t = (DateTime.now().millisecondsSinceEpoch % 2000) / 2000;
    return 0.5 + 0.5 * math.sin(t * math.pi * 2);
  }

  /// Rounded limb segment with metallic shading (shadow + specular strip).
  void _drawTube(Canvas canvas, Offset a, Offset b, double width, Color color) {
    final d = b - a;
    final len = d.distance;
    if (len == 0) return;
    var n = Offset(-d.dy / len, d.dx / len);
    if (n.dy > 0 || (n.dy == 0 && n.dx > 0)) n = -n; // point toward light

    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    final shadowOff = n * (-width * 0.22);
    canvas.drawLine(
      a + shadowOff,
      b + shadowOff,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..strokeWidth = width * 0.42
        ..strokeCap = StrokeCap.round,
    );
    final hiOff = n * (width * 0.24);
    canvas.drawLine(
      a + hiOff,
      b + hiOff,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.26)
        ..strokeWidth = width * 0.22
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Accent band near the end of a limb segment.
  void _drawCuff(Canvas canvas, Offset a, Offset b, double width) {
    final p1 = Offset.lerp(a, b, 0.70)!;
    final p2 = Offset.lerp(a, b, 0.82)!;
    canvas.drawLine(
      p1,
      p2,
      Paint()
        ..color = _joint
        ..strokeWidth = width + 1.2
        ..strokeCap = StrokeCap.butt,
    );
    canvas.drawLine(
      p1,
      p2,
      Paint()
        ..color = accentColor.withValues(alpha: 0.55)
        ..strokeWidth = width * 0.5
        ..strokeCap = StrokeCap.butt,
    );
  }

  void _drawHeadGloss(Canvas canvas, RRect headRRect) {
    final hr = headRRect.outerRect;
    canvas.save();
    canvas.clipRRect(headRRect);

    final gloss = Rect.fromLTWH(
      hr.left + hr.width * 0.08,
      hr.top + 2,
      hr.width * 0.84,
      hr.height * 0.42,
    );
    canvas.drawOval(
      gloss,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(gloss),
    );

    // accent rim light from below
    final rim = Rect.fromLTWH(
      hr.left,
      hr.bottom - hr.height * 0.28,
      hr.width,
      hr.height * 0.28,
    );
    canvas.drawRect(
      rim,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accentColor.withValues(alpha: 0.0),
            accentColor.withValues(alpha: 0.14),
          ],
        ).createShader(rim),
    );
    canvas.restore();
  }

  void _drawBodyShell(Canvas canvas, RRect bodyRect) {
    final r = bodyRect.outerRect;

    // base vertical gradient
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bodyTop, _bodyBg, _bodyBottom],
          stops: [0.0, 0.5, 1.0],
        ).createShader(r),
    );

    canvas.save();
    canvas.clipRRect(bodyRect);

    // side shading for volume
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.28),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.28),
          ],
          stops: const [0.0, 0.22, 0.78, 1.0],
        ).createShader(r),
    );

    // top gloss
    final glossRect = Rect.fromLTWH(
      r.left + r.width * 0.08,
      r.top + 2,
      r.width * 0.84,
      r.height * 0.34,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(glossRect, const Radius.circular(6)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(glossRect),
    );

    // panel seam (bevel)
    final seamY = r.top + r.height * 0.58;
    canvas.drawLine(
      Offset(r.left + 4, seamY),
      Offset(r.right - 4, seamY),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.30)
        ..strokeWidth = 1.0,
    );
    canvas.drawLine(
      Offset(r.left + 4, seamY + 1),
      Offset(r.right - 4, seamY + 1),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..strokeWidth = 0.8,
    );

    // corner rivets
    final rivet = Paint()..color = Colors.white.withValues(alpha: 0.22);
    for (final p in [
      Offset(r.left + 6, r.top + 6),
      Offset(r.right - 6, r.top + 6),
      Offset(r.left + 6, r.bottom - 6),
      Offset(r.right - 6, r.bottom - 6),
    ]) {
      canvas.drawCircle(p, 1.3, rivet);
    }
    canvas.restore();

    // belt with pulsing status LEDs (symmetric -> safe when flipped)
    final beltW = r.width * 0.58;
    final beltH = math.max(7.0, r.height * 0.13);
    final beltRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(r.center.dx, r.top + r.height * 0.76),
        width: beltW,
        height: beltH,
      ),
      Radius.circular(beltH / 2),
    );
    canvas.drawRRect(beltRect, Paint()..color = _visorBg);
    canvas.drawRRect(
      beltRect,
      Paint()
        ..color = accentColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    final pulse = _pulse;
    final ledR = beltH * 0.24;
    for (int i = -1; i <= 1; i++) {
      final c = Offset(r.center.dx + i * beltW * 0.26, beltRect.center.dy);
      final a = i == 0 ? 0.55 + 0.45 * pulse : 0.35 + 0.30 * (1 - pulse);
      canvas.drawCircle(
        c,
        ledR * 2.4,
        Paint()
          ..color = accentColor.withValues(alpha: a * 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(c, ledR, Paint()..color = accentColor.withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(covariant _RobotPainter old) {
    return old.accentColor != accentColor ||
        old.pose != pose ||
        old.eyeTrackX != eyeTrackX ||
        old.eyeTrackY != eyeTrackY ||
        old.antennaScale != antennaScale ||
        old.bodyBob != bodyBob ||
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

  final double bodyBob;

  const _BadgePainter({
    required this.accentColor,
    this.logoImage,
    this.bodyBob = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final l = _MascotLayout.of(size);
    canvas.translate(0, bodyBob);
    _drawSPCOnly(
      canvas: canvas,
      bodyX: l.bodyX,
      bodyY: l.bodyY,
      bodyW: l.bodyW,
      bodyH: l.bodyH,
    );
  }

  void _drawSPCOnly({
    required Canvas canvas,
    required double bodyX,
    required double bodyY,
    required double bodyW,
    required double bodyH,
  }) {
    // centered on the chest -> looks the same when the robot flips
    final center = Offset(bodyX + bodyW / 2, bodyY + bodyH * 0.36);
    final badgeW = bodyW * 0.62;
    final badgeH = badgeW / 2.28;

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
        oldDelegate.logoImage != logoImage ||
        oldDelegate.bodyBob != bodyBob;
  }
}
