import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/charts/signal_thresholds.dart';
import '../../catalog_view_models.dart';
import '../../models/signal_history_models.dart';
import '../../providers/filter_chart_controller.dart';
import '../../providers/filter_sparkline_controller.dart';
import '../signal_chart/signal_chart_controls.dart' show HistoryRangeChips;
import '../signal_chart/signal_chart_palette.dart';
import 'chart/filter_chart_groups.dart';
import 'filter_result_cells.dart';

/// Pill cam "K near threshold" / do "K over threshold" o header Filter
/// results.
///
/// Gia tri hien tai (latest) so voi nguong `thresholds[]` tu lich su da tai
/// (chart hoac cache sparkline), chi ANALOG. Signal chua co nguong khong
/// duoc tinh. Khong goi API.
class FilterThresholdPills extends StatelessWidget {
  final List<CatalogTableRow> rows;

  const FilterThresholdPills({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    final chart = context.watch<FilterChartController>();
    final sparklines = context.watch<FilterSparklineController>();

    var over = 0;
    var near = 0;

    for (final row in rows) {
      final signalId = filterSignalIdOf(row);
      final series =
          chart.seriesFor(row.deviceKey, signalId) ??
          sparklines.seriesFor(signalId);

      final proximity = thresholdProximityOf(
        series?.chartThresholds ?? const <SignalThreshold>[],
        row.value,
      );

      if (proximity == ThresholdProximity.over) over++;
      if (proximity == ThresholdProximity.near) near++;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (over > 0)
          HeaderPill(
            label: '$over over threshold',
            color: kThresholdLevel3Color,
          ),
        if (near > 0)
          HeaderPill(
            label: '$near near threshold',
            color: kThresholdLevel2Color,
          ),
      ],
    );
  }
}

/// Chip range cua Filter results › Chart.
class FilterChartRangeChips extends StatelessWidget {
  const FilterChartRangeChips({super.key});

  @override
  Widget build(BuildContext context) {
    final (range, loading) = context
        .select<FilterChartController, (HistoryRange, bool)>(
          (controller) => (controller.range, controller.loading),
        );

    return HistoryRangeChips(
      range: range,
      loading: loading,
      onSelected: context.read<FilterChartController>().setRange,
    );
  }
}

/// Pill trang thai tren header (online / stale / nguong).
class HeaderPill extends StatelessWidget {
  final String label;
  final Color color;

  const HeaderPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Mau pill "online" / "stale", cung mau voi bang va the chart.
const Color kOnlinePillColor = SignalChartColors.online;
const Color kStalePillColor = SignalChartColors.stale;
