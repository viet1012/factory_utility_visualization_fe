import 'package:flutter/material.dart';

import '../../../utility_dashboard_common/chart_theme.dart';
import '../../models/energy_monthly_summary.dart';
import '../../utility_dashboard_overview_widgets/utility_glow_card.dart';
import 'monthly_metric_widgets.dart';

class MonthlyElectricityCard extends StatelessWidget {
  final EnergyMonthlySummary item;

  const MonthlyElectricityCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = ChartThemes.byCate(item.cate);
    final color = theme.iconColor;
    final unit = MonthlyMetricFormat.unit(item, theme);

    return UtilityGlowCard.electricity(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MonthlyMetricHeader(title: 'Total Energy', color: theme.line),
            const SizedBox(height: 10),
            const MonthlyMetricColumnsHeader(),
            const SizedBox(height: 4),
            MonthlyMetricComparisonRow(
              currentValue: MonthlyMetricFormat.money(item.currentCost),
              currentUnit: item.currentCostUnit,
              previousValue: MonthlyMetricFormat.money(item.previousCost),
              previousUnit: item.previousCostUnit,
              mode: MonthlyMetricFormat.mode(item),
              delta: item.costDeltaPercent,
              currentColor: color,
            ),
            const SizedBox(height: 3),
            Divider(
              height: 1,
              thickness: .5,
              color: Colors.white.withOpacity(.7),
            ),
            const SizedBox(height: 3),
            MonthlyMetricAnimatedUtilityRow(
              item: item,
              color: color,
              unit: unit,
            ),
          ],
        ),
      ),
    );
  }
}
