
import 'package:flutter/material.dart';

import '../../utility_dashboard_common/data_health.dart';

class HealthIndicator extends StatefulWidget {
  final DataHealthResult result;

  final double size;
  const HealthIndicator({
    super.key,
    required this.result,
    this.size = 10,
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
      duration: const Duration(milliseconds: 700),
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

    /// OK → pulse
    if (widget.result.health == DataHealth.ok) {
      _pulseCtrl.repeat(reverse: true);
    }

    /// Loading → blink
    if (widget.result.health == DataHealth.loading) {
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
    final health = widget.result.health;

    final color = DataHealthAnalyzer.color(health);
    final label = DataHealthAnalyzer.label(health);

    final dot = AnimatedBuilder(
      animation: Listenable.merge([_pulseCtrl, _blinkCtrl]),
      builder: (_, __) {
        double scale = 1.0;
        double opacity = 1.0;

        /// pulse effect (OK)
        if (health == DataHealth.ok) {
          scale = 0.9 + (_pulseCtrl.value * 0.5);
        }

        /// blink effect (loading)
        if (health == DataHealth.loading) {
          opacity = 0.3 + (_blinkCtrl.value * 0.7);
        }

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(widget.size / 2),
                boxShadow: health == DataHealth.ok
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
            ),
          ),
        );
      },
    );

    return Tooltip(
      message: label,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 150),
      showDuration: const Duration(seconds: 2),
      child: dot,
    );
  }
}
