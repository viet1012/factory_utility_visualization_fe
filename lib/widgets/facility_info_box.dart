import 'package:flutter/material.dart';
import '../model/facility_data.dart';

class FacilityInfoBox extends StatefulWidget {
  final FacilityData facility;

  const FacilityInfoBox({Key? key, required this.facility}) : super(key: key);

  @override
  State<FacilityInfoBox> createState() => _FacilityInfoBoxState();
}

class _FacilityInfoBoxState extends State<FacilityInfoBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.07,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue.shade600, width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(_isHovered ? 0.25 : 0.15),
                    spreadRadius: 1,
                    blurRadius: _isHovered ? 10 : 6,
                    offset: Offset(0, _isHovered ? 6 : 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Facility name header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.facility.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildMetricRow(
                    Icons.flash_on,
                    '${_formatNumber(widget.facility.power)} kWh',
                    Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  _buildMetricRow(
                    Icons.water_drop,
                    '${_formatNumber(widget.facility.volume)} m³',
                    Colors.blue,
                  ),
                  const SizedBox(height: 8),
                  _buildMetricRow(
                    Icons.speed,
                    '${_formatNumber(widget.facility.pressure)} MPa',
                    Colors.red,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricRow(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  String _formatNumber(double number) {
    if (number >= 1000) {
      return number
          .toStringAsFixed(0)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );
    }
    return number.toStringAsFixed(0);
  }
}
