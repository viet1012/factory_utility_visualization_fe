import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../model/facility_data.dart';

// Option 1: Circular Gauge (Speedometer style)
class PowerCircularGauge extends StatefulWidget {
  final FacilityData facility;
  final double maxPower;

  const PowerCircularGauge({
    Key? key,
    required this.facility,
    this.maxPower = 250000, // 250kW default max
  }) : super(key: key);

  @override
  State<PowerCircularGauge> createState() => _PowerCircularGaugeState();
}

class _PowerCircularGaugeState extends State<PowerCircularGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = (widget.facility.electricPower / widget.maxPower).clamp(
      0.0,
      1.0,
    );
    final powerKW = widget.facility.electricPower / 1000;

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
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withOpacity(0.6),
                  Colors.black.withOpacity(0.3),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.flash_on, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  widget.facility.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Gauge
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: CircularGaugePainter(
                      percent: percent * _animation.value,
                      color: _getColorForPower(percent),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            powerKW.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'kW',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(percent * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: _getColorForPower(percent),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Status
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _getColorForPower(percent),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getColorForPower(percent).withOpacity(0.6),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _getStatusText(percent),
                  style: TextStyle(
                    color: _getColorForPower(percent),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForPower(double percent) {
    if (percent < 0.3) return Colors.greenAccent;
    if (percent < 0.7) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _getStatusText(double percent) {
    if (percent < 0.3) return 'LOW';
    if (percent < 0.7) return 'NORMAL';
    return 'HIGH';
  }
}

class CircularGaugePainter extends CustomPainter {
  final double percent;
  final Color color;

  CircularGaugePainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.5;
    final strokeWidth = 12.0;

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75, // Start angle
      math.pi * 1.5, // Sweep angle
      false,
      bgPaint,
    );

    // Foreground arc (progress)
    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.6), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5 * percent,
      false,
      progressPaint,
    );

    // Glow effect
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = strokeWidth + 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5 * percent,
      false,
      glowPaint,
    );

    // Draw tick marks
    _drawTickMarks(canvas, center, radius);
  }

  void _drawTickMarks(Canvas canvas, Offset center, double radius) {
    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 2;

    for (int i = 0; i <= 10; i++) {
      final angle = math.pi * 0.75 + (math.pi * 1.5 * i / 10);
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
  bool shouldRepaint(CircularGaugePainter oldDelegate) {
    return oldDelegate.percent != percent;
  }
}

// Option 2: Linear Bar Gauge
class PowerLinearGauge extends StatelessWidget {
  final FacilityData facility;
  final double maxPower;

  const PowerLinearGauge({
    Key? key,
    required this.facility,
    this.maxPower = 250000,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percent = (facility.electricPower / maxPower).clamp(0.0, 1.0);
    final powerKW = facility.electricPower / 1000;

    return Container(
      padding: const EdgeInsets.all(16),
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
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.flash_on, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    facility.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Text(
                '${powerKW.toStringAsFixed(1)} kW',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Linear gauge
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percent),
            duration: const Duration(seconds: 2),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Column(
                children: [
                  // Bar
                  Container(
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: Stack(
                      children: [
                        // Progress bar
                        FractionallySizedBox(
                          widthFactor: value,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [
                                  _getColorForPower(percent).withOpacity(0.7),
                                  _getColorForPower(percent),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _getColorForPower(
                                    percent,
                                  ).withOpacity(0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Percentage text
                        Center(
                          child: Text(
                            '${(value * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Scale markers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildScaleText('0'),
                      _buildScaleText(
                        '${(maxPower / 4000).toStringAsFixed(0)}',
                      ),
                      _buildScaleText(
                        '${(maxPower / 2000).toStringAsFixed(0)}',
                      ),
                      _buildScaleText(
                        '${(maxPower / 1333).toStringAsFixed(0)}',
                      ),
                      _buildScaleText(
                        '${(maxPower / 1000).toStringAsFixed(0)}',
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScaleText(String text) {
    return Text(
      text,
      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9),
    );
  }

  Color _getColorForPower(double percent) {
    if (percent < 0.3) return Colors.greenAccent;
    if (percent < 0.7) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}

// Grid cho cả Power, Volume, Pressure
class FacilityMetricsGrid extends StatelessWidget {
  final List<FacilityData> facilities;

  const FacilityMetricsGrid({Key? key, required this.facilities})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: facilities.length,
      itemBuilder: (context, index) {
        return PowerCircularGauge(
          facility: facilities[index],
          maxPower: 250000,
        );
      },
    );
  }
}

// Vertical list với tất cả metrics
class FacilityMetricsList extends StatelessWidget {
  final List<FacilityData> facilities;

  const FacilityMetricsList({Key? key, required this.facilities})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: facilities.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PowerLinearGauge(
            facility: facilities[index],
            maxPower: 250000,
          ),
        );
      },
    );
  }
}
