import 'dart:math' as math;

import 'package:flutter/material.dart';

enum SignalVisualType {
  temperatureHumidity,
  voltage,
  current,
  activePower,
  apparentPower,
  reactivePower,
  powerFactor,
  activeEnergy,
  reactiveEnergy,
  unknown,
}

class SignalVisualDescriptor {
  final SignalVisualType type;
  final String phaseLabel;

  const SignalVisualDescriptor({required this.type, this.phaseLabel = ''});
}

class SignalVisualResolver {
  static SignalVisualDescriptor resolve(String? nameEn) {
    final raw = _normalize(nameEn);

    if (raw.contains('slave sensor') ||
        raw.contains('temperature') ||
        raw.contains('temperure') ||
        raw.contains('humidity') ||
        raw.contains('humity')) {
      return const SignalVisualDescriptor(
        type: SignalVisualType.temperatureHumidity,
      );
    }

    if (raw.contains('voltage')) {
      return SignalVisualDescriptor(
        type: SignalVisualType.voltage,
        phaseLabel: _extractVoltagePhase(raw),
      );
    }

    if (raw.contains('current')) {
      return SignalVisualDescriptor(
        type: SignalVisualType.current,
        phaseLabel: _extractCurrentPhase(raw),
      );
    }

    // Reactive Energy phải kiểm tra trước Reactive Power.
    if (raw.contains('reactive energy')) {
      return const SignalVisualDescriptor(
        type: SignalVisualType.reactiveEnergy,
      );
    }

    if (raw.contains('energy consumption') ||
        raw == 'total energy' ||
        raw.contains('active energy')) {
      return const SignalVisualDescriptor(type: SignalVisualType.activeEnergy);
    }

    if (raw.contains('apparent power')) {
      return const SignalVisualDescriptor(type: SignalVisualType.apparentPower);
    }

    if (raw.contains('reactive power')) {
      return const SignalVisualDescriptor(type: SignalVisualType.reactivePower);
    }

    if (raw.contains('power factor') || raw.contains('cos phi')) {
      return const SignalVisualDescriptor(type: SignalVisualType.powerFactor);
    }

    if (raw.contains('total power') || raw.contains('active power')) {
      return const SignalVisualDescriptor(type: SignalVisualType.activePower);
    }

    return const SignalVisualDescriptor(type: SignalVisualType.unknown);
  }

  static String _normalize(String? value) {
    return (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _extractVoltagePhase(String raw) {
    if (raw.contains('v12')) return 'V12';
    if (raw.contains('v23')) return 'V23';
    if (raw.contains('v31')) return 'V31';

    return 'V';
  }

  static String _extractCurrentPhase(String raw) {
    if (raw.contains('i1')) return 'I1';
    if (raw.contains('i2')) return 'I2';
    if (raw.contains('i3')) return 'I3';

    return 'I';
  }
}

class SignalVisualBackground extends StatefulWidget {
  final String nameEn;
  final Color color;
  final bool animated;
  final Widget? child;

  const SignalVisualBackground({
    super.key,
    required this.nameEn,
    required this.color,
    this.animated = true,
    this.child,
  });

  @override
  State<SignalVisualBackground> createState() => _SignalVisualBackgroundState();
}

class _SignalVisualBackgroundState extends State<SignalVisualBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    if (widget.animated) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SignalVisualBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.animated == widget.animated) return;

    if (widget.animated) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (_, child) {
          return CustomPaint(
            painter: SignalMetricPainter(
              nameEn: widget.nameEn,
              color: widget.color,
              progress: _controller.value,
            ),
            child: child,
          );
        },
      ),
    );
  }
}

class SignalMetricPainter extends CustomPainter {
  final String nameEn;
  final Color color;
  final double progress;

  SignalMetricPainter({
    required this.nameEn,
    required this.color,
    this.progress = 0,
  });

  SignalVisualDescriptor get descriptor {
    return SignalVisualResolver.resolve(nameEn);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    _drawHalo(canvas, size);

    switch (descriptor.type) {
      case SignalVisualType.temperatureHumidity:
        _drawTemperatureHumidity(canvas, size);
        break;

      case SignalVisualType.voltage:
        _drawVoltage(canvas, size);
        break;

      case SignalVisualType.current:
        _drawCurrent(canvas, size);
        break;

      case SignalVisualType.activePower:
        _drawActivePower(canvas, size);
        break;

      case SignalVisualType.apparentPower:
        _drawApparentPower(canvas, size);
        break;

      case SignalVisualType.reactivePower:
        _drawReactivePower(canvas, size);
        break;

      case SignalVisualType.powerFactor:
        _drawPowerFactor(canvas, size);
        break;

      case SignalVisualType.activeEnergy:
        _drawEnergyMeter(canvas, size, reactive: false);
        break;

      case SignalVisualType.reactiveEnergy:
        _drawEnergyMeter(canvas, size, reactive: true);
        break;

      case SignalVisualType.unknown:
        _drawUnknown(canvas, size);
        break;
    }

    canvas.restore();
  }

