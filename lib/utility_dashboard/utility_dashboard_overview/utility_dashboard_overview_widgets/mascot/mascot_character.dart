part of '../monitoring_mascot.dart';

Future<ui.Image> loadUiImage(String path) async {
  final data = await rootBundle.load(path);
  final bytes = data.buffer.asUint8List();

  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();

  return frame.image;
}

class MonitoringMascot extends StatefulWidget {
  final double size;
  final double facing; // 1 = right, -1 = left
  final double lean; // body tilt
  final double walkStrength;
  final bool isWalking;
  final double walkPhase; // 0..2pi
  final double groundY; // ground line inside the widget
  final ui.Image? misumiLogo;

  const MonitoringMascot({
    super.key,
    this.size = 260,
    this.facing = 1.0,
    this.lean = 0.0,
    this.walkStrength = 0.0,
    this.isWalking = false,
    this.walkPhase = 0.0,
    this.groundY = 0.0,
    this.misumiLogo,
  });

  @override
  State<MonitoringMascot> createState() => _MonitoringMascotState();
}

typedef _MascotFrame = ({_MascotPose pose, double bob, double eyeX, double eyeY});

class _MonitoringMascotState extends State<MonitoringMascot>
    with TickerProviderStateMixin {
  /// Length of the idle "life" loop. Every idle behaviour is scheduled
  /// inside this loop so it stays deterministic and seamless.
  static const double _loopSeconds = 40;

  // ── idle action schedule (seconds inside the loop) ──
  static const _glanceRight = (3.0, 4.6);
  static const _wave = (6.0, 8.6); // "hello" wave
  static const _curious = (13.0, 15.6); // head tilt + look up
  static const _dance = (20.0, 23.8); // step in place + sway
  static const _hops = [28.0, 29.0]; // two happy jumps, arms up
  static const _glanceLeft = (24.6, 26.0);
  static const _stretch = (34.0, 36.8); // both arms up, eyes squint

  static const List<double> _blinkTimes = [
    1.8, 5.2, 10.9, 11.22, 17.6, 26.8, 31.4, 38.3, //
  ];
  static const double _blinkDuration = 0.18;

  static const Color _accentColor = Color(0xFF3FB950);

  late final AnimationController _lifeCtrl;
  late final AnimationController _hoverCtrl;
  late final Listenable _animation;

  @override
  void initState() {
    super.initState();

    _lifeCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_loopSeconds * 1000).round()),
    )..repeat();

    _hoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _animation = Listenable.merge([_lifeCtrl, _hoverCtrl]);
  }

  @override
  void dispose() {
    _lifeCtrl.dispose();
    _hoverCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────── timing helpers ─────────────────────────

  static double _smooth(double x) {
    final c = x.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  /// 1 inside [span], 0 outside, eased in/out over [ramp] seconds.
  static double _window(double t, (double, double) span, double ramp) =>
      _smooth((t - span.$1) / ramp) * _smooth((span.$2 - t) / ramp);

  static double _blinkAmount(double t) {
    var v = 0.0;
    for (final t0 in _blinkTimes) {
      final x = (t - t0) / _blinkDuration;
      if (x > 0 && x < 1) v = math.max(v, math.sin(x * math.pi));
    }
    return v;
  }

  /// One jump starting at [t0]: crouch -> airborne -> landing squash.
  /// Returns (lift 0..1, crouch 0..1).
  static (double, double) _hopAt(double t, double t0) {
    final x = t - t0;
    if (x <= 0 || x >= 1.0) return (0.0, 0.0);
    final lift = (x > 0.22 && x < 0.62)
        ? math.sin((x - 0.22) / 0.40 * math.pi)
        : 0.0;
    final double crouch;
    if (x < 0.22) {
      crouch = math.sin(x / 0.22 * math.pi / 2);
    } else if (x < 0.30) {
      crouch = 1 - (x - 0.22) / 0.08;
    } else if (x < 0.62) {
      crouch = 0;
    } else {
      crouch = math.sin((x - 0.62) / 0.38 * math.pi) * 0.8;
    }
    return (lift, crouch);
  }

  // ───────────────────────── pose ─────────────────────────

  _MascotFrame _buildFrame() {
    final u = widget.size / 210;
    final t = _lifeCtrl.value * _loopSeconds;
    final ws = widget.isWalking ? widget.walkStrength.clamp(0.0, 1.0) : 0.0;
    final idle = 1.0 - ws;

    // ── idle: breathing ──
    final breath = math.sin(2 * math.pi * t / (_loopSeconds / 12));
    final armIdle = breath * 0.05;
    var bob = (0.5 + 0.5 * breath) * 1.0 * u;
    var hair = breath * 1.2 * u;
    var antenna = math.sin(2 * math.pi * t / (_loopSeconds / 10)) * 1.4 * u;
    var eyeX = 2.4 * u * (_window(t, _glanceRight, 0.25) - _window(t, _glanceLeft, 0.25));
    var eyeY = 0.0;

    var armL = armIdle, armR = -armIdle, fore = armIdle * 0.4;
    var liftL = 0.0, liftR = 0.0;
    var headTilt = 0.0, bodyTilt = 0.0;

    // ── wave (scheduled or on hover) ──
    final hover = Curves.easeOut.transform(_hoverCtrl.value);
    final waving = math.max(_window(t, _wave, 0.35), hover);
    final wiggle = math.sin(t * 2 * math.pi * 1.8) * 0.38 * waving;

    // ── curious head tilt ──
    final curious = _window(t, _curious, 0.35);
    headTilt += 0.15 * curious;
    eyeX += 1.6 * u * curious;
    eyeY -= 1.6 * u * curious;
    antenna += 3.0 * u * curious;

    // ── dance: step in place, sway, swing arms ──
    final dance = _window(t, _dance, 0.4);
    if (dance > 0) {
      final p = (t - _dance.$1) * 2 * math.pi * 1.25;
      final s = math.sin(p);
      liftL = math.max(0.0, s) * 4.5 * u * dance;
      liftR = math.max(0.0, -s) * 4.5 * u * dance;
      bodyTilt = s * 0.07 * dance;
      headTilt -= bodyTilt * 0.6;
      armL -= s * 0.30 * dance;
      armR -= s * 0.30 * dance;
      fore += s * 0.2 * dance;
      bob += math.cos(p).abs() * 2.0 * u * dance;
      hair += math.sin(p * 2) * 1.2 * u * dance;
      antenna += s * 3.0 * u * dance;
    }

    // ── two happy hops with arms up ──
    var hopLift = 0.0, crouch = 0.0;
    for (final t0 in _hops) {
      final (l, c) = _hopAt(t, t0);
      hopLift += l;
      crouch = math.max(crouch, c);
    }
    final cheer = _window(t, (_hops.first + 0.15, _hops.last + 0.95), 0.15) * 0.9;
    bob += crouch * 5.0 * u;
    hair += (crouch * 1.5 - hopLift * 2.5) * u;

    // ── stretch: both arms up, eyes squint ──
    final stretch = _window(t, _stretch, 0.7);

    final raiseR = math.max(math.max(waving, cheer), stretch);
    final raiseL = math.max(cheer, stretch);

    // ── walk layer (already scaled by walk strength) ──
    var armWalkL = 0.0, armWalkR = 0.0, foreWalk = 0.0;
    var legSwingL = 0.0, legSwingR = 0.0, footLiftL = 0.0, footLiftR = 0.0;
    var hairWalk = 0.0, antennaWalk = 0.0, bobWalk = 0.0;

    if (ws > 0) {
      final phase = widget.walkPhase;
      double liftWave(double p) => math.max(0.0, math.sin(p));

      final leftSwing = math.sin(phase);
      armWalkL = leftSwing * 0.16 * ws;
      armWalkR = -leftSwing * 0.16 * ws;
      foreWalk = math.sin(phase - 0.45) * 0.16 * ws;

      legSwingL = -leftSwing * 0.24 * ws;
      legSwingR = leftSwing * 0.24 * ws;
      footLiftL = liftWave(phase) * 7.0 * u * ws;
      footLiftR = liftWave(phase + math.pi) * 7.0 * u * ws;

      hairWalk = math.sin(phase * 2 - 0.4) * 1.6 * u * ws;
      // antenna trails behind the direction of travel and bounces per step
      antennaWalk = (-2.2 + math.sin(phase * 2 - 0.9) * 1.2) * u * ws;
      // dip when both feet touch the ground
      bobWalk = math.cos(phase).abs() * 3.0 * u * ws;
    }

    final blink = _blinkAmount(t);
    final squint = 1 - 0.7 * stretch * idle;

    final pose = _MascotPose(
      facing: widget.facing,
      lean: widget.lean,
      blinkScale: (1 - 0.92 * blink) * squint,
      armSwingLeft: armL * idle + armWalkL,
      armSwingRight: armR * idle + armWalkR,
      forearmSwing: fore * idle + foreWalk,
      legSwingLeft: legSwingL,
      legSwingRight: legSwingR,
      footLiftLeft: liftL * idle + footLiftL,
      footLiftRight: liftR * idle + footLiftR,
      hairOffset: hair * idle + hairWalk,
      antennaSway: antenna * idle + antennaWalk,
      walkStrength: ws,
      walkPhase: widget.walkPhase,
      isWalking: widget.isWalking,
      raiseLeft: raiseL * idle,
      raiseRight: raiseR * idle,
      waveWiggle: wiggle * idle,
      headTilt: headTilt * idle,
      bodyTilt: bodyTilt * idle,
      hop: hopLift * 14.0 * u * idle,
    );

    return (
      pose: pose,
      bob: bob * idle + bobWalk,
      // walking: look ahead
      eyeX: eyeX * idle + 1.8 * u * ws,
      eyeY: eyeY * idle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final robotWidth = widget.size * 0.7;

    return MouseRegion(
      onEnter: (_) => _hoverCtrl.forward(),
      onExit: (_) => _hoverCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (_, __) {
          final frame = _buildFrame();
          final pose = frame.pose;

          final groundBaseOffset = widget.groundY - (widget.size * 0.90);
          return SizedBox(
            width: robotWidth,
            height: widget.size,
            child: Transform.translate(
              // feet stay on the ground; only the upper body bobs
              offset: Offset(0, groundBaseOffset),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // main robot: flips with facing
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..rotateZ(widget.lean)
                      ..scaleByDouble(widget.facing, 1.0, 1.0, 1.0),
                    child: SizedBox(
                      width: robotWidth,
                      height: widget.size,
                      child: CustomPaint(
                        painter: _RobotPainter(
                          accentColor: _accentColor,
                          pose: pose,
                          eyeTrackX: frame.eyeX,
                          eyeTrackY: frame.eyeY,
                          antennaScale: 1,
                          bodyBob: frame.bob,
                        ),
                        willChange: true,
                      ),
                    ),
                  ),
                  // logo badge: follows the body but never mirrors
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Transform.rotate(
                        angle: widget.lean,
                        child: CustomPaint(
                          painter: _BadgePainter(
                            accentColor: _accentColor,
                            logoImage: widget.misumiLogo,
                            bodyBob: frame.bob - pose.hop,
                            // mirrored space flips the rotation direction
                            bodyTilt: pose.bodyTilt * widget.facing,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
