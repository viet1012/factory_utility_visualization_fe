import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../catalog_view_models.dart';
import '../../models/signal_history_models.dart';
import '../../providers/signal_history_controller.dart';
import '../filter_results/filter_result_cells.dart'
    show filterSignalIdOf, isStatusSignal;
import 'signal_chart_format.dart';
import 'signal_chart_palette.dart';

/// So lan doi ma toi da liet ke trong tooltip.
const int _maxListedChanges = 8;

/// Signal STATUS cua device (vd "Slave ID"): khong ve the chart, moi signal
/// mot chip tren header. Co lich su cua device (che do Chart) ma trong range
/// co hon mot ma -> chip cam, tooltip liet ke cac lan doi.
class DeviceStatusChips extends StatelessWidget {
  final CatalogDeviceGroup device;

  const DeviceStatusChips({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final ids = [for (final row in device.signals) filterSignalIdOf(row)];

    return Selector<SignalHistoryController, List<SignalHistorySeries?>>(
      selector: (_, controller) => [
        for (final id in ids)
          // Lich su cua device khac (frame truoc khi bind): bo qua.
          controller.deviceKey == device.key ? controller.seriesById(id) : null,
      ],
      shouldRebuild: (previous, next) {
        if (previous.length != next.length) return true;
        for (var i = 0; i < next.length; i++) {
          if (!identical(previous[i], next[i])) return true;
        }
        return false;
      },
      builder: (context, seriesList, _) {
        final chips = <Widget>[
          for (var i = 0; i < device.signals.length; i++)
            if (isStatusSignal(device.signals[i], seriesList[i]))
              StatusSignalChip(row: device.signals[i], series: seriesList[i]),
        ];

        if (chips.isEmpty) return const SizedBox.shrink();

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final chip in chips)
              Padding(padding: const EdgeInsets.only(left: 6), child: chip),
          ],
        );
      },
    );
  }
}

/// Chip "Slave ID N" cua mot signal STATUS (header panel device, cuoi
/// Filter results › Chart). [showDevice]: tooltip ghi box / device.
class StatusSignalChip extends StatelessWidget {
  final CatalogTableRow row;
  final SignalHistorySeries? series;
  final bool showDevice;

  const StatusSignalChip({
    super.key,
    required this.row,
    required this.series,
    this.showDevice = false,
  });

  @override
  Widget build(BuildContext context) {
    final changes = _changes(series);
    final changed = changes.map((change) => change.$2).toSet().length > 1;

    final live = row.value;
    final code = live != null && live.isFinite
        ? live.round()
        : (changes.isEmpty ? null : changes.last.$2);

    final name = row.displaySignalName;
    final prefix = name.toLowerCase().startsWith('slave') ? 'Slave ID' : name;

    final color = changed ? SignalChartColors.stale : SignalChartColors.status;

    final tooltip = [
      name,
      if (showDevice) '${row.boxId} / ${row.boxDeviceId}',
      'PLC ${row.plcAddress.trim().isEmpty ? '--' : row.plcAddress.trim()}',
      'Updated ${row.displayTime}',
      if (changed) ...[
        '',
        'Changes in range:',
        if (changes.length > _maxListedChanges) '…',
        for (final (time, value) in changes.skip(
          changes.length > _maxListedChanges
              ? changes.length - _maxListedChanges
              : 0,
        ))
          '${formatSignalTimestamp(time)}  →  $value',
      ],
    ].join('\n');

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            '$prefix ${code ?? '--'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  /// Cac lan doi ma trong range (lan dau tien cung tinh), theo thoi gian.
  static List<(DateTime, int)> _changes(SignalHistorySeries? series) {
    if (series == null) return const [];

    final result = <(DateTime, int)>[];
    int? previous;

    for (final point in series.points) {
      final value = series.plotValue(point);
      if (value == null || !value.isFinite) continue;

      final code = value.round();
      if (code == previous) continue;

      result.add((point.ts, code));
      previous = code;
    }

    return result;
  }
}