  Paint _stroke(
    double opacity,
    double width, {
    PaintingStyle style = PaintingStyle.stroke,
  }) {
    return Paint()
      ..color = color.withOpacity(opacity)
      ..style = style
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }

  Paint _glow(double opacity, double width, double blur) {
    return Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
  }

  void _drawHalo(Canvas canvas, Size size) {
    final center = Offset(size.width * .78, size.height * .50);

    final radius = math.min(size.width, size.height) * .48;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(.10),
          color.withOpacity(.025),
          Colors.transparent,
        ],
        stops: const [0, .48, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  // ============================================================
  // TEMPERATURE + HUMIDITY
  // ============================================================

  void _drawTemperatureHumidity(Canvas canvas, Size size) {
    final center = Offset(size.width * .78, size.height * .50);

    final unit = math.min(size.width, size.height);
    final chipWidth = unit * .34;
    final chipHeight = unit * .42;

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: chipWidth, height: chipHeight),
      Radius.circular(unit * .035),
    );

    final line = _stroke(.42, 1.2);
    final glow = _glow(.07, 5, 5);

    canvas.drawRRect(rect, glow);
    canvas.drawRRect(rect, line);

    // Chân cảm biến.
    for (int i = 0; i < 4; i++) {
      final y = center.dy - chipHeight * .30 + i * chipHeight * .20;

      canvas.drawLine(
        Offset(center.dx - chipWidth / 2, y),
        Offset(center.dx - chipWidth / 2 - unit * .045, y),
        line,
      );

      canvas.drawLine(
        Offset(center.dx + chipWidth / 2, y),
        Offset(center.dx + chipWidth / 2 + unit * .045, y),
        line,
      );
    }

    _drawThermometer(
      canvas,
      Offset(center.dx - chipWidth * .20, center.dy),
      unit * .20,
    );

    _drawWaterDrop(
      canvas,
      Offset(center.dx + chipWidth * .20, center.dy),
      unit * .095,
    );

    // Điểm tín hiệu chạy quanh sensor.
    final angle = progress * math.pi * 2;

    final pulse = Offset(
      center.dx + math.cos(angle) * chipWidth * .62,
      center.dy + math.sin(angle) * chipHeight * .62,
    );

    canvas.drawCircle(
      pulse,
      3.5,
      Paint()
        ..color = color.withOpacity(.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawCircle(pulse, 1.5, Paint()..color = color.withOpacity(.9));
  }

  void _drawThermometer(Canvas canvas, Offset center, double height) {
    final line = _stroke(.62, 1.2);
    final fill = Paint()
      ..color = color.withOpacity(.35)
      ..style = PaintingStyle.fill;

    final top = Offset(center.dx, center.dy - height * .42);

    final bottom = Offset(center.dx, center.dy + height * .25);

    canvas.drawLine(top, bottom, line);
    canvas.drawCircle(
      Offset(center.dx, center.dy + height * .34),
      height * .12,
      line,
    );

    final liquidTop = Offset(
      center.dx,
      center.dy + height * (.12 - progress * .18),
    );

    canvas.drawLine(liquidTop, bottom, _stroke(.78, 2.2));

    canvas.drawCircle(
      Offset(center.dx, center.dy + height * .34),
      height * .075,
      fill,
    );
  }

  void _drawWaterDrop(Canvas canvas, Offset center, double radius) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..cubicTo(
        center.dx - radius * .85,
        center.dy,
        center.dx - radius * .72,
        center.dy + radius,
        center.dx,
        center.dy + radius,
      )
      ..cubicTo(
        center.dx + radius * .72,
        center.dy + radius,
        center.dx + radius * .85,
        center.dy,
        center.dx,
        center.dy - radius,
      );

    canvas.drawPath(path, _glow(.08, 5, 5));
    canvas.drawPath(path, _stroke(.64, 1.2));

    final waveY = center.dy + radius * (.1 + progress * .32);

    canvas.drawLine(
      Offset(center.dx - radius * .45, waveY),
      Offset(center.dx + radius * .45, waveY),
      _stroke(.38, 1),
    );
  }

