import 'package:flutter/material.dart';
import '../model/facility_data.dart';
import '../screens/facility_detail_screen.dart';

class FacilityInfoBox extends StatefulWidget {
  final FacilityData facility;
  final double width;
  final double? height;

  const FacilityInfoBox({
    super.key,
    required this.facility,
    this.width = 200,
    this.height = 270,
  });

  @override
  State<FacilityInfoBox> createState() => _FacilityInfoBoxState();
}

class _FacilityInfoBoxState extends State<FacilityInfoBox>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _slideController;
  late AnimationController _pulseController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  bool _isHovered = false;

  @override
  void initState() {
    super.initState();

    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 0.02).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideController.forward();
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Color _getFacilityColor() {
    switch (widget.facility.name) {
      case 'Fac A':
        return const Color(0xFF00BCD4); // Cyan
      case 'Fac B':
        return const Color(0xFF00BCD4); // Green
      case 'Fac C':
        return const Color(0xFF00BCD4); // Purple
      default:
        return const Color(0xFF00BCD4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final facilityColor = _getFacilityColor();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                FacilityDetailScreen(positionName: widget.facility.name),
          ),
        );
      },
      child: SlideTransition(
        position: _slideAnimation,
        child: MouseRegion(
          onEnter: (_) {
            setState(() => _isHovered = true);
            _hoverController.forward();
          },
          onExit: (_) {
            setState(() => _isHovered = false);
            _hoverController.reverse();
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([_scaleAnimation, _rotateAnimation]),
            builder: (context, child) {
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(_rotateAnimation.value),
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: widget.width,
                    height: widget.height ?? 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(
                            0xFF1A237E,
                          ).withOpacity(0.3), // xanh đậm nhưng trong suốt 30%
                          const Color(
                            0xFF0D47A1,
                          ).withOpacity(0.3), // xanh sáng hơn, trong suốt 30%
                        ],
                      ),

                      border: Border.all(
                        color: Color(0xFF0D47A1).withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: facilityColor.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          // Animated background pattern
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Positioned.fill(
                                child: CustomPaint(
                                  painter: CircuitPatternPainter(
                                    color: facilityColor,
                                    animationValue: _pulseAnimation.value,
                                  ),
                                ),
                              );
                            },
                          ),

                          // Content
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeader(facilityColor),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildMetricRow(
                                        Icons.flash_on,
                                        'Power',
                                        widget.facility.power,
                                        'kW',
                                        Colors.amber,
                                      ),
                                      _buildMetricRow(
                                        Icons.water_drop,
                                        'Volume',
                                        widget.facility.volume,
                                        'm³',
                                        Colors.lightBlueAccent,
                                      ),
                                      _buildMetricRow(
                                        Icons.speed,
                                        'Pressure',
                                        widget.facility.pressure,
                                        'MPa',
                                        Colors.redAccent,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color facilityColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            facilityColor.withOpacity(0.8),
            facilityColor.withOpacity(0.4),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: facilityColor.withOpacity(0.5), width: 2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: facilityColor.withOpacity(0.6),
                width: 1.5,
              ),
            ),
            child: Icon(Icons.factory, color: facilityColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.facility.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.6),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(
    IconData icon,
    String label,
    double value,
    String unit,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.3), color.withOpacity(0.15)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.4), width: 1),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: value),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, child) {
                    return Text(
                      '${_formatNumber(val)} $unit',
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return (number / 1000000).toStringAsFixed(1);
    } else if (number >= 1000) {
      return (number / 1000).toStringAsFixed(1);
    }
    return number.toStringAsFixed(0);
  }
}

// Custom painter for circuit-like background pattern
class CircuitPatternPainter extends CustomPainter {
  final Color color;
  final double animationValue;

  CircuitPatternPainter({required this.color, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.2 * animationValue)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw circuit lines
    final path = Path();

    // Horizontal lines
    path.moveTo(0, size.height * 0.3);
    path.lineTo(size.width * 0.3, size.height * 0.3);
    path.lineTo(size.width * 0.3, size.height * 0.5);
    path.lineTo(size.width, size.height * 0.5);

    path.moveTo(size.width * 0.7, size.height * 0.2);
    path.lineTo(size.width, size.height * 0.2);

    path.moveTo(0, size.height * 0.8);
    path.lineTo(size.width * 0.5, size.height * 0.8);
    path.lineTo(size.width * 0.5, size.height);

    canvas.drawPath(path, paint);
    canvas.drawPath(path, glowPaint);

    // Draw nodes
    final nodePaint = Paint()
      ..color = color.withOpacity(0.3 * animationValue)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.3),
      3,
      nodePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.5),
      3,
      nodePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.2),
      3,
      nodePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.8),
      3,
      nodePaint,
    );
  }

  @override
  bool shouldRepaint(CircuitPatternPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
