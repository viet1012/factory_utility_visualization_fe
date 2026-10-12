import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../catalog_view_models.dart';
import '../../providers/filter_chart_controller.dart';
import '../../providers/filter_sparkline_controller.dart';
import '../signal_chart/signal_chart_palette.dart';
import 'filter_result_cells.dart';

/// Badge "N over threshold" o header Filter results.
///
/// Gia tri hien tai (latest) so voi nguong tu lich su da tai (chart hoac
/// cache sparkline). Signal chua co nguong khong duoc tinh. Khong goi API.
class FilterOverThresholdBadge extends StatelessWidget {
  final List<CatalogTableRow> rows;

  const FilterOverThresholdBadge({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    final chart = context.watch<FilterChartController>();
    final sparklines = context.watch<FilterSparklineController>();

    var count = 0;

    for (final row in rows) {
      final value = row.value;
      if (value == null || !value.isFinite) continue;

      final signalId = filterSignalIdOf(row);
      final series =
          chart.seriesFor(row.deviceKey, signalId) ??
          sparklines.seriesFor(signalId);

      if (series != null && series.isOutOfRange(value)) count++;
    }

    if (count == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(right: 7),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: SignalChartColors.alert.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SignalChartColors.alert.withValues(alpha: .35)),
      ),
      child: Text(
        '$count over threshold',
        style: const TextStyle(
          color: SignalChartColors.alert,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
