import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/utility_daily_signal_controller.dart';
import '../../utility_dashboard_common/chart_theme.dart';
import '../../shared/widgets/chart_state_widgets.dart';
import '../models/utility_daily_models.dart';
import '../widgets/utility_chart_loading_state.dart';
import '../widgets/utility_daily_chart_grid.dart';

class UtilityDailyTab extends StatefulWidget {
  final bool isActive;
  final String facId;
  final String cate;
  final String? scadaId;

  final String? boxId;
  final String? selectedBoxDeviceId;

  /// Toàn bộ device thuộc Box đang chọn.
  final List<String> boxDeviceIds;

  const UtilityDailyTab({
    super.key,
    required this.isActive,
    required this.facId,
    required this.cate,
    required this.scadaId,
    required this.boxId,
    required this.selectedBoxDeviceId,
    required this.boxDeviceIds,
  });

  @override
  State<UtilityDailyTab> createState() => _UtilityDailyTabState();
}

class _UtilityDailyTabState extends State<UtilityDailyTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<String> get _requestedDeviceIds {
    final selectedDevice = widget.selectedBoxDeviceId?.trim();

    // Đã chọn một Device cụ thể.
    if (selectedDevice != null && selectedDevice.isNotEmpty) {
      return <String>[selectedDevice];
    }

    // Đang chọn Box ID / ALL DEVICES.
    return widget.boxDeviceIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  String get _currentMonth {
    final now = DateTime.now();

    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}';
  }

  String get _requestKey {
    final devices = List<String>.from(_requestedDeviceIds)..sort();

    return <String>[
      widget.facId,
      widget.cate,
      widget.scadaId ?? '',
      widget.boxId ?? '',
      ...devices,
    ].join('|');
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isActive) {
        _load();
      }
    });
  }

  @override
  void didUpdateWidget(covariant UtilityDailyTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldDevices = List<String>.from(
      oldWidget.selectedBoxDeviceId != null &&
              oldWidget.selectedBoxDeviceId!.trim().isNotEmpty
          ? <String>[oldWidget.selectedBoxDeviceId!.trim()]
          : oldWidget.boxDeviceIds,
    )..sort();

    final newDevices = List<String>.from(_requestedDeviceIds)..sort();

    final requestChanged =
        oldWidget.facId != widget.facId ||
        oldWidget.cate != widget.cate ||
        oldWidget.scadaId != widget.scadaId ||
        oldWidget.boxId != widget.boxId ||
        !listEquals(oldDevices, newDevices);

    final becameActive = !oldWidget.isActive && widget.isActive;

    if (!widget.isActive || (!requestChanged && !becameActive)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (!mounted || !widget.isActive) {
      return;
    }

    final provider = context.read<UtilityDailySignalController>();

    final deviceIds = _requestedDeviceIds;

    if (deviceIds.isEmpty) {
      provider.clear();
      return;
    }

    await provider.load(
      boxDeviceIds: deviceIds,
      month: _currentMonth,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final requestedDeviceIds = _requestedDeviceIds;

    if (requestedDeviceIds.isEmpty) {
      return EmptyChartState(
        icon: Icons.inventory_2_outlined,
        title: 'No Devices In Box',
        message:
            'No Box Device ID found for '
            '${widget.boxId ?? "selected box"} / '
            '${widget.scadaId ?? "-"}.',
        color: ChartThemes.byCate(widget.cate).line,
      );
    }

    return Selector<UtilityDailySignalController, _DailyTabVm>(
      selector: (_, provider) {
        return _DailyTabVm(
          loading: provider.loading,
          refreshing: provider.refreshing,
          error: provider.error,
          series: provider.series,
          dataVersion: provider.dataVersion,
        );
      },
      shouldRebuild: (previous, next) {
        return previous.loading != next.loading ||
            previous.refreshing != next.refreshing ||
            previous.error != next.error ||
            previous.dataVersion != next.dataVersion;
      },
      builder: (context, vm, _) {
        if (vm.loading && vm.series.isEmpty) {
          return UtilityChartLoadingState(
            cate: widget.cate,
            message: 'Loading daily data...',
          );
        }

        if (vm.error != null && vm.series.isEmpty) {
          return ChartApiErrorState(
            color: ChartThemes.byCate(widget.cate).line,
            onRetry: () {
              _load(forceRefresh: true);
            },
          );
        }

        if (vm.series.isEmpty) {
          return EmptyChartState(
            icon: Icons.query_stats_rounded,
            title: 'No Daily Data',
            message:
                'No daily data found for '
                '${widget.boxId ?? "-"} / '
                '${widget.scadaId ?? "-"}',
            color: Colors.white.withValues(alpha: .58),
          );
        }

        return Stack(
          children: [
            UtilityDailyChartGrid(
              key: ValueKey('$_requestKey-${vm.dataVersion}'),
              series: vm.series,
              facId: widget.facId,
              cate: widget.cate,
              scadaId: widget.scadaId,
              boxDeviceId:
                  widget.selectedBoxDeviceId ?? widget.boxId ?? 'ALL DEVICES',
            ),

            if (vm.refreshing)
              const Positioned(
                top: 10,
                right: 12,
                child: _DailyRefreshingBadge(),
              ),
          ],
        );
      },
    );
  }
}

class _DailyTabVm {
  final bool loading;
  final bool refreshing;
  final Object? error;

  final List<UtilityDailySeries> series;
  final int dataVersion;

  const _DailyTabVm({
    required this.loading,
    required this.refreshing,
    required this.error,
    required this.series,
    required this.dataVersion,
  });
}

class _DailyRefreshingBadge extends StatelessWidget {
  const _DailyRefreshingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E31),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 1.8),
          ),
          SizedBox(width: 7),
          Text(
            'Refreshing daily data',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
