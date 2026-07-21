import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

enum UtilityPaintType { electricity, water, air }

class UtilityIndustrialMotionBackground extends StatefulWidget {
  final String cate;
  final Color color;
  final bool animated;

  const UtilityIndustrialMotionBackground({
    super.key,
    required this.cate,
    required this.color,
    this.animated = true,
  });

  @override
  State<UtilityIndustrialMotionBackground> createState() =>
      _UtilityIndustrialMotionBackgroundState();
}

class _UtilityIndustrialMotionBackgroundState
    extends State<UtilityIndustrialMotionBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  UtilityPaintType get _type {
    final value = widget.cate.trim().toLowerCase();

    if (value.contains('water')) {
      return UtilityPaintType.water;
    }

    if (value.contains('air') || value.contains('compressed')) {
      return UtilityPaintType.air;
    }

    return UtilityPaintType.electricity;
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    );

    if (widget.animated) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant UtilityIndustrialMotionBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.animated != widget.animated) {
      if (widget.animated) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          child: Stack(
            key: ValueKey('industrial_motion_bg_${_type.name}'),
            fit: StackFit.expand,
            children: [
              // STATIC LAYER: không repaint theo animation
              CustomPaint(
                painter: _UtilityPremiumBackgroundPainter(
                  color: widget.color,
                  type: _type,
                  drawStatic: true,
                  drawMotion: false,
                ),
              ),

              // MOTION LAYER: chỉ repaint phần động
              if (widget.animated)
                CustomPaint(
                  painter: _UtilityPremiumBackgroundPainter(
                    color: widget.color,
                    type: _type,
                    animation: _controller,
                    drawStatic: false,
                    drawMotion: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UtilityPremiumBackgroundPainter extends CustomPainter {
  final Color color;
  final UtilityPaintType type;
  final Animation<double>? animation;
  final bool drawStatic;
  final bool drawMotion;

  _UtilityPremiumBackgroundPainter({
    required this.color,
    required this.type,
    this.animation,
    this.drawStatic = true,
    this.drawMotion = false,
  }) : super(repaint: animation);

  double get t => animation?.value ?? 0.0;

  Paint _stroke(double opacity, double width) {
    return Paint()
      ..color = color.withOpacity(opacity)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }

  Paint _glow(double opacity, double width, double blur) {
    return Paint()
      ..color = color.withOpacity(opacity)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (drawStatic) {
      _drawAmbientGlow(canvas, size);
      _drawBlueprintGrid(canvas, size);

      switch (type) {
        case UtilityPaintType.electricity:
          _drawElectricity(canvas, size);
          break;
        case UtilityPaintType.water:
          _drawWater(canvas, size);
          break;
        case UtilityPaintType.air:
          _drawAir(canvas, size);
          break;
      }

      _drawVignette(canvas, size);
    }

    if (drawMotion) {
      switch (type) {
        case UtilityPaintType.electricity:
          _drawElectricMovingCurrent(canvas, size);
          break;
        case UtilityPaintType.water:
          _drawWaterMovingFlow(canvas, size);
          break;
        case UtilityPaintType.air:
          _drawAirMovingFlow(canvas, size);
          break;
      }
    }
  }

  // ============================================================
  // COMMON BACKGROUND
  // ============================================================

  void _drawAmbientGlow(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final topGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              color.withOpacity(.1),
              color.withOpacity(.045),
              Colors.transparent,
            ],
            stops: const [0, .42, 1],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .18, size.height * .16),
              radius: size.width * .58,
            ),
          );

    final bottomGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              color.withOpacity(.12),
              color.withOpacity(.032),
              Colors.transparent,
            ],
            stops: const [0, .46, 1],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .86, size.height * .82),
              radius: size.width * .50,
            ),
          );

    canvas.drawRect(rect, topGlow);
    canvas.drawRect(rect, bottomGlow);
  }

  void _drawBlueprintGrid(Canvas canvas, Size size) {
    final minorPaint = Paint()
      ..color = Colors.white.withOpacity(.025)
      ..strokeWidth = .65
      ..style = PaintingStyle.stroke;

    final majorPaint = Paint()
      ..color = color.withOpacity(.045)
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke;

    const minor = 36.0;
    const major = 144.0;

    for (double x = 0; x <= size.width; x += minor) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorPaint);
    }

    for (double y = 0; y <= size.height; y += minor) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minorPaint);
    }

    for (double x = 0; x <= size.width; x += major) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), majorPaint);
    }

    for (double y = 0; y <= size.height; y += major) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), majorPaint);
    }

    final diagonalPaint = Paint()
      ..color = Colors.white.withOpacity(.018)
      ..strokeWidth = .7
      ..style = PaintingStyle.stroke;

    for (double x = -size.height; x < size.width; x += 120) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        diagonalPaint,
      );
    }
  }

  void _drawVignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final p = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(.10),
          Colors.black.withOpacity(.22),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);

    canvas.drawRect(rect, p);
  }

  // ============================================================
  // ELECTRICITY
  // ============================================================

  // ============================================================
  // ELECTRICITY — HIGH VOLTAGE STYLE
  // ============================================================
  double _mainTowerHeight(Size size) {
    return math.min(size.height * .72, 420.0);
  }

  double _mainTowerWidth(Size size) {
    return _mainTowerHeight(size) * .42;
  }

  Offset _mainTowerBase(Size size) {
    final height = _mainTowerHeight(size);
    final center = Offset(size.width * .82, size.height * .50);

    return Offset(center.dx, center.dy + height * .42);
  }

  Offset _mainTowerTop(Size size) {
    final base = _mainTowerBase(size);
    final height = _mainTowerHeight(size);

    return Offset(base.dx, base.dy - height);
  }

  Path _buildMainTowerFeederPath(Size size, {required int lane}) {
    final height = _mainTowerHeight(size);
    final width = _mainTowerWidth(size);
    final base = _mainTowerBase(size);
    final top = _mainTowerTop(size);

    final arm1Y = top.dy + height * .18;
    final arm2Y = top.dy + height * .32;

    late final Offset target;

    if (lane == 0) {
      target = Offset(base.dx, arm1Y);
    } else if (lane == 1) {
      target = Offset(base.dx - width * .58, arm2Y);
    } else {
      target = Offset(base.dx + width * .58, arm2Y);
    }

    final startY = target.dy + (lane == 0 ? -8 : 0);

    final path = Path()
      ..moveTo(-50, startY)
      ..cubicTo(
        size.width * .22,
        startY - 18,
        size.width * .55,
        target.dy + 18,
        target.dx,
        target.dy,
      );

    return path;
  }

  void _drawElectricity(Canvas canvas, Size size) {
    _drawHighVoltageWatermark(canvas, size);
    _drawHighVoltageGrid(canvas, size);
    _drawVoltageArcs(canvas, size);
  }

  /// Watermark cột điện lớn rất mờ ở góc phải.
  /// Nhìn như silhouette, tạo cảm giác industrial/high-voltage.
  void _drawMainTowerFeederStatic(Canvas canvas, Size size) {
    final line = _stroke(.065, .95);
    final glow = _glow(.006, 3.0, 4);

    for (int lane = 0; lane < 3; lane++) {
      final path = _buildMainTowerFeederPath(size, lane: lane);

      canvas.drawPath(path, glow);
      canvas.drawPath(path, line);
    }
  }

  void _drawHighVoltageWatermark(Canvas canvas, Size size) {
    final center = Offset(size.width * .82, size.height * .50);
    final height = math.min(size.height * .72, 420.0);
    final base = Offset(center.dx, center.dy + height * .42);

    final glow = _glow(.018, 6, 8);
    final paint = _stroke(.18, 1.45);

    _drawTransmissionTower(
      canvas,
      base: base,
      height: height,
      width: height * .42,
      paint: paint,
      glowPaint: glow,
      opacityBoost: .85,
    );

    _drawMainTowerFeederStatic(canvas, size);

    // Vùng sáng nhẹ sau cột.
    final halo = Paint()
      ..shader =
          RadialGradient(
            colors: [
              color.withOpacity(.12),
              color.withOpacity(.035),
              Colors.transparent,
            ],
            stops: const [0, .42, 1],
          ).createShader(
            Rect.fromCircle(
              center: Offset(center.dx, center.dy - height * .08),
              radius: height * .58,
            ),
          );

    canvas.drawCircle(
      Offset(center.dx, center.dy - height * .08),
      height * .58,
      halo,
    );
  }

  /// Lưới cột điện cao thế nhỏ chạy ngang nền.
  /// Có dây điện võng, chuỗi sứ và cross-arm.
  void _drawHighVoltageGrid(Canvas canvas, Size size) {
    // Static tower: luôn mờ.
    final towerPaint = _stroke(.055, 1.05);
    final towerGlow = _glow(.006, 3.2, 4);

    final wirePaint = _stroke(.060, .95);
    final wireGlow = _glow(.006, 3.0, 4);

    const stepX = 245.0;
    const stepY = 185.0;

    final rows = (size.height / stepY).ceil() + 2;
    final cols = (size.width / stepX).ceil() + 3;

    for (int row = -1; row < rows; row++) {
      final y = row * stepY + 150;
      final offsetX = row.isOdd ? stepX * .45 : 0.0;

      final tops = <Offset>[];
      final leftWirePoints = <Offset>[];
      final rightWirePoints = <Offset>[];

      for (int col = -1; col < cols; col++) {
        final x = col * stepX + offsetX;
        final base = Offset(x, y);
        final h = row.isEven ? 88.0 : 76.0;
        final w = h * .42;

        _drawTransmissionTower(
          canvas,
          base: base,
          height: h,
          width: w,
          paint: towerPaint,
          glowPaint: towerGlow,
          detailOpacity: .050,
          topNodeOpacity: .060,
        );

        tops.add(Offset(x, y - h));
        leftWirePoints.add(Offset(x - w * .48, y - h * .74));
        rightWirePoints.add(Offset(x + w * .48, y - h * .74));
      }

      _connectSaggingWires(canvas, leftWirePoints, wirePaint, wireGlow);
      _connectSaggingWires(canvas, rightWirePoints, wirePaint, wireGlow);
      _connectSaggingWires(canvas, tops, wirePaint, wireGlow);
    }
  }

  /// Vẽ một cột điện cao thế.
  /// Có 2 chân xiên, thân giàn, cross-arm và chuỗi sứ.
  void _drawTowerIndustrialDetails(
    Canvas canvas, {
    required Offset base,
    required Offset top,
    required double height,
    required double width,
    double opacity = .18,
  }) {
    final nodeOpacity = (opacity * 1.15).clamp(0.0, 1.0).toDouble();

    final detailPaint = _stroke(opacity, .75);
    final nodePaint = Paint()
      ..color = color.withOpacity(nodeOpacity)
      ..style = PaintingStyle.fill;

    // Xương sống giữa trụ.
    canvas.drawLine(
      top + Offset(0, height * .08),
      base - Offset(0, height * .06),
      detailPaint,
    );

    // Base plate / chân móng.
    final baseY = base.dy;
    canvas.drawLine(
      Offset(base.dx - width * .58, baseY + 3),
      Offset(base.dx + width * .58, baseY + 3),
      detailPaint,
    );

    canvas.drawLine(
      Offset(base.dx - width * .42, baseY + 7),
      Offset(base.dx - width * .22, baseY + 7),
      detailPaint,
    );

    canvas.drawLine(
      Offset(base.dx + width * .22, baseY + 7),
      Offset(base.dx + width * .42, baseY + 7),
      detailPaint,
    );

    // Bolt/node ở các tầng giàn.
    final levels = <double>[.22, .42, .62, .82];

    for (final k in levels) {
      final y = top.dy + height * k;
      final spread = width * .46 * k;

      canvas.drawCircle(Offset(base.dx - spread, y), 1.45, nodePaint);
      canvas.drawCircle(Offset(base.dx + spread, y), 1.45, nodePaint);
      canvas.drawCircle(Offset(base.dx, y), 1.15, nodePaint);
    }

    // End-cap ở cross arm để nhìn rõ sứ/dây.
    final armYs = [
      top.dy + height * .18,
      top.dy + height * .32,
      top.dy + height * .48,
    ];

    final armWidths = [width * 1.18, width * 1.45, width * 1.05];

    for (int i = 0; i < armYs.length; i++) {
      final y = armYs[i];
      final w = armWidths[i];

      canvas.drawCircle(Offset(base.dx - w / 2, y), 1.6, nodePaint);
      canvas.drawCircle(Offset(base.dx + w / 2, y), 1.6, nodePaint);

      canvas.drawLine(
        Offset(base.dx - w / 2, y - 4),
        Offset(base.dx - w / 2, y + 4),
        detailPaint,
      );

      canvas.drawLine(
        Offset(base.dx + w / 2, y - 4),
        Offset(base.dx + w / 2, y + 4),
        detailPaint,
      );
    }
  }

  void _drawTransmissionTower(
    Canvas canvas, {
    required Offset base,
    required double height,
    required double width,
    required Paint paint,
    required Paint glowPaint,
    double opacityBoost = 1.0,
    double detailOpacity = .18,
    double topNodeOpacity = .18,
  }) {
    final top = Offset(base.dx, base.dy - height);
    final bottomLeft = Offset(base.dx - width * .46, base.dy);
    final bottomRight = Offset(base.dx + width * .46, base.dy);

    final p = Path()
      // 2 chân chính
      ..moveTo(top.dx, top.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..moveTo(top.dx, top.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      // chân đáy
      ..moveTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy);

    // Các thanh ngang + giằng chéo.
    final levels = <double>[.22, .42, .62, .82];

    for (final t in levels) {
      final y = top.dy + height * t;
      final spread = width * .46 * t;

      final left = Offset(base.dx - spread, y);
      final right = Offset(base.dx + spread, y);

      p
        ..moveTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy);
    }

    for (int i = 0; i < levels.length - 1; i++) {
      final t1 = levels[i];
      final t2 = levels[i + 1];

      final y1 = top.dy + height * t1;
      final y2 = top.dy + height * t2;

      final s1 = width * .46 * t1;
      final s2 = width * .46 * t2;

      p
        ..moveTo(base.dx - s1, y1)
        ..lineTo(base.dx + s2, y2)
        ..moveTo(base.dx + s1, y1)
        ..lineTo(base.dx - s2, y2);
    }

    // Cross arms.
    final arm1Y = top.dy + height * .18;
    final arm2Y = top.dy + height * .32;
    final arm3Y = top.dy + height * .48;

    _drawCrossArm(
      canvas,
      center: Offset(base.dx, arm1Y),
      width: width * 1.18,
      paint: paint,
    );
    _drawCrossArm(
      canvas,
      center: Offset(base.dx, arm2Y),
      width: width * 1.45,
      paint: paint,
    );
    _drawCrossArm(
      canvas,
      center: Offset(base.dx, arm3Y),
      width: width * 1.05,
      paint: paint,
    );

    canvas.drawPath(p, glowPaint);
    canvas.drawPath(p, paint);

    // Chuỗi sứ hai bên.
    _drawInsulatorString(canvas, Offset(base.dx - width * .58, arm2Y), paint);
    _drawInsulatorString(canvas, Offset(base.dx + width * .58, arm2Y), paint);
    _drawInsulatorString(canvas, Offset(base.dx - width * .42, arm3Y), paint);
    _drawInsulatorString(canvas, Offset(base.dx + width * .42, arm3Y), paint);

    // Đỉnh cột glow nhẹ.
    final topOpacity = (topNodeOpacity * opacityBoost)
        .clamp(0.0, 1.0)
        .toDouble();

    canvas.drawCircle(top, 2.2, Paint()..color = color.withOpacity(topOpacity));

    _drawTowerIndustrialDetails(
      canvas,
      base: base,
      top: top,
      height: height,
      width: width,
      opacity: detailOpacity,
    );
  }

  void _drawCrossArm(
    Canvas canvas, {
    required Offset center,
    required double width,
    required Paint paint,
  }) {
    final left = Offset(center.dx - width / 2, center.dy);
    final right = Offset(center.dx + width / 2, center.dy);

    canvas.drawLine(left, right, paint);

    // Hai thanh chống xiên nhỏ.
    canvas.drawLine(
      Offset(center.dx - width * .26, center.dy),
      Offset(center.dx, center.dy + 12),
      paint,
    );

    canvas.drawLine(
      Offset(center.dx + width * .26, center.dy),
      Offset(center.dx, center.dy + 12),
      paint,
    );
  }

  /// Chuỗi sứ cách điện dạng các hạt nhỏ nối xuống dưới.
  void _drawInsulatorString(Canvas canvas, Offset start, Paint paint) {
    final beadPaint = Paint()
      ..color = color.withOpacity(.105)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;

    canvas.drawLine(start, start + const Offset(0, 17), paint);

    for (int i = 0; i < 4; i++) {
      final c = start + Offset(0, 4.0 + i * 3.8);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 7, height: 2.8),
        beadPaint,
      );
    }
  }

  /// Nối dây điện võng giữa các cột.
  void _connectSaggingWires(
    Canvas canvas,
    List<Offset> points,
    Paint paint,
    Paint glowPaint,
  ) {
    if (points.length < 2) return;

    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];

      final distance = (b - a).distance;
      final sag = math.min(18.0, distance * .08);

      final mid = Offset((a.dx + b.dx) / 2, math.max(a.dy, b.dy) + sag);

      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, paint);
    }
  }

  /// Các tia điện nhỏ trang trí, rất mờ.
  void _drawVoltageArcs(Canvas canvas, Size size) {
    final arcPaint = _stroke(.12, 1.05);
    final arcGlow = _glow(.026, 5, 9);

    for (double x = 80; x < size.width; x += 260) {
      for (double y = 70; y < size.height; y += 210) {
        final path = Path()
          ..moveTo(x, y)
          ..lineTo(x + 14, y - 10)
          ..lineTo(x + 6, y + 6)
          ..lineTo(x + 22, y - 2)
          ..lineTo(x + 12, y + 16);

        canvas.drawPath(path, arcGlow);
        canvas.drawPath(path, arcPaint);
      }
    }

    // Một vài node sáng nhỏ.
    final nodePaint = Paint()
      ..color = color.withOpacity(.15)
      ..style = PaintingStyle.fill;

    final ringPaint = _stroke(.075, .8);

    for (double x = 120; x < size.width; x += 220) {
      for (double y = 120; y < size.height; y += 180) {
        canvas.drawCircle(Offset(x, y), 2.1, nodePaint);
        canvas.drawCircle(Offset(x + 32, y - 26), 5.5, ringPaint);
      }
    }
  }

  // ============================================================
  // WATER
  // ============================================================

  // ============================================================
  // WATER — COOLING WATER / INDUSTRIAL PIPE NETWORK STYLE
  // ============================================================

  void _drawWater(Canvas canvas, Size size) {
    _drawCoolingTankSystem(canvas, size);
    _drawWaterPressureHeader(canvas, size);
    _drawWaterPipeNetwork(canvas, size);
    _drawWaterDropsAndBubbles(canvas, size);
    _drawWaterLevelMarks(canvas, size);
  }

  /// Watermark bồn nước lớn rất mờ phía phải.
  /// Tạo cảm giác cooling tank / water utility.
  ///
  void _drawCoolingTankSystem(Canvas canvas, Size size) {
    final tanks = _coolingTankRects(size);

    final tankW = tanks.first.width;
    final tankH = tanks.first.height;
    final startX = tanks.first.left;
    final baseY = tanks.first.bottom;

    _drawFactoryUtilityFrame(canvas, size, baseY);

    for (int i = 0; i < tanks.length; i++) {
      _drawCoolingTowerCell(canvas, tanks[i], index: i);
    }

    final headerY = baseY - tankH * .44;
    final headerPaint = _stroke(.18, 1.35);
    final headerGlow = _glow(.016, 4.5, 5.5);

    final header = Path()
      ..moveTo(startX - tankW * .46, headerY)
      ..lineTo(startX + tankW * 2.88, headerY);

    canvas.drawPath(header, headerGlow);
    canvas.drawPath(header, headerPaint);

    final downPipeX = startX + tankW * 1.10;
    final pumpY = baseY + tankH * .20;

    final downPipe = Path()
      ..moveTo(downPipeX, headerY)
      ..lineTo(downPipeX, pumpY);

    canvas.drawPath(downPipe, _glow(.012, 4.0, 5));
    canvas.drawPath(downPipe, _stroke(.15, 1.1));

    _drawLargeWaterPressureGauge(
      canvas,
      Offset(startX - tankW * .26, headerY - 30),
      label: 'BAR',
    );

    _drawWaterPumpIcon(canvas, Offset(downPipeX, pumpY + 22));

    _drawWaterValve(canvas, Offset(startX + tankW * 2.18, headerY));

    final outletY = pumpY + 22;
    final outlet = Path()
      ..moveTo(downPipeX + 48, outletY)
      ..lineTo(size.width + 40, outletY);

    canvas.drawPath(outlet, _glow(.010, 4, 5));
    canvas.drawPath(outlet, _stroke(.14, 1.05));

    _drawPipeJoint(canvas, Offset(downPipeX + 95, outletY));
    _drawPipeJoint(canvas, Offset(downPipeX + 185, outletY));
  }

  List<Rect> _coolingTankRects(Size size) {
    final tankW = math.min(size.width * .135, 118.0);
    final tankH = math.min(size.height * .32, 210.0);

    // Trái/phải của cụm 3 tank.
    final startX = size.width * .56;

    // CHỈNH Ở ĐÂY:
    // Số càng nhỏ => tank càng lên trên.
    // .06 rất cao, .10 vừa đẹp, .16 thấp hơn.
    final topY = math.max(12.0, size.height * .08);

    // baseY là đáy tank lớn nhất.
    final baseY = topY + tankH;

    return [
      Rect.fromLTWH(startX, baseY - tankH, tankW, tankH),
      Rect.fromLTWH(
        startX + tankW * .76,
        baseY - tankH * .94,
        tankW,
        tankH * .94,
      ),
      Rect.fromLTWH(
        startX + tankW * 1.52,
        baseY - tankH * .86,
        tankW,
        tankH * .86,
      ),
    ];
  }

  void _drawCoolingTankSystemMotion(Canvas canvas, Size size) {
    final tanks = _coolingTankRects(size);

    final tankW = tanks.first.width;
    final tankH = tanks.first.height;
    final startX = tanks.first.left;
    final baseY = tanks.first.bottom;

    final headerY = baseY - tankH * .44;
    final downPipeX = startX + tankW * 1.10;
    final pumpY = baseY + tankH * .20;
    final outletY = pumpY + 22;

    // Flow chạy trong header pipe phía trên 3 bồn.
    final headerPath = Path()
      ..moveTo(startX - tankW * .46, headerY)
      ..lineTo(startX + tankW * 2.88, headerY);

    _drawWaterFlowOnPipe(canvas, headerPath, phase: t);

    // Flow chạy xuống bơm.
    final downPipe = Path()
      ..moveTo(downPipeX, headerY)
      ..lineTo(downPipeX, pumpY + 22);

    _drawWaterFlowOnPipe(canvas, downPipe, phase: (t + .22) % 1.0);

    // Flow chạy ra outlet.
    final outletPath = Path()
      ..moveTo(downPipeX + 48, outletY)
      ..lineTo(size.width + 40, outletY);

    _drawWaterFlowOnPipe(canvas, outletPath, phase: (t + .42) % 1.0);

    for (int i = 0; i < tanks.length; i++) {
      _drawCoolingTankWaterMotion(canvas, tanks[i], index: i);
      _drawCoolingTankBubbles(canvas, tanks[i], index: i);
      _drawCoolingTankFanMotion(canvas, tanks[i], index: i);
      _drawCoolingTankLevelPulse(canvas, tanks[i], index: i);
    }
  }

  void _drawCoolingTankWaterMotion(
    Canvas canvas,
    Rect rect, {
    required int index,
  }) {
    final waterY = rect.top + rect.height * (.56 + index * .035);

    final waveGlow = Paint()
      ..color = color.withOpacity(.055)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final wavePaint = Paint()
      ..color = color.withOpacity(.26)
      ..strokeWidth = 1.35
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPath = Path();
    final wavePath = Path();

    for (double x = rect.left + 12; x <= rect.right - 12; x += 6) {
      final y =
          waterY + math.sin((x / 17) + t * math.pi * 2 + index * .85) * 3.2;

      if (x == rect.left + 12) {
        wavePath.moveTo(x, y);
        fillPath.moveTo(x, y);
      } else {
        wavePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath
      ..lineTo(rect.right - 12, rect.bottom - 12)
      ..lineTo(rect.left + 12, rect.bottom - 12)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(.055), color.withOpacity(.012)],
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(wavePath, waveGlow);
    canvas.drawPath(wavePath, wavePaint);
  }

  void _drawCoolingTankBubbles(Canvas canvas, Rect rect, {required int index}) {
    final bubblePaint = Paint()
      ..color = color.withOpacity(.24)
      ..strokeWidth = 1.05
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 7; i++) {
      final px = rect.left + rect.width * (.25 + (i % 3) * .22);
      final startY = rect.bottom - rect.height * (.18 + (i % 2) * .12);

      final rise = ((t + index * .13 + i * .17) % 1.0) * rect.height * .42;
      final sway = math.sin(t * math.pi * 2 + i + index) * 3.2;

      final p = Offset(px + sway, startY - rise);

      if (p.dy < rect.top + rect.height * .24 || p.dy > rect.bottom - 10) {
        continue;
      }

      canvas.drawCircle(p, 2.4 + (i % 3) * 1.0, bubblePaint);
    }
  }

  void _drawCoolingTankFanMotion(
    Canvas canvas,
    Rect rect, {
    required int index,
  }) {
    final center = Offset(rect.center.dx, rect.top + rect.width * .12);
    final r = rect.width * .15;

    final glow = Paint()
      ..color = color.withOpacity(.08)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final paint = Paint()
      ..color = color.withOpacity(.28)
      ..strokeWidth = 1.15
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, r, glow);

    final angle = t * math.pi * 2 * 1.8 + index * .7;

    for (int i = 0; i < 3; i++) {
      final a = angle + i * math.pi * 2 / 3;

      final p1 = center + Offset(math.cos(a), math.sin(a)) * r * .18;
      final p2 = center + Offset(math.cos(a), math.sin(a)) * r * .88;

      canvas.drawLine(p1, p2, paint);

      final bladeEnd =
          center + Offset(math.cos(a + .35), math.sin(a + .35)) * r * .62;

      canvas.drawLine(p2, bladeEnd, paint);
    }

    canvas.drawCircle(center, 2.4, Paint()..color = color.withOpacity(.30));
  }

  void _drawCoolingTankLevelPulse(
    Canvas canvas,
    Rect rect, {
    required int index,
  }) {
    final gaugeX = rect.right - rect.width * .18;

    final top = rect.top + rect.height * .30;
    final bottom = rect.bottom - rect.height * .18;

    final progress = (t + index * .18) % 1.0;
    final y = bottom - (bottom - top) * progress;

    final pulsePaint = Paint()
      ..color = color.withOpacity(.34)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    final dotPaint = Paint()
      ..color = color.withOpacity(.32)
      ..style = PaintingStyle.fill;

    canvas.drawLine(Offset(gaugeX - 10, y), Offset(gaugeX + 10, y), pulsePaint);

    canvas.drawCircle(Offset(gaugeX, y), 2.8, dotPaint);
  }

  void _drawFactoryUtilityFrame(Canvas canvas, Size size, double baseY) {
    final framePaint = _stroke(.060, .85);
    final softPaint = _stroke(.040, .7);

    final left = size.width * .52;
    final right = size.width * .96;
    final top = baseY - size.height * .36;
    final bottom = baseY + size.height * .16;

    // Khung thép phía sau cooling tank.
    canvas.drawLine(Offset(left, top), Offset(right, top), framePaint);
    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), framePaint);

    for (double x = left; x <= right; x += 42) {
      canvas.drawLine(Offset(x, top), Offset(x, bottom), softPaint);

      canvas.drawLine(Offset(x, top), Offset(x + 24, bottom), softPaint);
    }

    // Sàn kỹ thuật.
    final floorY = baseY + 18;
    canvas.drawLine(
      Offset(left - 24, floorY),
      Offset(right + 24, floorY),
      framePaint,
    );

    for (double x = left - 20; x < right; x += 26) {
      canvas.drawLine(Offset(x, floorY), Offset(x + 10, floorY + 8), softPaint);
    }
  }

  void _drawCoolingTowerCell(Canvas canvas, Rect rect, {required int index}) {
    final body = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.width * .16),
    );

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(.18), color.withOpacity(.065)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    // Nét chính của tank đậm hơn.
    final linePaint = _stroke(.32, 1.65);

    // Nét phụ/lưới/fan cũng rõ hơn.
    final softLine = _stroke(.18, 1.05);

    // Glow nhẹ hơn nhưng rộng hơn, nhìn nổi khối.
    final glow = _glow(.035, 6.5, 8);

    canvas.drawRRect(body, fillPaint);
    canvas.drawRRect(body, glow);
    canvas.drawRRect(body, linePaint);

    // Miệng tank / cooling tower top.
    final topOval = Rect.fromCenter(
      center: Offset(rect.center.dx, rect.top + rect.width * .12),
      width: rect.width * .76,
      height: rect.width * .18,
    );

    canvas.drawOval(topOval, linePaint);

    // Fan grille phía trên.
    final fanCenter = Offset(rect.center.dx, rect.top + rect.width * .12);
    canvas.drawCircle(fanCenter, rect.width * .16, softLine);

    for (int i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      canvas.drawLine(
        fanCenter,
        fanCenter + Offset(math.cos(a), math.sin(a)) * rect.width * .14,
        softLine,
      );
    }

    // Vạch nước trong tank.
    final waterY = rect.top + rect.height * (.56 + index * .035);
    final wave = Path();

    for (double x = rect.left + 12; x <= rect.right - 12; x += 8) {
      final y = waterY + math.sin((x / 18) + index) * 2.8;

      if (x == rect.left + 12) {
        wave.moveTo(x, y);
      } else {
        wave.lineTo(x, y);
      }
    }

    canvas.drawPath(wave, _stroke(.38, 1.55));

    // Cooling fins / lưới tản nhiệt.
    for (int i = 0; i < 5; i++) {
      final y = rect.top + rect.height * (.26 + i * .09);

      canvas.drawLine(
        Offset(rect.left + rect.width * .18, y),
        Offset(rect.right - rect.width * .18, y),
        softLine,
      );
    }

    // Level gauge bên hông tank.
    final gaugeX = rect.right - rect.width * .18;
    canvas.drawLine(
      Offset(gaugeX, rect.top + rect.height * .30),
      Offset(gaugeX, rect.bottom - rect.height * .18),
      softLine,
    );

    for (int i = 0; i < 5; i++) {
      final y = rect.top + rect.height * (.34 + i * .095);
      canvas.drawLine(Offset(gaugeX - 8, y), Offset(gaugeX + 8, y), softLine);
    }
  }

  void _drawWaterPressureHeader(Canvas canvas, Size size) {
    final y = size.height * .34;

    final mainPaint = _stroke(.17, 1.35);
    final glowPaint = _glow(.018, 5, 6);

    final path = Path()
      ..moveTo(-30, y)
      ..lineTo(size.width * .22, y)
      ..quadraticBezierTo(size.width * .28, y, size.width * .28, y + 38)
      ..lineTo(size.width * .45, y + 38)
      ..quadraticBezierTo(size.width * .51, y + 38, size.width * .51, y)
      ..lineTo(size.width + 30, y);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, mainPaint);

    // Đồng hồ áp lực nước lớn trên pipe chính.
    _drawLargeWaterPressureGauge(
      canvas,
      Offset(size.width * .34, y - 34),
      label: 'BAR',
    );

    // Pressure pulse marks.
    final markPaint = _stroke(.20, .95);

    for (double x = size.width * .10; x < size.width * .88; x += 92) {
      canvas.drawLine(Offset(x, y - 7), Offset(x + 18, y - 7), markPaint);
      canvas.drawLine(Offset(x + 6, y + 7), Offset(x + 24, y + 7), markPaint);
    }
  }

  void _drawLargeWaterPressureGauge(
    Canvas canvas,
    Offset center, {
    required String label,
  }) {
    final ring = _stroke(.20, 1.2);
    final glow = _glow(.020, 5, 6);
    final tick = _stroke(.13, .8);

    canvas.drawCircle(center, 15, glow);
    canvas.drawCircle(center, 15, ring);

    for (int i = 0; i <= 6; i++) {
      final a = -math.pi * .82 + i * math.pi * .27;
      final p1 = center + Offset(math.cos(a), math.sin(a)) * 10;
      final p2 = center + Offset(math.cos(a), math.sin(a)) * 13;

      canvas.drawLine(p1, p2, tick);
    }

    final needleAngle = -math.pi * .58;
    canvas.drawLine(
      center,
      center + Offset(math.cos(needleAngle), math.sin(needleAngle)) * 10,
      _stroke(.24, 1.15),
    );

    canvas.drawCircle(center, 2.2, Paint()..color = color.withOpacity(.22));

    // Chân gauge nối xuống pipe.
    canvas.drawLine(
      center + const Offset(0, 15),
      center + const Offset(0, 28),
      ring,
    );
  }

  void _drawWaterPumpIcon(Canvas canvas, Offset center) {
    final paint = _stroke(.17, 1.1);
    final glow = _glow(.018, 5, 6);

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 54, height: 30),
      const Radius.circular(8),
    );

    canvas.drawRRect(body, glow);
    canvas.drawRRect(body, paint);

    canvas.drawCircle(center + const Offset(-14, 0), 8, paint);

    canvas.drawLine(
      center + const Offset(-27, 0),
      center + const Offset(-48, 0),
      paint,
    );

    canvas.drawLine(
      center + const Offset(27, 0),
      center + const Offset(48, 0),
      paint,
    );

    // Motor fins.
    for (int i = 0; i < 4; i++) {
      final x = center.dx + 2 + i * 7;
      canvas.drawLine(
        Offset(x, center.dy - 11),
        Offset(x, center.dy + 11),
        _stroke(.10, .75),
      );
    }
  }

  /// Hệ ống nước dạng network, ít lặp hơn và nhìn có chiều sâu hơn.
  void _drawWaterPipeNetwork(Canvas canvas, Size size) {
    final mainGlow = _glow(.030, 7, 10);
    final mainLine = _stroke(.13, 1.25);
    final subLine = _stroke(.095, 1.0);

    final y1 = size.height * .24;
    final y2 = size.height * .48;
    final y3 = size.height * .72;

    final path1 = Path()
      ..moveTo(-40, y1)
      ..lineTo(size.width * .24, y1)
      ..quadraticBezierTo(size.width * .30, y1, size.width * .30, y1 + 42)
      ..lineTo(size.width * .52, y1 + 42)
      ..quadraticBezierTo(size.width * .58, y1 + 42, size.width * .58, y1)
      ..lineTo(size.width + 40, y1);

    final path2 = Path()
      ..moveTo(-40, y2)
      ..lineTo(size.width * .18, y2)
      ..quadraticBezierTo(size.width * .24, y2, size.width * .24, y2 - 38)
      ..lineTo(size.width * .44, y2 - 38)
      ..quadraticBezierTo(size.width * .50, y2 - 38, size.width * .50, y2)
      ..lineTo(size.width + 40, y2);

    final path3 = Path()
      ..moveTo(-40, y3)
      ..lineTo(size.width * .36, y3)
      ..quadraticBezierTo(size.width * .42, y3, size.width * .42, y3 - 34)
      ..lineTo(size.width * .70, y3 - 34)
      ..quadraticBezierTo(size.width * .76, y3 - 34, size.width * .76, y3)
      ..lineTo(size.width + 40, y3);

    for (final path in [path1, path2, path3]) {
      canvas.drawPath(path, mainGlow);
      canvas.drawPath(path, mainLine);
    }

    // Nhánh dọc nối các đường ống.
    final connectors = <Offset>[
      Offset(size.width * .18, y1),
      Offset(size.width * .30, y1 + 42),
      Offset(size.width * .50, y2),
      Offset(size.width * .68, y3 - 34),
    ];

    for (final p in connectors) {
      final path = Path()
        ..moveTo(p.dx, p.dy - 32)
        ..lineTo(p.dx, p.dy + 52);

      canvas.drawPath(path, _glow(.018, 5, 8));
      canvas.drawPath(path, subLine);
    }

    // Flow line bên trong ống.
    _drawPipeFlowLine(canvas, y1, size.width, phase: .0);
    _drawPipeFlowLine(canvas, y2, size.width, phase: 1.7);
    _drawPipeFlowLine(canvas, y3, size.width, phase: 3.1);

    // Van + joint + flange.
    _drawWaterValve(canvas, Offset(size.width * .30, y1 + 42));
    _drawWaterValve(canvas, Offset(size.width * .50, y2));
    _drawWaterValve(canvas, Offset(size.width * .76, y3));

    _drawPipeJoint(canvas, Offset(size.width * .24, y1));
    _drawPipeJoint(canvas, Offset(size.width * .58, y1));
    _drawPipeJoint(canvas, Offset(size.width * .24, y2 - 38));
    _drawPipeJoint(canvas, Offset(size.width * .42, y3 - 34));

    _drawPipeFlanges(canvas, y1, size.width, offset: 30);
    _drawPipeFlanges(canvas, y2, size.width, offset: 95);
    _drawPipeFlanges(canvas, y3, size.width, offset: 60);

    // Đồng hồ áp suất nhỏ.
    _drawWaterGauge(canvas, Offset(size.width * .62, y1 - 26));
    _drawWaterGauge(canvas, Offset(size.width * .38, y3 - 58));
  }

  void _drawPipeFlowLine(
    Canvas canvas,
    double y,
    double width, {
    required double phase,
  }) {
    final flowPaint = Paint()
      ..color = color.withOpacity(.17)
      ..strokeWidth = 1.15
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final flowGlow = Paint()
      ..color = color.withOpacity(.035)
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    final path = Path();

    for (double x = -30; x <= width + 30; x += 12) {
      final yy = y + math.sin((x / 34) + phase) * 4.8;

      if (x == -30) {
        path.moveTo(x, yy);
      } else {
        path.lineTo(x, yy);
      }
    }

    canvas.drawPath(path, flowGlow);
    canvas.drawPath(path, flowPaint);
  }

  /// Van tròn có tay xoay, vẽ nhỏ để không rối nền.
  void _drawWaterValve(Canvas canvas, Offset center) {
    final paint = _stroke(.13, 1.05);
    final glow = _glow(.022, 5, 8);

    canvas.drawCircle(center, 13, glow);
    canvas.drawCircle(center, 13, paint);

    for (int i = 0; i < 4; i++) {
      final a = i * math.pi / 2;

      canvas.drawLine(
        center + Offset(math.cos(a), math.sin(a)) * 3,
        center + Offset(math.cos(a), math.sin(a)) * 11,
        paint,
      );
    }

    canvas.drawCircle(center, 2.4, Paint()..color = color.withOpacity(.16));

    canvas.drawLine(
      center + const Offset(0, -13),
      center + const Offset(0, -24),
      paint,
    );

    canvas.drawLine(
      center + const Offset(-8, -24),
      center + const Offset(8, -24),
      paint,
    );
  }

  /// Joint/khớp nối ống.
  void _drawPipeJoint(Canvas canvas, Offset center) {
    final paint = _stroke(.105, .95);

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 24, height: 18),
      const Radius.circular(4),
    );

    canvas.drawRRect(rect, paint);

    canvas.drawLine(
      center + const Offset(-6, -9),
      center + const Offset(-6, 9),
      paint,
    );

    canvas.drawLine(
      center + const Offset(6, -9),
      center + const Offset(6, 9),
      paint,
    );
  }

  /// Mặt bích lặp theo ống, nhưng opacity nhẹ.
  void _drawPipeFlanges(
    Canvas canvas,
    double y,
    double width, {
    required double offset,
  }) {
    final paint = _stroke(.075, .85);

    for (double x = offset; x < width; x += 170) {
      canvas.drawLine(Offset(x, y - 11), Offset(x, y + 11), paint);

      canvas.drawLine(Offset(x + 6, y - 11), Offset(x + 6, y + 11), paint);
    }
  }

  /// Đồng hồ nhỏ trên pipe.
  void _drawWaterGauge(Canvas canvas, Offset center) {
    final paint = _stroke(.105, .9);

    canvas.drawCircle(center, 7, paint);

    canvas.drawLine(center, center + const Offset(3.5, -3.5), paint);

    canvas.drawLine(
      center + const Offset(0, 7),
      center + const Offset(0, 16),
      paint,
    );
  }

  /// Giọt nước và bubble rải nền, không đều để tự nhiên hơn.
  void _drawWaterDropsAndBubbles(Canvas canvas, Size size) {
    final bubblePaint = _stroke(.07, .85);

    for (double x = 72; x < size.width; x += 235) {
      for (double y = 88; y < size.height; y += 178) {
        canvas.drawCircle(Offset(x, y), 6.5, bubblePaint);
        canvas.drawCircle(Offset(x + 38, y + 28), 3.5, bubblePaint);
        canvas.drawCircle(Offset(x + 78, y - 20), 4.8, bubblePaint);
      }
    }

    final dropPaint = Paint()
      ..color = color.withOpacity(.055)
      ..style = PaintingStyle.fill;

    for (double x = 135; x < size.width; x += 290) {
      for (double y = 135; y < size.height; y += 220) {
        _drawMiniWaterDrop(canvas, Offset(x, y), 10, dropPaint);
      }
    }
  }

  void _drawMiniWaterDrop(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - r)
      ..cubicTo(
        center.dx - r * .68,
        center.dy - r * .20,
        center.dx - r * .52,
        center.dy + r * .72,
        center.dx,
        center.dy + r,
      )
      ..cubicTo(
        center.dx + r * .52,
        center.dy + r * .72,
        center.dx + r * .68,
        center.dy - r * .20,
        center.dx,
        center.dy - r,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  /// Vạch kỹ thuật nhẹ giống blueprint/water level marks.
  void _drawWaterLevelMarks(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(.055)
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (double x = 42; x < size.width; x += 220) {
      final top = size.height * .14;
      final bottom = size.height * .86;

      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);

      for (int i = 0; i < 8; i++) {
        final y = top + i * ((bottom - top) / 7);

        canvas.drawLine(
          Offset(x, y),
          Offset(x + (i.isEven ? 18 : 11), y),
          paint,
        );
      }
    }
  }

  // ============================================================
  // COMPRESSED AIR
  // ============================================================

  void _drawAir(Canvas canvas, Size size) {
    _drawAirFanWatermark(canvas, size);
    _drawAirStreamLines(canvas, size);
    _drawAirDuctNetwork(canvas, size);
  }

  void _drawAirFanWatermark(Canvas canvas, Size size) {
    final center = Offset(size.width * .84, size.height * .24);
    final radius = math.min(size.width, size.height) * .17;

    final ringPaint = _stroke(.10, 1.3);
    final fillPaint = Paint()
      ..color = color.withOpacity(.035)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawCircle(
      center,
      radius * .12,
      Paint()..color = color.withOpacity(.12),
    );

    for (int i = 0; i < 3; i++) {
      final a = -math.pi / 2 + i * math.pi * 2 / 3;

      final p1 =
          center + Offset(math.cos(a - .26), math.sin(a - .26)) * radius * .18;
      final p2 =
          center + Offset(math.cos(a + .18), math.sin(a + .18)) * radius * .78;
      final p3 =
          center + Offset(math.cos(a + .76), math.sin(a + .76)) * radius * .55;

      final blade = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(p3.dx, p3.dy, p2.dx, p2.dy);

      canvas.drawPath(blade, _stroke(.12, 1.4));
    }
  }

  void _drawAirStreamLines(Canvas canvas, Size size) {
    final paint = _stroke(.105, 1.05);
    final glow = _glow(.024, 5, 8);

    for (double y = 78; y < size.height + 80; y += 92) {
      final path = Path()..moveTo(-50, y);

      for (double x = -50; x < size.width + 100; x += 132) {
        path.cubicTo(x + 34, y - 24, x + 86, y + 24, x + 132, y);
      }

      canvas.drawPath(path, glow);
      canvas.drawPath(path, paint);
    }

    final arrowPaint = Paint()
      ..color = color.withOpacity(.11)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (double x = 100; x < size.width; x += 210) {
      for (double y = 80; y < size.height; y += 180) {
        canvas.drawLine(Offset(x, y), Offset(x + 18, y), arrowPaint);
        canvas.drawLine(Offset(x + 18, y), Offset(x + 12, y - 5), arrowPaint);
        canvas.drawLine(Offset(x + 18, y), Offset(x + 12, y + 5), arrowPaint);
      }
    }
  }

  void _drawAirDuctNetwork(Canvas canvas, Size size) {
    final ductPaint = _stroke(.085, 1);
    final machinePaint = _stroke(.12, 1.1);

    for (double y = 122; y < size.height; y += 180) {
      _drawDashedLine(
        canvas,
        Offset(-30, y),
        Offset(size.width + 30, y),
        ductPaint,
      );

      for (double x = 70; x < size.width; x += 260) {
        _drawCompressorIcon(canvas, Offset(x, y));
        _drawPressureGauge(canvas, Offset(x + 70, y - 20), machinePaint);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 9.0;
    const gap = 7.0;

    final total = (b - a).distance;
    final dir = (b - a) / total;

    double current = 0;

    while (current < total) {
      final start = a + dir * current;
      final end = a + dir * math.min(current + dash, total);

      canvas.drawLine(start, end, paint);

      current += dash + gap;
    }
  }

  void _drawCompressorIcon(Canvas canvas, Offset center) {
    final paint = _stroke(.12, 1.05);
    final glow = _glow(.025, 5, 8);

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 48, height: 26),
      const Radius.circular(8),
    );

    canvas.drawRRect(body, glow);
    canvas.drawRRect(body, paint);

    canvas.drawCircle(center + const Offset(-13, 0), 6, paint);
    canvas.drawCircle(center + const Offset(13, 0), 6, paint);

    canvas.drawLine(
      center + const Offset(-24, 0),
      center + const Offset(-42, 0),
      paint,
    );

    canvas.drawLine(
      center + const Offset(24, 0),
      center + const Offset(44, 0),
      paint,
    );
  }

  void _drawPressureGauge(Canvas canvas, Offset center, Paint paint) {
    canvas.drawCircle(center, 7, paint);
    canvas.drawLine(center, center + const Offset(3, -4), paint);
    canvas.drawLine(
      center + const Offset(0, 7),
      center + const Offset(0, 15),
      paint,
    );
  }

  // ============================================================
  // ANIMATED OVERLAYS - REAL UTILITY MOTION STYLE
  // ============================================================

  // ============================================================
  // ELECTRICITY MOTION
  // ============================================================
  double _electricProgressForRow(int row) {
    // Không nhân speed nhỏ hơn 1 ở đây.
    // Vì nếu speed < 1 thì progress không bao giờ chạy tới cuối path.
    const rowDelay = .045;

    return (t + row * rowDelay) % 1.0;
  }

  void _drawElectricMovingCurrent(Canvas canvas, Size size) {
    _drawActivatedTowersByCurrent(canvas, size);
    _drawElectricTravelingCurrent(canvas, size);

    // Dòng điện đi tới tháp lớn.
    _drawMainTowerCurrent(canvas, size);

    // Tháp lớn sáng khi điện tới.
    _drawMainTowerActivation(canvas, size);

    _drawCoronaAtInsulators(canvas, size);
    _drawRandomVoltageFlicker(canvas, size);
  }

  void _drawMainTowerActivation(Canvas canvas, Size size) {
    final progress = _electricProgressForRow(0);

    // Khi progress gần cuối dây thì tháp lớn sáng.
    final arrive = ((progress - .72) / .22).clamp(0.0, 1.0).toDouble();
    final leave = (1.0 - ((progress - .92) / .08).clamp(0.0, 1.0)).toDouble();

    final intensity = arrive * leave;

    if (intensity <= 0) return;

    final height = _mainTowerHeight(size);
    final width = _mainTowerWidth(size);
    final base = _mainTowerBase(size);

    _drawTowerElectricHalo(
      canvas,
      base: base,
      height: height,
      width: width,
      intensity: intensity,
    );

    _drawTransmissionTower(
      canvas,
      base: base,
      height: height,
      width: width,
      paint: _stroke(.060 + intensity * .26, 1.20 + intensity * .45),
      glowPaint: _glow(.008 + intensity * .060, 4.0 + intensity * 4.0, 5.0),
      detailOpacity: .050 + intensity * .24,
      topNodeOpacity: .060 + intensity * .34,
      opacityBoost: 1.0,
    );
  }

  void _drawMainTowerCurrent(Canvas canvas, Size size) {
    final progress = _electricProgressForRow(0);

    final outerGlow = Paint()
      ..color = color.withOpacity(.060)
      ..strokeWidth = 5.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);

    final glow = Paint()
      ..color = color.withOpacity(.16)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);

    final core = Paint()
      ..color = color.withOpacity(.68)
      ..strokeWidth = 1.35
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int lane = 0; lane < 3; lane++) {
      final path = _buildMainTowerFeederPath(size, lane: lane);

      for (final metric in path.computeMetrics()) {
        final len = metric.length;
        if (len <= 0) continue;

        final center = progress * len;

        // Dài hơn để thấy nó đi tới tận tháp lớn.
        const trailLen = 420.0;

        _drawWrappedMetricPart(
          canvas,
          metric,
          center - trailLen * .72,
          center + trailLen * .28,
          outerGlow,
        );

        _drawWrappedMetricPart(
          canvas,
          metric,
          center - trailLen * .58,
          center + trailLen * .22,
          glow,
        );

        _drawWrappedMetricPart(
          canvas,
          metric,
          center - trailLen * .44,
          center + trailLen * .16,
          core,
        );
      }
    }
  }

  Path _buildContinuousSaggingWirePath(List<Offset> points) {
    final path = Path();

    if (points.isEmpty) return path;

    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];

      final distance = (b - a).distance;
      final sag = math.min(18.0, distance * .08);

      final mid = Offset((a.dx + b.dx) / 2, math.max(a.dy, b.dy) + sag);

      path.quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
    }

    return path;
  }

  void _drawMetricPart(
    Canvas canvas,
    PathMetric metric,
    double start,
    double end,
    Paint paint,
  ) {
    final len = metric.length;
    if (len <= 0) return;

    final s = start.clamp(0.0, len).toDouble();
    final e = end.clamp(0.0, len).toDouble();

    if (e <= s) return;

    canvas.drawPath(metric.extractPath(s, e), paint);
  }

  void _drawWrappedMetricPart(
    Canvas canvas,
    PathMetric metric,
    double start,
    double end,
    Paint paint,
  ) {
    final len = metric.length;
    if (len <= 0) return;

    if (start < 0) {
      _drawMetricPart(canvas, metric, len + start, len, paint);
      _drawMetricPart(canvas, metric, 0, end, paint);
      return;
    }

    if (end > len) {
      _drawMetricPart(canvas, metric, start, len, paint);
      _drawMetricPart(canvas, metric, 0, end - len, paint);
      return;
    }

    _drawMetricPart(canvas, metric, start, end, paint);
  }

  void _drawElectricTravelingCurrent(Canvas canvas, Size size) {
    const stepX = 245.0;
    const stepY = 185.0;

    final rows = (size.height / stepY).ceil() + 2;
    final cols = (size.width / stepX).ceil() + 3;

    for (int row = -1; row < rows; row++) {
      final y = row * stepY + 150;
      final offsetX = row.isOdd ? stepX * .45 : 0.0;
      final h = row.isEven ? 88.0 : 76.0;
      final w = h * .42;

      final topWire = <Offset>[];
      final secondaryWire = <Offset>[];

      for (int col = -1; col < cols; col++) {
        final x = col * stepX + offsetX;

        topWire.add(Offset(x, y - h));

        secondaryWire.add(
          row.isEven
              ? Offset(x - w * .48, y - h * .74)
              : Offset(x + w * .48, y - h * .74),
        );
      }

      _drawCurrentOnContinuousWire(canvas, topWire, row: row, strong: true);

      // Chỉ vẽ dây phụ xen kẽ, giảm gần một nửa workload.
      if (row.isEven) {
        _drawCurrentOnContinuousWire(
          canvas,
          secondaryWire,
          row: row,
          strong: false,
        );
      }
    }
  }

  void _drawCurrentOnContinuousWire(
    Canvas canvas,
    List<Offset> points, {
    required int row,
    bool strong = false,
  }) {
    if (points.length < 2) return;

    final path = _buildContinuousSaggingWirePath(points);
    final metrics = path.computeMetrics();

    final progress = _electricProgressForRow(row);

    final glowPaint = Paint()
      ..color = color.withOpacity(strong ? .11 : .060)
      ..strokeWidth = strong ? 3.0 : 2.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);

    final corePaint = Paint()
      ..color = color.withOpacity(strong ? .68 : .40)
      ..strokeWidth = strong ? 1.2 : .85
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final trailLength = strong ? 320.0 : 250.0;

    for (final metric in metrics) {
      _drawCurrentMetric(
        canvas: canvas,
        metric: metric,
        progress: progress,
        trailLength: trailLength,
        glowPaint: glowPaint,
        corePaint: corePaint,
      );
    }
  }

  void _drawCurrentMetric({
    required Canvas canvas,
    required PathMetric metric,
    required double progress,
    required double trailLength,
    required Paint glowPaint,
    required Paint corePaint,
  }) {
    final length = metric.length;
    if (length <= 0) return;

    final center = progress * length;

    _drawWrappedMetricPart(
      canvas,
      metric,
      center - trailLength * .72,
      center + trailLength * .22,
      glowPaint,
    );

    _drawWrappedMetricPart(
      canvas,
      metric,
      center - trailLength * .42,
      center + trailLength * .12,
      corePaint,
    );
  }

  void _drawActivatedTowersByCurrent(Canvas canvas, Size size) {
    const stepX = 245.0;
    const stepY = 185.0;
    const activeRadius = 190.0;

    final rows = (size.height / stepY).ceil() + 2;
    final cols = (size.width / stepX).ceil() + 3;

    for (int row = -1; row < rows; row++) {
      final y = row * stepY + 150;
      final offsetX = row.isOdd ? stepX * .45 : 0.0;
      final progress = _electricProgressForRow(row);

      final firstX = -stepX + offsetX;
      final lastX = (cols - 1) * stepX + offsetX;
      final currentX = firstX + (lastX - firstX) * progress;

      for (int col = -1; col < cols; col++) {
        final x = col * stepX + offsetX;
        final distance = (x - currentX).abs();

        final raw = (1.0 - distance / activeRadius).clamp(0.0, 1.0).toDouble();

        if (raw <= .04) continue;

        final intensity = raw * raw * (3.0 - 2.0 * raw);
        final h = row.isEven ? 88.0 : 76.0;

        _drawLightweightTowerActivation(
          canvas,
          base: Offset(x, y),
          height: h,
          intensity: intensity,
        );
      }
    }
  }

  void _drawLightweightTowerActivation(
    Canvas canvas, {
    required Offset base,
    required double height,
    required double intensity,
  }) {
    final top = Offset(base.dx, base.dy - height);
    final center = Offset(base.dx, base.dy - height * .52);

    // Halo nhỏ, không dùng RadialGradient mỗi cột.
    final haloPaint = Paint()
      ..color = color.withOpacity(.025 * intensity)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawCircle(center, height * .26, haloPaint);

    // Chỉ sáng hai chân và trục giữa, không vẽ lại toàn bộ chi tiết.
    final highlightPaint = Paint()
      ..color = color.withOpacity(.12 + intensity * .34)
      ..strokeWidth = 1.0 + intensity * .65
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final halfWidth = height * .42 * .46;

    final path = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(base.dx - halfWidth, base.dy)
      ..moveTo(top.dx, top.dy)
      ..lineTo(base.dx + halfWidth, base.dy)
      ..moveTo(top.dx, top.dy)
      ..lineTo(base.dx, base.dy - height * .08);

    canvas.drawPath(path, highlightPaint);

    final nodePaint = Paint()
      ..color = color.withOpacity(.20 + intensity * .48)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(top, 1.6 + intensity * 1.4, nodePaint);
  }

  void _drawTowerElectricHalo(
    Canvas canvas, {
    required Offset base,
    required double height,
    required double width,
    required double intensity,
  }) {
    final center = Offset(base.dx, base.dy - height * .52);

    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(.030 * intensity),
          color.withOpacity(.010 * intensity),
          Colors.transparent,
        ],
        stops: const [0, .36, 1],
      ).createShader(Rect.fromCircle(center: center, radius: height * .42));

    canvas.drawCircle(center, height * .42, haloPaint);
  }

  void _drawCoronaAtInsulators(Canvas canvas, Size size) {
    const stepX = 245.0;
    const stepY = 185.0;

    final rows = (size.height / stepY).ceil() + 2;
    final cols = (size.width / stepX).ceil() + 3;

    final coronaPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    for (int row = -1; row < rows; row++) {
      // Chỉ vẽ corona ở hàng xen kẽ.
      if (row.isOdd) continue;

      final y = row * stepY + 150;
      final offsetX = row.isOdd ? stepX * .45 : 0.0;
      final h = row.isEven ? 88.0 : 76.0;
      final w = h * .42;

      final progress = _electricProgressForRow(row);

      final firstX = -stepX + offsetX;
      final lastX = (cols - 1) * stepX + offsetX;
      final currentX = firstX + (lastX - firstX) * progress;

      for (int col = -1; col < cols; col++) {
        final x = col * stepX + offsetX;

        final nearCurrent = (1.0 - (x - currentX).abs() / 170.0)
            .clamp(0.0, 1.0)
            .toDouble();

        if (nearCurrent < .25) continue;

        final topY = y - h;
        final armY = topY + h * .32;

        final points = <Offset>[
          Offset(x - w * .58, armY + 9),
          Offset(x + w * .58, armY + 9),
        ];

        for (int i = 0; i < points.length; i++) {
          final phase = (t + row * .09 + col * .07 + i * .13) % 1.0;
          final shimmer = .5 + math.sin(phase * math.pi * 2) * .5;
          final strength = nearCurrent * shimmer;

          if (strength < .35) continue;

          coronaPaint
            ..color = color.withOpacity(.025 + .055 * strength)
            ..strokeWidth = .65 + strength * .55;

          canvas.drawCircle(points[i], 3.0 + strength * 2.8, coronaPaint);
        }
      }
    }
  }

  void _drawRandomVoltageFlicker(Canvas canvas, Size size) {
    final flickerPaint = Paint()
      ..color = color.withOpacity(.14)
      ..strokeWidth = .9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);

    for (double x = 90; x < size.width; x += 280) {
      for (double y = 76; y < size.height; y += 240) {
        final phase = (t + x * .0017 + y * .0021) % 1;
        final visible = math.sin(phase * math.pi * 2);

        if (visible < .82) continue;

        final path = Path()
          ..moveTo(x, y)
          ..lineTo(x + 9, y - 7)
          ..lineTo(x + 4, y + 5)
          ..lineTo(x + 15, y - 2);

        canvas.drawPath(path, flickerPaint);
      }
    }
  }

  // ============================================================
  // WATER MOTION
  // ============================================================

  void _drawWaterFlowOnPipe(
    Canvas canvas,
    Path pipePath, {
    required double phase,
  }) {
    final metrics = pipePath.computeMetrics().toList();

    final glowPaint = Paint()
      ..color = color.withOpacity(.16)
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    final flowPaint = Paint()
      ..color = color.withOpacity(.48)
      ..strokeWidth = 2.25
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final headPaint = Paint()
      ..color = color.withOpacity(.55)
      ..style = PaintingStyle.fill;

    for (final metric in metrics) {
      final length = metric.length;
      if (length <= 0) continue;

      for (int i = 0; i < 3; i++) {
        final local = ((phase + i / 3) % 1.0);
        final center = local * length;

        final segLength = math.min(110.0, length * .24);

        final start = (center - segLength / 2).clamp(0.0, length);
        final end = (center + segLength / 2).clamp(0.0, length);

        if (end <= start) continue;

        final extract = metric.extractPath(start, end);

        canvas.drawPath(extract, glowPaint);
        canvas.drawPath(extract, flowPaint);

        final tangent = metric.getTangentForOffset(end);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, 3.0, headPaint);
        }
      }
    }
  }

  void _drawWaterMovingFlow(Canvas canvas, Size size) {
    // Nước: highlight dòng chảy chạy bên trong đúng network ống.
    // Không vẽ ngoài ống.
    final y1 = size.height * .24;
    final y2 = size.height * .48;
    final y3 = size.height * .72;

    final path1 = Path()
      ..moveTo(-40, y1)
      ..lineTo(size.width * .24, y1)
      ..quadraticBezierTo(size.width * .30, y1, size.width * .30, y1 + 42)
      ..lineTo(size.width * .52, y1 + 42)
      ..quadraticBezierTo(size.width * .58, y1 + 42, size.width * .58, y1)
      ..lineTo(size.width + 40, y1);

    final path2 = Path()
      ..moveTo(-40, y2)
      ..lineTo(size.width * .18, y2)
      ..quadraticBezierTo(size.width * .24, y2, size.width * .24, y2 - 38)
      ..lineTo(size.width * .44, y2 - 38)
      ..quadraticBezierTo(size.width * .50, y2 - 38, size.width * .50, y2)
      ..lineTo(size.width + 40, y2);

    final path3 = Path()
      ..moveTo(-40, y3)
      ..lineTo(size.width * .36, y3)
      ..quadraticBezierTo(size.width * .42, y3, size.width * .42, y3 - 34)
      ..lineTo(size.width * .70, y3 - 34)
      ..quadraticBezierTo(size.width * .76, y3 - 34, size.width * .76, y3)
      ..lineTo(size.width + 40, y3);

    _drawWaterFlowOnPipe(canvas, path1, phase: t);
    _drawWaterFlowOnPipe(canvas, path2, phase: (t + .33) % 1);
    _drawWaterFlowOnPipe(canvas, path3, phase: (t + .66) % 1);

    _drawCoolingTankSystemMotion(canvas, size);
  }

  // ============================================================
  // COMPRESSED AIR MOTION
  // ============================================================

  void _drawCompressedAirPressurePulses(Canvas canvas, Size size) {
    final pulsePaint = Paint()
      ..color = color.withOpacity(.24)
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pulseGlow = Paint()
      ..color = color.withOpacity(.065)
      ..strokeWidth = 5.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    // Theo duct network hiện tại: các đường y = 122, 302, ...
    for (double y = 122; y < size.height; y += 180) {
      final speed = (t * 340 + y * .23) % 180;

      for (double x = -180; x < size.width + 180; x += 180) {
        final cx = x + speed;

        // Xung áp suất là cụm 3 vạch ngắn, không phải mũi tên.
        for (int i = 0; i < 3; i++) {
          final dx = i * 13.0;

          final a = Offset(cx - dx, y);
          final b = Offset(cx - dx + 7, y);

          canvas.drawLine(a, b, pulseGlow);
          canvas.drawLine(a, b, pulsePaint);
        }
      }
    }

    // Một số sóng áp suất dạng vòng nhỏ quanh compressor.
    for (double y = 122; y < size.height; y += 180) {
      for (double x = 70; x < size.width; x += 260) {
        final phase = (t + x * .002 + y * .001) % 1;
        final r = 12 + phase * 18;

        final ringPaint = Paint()
          ..color = color.withOpacity((1 - phase) * .075)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;

        canvas.drawCircle(Offset(x, y), r, ringPaint);
      }
    }
  }

  void _drawCompressorVibration(Canvas canvas, Size size) {
    final vib = math.sin(t * math.pi * 2 * 5) * 1.3;

    final vibPaint = Paint()
      ..color = color.withOpacity(.09)
      ..strokeWidth = .9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (double y = 122; y < size.height; y += 180) {
      for (double x = 70; x < size.width; x += 260) {
        final c = Offset(x + vib, y);

        canvas.drawLine(
          c + const Offset(-30, -18),
          c + const Offset(-38, -24),
          vibPaint,
        );
        canvas.drawLine(
          c + const Offset(30, -18),
          c + const Offset(38, -24),
          vibPaint,
        );
        canvas.drawLine(
          c + const Offset(-30, 18),
          c + const Offset(-38, 24),
          vibPaint,
        );
        canvas.drawLine(
          c + const Offset(30, 18),
          c + const Offset(38, 24),
          vibPaint,
        );
      }
    }
  }

  void _drawGaugeNeedleVibration(Canvas canvas, Size size) {
    final needlePaint = Paint()
      ..color = color.withOpacity(.18)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (double y = 122; y < size.height; y += 180) {
      for (double x = 70; x < size.width; x += 260) {
        final center = Offset(x + 70, y - 20);

        final angle = -math.pi / 2.6 + math.sin(t * math.pi * 2 * 3 + x) * .22;
        final end = center + Offset(math.cos(angle), math.sin(angle)) * 6;

        canvas.drawLine(center, end, needlePaint);
      }
    }
  }

  void _drawAirMovingFlow(Canvas canvas, Size size) {
    // Khí nén: không vẽ nước/sóng mềm.
    // Nên là các xung áp suất ngắn, nét đứt, chạy nhanh trong ống.
    _drawCompressedAirPressurePulses(canvas, size);
    _drawCompressorVibration(canvas, size);
    _drawGaugeNeedleVibration(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _UtilityPremiumBackgroundPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.type != type ||
        oldDelegate.drawStatic != drawStatic ||
        oldDelegate.drawMotion != drawMotion;
  }
}
