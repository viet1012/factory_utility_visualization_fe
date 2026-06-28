import 'package:flutter/material.dart';

import '../../utility_dashboard_common/data_health.dart';
import 'health_indicator.dart';

class CommonChartTitleBar extends StatelessWidget {
  final String title;
  final DataHealthResult health;

  final String? valueLabel;
  final String? value;
  final String? valueTs;

  final Color? borderColor;
  final Color? backgroundColor;

  const CommonChartTitleBar({
    super.key,
    required this.title,
    required this.health,
    this.valueLabel,
    this.value,
    this.valueTs,
    this.borderColor,
    this.backgroundColor,
  });

  bool get _hasValue =>
      value != null &&
      value!.trim().isNotEmpty &&
      valueTs != null &&
      valueTs!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final label = valueLabel ?? 'Last';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(
            color: borderColor ?? Colors.white.withOpacity(0.10),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HealthIndicator(
                result: health,
                size: 10,
                showLabel: false,
                enableTooltip: true,
              ),
              if (_hasValue) ...[
                const SizedBox(width: 12),
                Text(
                  '$label: $value • $valueTs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
