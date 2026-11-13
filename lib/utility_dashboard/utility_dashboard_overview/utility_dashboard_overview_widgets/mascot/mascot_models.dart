part of '../monitoring_mascot.dart';

@immutable
class _MascotPose {
  final double facing;
  final double lean;
  final double blinkScale;
  final double armSwingLeft;
  final double armSwingRight;
  final double forearmSwing;
  final double legSwingLeft;
  final double legSwingRight;
  final double footLiftLeft;
  final double footLiftRight;
  final double hairOffset;
  final double antennaSway;
  final double walkStrength;
  final double walkPhase;
  final bool isWalking;

  /// 0..1 blend of each arm into a raised (overhead) pose.
  final double raiseLeft;
  final double raiseRight;

  /// Forearm wiggle (radians) on the raised right arm: the "hello" wave.
  final double waveWiggle;

  /// Head rotation around the neck (radians, + = clockwise).
  final double headTilt;

  /// Upper-body rotation around the hips (radians), used for dance sway.
  final double bodyTilt;

  /// Whole-body lift off the ground in px (jump); shadow stays down.
  final double hop;

  const _MascotPose({
    required this.facing,
    required this.lean,
    required this.blinkScale,
    required this.armSwingLeft,
    required this.armSwingRight,
    required this.forearmSwing,
    required this.legSwingLeft,
    required this.legSwingRight,
    required this.footLiftLeft,
    required this.footLiftRight,
    required this.hairOffset,
    required this.antennaSway,
    required this.walkStrength,
    required this.walkPhase,
    required this.isWalking,
    this.raiseLeft = 0,
    this.raiseRight = 0,
    this.waveWiggle = 0,
    this.headTilt = 0,
    this.bodyTilt = 0,
    this.hop = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MascotPose &&
          facing == other.facing &&
          lean == other.lean &&
          blinkScale == other.blinkScale &&
          armSwingLeft == other.armSwingLeft &&
          armSwingRight == other.armSwingRight &&
          forearmSwing == other.forearmSwing &&
          legSwingLeft == other.legSwingLeft &&
          legSwingRight == other.legSwingRight &&
          footLiftLeft == other.footLiftLeft &&
          footLiftRight == other.footLiftRight &&
          hairOffset == other.hairOffset &&
          antennaSway == other.antennaSway &&
          walkStrength == other.walkStrength &&
          walkPhase == other.walkPhase &&
          isWalking == other.isWalking &&
          raiseLeft == other.raiseLeft &&
          raiseRight == other.raiseRight &&
          waveWiggle == other.waveWiggle &&
          headTilt == other.headTilt &&
          bodyTilt == other.bodyTilt &&
          hop == other.hop;

  @override
  int get hashCode => Object.hashAll([
    facing,
    lean,
    blinkScale,
    armSwingLeft,
    armSwingRight,
    forearmSwing,
    legSwingLeft,
    legSwingRight,
    footLiftLeft,
    footLiftRight,
    hairOffset,
    antennaSway,
    walkStrength,
    walkPhase,
    isWalking,
    raiseLeft,
    raiseRight,
    waveWiggle,
    headTilt,
    bodyTilt,
    hop,
  ]);
}

class _MascotMoveFrame {
  final Alignment alignment;
  final double facing;
  final double lean;
  final double walkStrength;
  final bool isWalking;
  final double walkPhase;

  const _MascotMoveFrame({
    required this.alignment,
    required this.facing,
    required this.lean,
    required this.walkStrength,
    required this.isWalking,
    required this.walkPhase,
  });
}

/// Shared proportions for the robot and its badge overlay.
/// Chibi-style: head wider than the body, compact legs,
/// ground line at 90% of height.
class _MascotLayout {
  final double w, h;
  final double headW, headH, headX, headY;
  final double bodyW, bodyH, bodyX, bodyY;
  final double cx, groundY;

  const _MascotLayout._({
    required this.w,
    required this.h,
    required this.headW,
    required this.headH,
    required this.headX,
    required this.headY,
    required this.bodyW,
    required this.bodyH,
    required this.bodyX,
    required this.bodyY,
    required this.cx,
    required this.groundY,
  });

  factory _MascotLayout.of(Size size) {
    final w = size.width;
    final h = size.height;
    // vs. the previous layout: head a bit taller (less flat), body a bit
    // wider, everything shifted down so the legs are shorter / sturdier
    final headW = w * 0.60;
    final headH = h * 0.235;
    final headY = h * 0.185;
    final bodyW = w * 0.50;
    final bodyH = h * 0.23;
    final bodyY = headY + headH + h * 0.02;
    return _MascotLayout._(
      w: w,
      h: h,
      headW: headW,
      headH: headH,
      headX: (w - headW) / 2,
      headY: headY,
      bodyW: bodyW,
      bodyH: bodyH,
      bodyX: (w - bodyW) / 2,
      bodyY: bodyY,
      cx: w / 2,
      groundY: h * 0.90,
    );
  }

  /// Pivot for upper-body sway (center of the hips).
  Offset get hipPivot => Offset(cx, bodyY + bodyH);

  /// Pivot for head tilt (top of the neck).
  Offset get neckPivot => Offset(cx, headY + headH);
}
