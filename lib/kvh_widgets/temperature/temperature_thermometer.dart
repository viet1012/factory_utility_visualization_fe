import 'package:flutter/material.dart';

import '../../model/facility_data.dart';

class TemperatureThermometer extends StatefulWidget {
  final FacilityData facility;
  final double minTemp; // ví dụ -10
  final double maxTemp; // ví dụ 80

  const TemperatureThermometer({
    Key? key,
    required this.facility,
    this.minTemp = -10,
    this.maxTemp = 80,
  }) : super(key: key);

  @override
  State<TemperatureThermometer> createState() => _TemperatureThermometerState();
}

class _TemperatureThermometerState extends State<TemperatureThermometer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _oldTemp = 0.0;

  @override
  void initState() {
    super.initState();
    _oldTemp = widget.facility.temperature;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant TemperatureThermometer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.facility.temperature != widget.facility.temperature) {
      _oldTemp = oldWidget.facility.temperature;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.facility.temperature;
    final pct = ((t - widget.minTemp) / (widget.maxTemp - widget.minTemp))
        .clamp(0.0, 1.0);

    return Container(
      width: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [Colors.grey.shade900, Colors.black87],
        ),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8)],
      ),
      child: Column(
        children: [
          // header
          // Container(
          //   padding: const EdgeInsets.symmetric(vertical: 2),
          //   decoration: BoxDecoration(
          //     gradient: LinearGradient(
          //       colors: [
          //         Colors.black26.withOpacity(0.6),
          //         Colors.orange.withOpacity(0.3),
          //       ],
          //     ),
          //     borderRadius: const BorderRadius.vertical(
          //       top: Radius.circular(16),
          //     ),
          //   ),
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.center,
          //     children: [
          //       const Icon(Icons.thermostat, color: Colors.white, size: 16),
          //       const SizedBox(width: 6),
          //       Text(
          //         widget.facility.name,
          //         style: const TextStyle(
          //           color: Colors.white,
          //           fontWeight: FontWeight.bold,
          //           fontSize: 14,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          // thermometer graphic
          Expanded(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                final animatedPct = pct * _anim.value;
                return CustomPaint(
                  painter: _ThermometerPainter(
                    percentage: animatedPct,
                    color: _colorForTemp(pct),
                    minTemp: widget.minTemp,
                    maxTemp: widget.maxTemp,
                    currentTemp: t,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${t.toStringAsFixed(1)}°C',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _statusText(t),
                          style: TextStyle(
                            color: _colorForTemp(pct),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForTemp(double pct) {
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

    // thermometer body rect
    final bodyWidth = size.width * 0.28;
    final bulbRadius = bodyWidth * 1.1;
    final centerX = size.width / 2;
    final top = 12.0;
    final bottom = size.height - 20.0;
    final bodyLeft = centerX - bodyWidth / 2;
    final bodyRect = Rect.fromLTWH(bodyLeft, top, bodyWidth, bottom - top);

    // outline body
    final r = RRect.fromRectAndRadius(bodyRect, Radius.circular(bodyWidth / 2));
    canvas.drawRRect(r, paintOutline);

    // bulb outline
    final bulbCenter = Offset(centerX, bottom + bulbRadius / 4);
    canvas.drawCircle(bulbCenter, bulbRadius, paintOutline);

    // fill level
    final fillPaint = Paint()
      ..shader =
          LinearGradient(
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

      // draw bulb fill
      canvas.drawCircle(bulbCenter, bulbRadius - 3, fillPaint);

      // subtle glow
      final glow = Paint()
        ..color = color.withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(bulbCenter, bulbRadius + 4, glow);
    }

    // ticks on left
    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 1;
    final tickCount = 5;
    for (int i = 0; i <= tickCount; i++) {
      final y = top + i * (bottom - top) / tickCount;
      canvas.drawLine(Offset(bodyLeft - 8, y), Offset(bodyLeft, y), tickPaint);
      // right ticks
      canvas.drawLine(
        Offset(bodyLeft + bodyWidth, y),
        Offset(bodyLeft + bodyWidth + 8, y),
        tickPaint,
      );
    }

    // optional marker for warning temp (e.g. 60°C)
    final warnTemp = 60.0;
    if (warnTemp >= minTemp && warnTemp <= maxTemp) {
      final warnPct = ((warnTemp - minTemp) / (maxTemp - minTemp)).clamp(
        0.0,
        1.0,
      );
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
        oldDelegate.currentTemp != currentTemp;
  }
}
