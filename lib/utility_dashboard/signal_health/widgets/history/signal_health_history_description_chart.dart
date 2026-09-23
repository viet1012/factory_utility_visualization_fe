import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../shared/widgets/chart_state_widgets.dart';
import '../../signal_health_style.dart';
import '../../utils/signal_health_history_utils.dart';
import 'signal_health_history_panel.dart';

/// Horizontal bar chart of the most frequent alert descriptions.
///
/// Consumes the pre-aggregated output of [buildTopDescriptions].
class SignalHealthHistoryDescriptionChart extends StatefulWidget {
  final List<HistoryDescriptionStat> items;

  /// groupKey of the selected description, or null for "all".
  final String? selectedKey;

  final ValueChanged<String> onDescriptionSelected;

  /// Shown in the card subtitle so the bars are read as range totals.
  final String rangeLabel;

  const SignalHealthHistoryDescriptionChart({
    super.key,
    required this.items,
    required this.selectedKey,
    required this.onDescriptionSelected,
    required this.rangeLabel,
  });

  @override
  State<SignalHealthHistoryDescriptionChart> createState() =>
      _SignalHealthHistoryDescriptionChartState();
}

class _SignalHealthHistoryDescriptionChartState
    extends State<SignalHealthHistoryDescriptionChart> {
  late final TooltipBehavior _tooltipBehavior;

  @override
  void initState() {
    super.initState();

    _tooltipBehavior = TooltipBehavior(
      enable: true,
      textStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;

    return SignalHealthHistoryChartShell(
      title: 'Top Alert Descriptions',
      subtitle: 'Alert occurrences in selected period',
      icon: Icons.rule_rounded,
      helpText:
          'Sum of description.count across ${widget.rangeLabel}. '
          '$kHistoryCountMeaning',
      child: items.isEmpty
          ? const EmptyChartState(
              title: 'No Descriptions',
              message: 'No alert descriptions in this range.',
            )
          : SfCartesianChart(
              plotAreaBorderWidth: 0,
              tooltipBehavior: _tooltipBehavior,
              margin: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              primaryXAxis: CategoryAxis(
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: AxisLine(
                  color: Colors.white.withValues(alpha: .15),
                  width: 1,
                ),
                majorTickLines: const MajorTickLines(size: 0),
                // Long rule text would otherwise be truncated to nothing.
                maximumLabelWidth: 150,
                labelStyle: const TextStyle(color: kSubText, fontSize: 11),
              ),
              primaryYAxis: NumericAxis(
                minimum: 0,
                decimalPlaces: 0,
                majorGridLines: MajorGridLines(
                  width: 1,
                  color: Colors.white.withValues(alpha: .08),
                ),
                axisLine: const AxisLine(width: 0),
                labelStyle: const TextStyle(color: kSubText, fontSize: 11),
              ),
              series: <CartesianSeries<HistoryDescriptionStat, String>>[
                BarSeries<HistoryDescriptionStat, String>(
                  animationDuration: 0,
                  dataSource: items,
                  xValueMapper: (item, _) => item.label,
                  yValueMapper: (item, _) => item.alertCount,
                  // Non-selected bars dim so the active filter is obvious.
                  pointColorMapper: (item, _) {
                    final selected = widget.selectedKey;

                    if (selected == null || selected == item.key) {
                      return kOrange;
                    }

                    return kOrange.withValues(alpha: .35);
                  },
                  onPointTap: (details) {
                    final index = details.pointIndex;

                    if (index == null || index < 0 || index >= items.length) {
                      return;
                    }

                    widget.onDescriptionSelected(items[index].key);
                  },
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(4),
                  ),
                  width: .65,
                  dataLabelSettings: const DataLabelSettings(
                    isVisible: true,
                    textStyle: TextStyle(
                      color: kText,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
