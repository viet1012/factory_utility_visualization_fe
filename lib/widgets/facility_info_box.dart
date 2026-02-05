import 'package:flutter/material.dart';
import 'package:factory_utility_visualization/model/signal.dart';
import '../model/facility_filtered.dart';
import '../screens/facility_detail_screen.dart';
import 'overview/factory_map_with_rain.dart';

class FacilityInfoBox extends StatefulWidget {
  final FacilityFiltered facility;
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
    switch (widget.facility.fac) {
      case 'Fac A':
        return const Color(0xFF00BCD4);
      case 'Fac B':
        return const Color(0xFF4CAF50);
      case 'Fac C':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF00BCD4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final facilityColor = _getFacilityColor();

    // Lấy 3 tín hiệu đầu tiên (hoặc ít hơn)
    final signalsToShow = widget.facility.signals.take(3).toList();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewerPage(),
            // FacilityDetailScreen(positionName: widget.facility.fac),
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
                          const Color(0xFF1A237E).withOpacity(0.3),
                          const Color(0xFF0D47A1).withOpacity(0.3),
                        ],
                      ),
                      border: Border.all(
                        color: Color(0xFF0D47A1).withOpacity(0.3),
                        width: 1,
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeader(facilityColor),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: signalsToShow
                                        .map(
                                          (signal) => _buildSignalRow(signal),
                                        )
                                        .toList(),
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
          Icon(Icons.factory, color: facilityColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.facility.fac,
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

  Widget _buildSignalRow(Signal signal) {
    IconData iconData = Icons.sensors;
    Color color = Colors.lightBlueAccent;

    try {
      final type = signal.description;

      // Ưu tiên xét theo type, nếu không có thì xét theo description
      switch (type) {
        case 'Electricity':
          iconData = Icons.flash_on;
          color = Colors.orangeAccent;
          break;

        case 'Volume':
          iconData = Icons.water_drop_outlined;
          color = Colors.blueAccent;
          break;
      }
    } catch (e) {
      print("⚠️ Lỗi khi chọn icon cho signal: $e");
      iconData = Icons.error_outline;
      color = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Icon(iconData, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signal.fullName.trim(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${signal.value.toStringAsFixed(2)} ${signal.unit}',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter giữ nguyên
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

    final path = Path();
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
