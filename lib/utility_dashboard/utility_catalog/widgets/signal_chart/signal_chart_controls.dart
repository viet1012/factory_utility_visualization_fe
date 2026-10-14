import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/signal_history_models.dart';
import '../../providers/signal_history_controller.dart';
import 'signal_chart_palette.dart';

/// Dieu khien che do Chart tren header panel device: canh bao / dang lam
/// moi, chip range 1h / 6h / 24h / 7d, toggle Merge | Split.
class SignalChartHeaderControls extends StatelessWidget {
  const SignalChartHeaderControls({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.select<SignalHistoryController, _ControlsVm>(
      _ControlsVm.of,
    );
    final controller = context.read<SignalHistoryController>();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (vm.staleError)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Tooltip(
              message: 'Last chart refresh failed - showing previous data',
              child: Icon(
                Icons.cloud_off_rounded,
                size: 17,
                color: SignalChartColors.stale,
              ),
            ),
          ),
        if (vm.refreshing)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox.square(
              dimension: 13,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (vm.hourlySnapshot)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Tooltip(
              message: 'Hourly snapshot: one value per hour, no min / max',
              child: _InfoTag(label: '1 pt/hour'),
            ),
          ),
        HistoryRangeChips(
          range: vm.range,
          loading: vm.rangeLoading,
          onSelected: controller.setRange,
        ),
        const SizedBox(width: 8),
        _SegmentedToggle<CatalogChartLayout>(
          value: vm.layout,
          options: const [
            (
              CatalogChartLayout.merge,
              'Merge',
              'Group signals with the same code and unit',
            ),
            (CatalogChartLayout.split, 'Split', 'One compact card per signal'),
          ],
          onChanged: controller.setChartLayout,
        ),
      ],
    );
  }
}

/// Chip range 1h / 6h / 24h / 7d (panel device va Filter results).
/// [loading]: spinner tren chip cua range dang chon (dang tai / dang doi).
class HistoryRangeChips extends StatelessWidget {
  final HistoryRange range;
  final bool loading;
  final ValueChanged<HistoryRange> onSelected;

  const HistoryRangeChips({
    super.key,
    required this.range,
    required this.loading,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in HistoryRange.values)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _RangeChip(
              label: item.label,
              selected: item == range,
              loading: item == range && loading,
              onTap: () => onSelected(item),
            ),
          ),
      ],
    );
  }
}

class _ControlsVm {
  final HistoryRange range;
  final bool rangeLoading;
  final bool refreshing;
  final bool staleError;
  final bool hourlySnapshot;
  final CatalogChartLayout layout;

  const _ControlsVm({
    required this.range,
    required this.rangeLoading,
    required this.refreshing,
    required this.staleError,
    required this.hourlySnapshot,
    required this.layout,
  });

  static _ControlsVm of(SignalHistoryController controller) {
    return _ControlsVm(
      range: controller.range,
      rangeLoading: controller.initialLoading || controller.switching,
      refreshing: controller.refreshing,
      staleError: controller.hasData && controller.error != null,
      hourlySnapshot:
          controller.showingCurrent &&
          controller.aggregation == HistoryAggregation.snapshot,
      layout: controller.chartLayout,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _ControlsVm &&
        other.range == range &&
        other.rangeLoading == rangeLoading &&
        other.refreshing == refreshing &&
        other.staleError == staleError &&
        other.hourlySnapshot == hourlySnapshot &&
        other.layout == layout;
  }

  @override
  int get hashCode => Object.hash(
    range,
    rangeLoading,
    refreshing,
    staleError,
    hourlySnapshot,
    layout,
  );
}

/// Toggle nhieu lua chon cung style voi toggle Table | Chart.
class _SegmentedToggle<T> extends StatelessWidget {
  final T value;

  /// (gia tri, nhan, tooltip).
  final List<(T, String, String)> options;
  final ValueChanged<T> onChanged;

  const _SegmentedToggle({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF07111F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (option, label, tooltip) in options)
            Tooltip(
              message: tooltip,
              child: InkWell(
                onTap: () => onChanged(option),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: option == value
                        ? SignalChartColors.chipSelected
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: option == value
                          ? SignalChartColors.text
                          : SignalChartColors.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  final String label;

  const _InfoTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SignalChartColors.cardBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: SignalChartColors.subText,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? SignalChartColors.text : SignalChartColors.subText;

    return Material(
      color: selected
          ? SignalChartColors.chipSelected
          : SignalChartColors.chipIdle,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (loading) ...[
                const SizedBox(width: 5),
                SizedBox.square(
                  dimension: 9,
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
