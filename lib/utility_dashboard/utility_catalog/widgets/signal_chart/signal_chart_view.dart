import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../shared/polling/polling_coordinator.dart';
import '../../../shared/polling/polling_scope.dart';
import '../../../shared/polling/polling_task_ids.dart';
import '../../../shared/widgets/chart_state_widgets.dart';
import '../../../shared/widgets/debounced_layout_builder.dart';
import '../../api/signal_history_repository.dart';
import '../../catalog_view_models.dart';
import '../../models/signal_history_models.dart';
import '../../providers/signal_history_controller.dart';
import 'signal_chart_card.dart';
import 'signal_chart_palette.dart';

/// Che do Chart cua panel chi tiet: hang chip range + grid the signal.
///
/// Widget chi ton tai khi panel o Chart mode. No dang ky mot task polling
/// (scope scadaTable) goi [SignalHistoryController.refresh] theo chu ky cua
/// range: 1h = 1 phut, 6h = 2 phut, 24h / 7d = 5 phut. Scope scadaTable chi
/// hieu luc khi tab SCADA TABLE dang hien, tab trinh duyet khong an va
/// dashboard khong bi route khac che.
class SignalChartView extends StatefulWidget {
  final CatalogDeviceGroup device;

  const SignalChartView({super.key, required this.device});

  @override
  State<SignalChartView> createState() => _SignalChartViewState();
}

class _SignalChartViewState extends State<SignalChartView> {
  /// Chieu cao co dinh moi the: header ~150px + chart ~160px.
  static const double _cardExtent = 312;

  late List<String> _signalIds;
  late Map<String, CatalogTableRow> _rowsById;

  late final SignalHistoryController _controller;
  late final PollingCoordinator _coordinator;
  late final String _taskId = PollingTaskIds.catalogDeviceChart(this);

  /// Chu ky cua task dang dang ky (null = chua dang ky).
  Duration? _taskInterval;

  @override
  void initState() {
    super.initState();

    _controller = context.read<SignalHistoryController>();
    _coordinator = context.read<PollingCoordinator>();

    _indexRows();
    _bind();

    _controller.addListener(_syncPolling);
    _syncPolling();
  }

  @override
  void dispose() {
    _controller.removeListener(_syncPolling);
    _coordinator.unregister(_taskId);
    super.dispose();
  }

  /// Dang ky lai task khi range doi chu ky. Lich moi bat dau tu bay gio vi
  /// doi range da tu tai data moi.
  void _syncPolling() {
    final interval = SignalHistoryController.autoRefreshInterval(
      _controller.range,
    );

    if (interval == _taskInterval) return;

    _coordinator.unregister(_taskId);
    _coordinator.register(
      id: _taskId,
      scope: PollingScope.scadaTable,
      interval: interval,
      action: _controller.refresh,
    );
    _coordinator.start(_taskId);

    _taskInterval = interval;
  }

