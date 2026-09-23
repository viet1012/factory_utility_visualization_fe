import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../shared/widgets/chart_state_widgets.dart';
import '../../signal_health_style.dart';
import '../../utils/signal_health_history_utils.dart';
import 'signal_health_history_panel.dart';

/// Horizontal bar chart of the box devices raising the most alerts.
///
/// Consumes the pre-aggregated output of [buildTopDevices]. Tapping a bar
/// selects that device for the drill-down panel via [onDeviceSelected].
class SignalHealthHistoryDeviceChart extends StatefulWidget {
  final List<HistoryDeviceStat> items;
  final String? selectedBoxDeviceId;
  final ValueChanged<String> onDeviceSelected;

  /// Shown in the card subtitle so the bars are read as range totals.
  final String rangeLabel;

  const SignalHealthHistoryDeviceChart({
    super.key,
    required this.items,
    required this.selectedBoxDeviceId,
    required this.onDeviceSelected,
    required this.rangeLabel,
  });

  @override
  State<SignalHealthHistoryDeviceChart> createState() =>
      _SignalHealthHistoryDeviceChartState();
}

class _SignalHealthHistoryDeviceChartState
    extends State<SignalHealthHistoryDeviceChart> {
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
      title: 'Top Box Devices',
      subtitle: 'Alert occurrences by device in selected period',
      icon: Icons.memory_rounded,
      helpText:
          'Sum of device.count across ${widget.rangeLabel}. '
          '$kHistoryCountMeaning'
          ' Tap a bar to open its register details.',
      child: items.isEmpty
          ? const EmptyChartState(
              title: 'No Devices',
              message: 'No devices raised alerts in this range.',
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
                maximumLabelWidth: 130,
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
              series: <CartesianSeries<HistoryDeviceStat, String>>[
                BarSeries<HistoryDeviceStat, String>(
                  animationDuration: 0,
                  dataSource: items,
                  xValueMapper: (item, _) => item.boxDeviceId,
                  yValueMapper: (item, _) => item.alertCount,
                  // The selected device keeps full-strength colour; the rest
                  // dim, so the drill-down target is obvious at a glance.
                  pointColorMapper: (item, _) {
                    final selected = widget.selectedBoxDeviceId;

                    if (selected == null || selected == item.boxDeviceId) {
                      return kBlue;
                    }

                    return kBlue.withValues(alpha: .35);
                  },
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(4),
                  ),
                  width: .65,
                  onPointTap: (details) {
                    final index = details.pointIndex;

                    if (index == null || index < 0 || index >= items.length) {
                      return;
                    }

                    widget.onDeviceSelected(items[index].boxDeviceId);
                  },
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
