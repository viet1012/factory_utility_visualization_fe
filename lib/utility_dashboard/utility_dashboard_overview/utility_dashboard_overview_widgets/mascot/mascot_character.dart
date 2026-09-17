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
  final double groundY; // vá»‹ trÃ­ máº·t Ä‘áº¥t trong widget
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

class _MonitoringMascotState extends State<MonitoringMascot>
    with TickerProviderStateMixin {
  late final AnimationController _idleCtrl;
  late final AnimationController _blinkCtrl;
  late final Listenable _animation;

  late final Animation<double> _floatY;
  late final Animation<double> _idleArmSwing;
  late final Animation<double> _idleLegSwing;
  late final Animation<double> _hairBounce;

  late final Animation<double> _blinkScale;

  static const Color _accentColor = Color(0xFF3FB950);

  @override
  void initState() {
    super.initState();

    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
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

    _blinkScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 85),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.06), weight: 6),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: 1.0), weight: 9),
    ]).animate(CurvedAnimation(parent: _blinkCtrl, curve: Curves.easeInOut));

    _animation = Listenable.merge([_idleCtrl, _blinkCtrl]);

    _blinkCtrl.repeat();
    _idleCtrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _idleCtrl.dispose();
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final robotWidth = widget.size * 0.7;

    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        final walkCos = math.cos(widget.walkPhase);

        final walkBob = widget.isWalking
            ? (-walkCos.abs() * 6.0 * widget.walkStrength)
            : 0.0;

        // idle chá»‰ nhÃºn khi khÃ´ng Ä‘i
        final idleBob = widget.isWalking ? 0.0 : _floatY.value;

        final internalDy = idleBob + walkBob;
        final double armSwingL;
        final double armSwingR;
        final double foreSwing;
        final double hairOffset;
        final double legSwingL;
        final double legSwingR;
        final double kneeBendL;
        final double kneeBendR;
        final double footLiftL;
        final double footLiftR;

        if (widget.isWalking) {
          final armAmp = 0.32 * widget.walkStrength;
          final legAmp = 0.24 * widget.walkStrength;

          double liftWave(double phase) {
            final s = math.sin(phase);
            return s > 0
                ? s
                : 0.0; // chá»‰ nháº¥c á»Ÿ ná»­a vÃ²ng Ä‘Æ°a chÃ¢n lÃªn trÆ°á»›c
          }

          final leftPhase = widget.walkPhase;
          final rightPhase = widget.walkPhase + math.pi;

          final leftSwing = math.sin(leftPhase);
          final rightSwing = math.sin(rightPhase);

          armSwingL = leftSwing * armAmp;
          armSwingR = -leftSwing * armAmp;

          foreSwing =
              (math.sin(widget.walkPhase - 0.45) * 0.16) * widget.walkStrength;

          legSwingL = -leftSwing * legAmp;
          legSwingR = -rightSwing * legAmp;

          kneeBendL = liftWave(leftPhase) * 0.42;
          kneeBendR = liftWave(rightPhase) * 0.42;

          footLiftL = liftWave(leftPhase) * 10.0 * widget.walkStrength;
          footLiftR = liftWave(rightPhase) * 10.0 * widget.walkStrength;

          hairOffset =
              math.sin(widget.walkPhase - 0.2) * 1.8 * widget.walkStrength;
        } else {
          armSwingL = _idleArmSwing.value;
          armSwingR = -_idleArmSwing.value;
          foreSwing = _idleArmSwing.value * 0.4;
          hairOffset = _hairBounce.value;
          legSwingL = _idleLegSwing.value;
          legSwingR = -_idleLegSwing.value;

          kneeBendL = 0.0;
          kneeBendR = 0.0;
          footLiftL = 0.0;
          footLiftR = 0.0;
        }

        final pose = _MascotPose(
          facing: widget.facing,
          lean: widget.lean,
          blinkScale: _blinkScale.value,
          armSwingLeft: armSwingL,
          armSwingRight: armSwingR,
          forearmSwing: foreSwing,
          legSwingLeft: legSwingL,
          legSwingRight: legSwingR,
          kneeBendLeft: kneeBendL,
          kneeBendRight: kneeBendR,
          footLiftLeft: footLiftL,
          footLiftRight: footLiftR,
          hairOffset: hairOffset,
          walkStrength: widget.walkStrength,
          walkPhase: widget.walkPhase,
          isWalking: widget.isWalking,
        );

        final groundBaseOffset = widget.groundY - (widget.size * 0.90);
        return SizedBox(
          width: robotWidth,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Transform.translate(
                offset: Offset(0, groundBaseOffset + internalDy),
                child: SizedBox(
                  width: robotWidth,
                  height: widget.size,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Robot chÃ­nh: cÃ³ flip
                      Transform(
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
                              pose: pose,
                              eyeTrackX: 0,
                              eyeTrackY: 0,
                              antennaScale: 1,
                            ),
                            willChange: true,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _BadgePainter(
                              accentColor: _accentColor,
                              logoImage: widget.misumiLogo,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
