import 'package:flutter/material.dart';

import '../../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_overview_models/energy_monthly_summary.dart';
import '../../utility_dashboard_overview_widgets/utility_glow_card.dart';
import 'monthly_metric_widgets.dart';

// ============================================================
// WATER GROUP CARD
// ============================================================

class MonthlyWaterCard extends StatelessWidget {
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: 2,
    vertical: 5,
  );

  final List<EnergyMonthlySummary> items;

  const MonthlyWaterCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final color = ChartThemes.water.iconColor;

    return UtilityGlowCard.water(
      color: color,
      child: Padding(
        padding: _padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < items.length; index++) ...[
              _WaterCompactRow(item: items[index], color: color),

              if (index < items.length - 1) ...[
                const SizedBox(height: 3),

                Divider(
                  height: 1,
                  thickness: .5,
                  color: Colors.white.withOpacity(.5),
                ),

                const SizedBox(height: 3),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// WATER ROW
// ============================================================

class _WaterCompactRow extends StatelessWidget {
  final EnergyMonthlySummary item;
  final Color color;

  const _WaterCompactRow({required this.item, required this.color});

  String get _displayName {
    final name = item.name.trim();

    final normalized = name.toUpperCase();

    if (normalized.contains('COOLING TANK')) {
      return 'Cooling Tank Temperature';
    }

    if (normalized.contains('PIPELINE PRESSURE')) {
      return 'Pipeline Pressure';
    }

    return name.isNotEmpty ? name : 'Water Metric';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChartThemes.water;

    final unit = MonthlyMetricFormat.unit(item, theme);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MonthlyMetricHeader(title: _displayName, color: theme.accent),

        const SizedBox(height: 10),

        const MonthlyMetricColumnsHeader(),

        const SizedBox(height: 4),

        MonthlyMetricComparisonRow(
          currentValue: MonthlyMetricFormat.utility(item, item.displayValue),

          currentUnit: unit,

          previousValue: MonthlyMetricFormat.utility(
            item,
            item.previousDisplayValue,
          ),

          previousUnit: unit,

          mode: 'AVG',

          delta: item.deltaPercent,

          currentColor: color,
        ),
      ],
    );
  }
}
