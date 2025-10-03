import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../model/facility_data.dart';

// Option 2: Air Tank Level Indicator (Vertical)
class AirTankIndicator extends StatefulWidget {
  final FacilityData facility;
  final double maxPressure;

  const AirTankIndicator({
    Key? key,
    required this.facility,
    this.maxPressure = 1.0, // 1.0 MPa default
  }) : super(key: key);

  @override
  State<AirTankIndicator> createState() => _AirTankIndicatorState();
}

class _AirTankIndicatorState extends State<AirTankIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = (widget.facility.compressedAirPressure / widget.maxPressure)
        .clamp(0.0, 1.0);
    final pressureBar = widget.facility.compressedAirPressure * 10;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF263238).withOpacity(0.9),
            const Color(0xFF37474F).withOpacity(0.9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          // Container(
          //   padding: const EdgeInsets.symmetric(vertical: 2),
          //   decoration: BoxDecoration(
          //     gradient: LinearGradient(
          //       colors: [
          //         Colors.cyanAccent.withOpacity(0.6),
          //         Colors.white.withOpacity(0.3),
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
          //         Icons.inventory_2_outlined,
          //         color: Colors.white,
          //         size: 16,
          //       ),
          //       const SizedBox(width: 6),
          //       Text(
          //         widget.facility.name,
          //         style: const TextStyle(
          //           color: Colors.white,
          //           fontWeight: FontWeight.bold,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),

          // Tank visualization
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: AirTankPainter(
                      level: percent * _animation.value,
                      color: _getColorForLevel(percent),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${(percent * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.facility.compressedAirPressure.toStringAsFixed(2)} MPa',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            '${pressureBar.toStringAsFixed(1)} bar',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Footer info
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                _buildInfoChip(
                  icon: Icons.water_drop,
                  label: '${widget.facility.waterFlow.toStringAsFixed(1)} m³',
                ),
                // _buildInfoChip(
                //   icon: Icons.thermostat_outlined,
                //   label: '${widget.facility.temperature.toStringAsFixed(0)}°C',
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Row(
      children: [
        Icon(icon, color: Colors.cyanAccent, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  Color _getColorForLevel(double level) {
    if (level < 0.3) return Colors.redAccent;
    if (level < 0.6) return Colors.yellowAccent;
    return Colors.cyanAccent;
  }
}

// Custom Painter cho Tank
class AirTankPainter extends CustomPainter {
  final double level;
  final Color color;

  AirTankPainter({required this.level, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final tankWidth = size.width * 0.6;
    final tankHeight = size.height * 0.8;
    final left = (size.width - tankWidth) / 2;
    final top = (size.height - tankHeight) / 2;

    // Tank outline
    final outlinePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final tankRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, tankWidth, tankHeight),
      const Radius.circular(12),
    );
    canvas.drawRRect(tankRect, outlinePaint);

    // Fill level với gradient
    if (level > 0) {
      final fillHeight = tankHeight * level;
      final fillTop = top + tankHeight - fillHeight;

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.3), color.withOpacity(0.7), color],
        ).createShader(Rect.fromLTWH(left, fillTop, tankWidth, fillHeight));

      final fillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left + 3, fillTop, tankWidth - 6, fillHeight - 3),
        const Radius.circular(10),
      );
      canvas.drawRRect(fillRect, fillPaint);

      // Bubbles effect
      _drawBubbles(canvas, left, fillTop, tankWidth, fillHeight);
    }

    // Level markers
    for (int i = 0; i <= 4; i++) {
      final y = top + tankHeight * (i / 4);
      final markerPaint = Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..strokeWidth = 1;

      canvas.drawLine(Offset(left - 5, y), Offset(left, y), markerPaint);
      canvas.drawLine(
        Offset(left + tankWidth, y),
        Offset(left + tankWidth + 5, y),
        markerPaint,
      );
    }
  }

  void _drawBubbles(
    Canvas canvas,
    double left,
    double top,
    double width,
    double height,
  ) {
    final bubblePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final random = math.Random(42);
    for (int i = 0; i < 8; i++) {
      final x = left + width * 0.2 + random.nextDouble() * width * 0.6;
      final y = top + random.nextDouble() * height;
      final radius = 2.0 + random.nextDouble() * 3;
      canvas.drawCircle(Offset(x, y), radius, bubblePaint);
    }
  }

  @override
  bool shouldRepaint(AirTankPainter oldDelegate) {
    return oldDelegate.level != level || oldDelegate.color != color;
  }
}
