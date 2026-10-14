import 'dart:async';

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
import 'signal_compact_card.dart';
import 'signal_chart_group_card.dart';
import 'signal_chart_groups.dart';
import 'signal_chart_palette.dart';

/// Che do Chart cua panel chi tiet: grid the signal (range / Merge | Split
/// nam tren header, xem SignalChartHeaderControls).
///
/// - Merge: signal ANALOG / COUNTER cung (code, unit) chung mot the.
/// - Split: moi signal mot the gon.
/// - Signal STATUS khong co the (chip tren header, DeviceStatusChips).
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
  /// Chieu cao co dinh moi the.
  static const double _mergeExtent = 300;
  static const double _splitExtent = 176;

  late List<String> _signalIds;
  late Map<String, CatalogTableRow> _rowsById;

  late final SignalHistoryController _controller;
  late final PollingCoordinator _coordinator;
  late final String _taskId = PollingTaskIds.catalogDeviceChart(this);

  /// Chu ky cua task dang dang ky (null = chua dang ky).
  Duration? _taskInterval;

  /// Cach xep the, tinh lai khi chu ky signal / kind / code / unit doi.
  String? _layoutSignature;
  DeviceChartLayout _layout = DeviceChartLayout.empty;

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
    _layoutSignature = null;
  }

  void _bind() {
    _controller.bind(deviceKey: widget.device.key, signalIds: _signalIds);
  }

  @override
  Widget build(BuildContext context) {
    /*
     * Chi lang nghe trang thai chung (dang tai / loi / chu ky xep the).
     * Du lieu tung signal do moi the tu Selector rieng, nen polling cap nhat
     * the khong build lai ca grid.
     */
    final vm = context.select<SignalHistoryController, _ViewVm>(
      (controller) => _ViewVm.of(controller, _rowsById),
    );
    final controller = context.read<SignalHistoryController>();

    // Doi range: chart cu van hien (lam mo) kem progress bar manh o tren.
    final switching = vm.switching;

    return Column(
      children: [
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

  DeviceChartLayout _layoutFor(_ViewVm vm, SignalHistoryController controller) {
    if (_layoutSignature != vm.layoutSignature) {
      _layoutSignature = vm.layoutSignature;
      _layout = buildDeviceChartLayout(
        vm.signalIds,
        _rowsById,
        controller.seriesById,
      );
    }
    return _layout;
  }

  Widget _buildContent(_ViewVm vm, SignalHistoryController controller) {
    // Controller con giu data cua device khac (frame truoc khi bind chay).
    final bound = vm.deviceKey == widget.device.key;
    final merge = vm.layout == CatalogChartLayout.merge;
    final extent = merge ? _mergeExtent : _splitExtent;

    // Skeleton CHI o lan tai dau cua device (chua co gi de hien).
    if (!bound || vm.initialLoading) {
      return _ChartGridLayout(
        itemCount: widget.device.signals.isEmpty
            ? 2
            : widget.device.signals.length.clamp(1, merge ? 4 : 9),
        extent: extent,
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

    final layout = _layoutFor(vm, controller);

    if (layout.chartIds.isEmpty) {
      return const EmptyChartState(
        title: 'Status Signals Only',
        message: 'This device only has status signals, shown in the header.',
      );
    }

    if (merge) {
      final groups = layout.groups;

      return _ChartGridLayout(
        itemCount: groups.length,
        extent: extent,
        itemBuilder: (index) => RepaintBoundary(
          key: ValueKey('group:${groups[index].key}'),
          child: SignalChartGroupCard(
            group: groups[index],
            // Range cua data dang hien (co the khac range dang chon khi doi).
            range: vm.displayedRange,
            onRetry: controller.retry,
          ),
        ),
      );
    }

    final ids = layout.chartIds;

    return _ChartGridLayout(
      itemCount: ids.length,
      extent: extent,
      maxColumns: 4,
      itemBuilder: (index) => RepaintBoundary(
        key: ValueKey(ids[index]),
        child: _SignalCardSlot(
          signalId: ids[index],
          current: _rowsById[ids[index]],
          onRetry: controller.retry,
          range: vm.displayedRange,
        ),
      ),
    );
  }
}

/// Trang thai chung cua che do Chart (khong gom du lieu tung signal).
class _ViewVm {
  final String? deviceKey;
  final HistoryRange? displayedRange;
  final bool initialLoading;
  final bool switching;
  final bool hasData;
  final Object? error;
  final CatalogChartLayout layout;
  final List<String> signalIds;

  /// Doi khi tap signal / kind / code / unit / ten doi (xep the lai).
  final String layoutSignature;

  const _ViewVm({
    required this.deviceKey,
    required this.displayedRange,
    required this.initialLoading,
    required this.switching,
    required this.hasData,
    required this.error,
    required this.layout,
    required this.signalIds,
    required this.layoutSignature,
  });

  factory _ViewVm.of(
    SignalHistoryController controller,
    Map<String, CatalogTableRow> rowsById,
  ) {
    final ids = [for (final item in controller.series) item.signalId];

    return _ViewVm(
      deviceKey: controller.deviceKey,
      displayedRange: controller.displayedRange,
      initialLoading: controller.initialLoading,
      switching: controller.switching,
      hasData: controller.hasData,
      error: controller.error,
      layout: controller.chartLayout,
      signalIds: ids,
      layoutSignature: deviceChartLayoutSignature(
        ids,
        rowsById,
        controller.seriesById,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _ViewVm &&
        other.deviceKey == deviceKey &&
        other.displayedRange == displayedRange &&
        other.initialLoading == initialLoading &&
        other.switching == switching &&
        other.hasData == hasData &&
        other.error == error &&
        other.layout == layout &&
        other.layoutSignature == layoutSignature;
  }

  @override
  int get hashCode => Object.hash(
    deviceKey,
    displayedRange,
    initialLoading,
    switching,
    hasData,
    error,
    layout,
    layoutSignature,
  );
}

/// Mot the Split: chi build lai khi series cua chinh signal nay doi.
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
        final row = current;
        if (series == null || row == null) return const SizedBox.shrink();

        return SignalCompactCard(
          row: row,
          series: series,
          subtitle: series.plc,
          onRetry: onRetry,
          range: range,
        );
      },
    );
  }
}

/// Grid responsive: 1 cot hep, 2 cot vua, 3 cot rong (Split toi 4 cot).
class _ChartGridLayout extends StatelessWidget {
  final int itemCount;
  final double extent;
  final int maxColumns;
  final Widget Function(int index) itemBuilder;
  final Widget Function(Widget child)? wrap;

  const _ChartGridLayout({
    required this.itemCount,
    required this.extent,
    required this.itemBuilder,
    this.maxColumns = 3,
    this.wrap,
  });

  @override
  Widget build(BuildContext context) {
    // Resize: giu grid cu 150ms roi moi tinh lai so cot.
    return DebouncedLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final columns =
            (width < 640
                    ? 1
                    : width < 1100
                    ? 2
                    : width < 1600
                    ? 3
                    : 4)
                .clamp(1, maxColumns);

        final grid = GridView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: extent,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemBuilder: (context, index) => itemBuilder(index),
        );

        return wrap == null ? grid : wrap!(grid);
      },
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(140, 13),
          const SizedBox(height: 8),
          bar(90, 20),
          const SizedBox(height: 8),
          Expanded(child: bar(double.infinity, double.infinity)),
        ],
      ),
    );
  }
}
