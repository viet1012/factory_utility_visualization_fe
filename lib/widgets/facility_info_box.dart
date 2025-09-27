import 'package:flutter/material.dart';

import '../main.dart';
import '../model/facility_data.dart';

class FacilityInfoBox extends StatefulWidget {
  final FacilityData facility;

  const FacilityInfoBox({Key? key, required this.facility}) : super(key: key);

  @override
  _FacilityInfoBoxState createState() => _FacilityInfoBoxState();
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
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
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
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(_isHovered ? 0.3 : 0.2),
                    spreadRadius: _isHovered ? 3 : 1,
                    blurRadius: _isHovered ? 8 : 4,
                    offset: Offset(0, _isHovered ? 4 : 2),
                  ),
                ],
              ),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Facility name
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.facility.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    SizedBox(height: 12),

                    _buildMetricRow(
                      Icons.flash_on,
                      '${_formatNumber(widget.facility.power)} kWh',
                      Colors.orange,
                    ),
                    SizedBox(height: 8),
                    _buildMetricRow(
                      Icons.water_drop,
                      '${_formatNumber(widget.facility.volume)} m³',
                      Colors.blue,
                    ),
                    SizedBox(height: 8),
                    _buildMetricRow(
                      Icons.speed,
                      '${_formatNumber(widget.facility.pressure)} MPa',
                      Colors.red,
                    ),
                  ],
                ),
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
        Icon(icon, color: color, size: 16),
        SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  String _formatNumber(double number) {
    if (number >= 1000) {
      String numStr = number.toInt().toString();
      if (numStr.length > 3) {
        return '${numStr.substring(0, numStr.length - 3)},${numStr.substring(numStr.length - 3)}';
      }
    }
    return number.toInt().toString();
  }
}
