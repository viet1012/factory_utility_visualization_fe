import 'package:flutter/material.dart';

import '../../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_overview_models/energy_monthly_summary.dart';
import '../../utility_dashboard_overview_widgets/utility_glow_card.dart';
import 'monthly_metric_widgets.dart';

class MonthlyAirCard extends StatelessWidget {
  final EnergyMonthlySummary item;

  const MonthlyAirCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = ChartThemes.byCate(item.cate);
    final color = theme.iconColor;
    final unit = MonthlyMetricFormat.unit(item, theme);

    return UtilityGlowCard.air(
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MonthlyMetricHeader(title: 'Compressed Air', color: theme.line),
            const SizedBox(height: 10),
            const MonthlyMetricColumnsHeader(),
            const SizedBox(height: 4),
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
