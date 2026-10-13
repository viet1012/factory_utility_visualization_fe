import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/polling/polling_coordinator.dart';
import '../../../../shared/polling/polling_scope.dart';
import '../../../catalog_view_models.dart';
import '../../../models/signal_history_models.dart';
import '../../../providers/filter_chart_controller.dart';
import '../../../providers/filter_sparkline_controller.dart';
import '../../signal_chart/signal_chart_palette.dart';
import '../filter_result_cells.dart';
import 'filter_chart_group_card.dart';
import 'filter_chart_groups.dart';

/// Che do Chart cua Filter results: moi nhom signal (code, unit) mot the,
/// cho MOI device khop filter (toi da FilterChartController.maxDevices).
class FilterChartView extends StatefulWidget {
  /// Moi dong khop filter (khong chi trang hien tai).
  final List<CatalogTableRow> rows;

  /// Mo panel device (cung cach bam device trong danh sach).
  final ValueChanged<String> onOpenDevice;

  const FilterChartView({
    super.key,
    required this.rows,
    required this.onOpenDevice,
  });

  @override
  State<FilterChartView> createState() => _FilterChartViewState();
}

class _FilterChartViewState extends State<FilterChartView> {
  late FilterChartController _controller;
  late final PollingCoordinator _coordinator;

  late Map<String, List<String>> _signalsByDevice;

  @override
  void initState() {
    super.initState();

    _controller = context.read<FilterChartController>();

    // Nhip lam moi 30s chi chay khi chart that su hien.
    _coordinator = context.read<PollingCoordinator>();
    _coordinator.activity.addListener(_syncOnScreen);
    _syncOnScreen();

    _indexDevices();
    _sync();
  }

  void _syncOnScreen() {
    _controller.setOnScreen(
      _coordinator.isScopeActive(PollingScope.scadaTable),
    );
  }

  @override
  void didUpdateWidget(covariant FilterChartView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (identical(oldWidget.rows, widget.rows)) return;

    final before = _signalsByDevice;
    _indexDevices();

    // Polling tao danh sach dong moi: chi sync khi tap device / signal doi.
    if (!_sameDevices(before, _signalsByDevice)) _sync();
  }

  void _indexDevices() {
    final map = <String, List<String>>{};

    for (final row in widget.rows) {
      map.putIfAbsent(row.deviceKey, () => <String>[]).add(filterSignalIdOf(row));
    }

    _signalsByDevice = map;
  }

  @override
  void dispose() {
    _coordinator.activity.removeListener(_syncOnScreen);

    // Roi Filter results / ve Table: huy request, dung lam moi. Cache giu lai
    // (60s) de quay lai nhanh.
    _controller.sync(const <SparklineDeviceRequest>[]);

    super.dispose();
  }

  bool get _tooMany =>
      _signalsByDevice.length > FilterChartController.maxDevices;

  void _sync() {
    _controller.sync(
      _tooMany
          ? const <SparklineDeviceRequest>[]
          : [
              for (final entry in _signalsByDevice.entries)
                SparklineDeviceRequest(
                  deviceKey: entry.key,
                  signalIds: List<String>.unmodifiable(entry.value),
                ),
            ],
    );
  }

  static bool _sameDevices(
    Map<String, List<String>> a,
    Map<String, List<String>> b,
  ) {
    if (a.length != b.length) return false;

    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || other.length != entry.value.length) return false;

      for (var i = 0; i < other.length; i++) {
        if (other[i] != entry.value[i]) return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FilterChartController>();
    final sparklines = context.watch<FilterSparklineController>();

    if (_tooMany) {
      return _NarrowFilterMessage(deviceCount: _signalsByDevice.length);
    }

    final groups = buildFilterChartGroups(
      widget.rows,
      chartSeriesOf: (row, signalId) =>
          controller.seriesFor(row.deviceKey, signalId),
      fallbackSeriesOf: sparklines.seriesFor,
      stateOf: controller.stateOf,
    );

    final switching = controller.switching;

    return Column(
      children: [
        _RangeBar(
          range: controller.range,
          loading: controller.loading,
          deviceCount: _signalsByDevice.length,
          groupCount: groups.length,
          onSelected: controller.setRange,
        ),
        SizedBox(
          height: 2,
          child: switching
              ? const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: SignalChartColors.progress,
                )
              : null,
        ),
        Expanded(
          child: AnimatedOpacity(
            // Doi range: giu chart cu, lam mo cho toi khi range moi xong.
            opacity: switching ? .45 : 1,
            duration: const Duration(milliseconds: 150),
            child: groups.isEmpty
                ? const Center(
                    child: Text(
                      'No signals to chart',
                      style: TextStyle(color: SignalChartColors.mutedText),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => FilterChartGroupCard(
                      key: ValueKey(groups[index].key),
                      group: groups[index],
                      onOpenDevice: widget.onOpenDevice,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _NarrowFilterMessage extends StatelessWidget {
  final int deviceCount;

  const _NarrowFilterMessage({required this.deviceCount});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.filter_alt_rounded,
            size: 36,
            color: SignalChartColors.mutedText,
          ),
          const SizedBox(height: 10),
          Text(
            'Narrow the filter to view charts ($deviceCount devices)',
            style: const TextStyle(
              color: SignalChartColors.subText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Charts are available for up to '
            '${FilterChartController.maxDevices} devices.',
            style: TextStyle(color: SignalChartColors.mutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RangeBar extends StatelessWidget {
  final HistoryRange range;
  final bool loading;
  final int deviceCount;
  final int groupCount;
  final ValueChanged<HistoryRange> onSelected;

  const _RangeBar({
    required this.range,
    required this.loading,
    required this.deviceCount,
    required this.groupCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SignalChartColors.cardBorder)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 16,
            color: SignalChartColors.mutedText,
          ),
          const SizedBox(width: 8),
          for (final item in HistoryRange.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _RangeChip(
                label: item.label,
                selected: item == range,
                loading: item == range && loading,
                onTap: () => onSelected(item),
              ),
            ),
          const Spacer(),
          Text(
            '$groupCount groups  •  $deviceCount devices',
            style: const TextStyle(
              color: SignalChartColors.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cung style chip range voi panel device.
class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? SignalChartColors.text : SignalChartColors.subText;

    return Material(
      color: selected
          ? SignalChartColors.chipSelected
          : SignalChartColors.chipIdle,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (loading) ...[
                const SizedBox(width: 6),
                SizedBox.square(
                  dimension: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
