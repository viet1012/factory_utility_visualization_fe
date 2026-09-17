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
