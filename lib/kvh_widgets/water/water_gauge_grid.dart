import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../model/facility_data.dart';

// Alternative: Custom Water Wave Widget (không cần package)
class CustomWaterWaveGauge extends StatefulWidget {
  final FacilityData facility;
  final double maxVolume;

  const CustomWaterWaveGauge({
    Key? key,
    required this.facility,
    this.maxVolume = 3000,
  }) : super(key: key);

  @override
  State<CustomWaterWaveGauge> createState() => _CustomWaterWaveGaugeState();
}

class _CustomWaterWaveGaugeState extends State<CustomWaterWaveGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = (widget.facility.waterFlow / widget.maxVolume).clamp(
      0.0,
      1.0,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A237E).withOpacity(0.9),
            const Color(0xFF0D47A1).withOpacity(0.9),
          ],
        ),
      ),
      child: Column(
        children: [
          // Header
          // Container(
          //   padding: const EdgeInsets.symmetric(vertical: 2),
          //   decoration: BoxDecoration(
          //     gradient: LinearGradient(
          //       colors: [
          //         Colors.blue.withOpacity(0.6),
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
          //       const Icon(
          //         Icons.water_drop_outlined,
          //         color: Colors.white,
          //         size: 16,
          //       ),
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

          // Custom wave
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: WaterWavePainter(
                      percent: percent,
                      wavePhase: _waveController.value * 2 * 3.14159,
                      color: const Color(0xFF00BCD4),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${(percent * 100).toStringAsFixed(0)}%",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${widget.facility.waterFlow.toStringAsFixed(0)} m³",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter cho water wave
class WaterWavePainter extends CustomPainter {
  final double percent;
  final double wavePhase;
  final Color color;

  WaterWavePainter({
    required this.percent,
    required this.wavePhase,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final waterLevel = size.height * (1 - percent);

    // Background circle
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      bgPaint,
    );

    // Water with wave
    final path = Path();
    path.moveTo(0, size.height);

    // Draw wave
    for (double i = 0; i <= size.width; i++) {
      final waveHeight = 8 * (percent + 0.2);
      final y =
          waterLevel +
          waveHeight * math.sin((i / size.width * 4 * 3.14159) + wavePhase);

      if (i == 0) {
        path.lineTo(i, y);
      } else {
        path.lineTo(i, y);
      }
    }

    path.lineTo(size.width, size.height);
    path.close();

    // Clip to circle
    canvas.clipPath(
      Path()..addOval(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: size.width / 2,
        ),
      ),
    );

    final waterPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, waterPaint);

    // Border
    final borderPaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(WaterWavePainter oldDelegate) {
    return oldDelegate.wavePhase != wavePhase || oldDelegate.percent != percent;
  }
}
