import 'package:flutter/material.dart';

import '../../utility_dashboard_common/data_health.dart';
import 'health_indicator.dart';

class CommonChartTitleBar extends StatelessWidget {
  final String title;
  final DataHealthResult health;

  final String? lastVal;
  final String? lastTs;

  final Color? borderColor;
  final Color? backgroundColor;

  const CommonChartTitleBar({
    super.key,
    required this.title,
    required this.health,
    this.lastVal,
    this.lastTs,
    this.borderColor,
    this.backgroundColor,
  });

  bool get _hasLast =>
      lastVal != null &&
      lastVal!.trim().isNotEmpty &&
      lastTs != null &&
      lastTs!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
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
          ////////////////////////////////////////////////////////////
          /// TITLE
          ////////////////////////////////////////////////////////////
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

          ////////////////////////////////////////////////////////////
          /// RIGHT SIDE
          ////////////////////////////////////////////////////////////
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HealthIndicator(
                result: health,
                size: 10,
                showLabel: false,
                enableTooltip: true,
              ),

              if (_hasLast) ...[
                const SizedBox(width: 12),

                Text(
                  'Last: $lastVal • $lastTs',
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
