import 'dart:math' as math;

import 'package:flutter/material.dart';

class FactoryCampusMap extends StatelessWidget {
  final double progress;

  const FactoryCampusMap({super.key, this.progress = 0});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: FactoryCampusPainter(progress: progress),
      size: Size.infinite,
    );
  }
}

class FactoryCampusPainter extends CustomPainter {
  final double progress;

  FactoryCampusPainter({this.progress = 0});

  static const double baseW = 1000;
  static const double baseH = 640;

  final Color grass = const Color(0xff5f7f3a);
  final Color grassDark = const Color(0xff355c2c);
  final Color road = const Color(0xff52605d);
  final Color roadEdge = const Color(0xffd7ded7);
  final Color buildingWall = const Color(0xffdfe8e9);
  final Color buildingSide = const Color(0xffb8c8ca);
  final Color roofBlue = const Color(0xff3d7ea3);
  final Color roofDark = const Color(0xff285f81);
  final Color window = const Color(0xff355b66);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / baseW;
    final sy = size.height / baseH;

    canvas.save();
    canvas.scale(sx, sy);

    _drawGrass(canvas);
    _drawRoads(canvas);
    _drawSidewalks(canvas);
    _drawBuildings(canvas);
    _drawGateBridge(canvas);
    _drawZebraCrossings(canvas);
    _drawTrees(canvas);
    _drawSmallDetails(canvas);
    _drawSunHighlight(canvas);

