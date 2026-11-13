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
  final double kneeBendLeft;
  final double kneeBendRight;
  final double footLiftLeft;
  final double footLiftRight;
  final double hairOffset;
  final double walkStrength;
  final double walkPhase;
  final bool isWalking;

  const _MascotPose({
    required this.facing,
    required this.lean,
    required this.blinkScale,
    required this.armSwingLeft,
    required this.armSwingRight,
    required this.forearmSwing,
    required this.legSwingLeft,
    required this.legSwingRight,
    required this.kneeBendLeft,
    required this.kneeBendRight,
    required this.footLiftLeft,
    required this.footLiftRight,
    required this.hairOffset,
    required this.walkStrength,
    required this.walkPhase,
    required this.isWalking,
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
          kneeBendLeft == other.kneeBendLeft &&
          kneeBendRight == other.kneeBendRight &&
          footLiftLeft == other.footLiftLeft &&
          footLiftRight == other.footLiftRight &&
          hairOffset == other.hairOffset &&
          walkStrength == other.walkStrength &&
          walkPhase == other.walkPhase &&
          isWalking == other.isWalking;

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
    kneeBendLeft,
    kneeBendRight,
    footLiftLeft,
    footLiftRight,
    hairOffset,
    walkStrength,
    walkPhase,
    isWalking,
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

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// MonitoringMascot

/// Shared proportions for the robot and its badge overlay.
/// Chibi-style: head ~1.3x body width, ground line at 90% of height.
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
    final headW = w * 0.58;
    final headH = h * 0.215;
    final headY = h * 0.165;
    final bodyW = w * 0.48;
    final bodyH = h * 0.245;
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
}