  // ============================================================
  // VOLTAGE V12 / V23 / V31
  // ============================================================

  void _drawVoltage(Canvas canvas, Size size) {
    final center = Offset(size.width * .76, size.height * .50);

    final unit = math.min(size.width, size.height);
    final radius = unit * .16;

    final line = _stroke(.45, 1.15);
    final glow = _glow(.065, 5, 5);

    final phasePoints = <Offset>[
      Offset(center.dx, center.dy - radius),
      Offset(center.dx - radius * .87, center.dy + radius * .50),
      Offset(center.dx + radius * .87, center.dy + radius * .50),
    ];

    final triangle = Path()
      ..moveTo(phasePoints[0].dx, phasePoints[0].dy)
      ..lineTo(phasePoints[1].dx, phasePoints[1].dy)
      ..lineTo(phasePoints[2].dx, phasePoints[2].dy)
      ..close();

    canvas.drawPath(triangle, glow);
    canvas.drawPath(triangle, line);

    for (int i = 0; i < phasePoints.length; i++) {
      final point = phasePoints[i];

      canvas.drawCircle(
        point,
        unit * .026,
        Paint()..color = color.withOpacity(.42),
      );

      canvas.drawCircle(point, unit * .045, _stroke(.20, .9));
    }

    _drawSineWave(
      canvas,
      start: Offset(center.dx - unit * .23, center.dy + unit * .25),
      width: unit * .46,
      amplitude: unit * .055,
      cycles: 2.5,
      phase: progress * math.pi * 2,
    );

    _drawLabel(
      canvas,
      descriptor.phaseLabel,
      Offset(center.dx, center.dy + unit * .05),
      fontSize: unit * .085,
    );
  }

  // ============================================================
  // CURRENT I1 / I2 / I3
  // ============================================================

  void _drawCurrent(Canvas canvas, Size size) {
    final center = Offset(size.width * .78, size.height * .50);

    final unit = math.min(size.width, size.height);
    final line = _stroke(.42, 1.15);

    final cableXs = <double>[
      center.dx - unit * .12,
      center.dx,
      center.dx + unit * .12,
    ];

    for (int i = 0; i < cableXs.length; i++) {
      final x = cableXs[i];

      final path = Path()
        ..moveTo(x, center.dy - unit * .24)
        ..cubicTo(
          x - unit * .035,
          center.dy - unit * .05,
          x + unit * .035,
          center.dy + unit * .05,
          x,
          center.dy + unit * .24,
        );

      canvas.drawPath(path, _glow(.05, 5, 5));
      canvas.drawPath(path, line);

      final movingY =
          center.dy - unit * .22 + unit * .44 * ((progress + i / 3) % 1);

      canvas.drawCircle(
        Offset(x, movingY),
        unit * .025,
        Paint()
          ..color = color.withOpacity(.65)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Vòng từ trường.
    for (int i = 0; i < 3; i++) {
      final radius = unit * (.09 + i * .045);
      final start = progress * math.pi * 2 + i;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        math.pi * 1.20,
        false,
        _stroke(.18 - i * .035, 1),
      );
    }

    _drawLabel(
      canvas,
      descriptor.phaseLabel,
      Offset(center.dx, center.dy),
      fontSize: unit * .085,
    );
  }

  // ============================================================
  // ACTIVE POWER
  // ============================================================

  void _drawActivePower(Canvas canvas, Size size) {
    final center = Offset(size.width * .78, size.height * .48);

    final unit = math.min(size.width, size.height);

    _drawLightning(
      canvas,
      center: Offset(center.dx - unit * .09, center.dy),
      height: unit * .32,
    );

    final baseY = center.dy + unit * .17;

    final values = <double>[.32, .52, .72, .95];

    for (int i = 0; i < values.length; i++) {
      final height = unit * values[i] * (.22 + progress * .05);

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          center.dx + unit * .02 + i * unit * .055,
          baseY - height,
          unit * .032,
          height,
        ),
        Radius.circular(unit * .008),
      );

      canvas.drawRRect(
        rect,
        Paint()
          ..color = color.withOpacity(.18 + i * .09)
          ..style = PaintingStyle.fill,
      );
    }

