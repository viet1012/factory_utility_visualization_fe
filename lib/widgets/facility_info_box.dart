import 'package:flutter/material.dart';
import '../model/facility_data.dart';

class FacilityInfoBox extends StatefulWidget {
  final FacilityData facility;

  /// Cho phép tuỳ chỉnh kích thước
  final double width;
  final double? height; // height có thể null → auto fit content

  const FacilityInfoBox({
    Key? key,
    required this.facility,
    this.width = 280, // mặc định 280
    this.height, // mặc định null
  }) : super(key: key);

  @override
  State<FacilityInfoBox> createState() => _FacilityInfoBoxState();
}

class _FacilityInfoBoxState extends State<FacilityInfoBox>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _slideController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<Color?> _borderColorAnimation;
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

    _elevationAnimation = Tween<double>(begin: 8, end: 25).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 0.05).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );

    _borderColorAnimation =
        ColorTween(
          begin: Colors.blue.shade300,
          end: Colors.purple.shade400,
        ).animate(
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

    return SlideTransition(
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
          animation: Listenable.merge([
            _scaleAnimation,
            _elevationAnimation,
            _rotateAnimation,
          ]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: SizedBox(
                width: widget.width,
                height: widget.height, // nếu null thì auto fit
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
                          '${_formatNumber(widget.facility.power)} kWh',
                          Colors.orange,
                        ),
                        _buildMetricRow(
                          Icons.water_drop,
                          'Volume',
                          '${_formatNumber(widget.facility.volume)} m³',
                          Colors.blue,
                        ),
                        _buildMetricRow(
                          Icons.speed,
                          'Pressure',
                          '${_formatNumber(widget.facility.pressure)} MPa',
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
          stops: const [0.0, 0.5, 1.0],
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.factory, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            widget.facility.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 28,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent.shade400,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigoAccent.shade700,
                    letterSpacing: 0.2,
                  ),
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
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toStringAsFixed(0);
  }
}
