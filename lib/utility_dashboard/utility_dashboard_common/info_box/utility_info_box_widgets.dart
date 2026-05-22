import 'package:flutter/material.dart';

import '../../../utility_models/response/latest_record.dart';

class UtilityInfoBoxWidgets {
  static Widget header({
    required Color facilityColor,
    required String facTitle,
    required bool isLoading,
    required bool hasError,
    required Object? err,
    String? boxDeviceId,
    String? plcAddress,
    String? unit,
  }) {
    final sub = [
      if ((boxDeviceId ?? '').trim().isNotEmpty) boxDeviceId!.trim(),
      if ((plcAddress ?? '').trim().isNotEmpty) plcAddress!.trim(),
      if ((unit ?? '').trim().isNotEmpty) unit!.trim(),
    ].join(' • ');

    final statusColor = hasError
        ? Colors.redAccent
        : (isLoading ? Colors.amberAccent : Colors.greenAccent);

    final statusText = hasError
        ? 'API error: $err'
        : (isLoading ? 'Loading...' : 'Live');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),

        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.06),
            Colors.white.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          // ?? accent nh? theo cate
          BoxShadow(
            color: facilityColor.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 22,
            decoration: BoxDecoration(
              color: facilityColor.withOpacity(0.95),
              borderRadius: BorderRadius.circular(99),
              boxShadow: [
                BoxShadow(
                  color: facilityColor.withOpacity(0.45),
                  blurRadius: 8,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          ////////////////////////////////////////////////////////////
          /// PUSH STATUS TO RIGHT
          ////////////////////////////////////////////////////////////
          const SizedBox(width: 8),
          _StatusDot(
            color: statusColor,
            tooltip: statusText,
            animate: !hasError,
          ),
        ],
      ),
    );
  }

  static Widget emptyState({required bool hasError, required Object? err}) {
    return Center(
      child: Text(
        hasError ? 'Error: $err' : 'No data',
        style: TextStyle(color: Colors.white.withOpacity(0.7)),
        textAlign: TextAlign.center,
      ),
    );
  }

  static Widget latestRow(LatestRecordDto r) {
    IconData iconData = Icons.sensors;
    Color color = Colors.lightBlueAccent;

    final type = (r.cate ?? '').toLowerCase();

    // NOTE: type đang lowercase => so sánh lowercase
    if (type.contains('electricity')) {
      iconData = Icons.flash_on;
      color = Colors.orangeAccent;
    } else if (type.contains('volume') || type.contains('water')) {
      iconData = Icons.water_drop_outlined;
      color = Colors.blueAccent;
    }

    final valueText = r.value == null ? '--' : r.value!.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Icon(iconData, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.plcAddress} • ${valueText}',
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
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

  static Widget latestChip(LatestRecordDto r) {
    final type = (r.cate ?? '').toLowerCase();

    IconData icon = Icons.sensors;
    Color accent = Colors.lightBlueAccent;

    if (type.contains('electricity') || type.contains('power')) {
      icon = Icons.flash_on;
      accent = Colors.orangeAccent;
    } else if (type.contains('water') || type.contains('volume')) {
      icon = Icons.water_drop_outlined;
      accent = Colors.blueAccent;
    } else if (type.contains('air') || type.contains('compress')) {
      icon = Icons.air;
      accent = Colors.cyanAccent;
    }

    final v = r.value == null ? '--' : r.value!.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Dòng chính (plc + value)
                Text(
                  '${r.nameEn}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),

                const SizedBox(height: 4),

                // 🔹 Dòng dưới: boxDeviceId (plain text)
                Row(
                  children: [
                    Text(
                      // r.boxDeviceId ?? '',
                      v,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatefulWidget {
  final Color color;
  final String tooltip;
  final bool animate;

  const _StatusDot({
    required this.color,
    required this.tooltip,
    required this.animate,
  });

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scale = Tween<double>(
      begin: 1,
      end: 1.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacity = Tween<double>(
      begin: 0.45,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: SizedBox(
        width: 18,
        height: 18,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.animate)
              AnimatedBuilder(
                animation: _controller,
                builder: (_, __) {
                  return Transform.scale(
                    scale: _scale.value,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(_opacity.value),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.55),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
