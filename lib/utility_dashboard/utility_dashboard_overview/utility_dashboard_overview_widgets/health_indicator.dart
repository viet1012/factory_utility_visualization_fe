import 'package:flutter/material.dart';

import '../data_health.dart';

class HealthIndicator extends StatefulWidget {
  final DataHealthResult result;

  /// size của icon/dot
  final double size;

  /// hiển thị label text nhỏ cạnh icon (tuỳ)
  final bool showLabel;

  /// tooltip bật/tắt
  final bool enableTooltip;

  const HealthIndicator({
    super.key,
    required this.result,
    this.size = 10,
    this.showLabel = false,
    this.enableTooltip = true,
  });

  @override
  State<HealthIndicator> createState() => _HealthIndicatorState();
}

class _HealthIndicatorState extends State<HealthIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _syncAnim();
  }

  @override
  void didUpdateWidget(covariant HealthIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result.health != widget.result.health) {
      _syncAnim();
    }
  }

  void _syncAnim() {
    _pulseCtrl.stop();
    _blinkCtrl.stop();

    // OK -> pulse
    if (widget.result.health == DataHealth.ok) {
      _pulseCtrl.repeat(reverse: true);
    }

    // ERROR -> blink
    if (widget.result.health == DataHealth.error) {
      _blinkCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = DataHealthAnalyzer.color(widget.result.health);
    final label = DataHealthAnalyzer.label(widget.result);

    Widget dot = AnimatedBuilder(
      animation: Listenable.merge([_pulseCtrl, _blinkCtrl]),
      builder: (_, __) {
        // pulse effect
        final pulse = widget.result.health == DataHealth.ok
            ? (0.85 + _pulseCtrl.value * 0.55) // 0.85 -> 1.4
            : 1.0;

        // blink effect
        final blinkOpacity = widget.result.health == DataHealth.error
            ? (0.25 + _blinkCtrl.value * 0.75) // 0.25 -> 1.0
            : 1.0;

        return Opacity(
          opacity: blinkOpacity,
          child: Transform.scale(
            scale: pulse,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.45),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // optional label text
    if (widget.showLabel) {
      dot = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    }

    if (!widget.enableTooltip) return dot;

    return Tooltip(
      message: label,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 150),
      showDuration: const Duration(seconds: 2),
      child: dot,
    );
  }
}
