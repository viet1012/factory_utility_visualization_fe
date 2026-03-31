import 'dart:math' as math;

import 'package:flutter/material.dart';

class MovingMascot extends StatefulWidget {
  final int alarmCount;
  final double size;
  final Alignment targetAlignment;
  final Alignment idleAlignment;

  const MovingMascot({
    super.key,
    required this.alarmCount,
    required this.size,
    required this.targetAlignment,
    this.idleAlignment = const Alignment(-0.60, 0.80),
  });

  @override
  State<MovingMascot> createState() => _MovingMascotState();
}

class _MovingMascotState extends State<MovingMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _moveCtrl;

  Alignment _current = const Alignment(-0.60, 0.80);
  Alignment _from = const Alignment(-0.60, 0.80);
  Alignment _to = const Alignment(-0.60, 0.80);

  @override
  void initState() {
    super.initState();

    _moveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _current = widget.alarmCount > 0
        ? widget.targetAlignment
        : widget.idleAlignment;
    _from = _current;
    _to = _current;
  }

  @override
  void didUpdateWidget(covariant MovingMascot oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextTarget = widget.alarmCount > 0
        ? widget.targetAlignment
        : widget.idleAlignment;

    if (oldWidget.targetAlignment != widget.targetAlignment ||
        oldWidget.alarmCount != widget.alarmCount) {
      _from = _current;
      _to = nextTarget;
      _moveCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _moveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _moveCtrl,
      builder: (_, __) {
        final t = Curves.easeInOutCubic.transform(_moveCtrl.value);

        // Quadratic-like curve
        final mid = Alignment(
          (_from.x + _to.x) / 2,
          ((_from.y + _to.y) / 2) - 0.06,
        );
        final a = Alignment.lerp(_from, mid, t)!;
        final b = Alignment.lerp(mid, _to, t)!;
        final alignment = Alignment.lerp(a, b, t)!;
        _current = alignment;

        final dx = _to.x - _from.x;
        final dy = _to.y - _from.y;
        final distance = math.sqrt(dx * dx + dy * dy);

        final isWalking = _moveCtrl.isAnimating && distance > 0.001;
        final facing = dx >= 0 ? 1.0 : -1.0;
        final walkStrength = isWalking ? (distance * 1.9).clamp(0.0, 1.0) : 0.0;

        // lean strongest in the middle of the move, settles near the end
        final leanEnvelope = math.sin(t * math.pi);
        final lean = dx.clamp(-1.0, 1.0) * 0.10 * leanEnvelope;

        return Align(
          alignment: alignment,
          child: MonitoringMascot(
            alarmCount: widget.alarmCount,
            size: widget.size,
            facing: facing,
            lean: lean,
            walkStrength: walkStrength,
            isWalking: isWalking,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MonitoringMascot
// ─────────────────────────────────────────────────────────────────────────────

class MonitoringMascot extends StatefulWidget {
  final int alarmCount;
  final double size;
  final double facing; // 1 = right, -1 = left
  final double lean; // body tilt
  final double walkStrength;
  final bool isWalking;

  const MonitoringMascot({
    super.key,
    required this.alarmCount,
    this.size = 260,
    this.facing = 1.0,
    this.lean = 0.0,
    this.walkStrength = 0.0,
    this.isWalking = false,
  });

  @override
  State<MonitoringMascot> createState() => _MonitoringMascotState();
}

class _MonitoringMascotState extends State<MonitoringMascot>
    with TickerProviderStateMixin {
  late final AnimationController _idleCtrl;
  late final AnimationController _alarmCtrl;
  late final AnimationController _blinkCtrl;

  late final Animation<double> _floatY;
  late final Animation<double> _idleArmSwing;
  late final Animation<double> _idleLegSwing;
  late final Animation<double> _hairBounce;

  late final Animation<double> _shakeX;
  late final Animation<double> _antennaPulse;
  late final Animation<double> _eyeTrackX;
  late final Animation<double> _eyeTrackY;
  late final Animation<double> _angryBrow;
  late final Animation<double> _alarmArmSwing;
  late final Animation<double> _forearmLag;
  late final Animation<double> _alarmLegSwing;
  late final Animation<double> _alarmHairShake;

  late final Animation<double> _blinkScale;

  bool get _isAlarm => widget.alarmCount > 0;

  Color get _accentColor =>
      _isAlarm ? const Color(0xFFF85149) : const Color(0xFF3FB950);

  @override
  void initState() {
    super.initState();

    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _alarmCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _floatY = Tween<double>(
      begin: -5,
      end: 5,
    ).animate(CurvedAnimation(parent: _idleCtrl, curve: Curves.easeInOut));

    _idleArmSwing = Tween<double>(
      begin: -0.10,
      end: 0.10,
    ).animate(CurvedAnimation(parent: _idleCtrl, curve: Curves.easeInOut));

    _idleLegSwing = Tween<double>(
      begin: -0.07,
      end: 0.07,
    ).animate(CurvedAnimation(parent: _idleCtrl, curve: Curves.easeInOut));

    _hairBounce = Tween<double>(
      begin: -2.5,
      end: 2.5,
    ).animate(CurvedAnimation(parent: _idleCtrl, curve: Curves.easeInOut));

    _shakeX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -3.5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -3.5, end: 3.5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 3.5, end: -2.5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -2.5, end: 2.5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 2.5, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _alarmCtrl, curve: Curves.easeInOut));

    _antennaPulse = Tween<double>(
      begin: 1.0,
      end: 1.30,
    ).animate(CurvedAnimation(parent: _alarmCtrl, curve: Curves.easeInOut));

    _eyeTrackX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -2.5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -2.5, end: 2.5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 2.5, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _alarmCtrl, curve: Curves.linear));

    _eyeTrackY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -1.2), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -1.2, end: 1.2), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _alarmCtrl, curve: Curves.linear));

    _angryBrow = Tween<double>(
      begin: 0.0,
      end: 0.14,
    ).animate(CurvedAnimation(parent: _alarmCtrl, curve: Curves.easeInOut));

    _alarmArmSwing = Tween<double>(
      begin: -0.20,
      end: 0.20,
    ).animate(CurvedAnimation(parent: _alarmCtrl, curve: Curves.easeInOut));

    _forearmLag = Tween<double>(begin: -0.12, end: 0.12).animate(
      CurvedAnimation(
        parent: _alarmCtrl,
        curve: const Interval(0.25, 1.0, curve: Curves.easeInOut),
      ),
    );

    _alarmLegSwing = Tween<double>(
      begin: -0.09,
      end: 0.09,
    ).animate(CurvedAnimation(parent: _alarmCtrl, curve: Curves.easeInOut));

    _alarmHairShake = Tween<double>(begin: -1.2, end: 1.2).animate(
      CurvedAnimation(
        parent: _alarmCtrl,
        curve: const Interval(0.15, 1.0, curve: Curves.easeInOut),
      ),
    );

    _blinkScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 85),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.06), weight: 6),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: 1.0), weight: 9),
    ]).animate(CurvedAnimation(parent: _blinkCtrl, curve: Curves.easeInOut));

    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant MonitoringMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alarmCount != widget.alarmCount) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (!_blinkCtrl.isAnimating) _blinkCtrl.repeat();

    if (_isAlarm) {
      _idleCtrl.stop();
      _idleCtrl.reset();
      if (!_alarmCtrl.isAnimating) {
        _alarmCtrl.repeat(reverse: true);
      }
    } else {
      _alarmCtrl.stop();
      _alarmCtrl.reset();
      if (!_idleCtrl.isAnimating) {
        _idleCtrl.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _idleCtrl.dispose();
    _alarmCtrl.dispose();
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final merged = Listenable.merge([_idleCtrl, _alarmCtrl, _blinkCtrl]);
    final robotWidth = widget.size * 0.65;

    return AnimatedBuilder(
      animation: merged,
      builder: (_, __) {
        final internalDx = _isAlarm ? _shakeX.value : 0.0;

        final walkBob = widget.isWalking ? (_hairBounce.value * 0.35) : 0.0;
        final internalDy = _isAlarm ? 0.0 : (_floatY.value + walkBob);

        final double armSwingL;
        final double armSwingR;
        final double foreSwing;
        final double hairOffset;

        if (_isAlarm) {
          armSwingL = _alarmArmSwing.value;
          armSwingR = -_alarmArmSwing.value;
          foreSwing = _forearmLag.value;
          hairOffset = _alarmHairShake.value;
        } else if (widget.isWalking) {
          final walkAmp = 0.22 * widget.walkStrength;
          armSwingL = _idleArmSwing.value * (walkAmp / 0.10);
          armSwingR = -_idleArmSwing.value * (walkAmp / 0.10);
          foreSwing = _idleArmSwing.value * 0.7;
          hairOffset = _hairBounce.value * 0.6;
        } else {
          armSwingL = _idleArmSwing.value;
          armSwingR = -_idleArmSwing.value;
          foreSwing = _idleArmSwing.value * 0.4;
          hairOffset = _hairBounce.value;
        }

        final double legSwingL;
        final double legSwingR;
        if (_isAlarm) {
          legSwingL = _alarmLegSwing.value;
          legSwingR = -_alarmLegSwing.value;
        } else if (widget.isWalking) {
          final walkLegAmp = 0.16 * widget.walkStrength;
          legSwingL = _idleLegSwing.value * (walkLegAmp / 0.07);
          legSwingR = -_idleLegSwing.value * (walkLegAmp / 0.07);
        } else {
          legSwingL = _idleLegSwing.value;
          legSwingR = -_idleLegSwing.value;
        }

        return SizedBox(
          width: robotWidth,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Transform.translate(
                offset: Offset(internalDx, internalDy),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..rotateZ(widget.lean)
                    ..scale(widget.facing, 1.0),
                  child: SizedBox(
                    width: robotWidth,
                    height: widget.size,
                    child: CustomPaint(
                      painter: _RobotPainter(
                        accentColor: _accentColor,
                        isAlarm: _isAlarm,
                        alarmCount: widget.alarmCount,
                        blinkScale: _blinkScale.value,
                        eyeTrackX: _isAlarm ? _eyeTrackX.value : 0,
                        eyeTrackY: _isAlarm ? _eyeTrackY.value : 0,
                        antennaScale: _isAlarm ? _antennaPulse.value : 1.0,
                        angryBrow: _isAlarm ? _angryBrow.value : 0.0,
                        armSwingL: armSwingL,
                        armSwingR: armSwingR,
                        foreSwing: foreSwing,
                        legSwingL: legSwingL,
                        legSwingR: legSwingR,
                        hairOffset: hairOffset,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 1,
                right: -8,
                child: _StatusBadge(
                  count: widget.alarmCount,
                  isAlarm: _isAlarm,
                  accentColor: _accentColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusBadge
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final int count;
  final bool isAlarm;
  final Color accentColor;

  const _StatusBadge({
    required this.count,
    required this.isAlarm,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final label = isAlarm ? (count > 1 ? 'ALARM $count' : 'ALARM') : 'OK';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentColor.withOpacity(0.9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.25),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RobotPainter
// ─────────────────────────────────────────────────────────────────────────────

class _RobotPainter extends CustomPainter {
  final Color accentColor;
  final bool isAlarm;
  final int alarmCount;
  final double blinkScale;
  final double eyeTrackX;
  final double eyeTrackY;
  final double antennaScale;
  final double angryBrow;
  final double armSwingL;
  final double armSwingR;
  final double foreSwing;
  final double legSwingL;
  final double legSwingR;
  final double hairOffset;

  static const _headBg = Color(0xFF161B22);
  static const _bodyBg = Color(0xFF161B22);
  static const _neckBg = Color(0xFF21262D);
  static const _headRim = Color(0xFF30363D);
  static const _visorBg = Color(0xFF0D1117);
  static const _limbUp = Color(0xFFC9D1D9);
  static const _limbMid = Color(0xFF8B949E);
  static const _limbLow = Color(0xFF6E7681);
  static const _joint = Color(0xFF484F58);
  static const _jointRim = Color(0xFF6E7681);
  static const _footBg = Color(0xFF30363D);
  static const _footRim = Color(0xFF484F58);
  static const _cheek = Color(0xFFF97583);
  static const _white = Color(0xFFE6EDF3);

  static const _hairBase = Color(0xFFB0BEC5);
  static const _hairMid = Color(0xFFCFD8DC);
  static const _hairLight = Color(0xFFECEFF1);
  static const _hairDark = Color(0xFF78909C);
  static const _hairShine = Color(0xFFFFFFFF);

  _RobotPainter({
    required this.accentColor,
    required this.isAlarm,
    required this.alarmCount,
    required this.blinkScale,
    required this.eyeTrackX,
    required this.eyeTrackY,
    required this.antennaScale,
    required this.angryBrow,
    required this.armSwingL,
    required this.armSwingR,
    required this.foreSwing,
    required this.legSwingL,
    required this.legSwingR,
    required this.hairOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final headW = w * 0.72;
    final headH = h * 0.22;
    final bodyW = w * 0.60;
    final bodyH = h * 0.20;
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

    _drawLeg(
      canvas: canvas,
      hip: Offset(bodyX + bodyW * 0.33, bodyY + bodyH - 1),
      swing: legSwingL,
      isLeft: true,
    );
    _drawLeg(
      canvas: canvas,
      hip: Offset(bodyX + bodyW * 0.67, bodyY + bodyH - 1),
      swing: legSwingR,
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
      const Radius.circular(16),
    );
    canvas.drawRRect(
      bodyRect.inflate(4),
      Paint()..color = accentColor.withOpacity(0.08),
    );
    canvas.drawRRect(bodyRect, Paint()..color = _bodyBg);
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = accentColor.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bodyX + 3, bodyY + 3, bodyW - 6, bodyH - 6),
        const Radius.circular(13),
      ),
      Paint()
        ..color = Colors.white.withOpacity(0.03)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    _glowCircle(canvas, Offset(cx, bodyY + bodyH * 0.38), 5, accentColor);
    canvas.drawCircle(
      Offset(cx, bodyY + bodyH * 0.38),
      9,
      Paint()
        ..color = accentColor.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
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
      headRRect.inflate(4),
      Paint()..color = accentColor.withOpacity(0.08),
    );
    canvas.drawRRect(headRRect, Paint()..color = _headBg);
    canvas.drawRRect(
      headRRect,
      Paint()
        ..color = accentColor.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(headX + 3, headY + 3, headW - 6, headH - 6),
        const Radius.circular(19),
      ),
      Paint()
        ..color = Colors.white.withOpacity(0.04)
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
        ..color = accentColor.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(visorX + 2, visorY + 2, visorW - 4, 5),
        const Radius.circular(3),
      ),
      Paint()..color = accentColor.withOpacity(0.65),
    );

    final eyeY = headY + headH * 0.57;
    final leftEyeX = headX + headW * 0.32;
    final rightEyeX = headX + headW * 0.68;
    _drawEye(canvas, Offset(leftEyeX, eyeY));
    _drawEye(canvas, Offset(rightEyeX, eyeY));

    if (!isAlarm) {
      final cheekPaint = Paint()..color = _cheek.withOpacity(0.22);
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
    }

    if (isAlarm) {
      final browPaint = Paint()
        ..color = _white
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      canvas.save();
      canvas.translate(leftEyeX, eyeY - 12);
      canvas.rotate(-0.28 - angryBrow);
      canvas.drawLine(const Offset(-11, 0), const Offset(11, 0), browPaint);
      canvas.restore();
      canvas.save();
      canvas.translate(rightEyeX, eyeY - 12);
      canvas.rotate(0.28 + angryBrow);
      canvas.drawLine(const Offset(-11, 0), const Offset(11, 0), browPaint);
      canvas.restore();
    }

    _drawMouth(canvas: canvas, center: Offset(cx, headY + headH * 0.80));

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

    final puffPaint = Paint()..color = _hairDark;

    canvas.save();
    canvas.translate(headX + 13, headY + headH * 0.28 + dy);
    canvas.save();
    canvas.scale(1, 1.4);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 30, height: 22),
      puffPaint,
    );
    canvas.restore();
    canvas.restore();

    canvas.save();
    canvas.translate(headX + headW - 13, headY + headH * 0.28 + dy);
    canvas.save();
    canvas.scale(1, 1.4);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 30, height: 22),
      puffPaint,
    );
    canvas.restore();
    canvas.restore();

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headX + headW / 2, headY - 4 + dy),
        width: 54,
        height: 34,
      ),
      puffPaint,
    );

    final midPaint = Paint()
      ..color = _hairMid
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final topArcs = [
      _CurlSpec(
        cx: headX + headW * 0.28,
        cy: headY + 2 + dy,
        rx: 10,
        ry: 9,
        startAngle: -math.pi * 0.9,
        sweep: math.pi * 1.6,
        thickness: 5.0,
      ),
      _CurlSpec(
        cx: headX + headW * 0.50,
        cy: headY - 5 + dy,
        rx: 12,
        ry: 10,
        startAngle: -math.pi * 0.8,
        sweep: math.pi * 1.5,
        thickness: 5.5,
      ),
      _CurlSpec(
        cx: headX + headW * 0.72,
        cy: headY + 2 + dy,
        rx: 10,
        ry: 9,
        startAngle: -math.pi * 0.9,
        sweep: math.pi * 1.6,
        thickness: 5.0,
      ),
    ];
    for (final c in topArcs) {
      _drawCurlArc(canvas, c, midPaint);
    }

    final leftArcs = [
      _CurlSpec(
        cx: headX + 8,
        cy: headY + headH * 0.15 + dy,
        rx: 8,
        ry: 11,
        startAngle: -math.pi * 0.5,
        sweep: math.pi * 1.4,
        thickness: 4.5,
      ),
      _CurlSpec(
        cx: headX + 6,
        cy: headY + headH * 0.42 + dy,
        rx: 7,
        ry: 10,
        startAngle: -math.pi * 0.4,
        sweep: math.pi * 1.3,
        thickness: 4.0,
      ),
      _CurlSpec(
        cx: headX + 8,
        cy: headY + headH * 0.65 + dy,
        rx: 7,
        ry: 8,
        startAngle: -math.pi * 0.3,
        sweep: math.pi * 1.2,
        thickness: 3.5,
      ),
    ];
    for (final c in leftArcs) {
      _drawCurlArc(canvas, c, midPaint);
    }

    final rightArcs = [
      _CurlSpec(
        cx: headX + headW - 8,
        cy: headY + headH * 0.15 + dy,
        rx: 8,
        ry: 11,
        startAngle: -math.pi * 0.5,
        sweep: -math.pi * 1.4,
        thickness: 4.5,
      ),
      _CurlSpec(
        cx: headX + headW - 6,
        cy: headY + headH * 0.42 + dy,
        rx: 7,
        ry: 10,
        startAngle: -math.pi * 0.4,
        sweep: -math.pi * 1.3,
        thickness: 4.0,
      ),
      _CurlSpec(
        cx: headX + headW - 8,
        cy: headY + headH * 0.65 + dy,
        rx: 7,
        ry: 8,
        startAngle: -math.pi * 0.3,
        sweep: -math.pi * 1.2,
        thickness: 3.5,
      ),
    ];
    for (final c in rightArcs) {
      _drawCurlArc(canvas, c, midPaint);
    }

    final coilPaint = Paint()
      ..color = _hairBase
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final coils = [
      _CoilSpec(
        cx: headX + headW * 0.22,
        cy: headY - 1 + dy,
        rx: 5,
        ry: 6,
        loops: 1.4,
        thickness: 3.2,
      ),
      _CoilSpec(
        cx: headX + headW * 0.36,
        cy: headY - 5 + dy,
        rx: 5,
        ry: 7,
        loops: 1.5,
        thickness: 3.4,
      ),
      _CoilSpec(
        cx: headX + headW * 0.50,
        cy: headY - 9 + dy,
        rx: 6,
        ry: 8,
        loops: 1.6,
        thickness: 3.8,
      ),
      _CoilSpec(
        cx: headX + headW * 0.64,
        cy: headY - 5 + dy,
        rx: 5,
        ry: 7,
        loops: 1.5,
        thickness: 3.4,
      ),
      _CoilSpec(
        cx: headX + headW * 0.78,
        cy: headY - 1 + dy,
        rx: 5,
        ry: 6,
        loops: 1.4,
        thickness: 3.2,
      ),
      _CoilSpec(
        cx: headX + 2,
        cy: headY + headH * 0.52 + dy,
        rx: 4,
        ry: 6,
        loops: 1.2,
        thickness: 2.8,
      ),
      _CoilSpec(
        cx: headX + headW - 2,
        cy: headY + headH * 0.52 + dy,
        rx: 4,
        ry: 6,
        loops: 1.2,
        thickness: 2.8,
      ),
    ];
    for (final c in coils) {
      _drawSpringCoil(canvas, c, coilPaint);
    }

    final shinePaint = Paint()..color = _hairShine.withOpacity(0.55);
    final shines = [
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
    for (final s in shines) {
      canvas.save();
      canvas.translate(s.cx, s.cy);
      canvas.rotate(s.angle);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s.rx * 2, height: s.ry * 2),
        shinePaint,
      );
      canvas.restore();
    }
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
        ..color = accentColor.withOpacity(0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    canvas.save();
    canvas.translate(center.dx + eyeTrackX, center.dy + eyeTrackY);
    canvas.scale(1.0, blinkScale);
    canvas.drawCircle(
      Offset.zero,
      9,
      Paint()..color = accentColor.withOpacity(0.08),
    );
    canvas.drawCircle(
      Offset.zero,
      6.5,
      Paint()..color = accentColor.withOpacity(0.16),
    );
    canvas.drawCircle(Offset.zero, 4.2, Paint()..color = accentColor);
    canvas.drawCircle(
      const Offset(-1.3, -1.3),
      1.4,
      Paint()..color = Colors.white.withOpacity(0.88),
    );
    canvas.restore();
  }

  void _drawMouth({required Canvas canvas, required Offset center}) {
    final path = Path();
    if (isAlarm) {
      path.moveTo(center.dx - 13, center.dy + 4);
      path.quadraticBezierTo(
        center.dx,
        center.dy - 6,
        center.dx + 13,
        center.dy + 4,
      );
    } else {
      path.moveTo(center.dx - 13, center.dy - 1);
      path.quadraticBezierTo(
        center.dx,
        center.dy + 9,
        center.dx + 13,
        center.dy - 1,
      );
    }
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
    final foreAngle = upperAngle + (isLeft ? 0.52 : -0.52) + foreSwing;

    final elbow = Offset(
      shoulder.dx + math.cos(upperAngle) * upperLen,
      shoulder.dy + math.sin(upperAngle) * upperLen,
    );
    final wrist = Offset(
      elbow.dx + math.cos(foreAngle) * foreLen,
      elbow.dy + math.sin(foreAngle) * foreLen,
    );

    canvas.drawCircle(shoulder, 5, Paint()..color = _joint);
    canvas.drawCircle(
      shoulder,
      5,
      Paint()
        ..color = _jointRim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    canvas.drawLine(
      shoulder,
      elbow,
      Paint()
        ..color = _limbUp
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(elbow, 7, Paint()..color = accentColor.withOpacity(0.08));
    canvas.drawCircle(elbow, 5, Paint()..color = _joint);
    canvas.drawCircle(
      elbow,
      5,
      Paint()
        ..color = _jointRim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    canvas.drawLine(
      elbow,
      wrist,
      Paint()
        ..color = _limbMid
        ..strokeWidth = 7.5
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(wrist, 3.5, Paint()..color = _limbLow);
    final handRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(wrist.dx, wrist.dy + 2),
        width: 11,
        height: 6,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(handRect, Paint()..color = _limbLow);
    canvas.drawRRect(
      handRect,
      Paint()
        ..color = _joint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6,
    );
  }

  void _drawLeg({
    required Canvas canvas,
    required Offset hip,
    required double swing,
    required bool isLeft,
  }) {
    const thighLen = 32.0;
    const shinLen = 26.0;
    final thighAngle = 1.57 + swing;
    final shinAngle = thighAngle + (isLeft ? 0.06 : -0.06);

    final knee = Offset(
      hip.dx + math.cos(thighAngle) * thighLen,
      hip.dy + math.sin(thighAngle) * thighLen,
    );
    final ankle = Offset(
      knee.dx + math.cos(shinAngle) * shinLen,
      knee.dy + math.sin(shinAngle) * shinLen,
    );

    canvas.drawCircle(hip, 5, Paint()..color = _joint);
    canvas.drawLine(
      hip,
      knee,
      Paint()
        ..color = _limbUp
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(knee, 7, Paint()..color = accentColor.withOpacity(0.08));
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
    final footCenter = Offset(ankle.dx + footOffX, ankle.dy + 5);
    final footRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: footCenter, width: 26, height: 10),
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

    final toeX = ankle.dx + footOffX + (isLeft ? -7.0 : 7.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(toeX, ankle.dy + 5),
          width: 9,
          height: 8,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = _footRim,
    );
  }

  void _glowCircle(Canvas canvas, Offset center, double r, Color color) {
    canvas.drawCircle(center, r + 7, Paint()..color = color.withOpacity(0.10));
    canvas.drawCircle(
      center,
      r + 3.5,
      Paint()..color = color.withOpacity(0.20),
    );
    canvas.drawCircle(center, r, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RobotPainter old) {
    return old.accentColor != accentColor ||
        old.isAlarm != isAlarm ||
        old.alarmCount != alarmCount ||
        old.blinkScale != blinkScale ||
        old.eyeTrackX != eyeTrackX ||
        old.eyeTrackY != eyeTrackY ||
        old.antennaScale != antennaScale ||
        old.angryBrow != angryBrow ||
        old.armSwingL != armSwingL ||
        old.armSwingR != armSwingR ||
        old.foreSwing != foreSwing ||
        old.legSwingL != legSwingL ||
        old.legSwingR != legSwingR ||
        old.hairOffset != hairOffset;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hair helpers
// ─────────────────────────────────────────────────────────────────────────────

class _CurlSpec {
  final double cx, cy, rx, ry, startAngle, sweep, thickness;

  const _CurlSpec({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.startAngle,
    required this.sweep,
    required this.thickness,
  });
}

class _CoilSpec {
  final double cx, cy, rx, ry, loops, thickness;

  const _CoilSpec({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.loops,
    required this.thickness,
  });
}

class _ShineSpec {
  final double cx, cy, rx, ry, angle;

  const _ShineSpec({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.angle,
  });
}
