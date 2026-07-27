import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  String? get _formattedValueTs {
    final raw = valueTs?.trim();

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final parsed = DateTime.parse(raw);
      return DateFormat('dd/MMM', 'en_US').format(parsed);
    } catch (_) {
      // Nếu không phải chuỗi ngày hợp lệ thì giữ nguyên.
      return raw;
    }
  }

  bool get _hasValue =>
      value != null &&
      value!.trim().isNotEmpty &&
      _formattedValueTs != null &&
      _formattedValueTs!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final label = valueLabel ?? 'Last';
    final formattedTs = _formattedValueTs;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withOpacity(.05),
        border: Border(
          bottom: BorderSide(
            color: borderColor ?? Colors.white.withOpacity(.10),
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
                letterSpacing: .6,
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
                  '$label: $value • $formattedTs',
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
