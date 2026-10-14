import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UtilityInfoBoxWidgets {
  /// [breachCount] > 0: hien badge "N breaches" mau [breachColor], tooltip
  /// ghi [lastBreachAt].
  static Widget header({
    required Color facilityColor,
    required String facTitle,
    required bool isLoading,
    required bool hasError,
    required Object? err,
    String? boxDeviceId,
    String? plcAddress,
    String? unit,
    int breachCount = 0,
    DateTime? lastBreachAt,
    Color breachColor = Colors.redAccent,
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
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          // ?? accent nh? theo cate
          BoxShadow(
            color: facilityColor.withValues(alpha: 0.10),
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
              color: facilityColor.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(99),
              boxShadow: [
                BoxShadow(
                  color: facilityColor.withValues(alpha: 0.45),
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

          if (breachCount > 0) ...[
            const SizedBox(width: 8),
            _BreachBadge(
              count: breachCount,
              lastBreachAt: lastBreachAt,
              color: breachColor,
            ),
          ],

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
}

class _BreachBadge extends StatelessWidget {
  static final DateFormat _format = DateFormat('dd/MM HH:mm');

  final int count;
  final DateTime? lastBreachAt;
  final Color color;

  const _BreachBadge({
    required this.count,
    required this.lastBreachAt,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final last = lastBreachAt;

    return Tooltip(
      message: last == null
          ? 'Threshold breaches in range'
          : 'Last breach: ${_format.format(last.toLocal())}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .45)),
        ),
        child: Text(
          count == 1 ? '1 breach' : '$count breaches',
          maxLines: 1,
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
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
                        color: widget.color.withValues(alpha: _opacity.value),
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
                    color: widget.color.withValues(alpha: 0.55),
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