  @override
  void didUpdateWidget(covariant SignalChartView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.device, widget.device)) {
      _indexRows();
    }

    if (oldWidget.device.key != widget.device.key ||
        !identical(oldWidget.device, widget.device)) {
      _bind();
    }
  }

  void _indexRows() {
    final ids = <String>[];
    final rows = <String, CatalogTableRow>{};

    for (final row in widget.device.signals) {
      final id = buildSignalHistoryId(
        fac: row.facility,
        cate: row.rawCategory,
        scadaId: row.scadaId,
        boxId: row.boxId,
        boxDeviceId: row.boxDeviceId,
        plcAddress: row.plcAddress,
      );

      ids.add(id);
      rows[id] = row;
    }

    _signalIds = List<String>.unmodifiable(ids);
    _rowsById = rows;
  }

  void _bind() {
    _controller.bind(deviceKey: widget.device.key, signalIds: _signalIds);
  }

  @override
  Widget build(BuildContext context) {
    /*
     * Chi lang nghe trang thai chung (range / dang tai / loi / danh sach
     * signal). Du lieu tung signal do moi the tu Selector rieng
     * (_SignalCardSlot), nen polling cap nhat the khong build lai ca grid.
     */
    final vm = context.select<SignalHistoryController, _ViewVm>(
      (controller) => _ViewVm.of(controller),
    );
    final controller = context.read<SignalHistoryController>();

    // Doi range: chart cu van hien (lam mo) kem progress bar manh o tren.
    final switching = vm.switching;

    return Column(
      children: [
        _RangeBar(
          range: vm.range,
          // Spinner tren chip cua range dang tai (lan dau hoac dang doi).
          rangeLoading: vm.initialLoading || switching,
          refreshing: vm.refreshing,
          staleError: vm.staleError,
          hourlySnapshot: vm.hourlySnapshot,
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
            opacity: switching ? .45 : 1,
            duration: const Duration(milliseconds: 150),
            child: IgnorePointer(
              ignoring: switching,
              child: _buildContent(vm, controller),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(_ViewVm vm, SignalHistoryController controller) {
    // Controller con giu data cua device khac (frame truoc khi bind chay).
    final bound = vm.deviceKey == widget.device.key;

    // Skeleton CHI o lan tai dau cua device (chua co gi de hien).
    if (!bound || vm.initialLoading) {
      return _ChartGridLayout(
        itemCount: widget.device.signals.isEmpty
            ? 2
            : widget.device.signals.length,
        extent: _cardExtent,
        itemBuilder: (_) => const _SkeletonCard(),
        wrap: (child) => Shimmer.fromColors(
          baseColor: SignalChartColors.skeleton,
          highlightColor: SignalChartColors.skeletonHighlight,
          child: child,
        ),
      );
    }

    final error = vm.error;

    if (error != null && !vm.hasData) {
      // 400: hien message cua backend; loi khac: message chung.
      if (error is SignalHistoryRequestException) {
        return ChartApiErrorState(
          onRetry: controller.retry,
          title: 'Request Rejected',
          message: error.message,
        );
      }

      if (error is TimeoutException) {
        return ChartApiErrorState(
          onRetry: controller.retry,
          message:
              'No response from the history API after '
              '${SignalHistoryController.requestTimeout.inSeconds}s.',
        );
      }

      return ChartApiErrorState(onRetry: controller.retry);
    }

    if (!vm.hasData) {
      return const EmptyChartState(
        title: 'No History',
        message: 'No history data for this device in the selected range.',
      );
    }

    final ids = vm.signalIds;

    return _ChartGridLayout(
      itemCount: ids.length,
      extent: _cardExtent,
      itemBuilder: (index) => RepaintBoundary(
        key: ValueKey(ids[index]),
        child: _SignalCardSlot(
          signalId: ids[index],
          current: _rowsById[ids[index]],
          onRetry: controller.retry,
          // Range cua data dang hien (co the khac range dang chon khi doi).
          range: vm.displayedRange,
        ),
      ),
    );
  }
}

/// Trang thai chung cua che do Chart (khong gom du lieu tung signal).
class _ViewVm {
  final String? deviceKey;
  final HistoryRange? range;
  final HistoryRange? displayedRange;
  final bool initialLoading;
  final bool switching;
  final bool refreshing;
  final bool hasData;
  final bool hourlySnapshot;
  final Object? error;
  final List<String> signalIds;

  const _ViewVm({
    required this.deviceKey,
    required this.range,
    required this.displayedRange,
    required this.initialLoading,
    required this.switching,
    required this.refreshing,
    required this.hasData,
    required this.hourlySnapshot,
    required this.error,
    required this.signalIds,
  });

  factory _ViewVm.of(SignalHistoryController controller) {
    return _ViewVm(
      deviceKey: controller.deviceKey,
      range: controller.range,
      displayedRange: controller.displayedRange,
      initialLoading: controller.initialLoading,
      switching: controller.switching,
      refreshing: controller.refreshing,
      hasData: controller.hasData,
      hourlySnapshot:
          controller.showingCurrent &&
          controller.aggregation == HistoryAggregation.snapshot,
      error: controller.error,
      signalIds: [for (final item in controller.series) item.signalId],
    );
  }

  bool get staleError => hasData && error != null;

  @override
  bool operator ==(Object other) {
    return other is _ViewVm &&
        other.deviceKey == deviceKey &&
        other.range == range &&
        other.displayedRange == displayedRange &&
        other.initialLoading == initialLoading &&
        other.switching == switching &&
        other.refreshing == refreshing &&
        other.hasData == hasData &&
        other.hourlySnapshot == hourlySnapshot &&
        other.error == error &&
        listEquals(other.signalIds, signalIds);
  }

  @override
  int get hashCode => Object.hash(
    deviceKey,
    range,
    displayedRange,
    initialLoading,
    switching,
    refreshing,
    hasData,
    error,
    signalIds.length,
  );
}

/// Mot the: chi build lai khi series cua chinh signal nay doi.
class _SignalCardSlot extends StatelessWidget {
  final String signalId;
  final CatalogTableRow? current;
  final VoidCallback onRetry;
  final HistoryRange? range;

  const _SignalCardSlot({
    required this.signalId,
    required this.current,
    required this.onRetry,
    required this.range,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<SignalHistoryController, SignalHistorySeries?>(
      selector: (_, controller) => controller.seriesById(signalId),
      shouldRebuild: (previous, next) => !identical(previous, next),
      builder: (context, series, _) {
        if (series == null) return const SizedBox.shrink();

        return SignalChartCard(
          series: series,
          current: current,
          onRetry: onRetry,
          range: range,
        );
      },
    );
  }
}

/// Grid responsive: 1 cot hep, 2 cot vua, 3 cot rong.
class _ChartGridLayout extends StatelessWidget {
  final int itemCount;
  final double extent;
  final Widget Function(int index) itemBuilder;
  final Widget Function(Widget child)? wrap;

  const _ChartGridLayout({
    required this.itemCount,
    required this.extent,
    required this.itemBuilder,
    this.wrap,
  });

  @override
  Widget build(BuildContext context) {
    // Resize: giu grid cu 150ms roi moi tinh lai so cot.
    return DebouncedLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final columns = width < 640
            ? 1
            : width < 1100
            ? 2
            : 3;

        final grid = GridView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: extent,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemBuilder: (context, index) => itemBuilder(index),
        );

        return wrap == null ? grid : wrap!(grid);
      },
    );
  }
}

class _RangeBar extends StatelessWidget {
  /// Null khi dang dung custom window.
  final HistoryRange? range;

  /// Range dang chon dang duoc tai (spinner nho tren chip cua no).
  final bool rangeLoading;
  final bool refreshing;
  final bool staleError;

  /// Backend tra HOURLY_SNAPSHOT (range > 24h): 1 diem moi gio.
  final bool hourlySnapshot;
  final ValueChanged<HistoryRange> onSelected;

  const _RangeBar({
    required this.range,
    required this.rangeLoading,
    required this.refreshing,
    required this.staleError,
    required this.hourlySnapshot,
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
                loading: item == range && rangeLoading,
                onTap: () => onSelected(item),
              ),
            ),
          if (hourlySnapshot)
            const Tooltip(
              message: 'Hourly snapshot: one value per hour, no min / max',
              child: _InfoTag(label: '1 pt/hour'),
            ),
          const Spacer(),
          if (staleError)
            const Tooltip(
              message: 'Last chart refresh failed - showing previous data',
              child: Icon(
                Icons.cloud_off_rounded,
                size: 18,
                color: SignalChartColors.stale,
              ),
            ),
          if (refreshing)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
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
      margin: const EdgeInsets.only(left: 4),
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

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(56, 20),
          const SizedBox(height: 12),
          bar(140, 14),
          const SizedBox(height: 10),
          bar(90, 24),
          const SizedBox(height: 8),
          bar(180, 10),
          const SizedBox(height: 12),
          Expanded(child: bar(double.infinity, double.infinity)),
        ],
      ),
    );
  }
}