    canvas.restore();
  }

  void _drawGrass(Canvas canvas) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff6f8f45), Color(0xff4f7337), Color(0xff31542d)],
      ).createShader(const Rect.fromLTWH(0, 0, baseW, baseH));

    canvas.drawRect(const Rect.fromLTWH(0, 0, baseW, baseH), bg);

    final grid = Paint()
      ..color = Colors.white.withOpacity(.025)
      ..strokeWidth = 1;

    for (double x = 0; x < baseW; x += 80) {
      canvas.drawLine(Offset(x, 0), Offset(x - 80, baseH), grid);
    }
  }

  void _drawRoads(Canvas canvas) {
    final roadPaint = Paint()..color = road;

    // Đường ngang phía trên.
    final topRoad = Path()
      ..moveTo(0, 45)
      ..lineTo(baseW, 45)
      ..lineTo(baseW, 112)
      ..lineTo(0, 112)
      ..close();

    canvas.drawPath(topRoad, roadPaint);

    // Đường chính giữa.
    final mainRoad = Path()
      ..moveTo(390, 0)
      ..quadraticBezierTo(390, 82, 430, 112)
      ..lineTo(482, 150)
      ..quadraticBezierTo(505, 168, 505, 205)
      ..lineTo(505, baseH)
      ..lineTo(620, baseH)
      ..lineTo(620, 210)
      ..quadraticBezierTo(620, 168, 655, 135)
      ..lineTo(700, 95)
      ..quadraticBezierTo(725, 70, 725, 0)
      ..close();

    canvas.drawPath(mainRoad, roadPaint);

    // Đường chéo góc trái dưới.
    final diagonal = Path()
      ..moveTo(0, 520)
      ..lineTo(285, baseH)
      ..lineTo(210, baseH)
      ..lineTo(0, 585)
      ..close();

    canvas.drawPath(diagonal, Paint()..color = road.withOpacity(.92));

    // Đường phụ vào các block phải.
    final rightRoad = Path()
      ..moveTo(620, 225)
      ..lineTo(830, 225)
      ..lineTo(830, 268)
      ..lineTo(620, 268)
      ..close();

    canvas.drawPath(rightRoad, Paint()..color = road.withOpacity(.72));

    // Đường biên trắng/xám.
    final edge = Paint()
      ..color = roadEdge.withOpacity(.65)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(topRoad, edge);
    canvas.drawPath(mainRoad, edge);
    canvas.drawPath(diagonal, edge);
  }

  void _drawSidewalks(Canvas canvas) {
    final p = Paint()
      ..color = const Color(0xffd9ded5).withOpacity(.80)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(335, 110), const Offset(335, 420), p);
    canvas.drawLine(const Offset(645, 145), const Offset(645, 445), p);
    canvas.drawLine(const Offset(705, 135), const Offset(900, 135), p);
    canvas.drawLine(const Offset(180, 510), const Offset(360, 585), p);

    final thin = Paint()
      ..color = Colors.white.withOpacity(.35)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(335, 110), const Offset(335, 420), thin);
    canvas.drawLine(const Offset(645, 145), const Offset(645, 445), thin);
  }

  void _drawBuildings(Canvas canvas) {
    // Nhà lớn bên trái.
    _drawFactoryBuilding(
      canvas,
      roof: const Rect.fromLTWH(75, 130, 250, 250),
      depth: 58,
      roofLabel: '',
      frontWindows: true,
    );

    // Nhà lớn phía phải trên.
    _drawFactoryBuilding(
      canvas,
      roof: const Rect.fromLTWH(565, 175, 285, 150),
      depth: 50,
      roofLabel: '',
      frontWindows: true,
    );

    // Nhà nhỏ phía sau trên bên phải.
    _drawFactoryBuilding(
      canvas,
      roof: const Rect.fromLTWH(615, 140, 215, 75),
      depth: 34,
      roofLabel: '',
      frontWindows: false,
    );

    // Nhà dài phía dưới phải.
    _drawFactoryBuilding(
      canvas,
      roof: const Rect.fromLTWH(555, 385, 315, 135),
      depth: 48,
      roofLabel: '',
      frontWindows: true,
    );

    // Nhà nhỏ giữa.
    _drawFactoryBuilding(
      canvas,
      roof: const Rect.fromLTWH(495, 365, 48, 112),
      depth: 36,
      roofLabel: '',
      frontWindows: true,
      roofColor: const Color(0xfff2f1e8),
    );

    // Nhà nhỏ dưới giữa.
    _drawFactoryBuilding(
      canvas,
      roof: const Rect.fromLTWH(545, 540, 130, 95),
      depth: 42,
      roofLabel: '',
      frontWindows: false,
    );

    // Một phần nhà bên phải ngoài màn.
    _drawFactoryBuilding(
      canvas,
      roof: const Rect.fromLTWH(920, 300, 170, 95),
      depth: 42,
      roofLabel: '',
      frontWindows: true,
      roofColor: const Color(0xffebe7dd),
    );

    _drawFactoryBuilding(
      canvas,
      roof: const Rect.fromLTWH(920, 470, 170, 95),
      depth: 42,
      roofLabel: '',
      frontWindows: true,
      roofColor: const Color(0xffebe7dd),
    );
  }

  void _drawFactoryBuilding(
    Canvas canvas, {
    required Rect roof,
    required double depth,
    required String roofLabel,
    bool frontWindows = true,
    Color? roofColor,
  }) {
    final shadow = Paint()
      ..color = Colors.black.withOpacity(.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        roof.shift(Offset(10, depth + 12)),
        const Radius.circular(4),
      ),
      shadow,
    );

    // Mặt trước.
    final front = Path()
      ..moveTo(roof.left, roof.bottom)
      ..lineTo(roof.right, roof.bottom)
      ..lineTo(roof.right - 8, roof.bottom + depth)
      ..lineTo(roof.left - 8, roof.bottom + depth)
      ..close();

    canvas.drawPath(front, Paint()..color = buildingWall);

    // Mặt cạnh phải.
    final side = Path()
      ..moveTo(roof.right, roof.top)
      ..lineTo(roof.right + 10, roof.top + 10)
      ..lineTo(roof.right - 8, roof.bottom + depth)
      ..lineTo(roof.right, roof.bottom)
      ..close();

    canvas.drawPath(side, Paint()..color = buildingSide);

    // Mái.
    final roofPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [roofColor ?? roofBlue, roofColor ?? roofDark],
      ).createShader(roof);

    canvas.drawRRect(
      RRect.fromRectAndRadius(roof, const Radius.circular(4)),
      roofPaint,
    );

    // Viền mái.
    canvas.drawRRect(
      RRect.fromRectAndRadius(roof, const Radius.circular(4)),
      Paint()
        ..color = Colors.white.withOpacity(.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(roof.inflate(3), const Radius.circular(5)),
      Paint()
        ..color = const Color(0xff1e5f86).withOpacity(.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Sọc mái tôn.
    final roofLine = Paint()
      ..color = Colors.white.withOpacity(.08)
      ..strokeWidth = 1;

    for (double y = roof.top + 12; y < roof.bottom - 8; y += 8) {
      canvas.drawLine(
        Offset(roof.left + 8, y),
        Offset(roof.right - 8, y),
        roofLine,
      );
    }

    if (frontWindows) {
      _drawWindowsOnFront(canvas, roof, depth);
    }
  }

  void _drawWindowsOnFront(Canvas canvas, Rect roof, double depth) {
    final frontY = roof.bottom + depth * .25;

    final windowPaint = Paint()
      ..color = window.withOpacity(.75)
      ..style = PaintingStyle.fill;

    final stroke = Paint()
      ..color = Colors.white.withOpacity(.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final count = math.max(2, (roof.width / 65).floor());

    for (int i = 0; i < count; i++) {
      final w = math.min(44.0, roof.width / count * .62);
      final x = roof.left + 18 + i * ((roof.width - 36) / count);

      final rect = Rect.fromLTWH(x, frontY, w, depth * .42);

      canvas.drawRect(rect, windowPaint);
      canvas.drawRect(rect, stroke);

      canvas.drawLine(
        Offset(rect.center.dx, rect.top),
        Offset(rect.center.dx, rect.bottom),
        stroke,
      );

      canvas.drawLine(
        Offset(rect.left, rect.center.dy),
        Offset(rect.right, rect.center.dy),
        stroke,
      );
    }
  }

  void _drawGateBridge(Canvas canvas) {
    final bridge = Rect.fromLTWH(315, 275, 275, 30);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bridge.shift(const Offset(4, 5)),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.black.withOpacity(.25),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(bridge, const Radius.circular(4)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffffffff), Color(0xffdbe4e7)],
        ).createShader(bridge),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(bridge, const Radius.circular(4)),
      Paint()
        ..color = Colors.black.withOpacity(.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    _drawMisumiMark(canvas, bridge.center);
  }

  void _drawMisumiMark(Canvas canvas, Offset center) {
    // Icon nhỏ trước chữ.
    final iconCenter = center + const Offset(-55, 0);

    final iconPaint1 = Paint()..color = const Color(0xfffacc15);
    final iconPaint2 = Paint()..color = const Color(0xff2563eb);

    final p1 = Path()
      ..moveTo(iconCenter.dx - 8, iconCenter.dy - 6)
      ..lineTo(iconCenter.dx, iconCenter.dy - 11)
      ..lineTo(iconCenter.dx + 8, iconCenter.dy - 6)
      ..lineTo(iconCenter.dx, iconCenter.dy)
      ..close();

    final p2 = Path()
      ..moveTo(iconCenter.dx - 8, iconCenter.dy - 6)
      ..lineTo(iconCenter.dx, iconCenter.dy)
      ..lineTo(iconCenter.dx, iconCenter.dy + 10)
      ..lineTo(iconCenter.dx - 8, iconCenter.dy + 4)
      ..close();

    final p3 = Path()
      ..moveTo(iconCenter.dx + 8, iconCenter.dy - 6)
      ..lineTo(iconCenter.dx, iconCenter.dy)
      ..lineTo(iconCenter.dx, iconCenter.dy + 10)
      ..lineTo(iconCenter.dx + 8, iconCenter.dy + 4)
      ..close();

    canvas.drawPath(p1, iconPaint1);
    canvas.drawPath(p2, iconPaint2);
    canvas.drawPath(p3, iconPaint2..color = const Color(0xff1d4ed8));

    final tp = TextPainter(
      text: const TextSpan(
        text: 'MISUMI',
        style: TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, center + Offset(-tp.width / 2 + 12, -tp.height / 2));
  }

  void _drawZebraCrossings(Canvas canvas) {
    final p = Paint()
      ..color = Colors.white.withOpacity(.80)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square;

    // Zebra trên đường ngang phía trên.
    for (int i = 0; i < 7; i++) {
      final x = 405 + i * 7.0;
      canvas.drawLine(Offset(x, 62), Offset(x + 7, 95), p);
    }

    for (int i = 0; i < 7; i++) {
      final x = 555 + i * 7.0;
      canvas.drawLine(Offset(x, 62), Offset(x + 7, 95), p);
    }

    // Zebra giữa.
    for (int i = 0; i < 8; i++) {
      final x = 430 + i * 9.0;
      canvas.drawLine(Offset(x, 132), Offset(x + 8, 132), p);
    }
  }

  void _drawTrees(Canvas canvas) {
    final treePositions = <Offset>[
      const Offset(55, 45),
      const Offset(145, 35),
      const Offset(220, 100),
      const Offset(300, 105),
      const Offset(70, 410),
      const Offset(118, 460),
      const Offset(190, 505),
      const Offset(270, 535),
      const Offset(365, 395),
      const Offset(365, 465),
      const Offset(510, 330),
      const Offset(525, 535),
      const Offset(690, 70),
      const Offset(735, 85),
      const Offset(790, 80),
      const Offset(840, 82),
      const Offset(895, 85),
      const Offset(955, 92),
      const Offset(655, 145),
      const Offset(710, 145),
      const Offset(760, 145),
      const Offset(830, 145),
      const Offset(900, 150),
      const Offset(940, 420),
      const Offset(955, 520),
      const Offset(885, 560),
      const Offset(765, 560),
      const Offset(690, 560),
    ];

    for (int i = 0; i < treePositions.length; i++) {
      _drawTree(canvas, treePositions[i], radius: 12 + (i % 4) * 2.0);
    }
  }

  void _drawTree(Canvas canvas, Offset center, {required double radius}) {
    final shadow = Paint()
      ..color = Colors.black.withOpacity(.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(radius * .55, radius * .55),
        width: radius * 2.2,
        height: radius * 1.3,
      ),
      shadow,
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xff6da544), const Color(0xff2f6b2f)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    canvas.drawCircle(
      center + Offset(-radius * .25, -radius * .25),
      radius * .45,
      Paint()..color = Colors.white.withOpacity(.10),
    );
  }

  void _drawSmallDetails(Canvas canvas) {
    // Sân bê tông quanh nhà.
    final concrete = Paint()..color = const Color(0xffd8ddd7).withOpacity(.55);

    canvas.drawRect(const Rect.fromLTWH(525, 130, 380, 25), concrete);
    canvas.drawRect(const Rect.fromLTWH(520, 330, 390, 32), concrete);
    canvas.drawRect(const Rect.fromLTWH(135, 385, 190, 22), concrete);
    canvas.drawRect(const Rect.fromLTWH(570, 520, 220, 22), concrete);

    // Cửa loading dock.
    final dock = Paint()..color = const Color(0xff1f2937).withOpacity(.65);

    canvas.drawRect(const Rect.fromLTWH(145, 380, 48, 38), dock);
    canvas.drawRect(const Rect.fromLTWH(205, 382, 38, 36), dock);
    canvas.drawRect(const Rect.fromLTWH(660, 325, 60, 22), dock);
    canvas.drawRect(const Rect.fromLTWH(648, 520, 36, 25), dock);

    // Đường line nhẹ trên đường.
    final lane = Paint()
      ..color = Colors.white.withOpacity(.20)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (double y = 160; y < 610; y += 42) {
      canvas.drawLine(Offset(562, y), Offset(562, y + 20), lane);
    }
  }

  void _drawSunHighlight(Canvas canvas) {
    final x = -220 + progress * 1400;

    final shine = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(.11),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(x, 0, 180, baseH));

    canvas.drawRect(Rect.fromLTWH(x, 0, 180, baseH), shine);
  }

  @override
  bool shouldRepaint(covariant FactoryCampusPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
