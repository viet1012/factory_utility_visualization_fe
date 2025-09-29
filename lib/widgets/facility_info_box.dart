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
    this.width = 280,
    this.height,
  });

  @override
  State<FacilityInfoBox> createState() => _FacilityInfoBoxState();
}

class _FacilityInfoBoxState extends State<FacilityInfoBox>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _slideController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<Offset> _slideAnimation;

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

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.elasticOut),
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 0.05).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    _slideController.forward();
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Color _getFacilityColor() {
    switch (widget.facility.name) {
      case 'Fac A':
        return Colors.blue.shade600;
      case 'Fac B':
        return Colors.green.shade600;
      case 'Fac C':
        return Colors.purple.shade600;
      default:
        return Colors.blue.shade600;
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
            builder: (_) => FacilityDetailScreen(positionName: "Tủ P1"),
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
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: SizedBox(
                  width: widget.width,
                  height: widget.height,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(facilityColor),
                          _buildMetricRow(
                            Icons.flash_on,
                            'Power',
                            widget.facility.power,
                            Colors.orange,
                          ),
                          _buildMetricRow(
                            Icons.water_drop,
                            'Volume',
                            widget.facility.volume,
                            Colors.blue,
                          ),
                          _buildMetricRow(
                            Icons.speed,
                            'Pressure',
                            widget.facility.pressure,
                            Colors.red,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            facilityColor,
            facilityColor.withOpacity(0.8),
            facilityColor,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: facilityColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.factory, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(
            widget.facility.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
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
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedScale(
            duration: const Duration(milliseconds: 400),
            scale: _isHovered ? 1.2 : 1.0,
            curve: Curves.easeOutBack,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.9), color.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: value),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, child) {
                    return Text(
                      '${_formatNumber(val)} ${_getUnit(label)}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade700,
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

  String _getUnit(String label) {
    switch (label) {
      case 'Power':
        return 'kWh';
      case 'Volume':
        return 'm³';
      case 'Pressure':
        return 'MPa';
      default:
        return '';
    }
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toStringAsFixed(0);
  }
}
