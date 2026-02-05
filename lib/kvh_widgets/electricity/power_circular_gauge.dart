import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../common/animated_gauge_card.dart';
import '../../common/gauge_center_text.dart';
import '../../model/facility_filtered.dart';
import '../../model/signal.dart';

class PowerCircularGauge extends StatefulWidget {
  final FacilityFiltered facility;
  final double maxPower;

  const PowerCircularGauge({
    super.key,
    required this.facility,
    this.maxPower = 3000,
  });

  @override
  State<PowerCircularGauge> createState() => _PowerCircularGaugeState();
}

class _PowerCircularGaugeState extends State<PowerCircularGauge>
    with SingleTickerProviderStateMixin {
  static const _animDuration = Duration(seconds: 2);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _animDuration,
  );

  late final Animation<double> _anim = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  double _lastValue = double.nan;
  double _lastMax = double.nan;

  @override
  void initState() {
    super.initState();
    _syncLastFromWidget(); // set baseline
    _controller.forward(); // animate lần đầu
  }

  @override
  void didUpdateWidget(covariant PowerCircularGauge oldWidget) {
    super.didUpdateWidget(oldWidget);

    final currentValue = _currentPowerValue();
    final currentMax = widget.maxPower;

    // ✅ chỉ animate khi value/max đổi thật
    if (currentValue != _lastValue || currentMax != _lastMax) {
      _controller.forward(from: 0);
      _lastValue = currentValue;
      _lastMax = currentMax;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _currentPowerValue() {
    final signal = _pickPowerSignal(widget.facility);
    return (signal.value ?? 0.0);
  }

  void _syncLastFromWidget() {
    _lastValue = _currentPowerValue();
    _lastMax = widget.maxPower;
  }

  @override
  Widget build(BuildContext context) {
    final powerSignal = _pickPowerSignal(widget.facility);
    final powerValue = (powerSignal.value ?? 0.0);
    final percent = (powerValue / widget.maxPower).clamp(0.0, 1.0);

    final color = _colorForPercent(percent);
    final status = _statusForPercent(percent);

    final gauge = Padding(
      padding: const EdgeInsets.all(8),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final p = percent * _anim.value;
          return CustomPaint(
            painter: CircularGaugePainter(percent: p, color: color),
            child: Center(
              child: GaugeCenterText(
                value: powerValue,
                unit: powerSignal.unit,
                percent: percent,
                color: color,
              ),
            ),
          );
        },
      ),
    );

    return AnimatedGaugeCard(
      gauge: gauge,
      statusColor: color,
      statusText: status,
    );
  }

  // =========================
  // Helpers
  // =========================

  Signal _pickPowerSignal(FacilityFiltered facility) {
    return facility.signals.firstWhere(
          (s) =>
      (s.position == 'P1 Cabinets') ||
          s.description.toLowerCase().contains('electricity'),
      orElse: _mockSignal,
    );
  }

  Signal _mockSignal() => Signal(
    plcAddress: '',
    description: 'Mock Power',
    shortName: 'PWR',
    value: 0.0,
    unit: 'kW',
    dataType: 'Float',
    position: '',
    dateadd: DateTime.now(),
    fullName: 'Mock',
  );

  Color _colorForPercent(double percent) {
    if (percent < 0.3) return Colors.greenAccent;
    if (percent < 0.7) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _statusForPercent(double percent) {
    if (percent < 0.3) return 'LOW';
    if (percent < 0.7) return 'NORMAL';
    return 'HIGH';
  }
}

// =========================
// Painter (giữ nguyên)
// =========================

class CircularGaugePainter extends CustomPainter {
  static const double _startAngle = math.pi * 0.75;
  static const double _sweepAngle = math.pi * 1.5;
  static const double _strokeWidth = 12.0;

  final double percent; // 0..1
  final Color color;

  CircularGaugePainter({
    required this.percent,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = _strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _startAngle, _sweepAngle, false, bgPaint);

    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.6), color],
      ).createShader(rect)
      ..strokeWidth = _strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweep = _sweepAngle * percent;
    canvas.drawArc(rect, _startAngle, sweep, false, progressPaint);

    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = _strokeWidth + 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawArc(rect, _startAngle, sweep, false, glowPaint);

    _drawTickMarks(canvas, center, radius);
  }

  void _drawTickMarks(Canvas canvas, Offset center, double radius) {
    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 2;

    for (int i = 0; i <= 10; i++) {
      final angle = _startAngle + (_sweepAngle * i / 10);
      final startRadius = radius - 8;
      final endRadius = radius + 8;

      final start = Offset(
        center.dx + startRadius * math.cos(angle),
        center.dy + startRadius * math.sin(angle),
      );
      final end = Offset(
        center.dx + endRadius * math.cos(angle),
        center.dy + endRadius * math.sin(angle),
      );

      canvas.drawLine(start, end, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CircularGaugePainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.color != color;
  }
}
