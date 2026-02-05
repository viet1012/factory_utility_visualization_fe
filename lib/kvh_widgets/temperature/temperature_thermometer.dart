import 'package:flutter/material.dart';

import '../../common/animated_gauge_card.dart';
import '../../model/facility_data.dart';

class TemperatureThermometer extends StatefulWidget {
  final FacilityData facility;
  final double minTemp;
  final double maxTemp;

  const TemperatureThermometer({
    super.key,
    required this.facility,
    this.minTemp = -10,
    this.maxTemp = 80,
  });

  @override
  State<TemperatureThermometer> createState() => _TemperatureThermometerState();
}

class _TemperatureThermometerState extends State<TemperatureThermometer>
    with SingleTickerProviderStateMixin {
  static const _animDuration = Duration(milliseconds: 700);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _animDuration,
  );

  late final Animation<double> _anim = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  double _lastTemp = double.nan;

  @override
  void initState() {
    super.initState();
    _lastTemp = widget.facility.temperature;
    _controller.forward(); // animate lần đầu
  }

  @override
  void didUpdateWidget(covariant TemperatureThermometer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final t = widget.facility.temperature;
    if (t != _lastTemp) {
      _controller.forward(from: 0);
      _lastTemp = t;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.facility.temperature;

    final pct = ((t - widget.minTemp) / (widget.maxTemp - widget.minTemp))
        .clamp(0.0, 1.0);

    final color = _colorForTempPct(pct);
    final status = _statusText(t);

    final gauge = AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final animatedPct = pct * _anim.value;

        return CustomPaint(
          painter: _ThermometerPainter(
            percentage: animatedPct,
            color: color,
            minTemp: widget.minTemp,
            maxTemp: widget.maxTemp,
            currentTemp: t,
          ),
          child: Center(
            child: _ThermoCenterText(
              temp: t,
              status: status,
              color: color,
            ),
          ),
        );
      },
    );

    return AnimatedGaugeCard(
      gauge: Padding(
        padding: const EdgeInsets.all(8),
        child: gauge,
      ),
      statusColor: color,
      statusText: status,
    );
  }

  Color _colorForTempPct(double pct) {
    if (pct <= 0.3) return Colors.lightBlueAccent;
    if (pct <= 0.7) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _statusText(double t) {
    if (t < 10) return 'COLD';
    if (t < 30) return 'COMFORT';
    if (t < 45) return 'WARM';
    return 'HOT';
  }
}

class _ThermoCenterText extends StatelessWidget {
  final double temp;
  final String status;
  final Color color;

  const _ThermoCenterText({
    required this.temp,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${temp.toStringAsFixed(1)}°C',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          status,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// =========================
// Painter (giữ gần như nguyên)
// =========================

class _ThermometerPainter extends CustomPainter {
  final double percentage; // 0..1
  final Color color;
  final double minTemp;
  final double maxTemp;
  final double currentTemp;

  _ThermometerPainter({
    required this.percentage,
    required this.color,
    required this.minTemp,
    required this.maxTemp,
    required this.currentTemp,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintOutline = Paint()
      ..color = Colors.white.withOpacity(0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final bodyWidth = size.width * 0.28;
    final bulbRadius = bodyWidth * 1.1;
    final centerX = size.width / 2;
    const top = 12.0;
    final bottom = size.height - 20.0;

    final bodyLeft = centerX - bodyWidth / 2;
    final bodyRect = Rect.fromLTWH(bodyLeft, top, bodyWidth, bottom - top);

    final r = RRect.fromRectAndRadius(
      bodyRect,
      Radius.circular(bodyWidth / 2),
    );
    canvas.drawRRect(r, paintOutline);

    final bulbCenter = Offset(centerX, bottom + bulbRadius / 4);
    canvas.drawCircle(bulbCenter, bulbRadius, paintOutline);

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.4), color],
      ).createShader(
        Rect.fromLTWH(bodyLeft, top, bodyWidth, bottom - top + bulbRadius),
      );

    if (percentage > 0) {
      final fillTop = top + (1 - percentage) * (bottom - top);

      final fillRect = Rect.fromLTWH(
        bodyLeft + 1.5,
        fillTop,
        bodyWidth - 3,
        bottom - fillTop,
      );

      final fillR = RRect.fromRectAndRadius(
        fillRect,
        Radius.circular((bodyWidth - 3) / 2),
      );
      canvas.drawRRect(fillR, fillPaint);

      canvas.drawCircle(bulbCenter, bulbRadius - 3, fillPaint);

      final glow = Paint()
        ..color = color.withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(bulbCenter, bulbRadius + 4, glow);
    }

    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 1;

    const tickCount = 5;
    for (int i = 0; i <= tickCount; i++) {
      final y = top + i * (bottom - top) / tickCount;
      canvas.drawLine(Offset(bodyLeft - 8, y), Offset(bodyLeft, y), tickPaint);
      canvas.drawLine(
        Offset(bodyLeft + bodyWidth, y),
        Offset(bodyLeft + bodyWidth + 8, y),
        tickPaint,
      );
    }

    const warnTemp = 60.0;
    if (warnTemp >= minTemp && warnTemp <= maxTemp) {
      final warnPct = ((warnTemp - minTemp) / (maxTemp - minTemp)).clamp(0.0, 1.0);
      final yWarn = top + (1 - warnPct) * (bottom - top);

      final warnPaint = Paint()
        ..color = Colors.redAccent.withOpacity(0.9)
        ..strokeWidth = 2;

      canvas.drawLine(
        Offset(bodyLeft - 12, yWarn),
        Offset(bodyLeft + bodyWidth + 12, yWarn),
        warnPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ThermometerPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.color != color ||
        oldDelegate.currentTemp != currentTemp ||
        oldDelegate.minTemp != minTemp ||
        oldDelegate.maxTemp != maxTemp;
  }
}