    _drawLabel(
      canvas,
      'P',
      Offset(center.dx + unit * .10, center.dy - unit * .19),
      fontSize: unit * .075,
    );
  }

  // ============================================================
  // APPARENT POWER
  // ============================================================

  void _drawApparentPower(Canvas canvas, Size size) {
    final center = Offset(size.width * .77, size.height * .52);

    final unit = math.min(size.width, size.height);

    final p1 = Offset(center.dx - unit * .18, center.dy + unit * .15);

    final p2 = Offset(center.dx + unit * .18, center.dy + unit * .15);

    final p3 = Offset(center.dx - unit * .18, center.dy - unit * .18);

    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();

    canvas.drawPath(path, _glow(.07, 5, 5));
    canvas.drawPath(path, _stroke(.48, 1.3));

    final travel = progress;

    final movingPoint = Offset(p1.dx + (p2.dx - p1.dx) * travel, p1.dy);

    canvas.drawCircle(
      movingPoint,
      unit * .022,
      Paint()..color = color.withOpacity(.72),
    );

    _drawLabel(
      canvas,
      'P',
      Offset(center.dx, p1.dy + unit * .05),
      fontSize: unit * .055,
    );

    _drawLabel(
      canvas,
      'Q',
      Offset(p1.dx - unit * .045, center.dy),
      fontSize: unit * .055,
    );

    _drawLabel(
      canvas,
      'S',
      Offset(center.dx + unit * .015, center.dy - unit * .03),
      fontSize: unit * .075,
    );
  }

  // ============================================================
  // REACTIVE POWER
  // ============================================================

  void _drawReactivePower(Canvas canvas, Size size) {
    final center = Offset(size.width * .77, size.height * .50);

    final unit = math.min(size.width, size.height);

    final start = Offset(center.dx - unit * .23, center.dy);

    final coil = Path()..moveTo(start.dx, start.dy);

    const loops = 5;

    for (int i = 0; i < loops; i++) {
      final x1 = start.dx + i * unit * .09;
      final x2 = x1 + unit * .045;
      final x3 = x1 + unit * .09;

      coil.cubicTo(
        x1 + unit * .015,
        center.dy - unit * .10,
        x2 - unit * .015,
        center.dy - unit * .10,
        x2,
        center.dy,
      );

      coil.cubicTo(
        x2 + unit * .015,
        center.dy + unit * .10,
        x3 - unit * .015,
        center.dy + unit * .10,
        x3,
        center.dy,
      );
    }

    canvas.drawPath(coil, _glow(.075, 5, 5));
    canvas.drawPath(coil, _stroke(.55, 1.3));

    final pulseX = start.dx + unit * .45 * progress;

    canvas.drawCircle(
      Offset(
        pulseX,
        center.dy + math.sin(progress * math.pi * loops * 2) * unit * .07,
      ),
      unit * .022,
      Paint()..color = color.withOpacity(.7),
    );

    _drawLabel(
      canvas,
      'Q',
      Offset(center.dx, center.dy - unit * .19),
      fontSize: unit * .075,
    );
  }

  // ============================================================
  // POWER FACTOR
  // ============================================================

  void _drawPowerFactor(Canvas canvas, Size size) {
    final center = Offset(size.width * .78, size.height * .57);

    final unit = math.min(size.width, size.height);
    final radius = unit * .20;

    final gaugeRect = Rect.fromCircle(center: center, radius: radius);

    const startAngle = math.pi;
    const sweepAngle = math.pi;

    canvas.drawArc(gaugeRect, startAngle, sweepAngle, false, _glow(.06, 7, 6));

    canvas.drawArc(gaugeRect, startAngle, sweepAngle, false, _stroke(.28, 4));

    // Giả lập kim dao động khoảng 0.85–0.98.
    final normalized = .72 + math.sin(progress * math.pi * 2) * .10;

    final needleAngle = startAngle + sweepAngle * normalized;

    final needleEnd = Offset(
      center.dx + math.cos(needleAngle) * radius * .83,
      center.dy + math.sin(needleAngle) * radius * .83,
    );

    canvas.drawLine(center, needleEnd, _stroke(.78, 1.8));

    canvas.drawCircle(
      center,
      unit * .025,
      Paint()..color = color.withOpacity(.75),
    );

    for (int i = 0; i <= 5; i++) {
      final angle = startAngle + sweepAngle * (i / 5);

      final outer = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );

      final inner = Offset(
        center.dx + math.cos(angle) * radius * .86,
        center.dy + math.sin(angle) * radius * .86,
      );

      canvas.drawLine(inner, outer, _stroke(.30, 1));
    }

    _drawLabel(
      canvas,
      'cos φ',
      Offset(center.dx, center.dy + unit * .06),
      fontSize: unit * .060,
    );
  }

  // ============================================================
  // ENERGY METER
  // ============================================================

  void _drawEnergyMeter(Canvas canvas, Size size, {required bool reactive}) {
    final center = Offset(size.width * .78, size.height * .50);

    final unit = math.min(size.width, size.height);

    final meterRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: unit * .42, height: unit * .36),
      Radius.circular(unit * .035),
    );

    canvas.drawRRect(meterRect, _glow(.065, 6, 6));

    canvas.drawRRect(meterRect, _stroke(.48, 1.2));

    // Màn hình số.
    final displayRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - unit * .045),
        width: unit * .29,
        height: unit * .105,
      ),
      Radius.circular(unit * .015),
    );

    canvas.drawRRect(
      displayRect,
      Paint()
        ..color = color.withOpacity(.075)
        ..style = PaintingStyle.fill,
    );

    canvas.drawRRect(displayRect, _stroke(.25, .9));

    for (int i = 0; i < 5; i++) {
      final valueHeight = unit * (.018 + ((i + progress * 5) % 5) * .004);

      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(
            center.dx - unit * .10 + i * unit * .05,
            center.dy - unit * .045,
          ),
          width: unit * .022,
          height: valueHeight,
        ),
        Paint()..color = color.withOpacity(.45),
      );
    }

    // Scan line.
    final scanX = center.dx - unit * .145 + unit * .29 * progress;

    canvas.drawLine(
      Offset(scanX, center.dy - unit * .09),
      Offset(scanX, center.dy),
      _stroke(.45, 1.2),
    );

    // LED status.
    canvas.drawCircle(
      Offset(center.dx - unit * .14, center.dy + unit * .09),
      unit * .012,
      Paint()..color = color.withOpacity(.75),
    );

    if (reactive) {
      _drawMiniCoil(
        canvas,
        Offset(center.dx + unit * .08, center.dy + unit * .09),
        unit * .13,
      );

      _drawLabel(
        canvas,
        'kVArh',
        Offset(center.dx, center.dy + unit * .16),
        fontSize: unit * .042,
      );
    } else {
      _drawLightning(
        canvas,
        center: Offset(center.dx + unit * .10, center.dy + unit * .09),
        height: unit * .10,
      );

      _drawLabel(
        canvas,
        'kWh',
        Offset(center.dx, center.dy + unit * .16),
        fontSize: unit * .046,
      );
    }
  }

  void _drawMiniCoil(Canvas canvas, Offset center, double width) {
    final path = Path()..moveTo(center.dx - width / 2, center.dy);

    for (int i = 0; i < 3; i++) {
      final startX = center.dx - width / 2 + i * width / 3;

      path.cubicTo(
        startX + width / 12,
        center.dy - width * .18,
        startX + width / 4,
        center.dy - width * .18,
        startX + width / 3,
        center.dy,
      );
    }

    canvas.drawPath(path, _stroke(.52, 1));
  }

  // ============================================================
  // COMMON HELPERS
  // ============================================================

  void _drawLightning(
    Canvas canvas, {
    required Offset center,
    required double height,
  }) {
    final width = height * .45;

    final path = Path()
      ..moveTo(center.dx + width * .10, center.dy - height / 2)
      ..lineTo(center.dx - width * .42, center.dy + height * .02)
      ..lineTo(center.dx - width * .04, center.dy + height * .02)
      ..lineTo(center.dx - width * .17, center.dy + height / 2)
      ..lineTo(center.dx + width * .43, center.dy - height * .10)
      ..lineTo(center.dx + width * .07, center.dy - height * .10)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(.10)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(.60)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawSineWave(
    Canvas canvas, {
    required Offset start,
    required double width,
    required double amplitude,
    required double cycles,
    required double phase,
  }) {
    final path = Path();

    const segments = 80;

    for (int i = 0; i <= segments; i++) {
      final t = i / segments;

      final x = start.dx + width * t;
      final y =
          start.dy + math.sin(t * cycles * math.pi * 2 + phase) * amplitude;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, _glow(.06, 5, 5));

    canvas.drawPath(path, _stroke(.55, 1.2));
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset center, {
    required double fontSize,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withOpacity(.56),
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: .4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  void _drawUnknown(Canvas canvas, Size size) {
    final center = Offset(size.width * .78, size.height * .50);

    final unit = math.min(size.width, size.height);

    canvas.drawCircle(center, unit * .16, _glow(.06, 6, 6));

    canvas.drawCircle(center, unit * .16, _stroke(.34, 1.2));

    _drawLabel(canvas, '?', center, fontSize: unit * .12);
  }

  @override
  bool shouldRepaint(covariant SignalMetricPainter oldDelegate) {
    return oldDelegate.nameEn != nameEn ||
        oldDelegate.color != color ||
        oldDelegate.progress != progress;
  }
}
