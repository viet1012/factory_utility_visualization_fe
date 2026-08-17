import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_dashboard_common/chart_theme.dart';
// Water + Air
import '../utility_dashboard_overview_daily/'
    'utility_dashboard_overview_daily_chart.dart';
// Electricity Grid + Solar
import '../utility_dashboard_overview_daily/'
    'utility_dashboard_overview_daily_electricity_chart.dart';
import '../utility_dashboard_overview_models/'
    'utility_daily_dashboard_response.dart';
import '../utility_dashboard_overview_provider/'
    'utility_daily_dashboard_provider.dart';
import '../utility_dashboard_overview_widgets/'
    'chart_state_widgets.dart';

class UtilityDailyDashboardSection extends StatefulWidget {
  final String facId;
  final String month;

  const UtilityDailyDashboardSection({
    super.key,
    required this.facId,
    required this.month,
  });

  @override
  State<UtilityDailyDashboardSection> createState() =>
      _UtilityDailyDashboardSectionState();
}

class _UtilityDailyDashboardSectionState
    extends State<UtilityDailyDashboardSection> {
  // ============================================================
  // PROVIDER
  // ============================================================

  late final UtilityDailyDashboardProvider _provider;

  // Dùng để vô hiệu hóa callback cũ nếu FAC/month đổi liên tục.
  int _startGeneration = 0;

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _provider = context.read<UtilityDailyDashboardProvider>();

    _queueStart();
  }

  @override
  void didUpdateWidget(covariant UtilityDailyDashboardSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_sourceChanged(oldWidget)) {
      return;
    }

    _queueStart();
  }

  bool _sourceChanged(UtilityDailyDashboardSection oldWidget) {
    return oldWidget.facId.trim() != widget.facId.trim() ||
        oldWidget.month.trim() != widget.month.trim();
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  bool get _hasValidSource {
    final facId = widget.facId.trim();
    final month = widget.month.trim();

    return facId.isNotEmpty && RegExp(r'^\d{6}$').hasMatch(month);
  }

  // ============================================================
  // START PROVIDER
  // ============================================================

  void _queueStart() {
    final generation = ++_startGeneration;

    final facId = widget.facId.trim();
    final month = widget.month.trim();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      // Có FAC/month mới hơn đang chờ.
      if (generation != _startGeneration) {
        return;
      }

      if (facId.isEmpty || !RegExp(r'^\d{6}$').hasMatch(month)) {
        return;
      }

      unawaited(_provider.start(facId: facId, month: month));
    });
  }

  // ============================================================
  // RETRY
  // ============================================================

  void _retry() {
    if (!_hasValidSource) {
      return;
    }

    unawaited(_provider.load());
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (!_hasValidSource) {
      return const Center(
        child: Text(
          'Invalid FAC or month.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Selector<UtilityDailyDashboardProvider, _DailyDashboardVm>(
      selector: (_, provider) {
        return _DailyDashboardVm.fromProvider(provider);
      },

      shouldRebuild: (previous, next) {
        return previous.shouldRebuild(next);
      },

      builder: (_, vm, __) {
        return _buildDashboard(vm);
      },
    );
  }

  // ============================================================
  // DASHBOARD STATE
  // ============================================================

  Widget _buildDashboard(_DailyDashboardVm vm) {
    // First loading
    if (vm.isInitialLoading) {
      return const Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      );
    }

    // Không có data và API lỗi.
    if (vm.hasBlockingError) {
      return ChartApiErrorState(onRetry: _retry);
    }

    return Stack(
      children: [
        Positioned.fill(child: _buildCharts(vm)),

        if (vm.refreshing) _buildRefreshIndicator(),
      ],
    );
  }

  // ============================================================
  // CHARTS
  // ============================================================

  Widget _buildCharts(_DailyDashboardVm vm) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ======================================================
        // ELECTRICITY
        // GRID + SOLAR
        // ======================================================
        Expanded(
          child: UtilityDashboardOverviewDailyElectricityChart(
            facId: widget.facId,
            month: widget.month,

            rows: vm.electricity,

            loading: vm.loading,
            error: vm.error,

            onRetry: _retry,

            theme: ChartThemes.power,
          ),
        ),

        const SizedBox(width: 8),

        // ======================================================
        // WATER
        // ======================================================
        Expanded(
          child: UtilityDashboardOverviewDailyChart(
            facId: widget.facId,
            month: widget.month,

            rows: vm.water,

            loading: vm.loading,
            error: vm.error,

            onRetry: _retry,

            theme: ChartThemes.water,
          ),
        ),

        const SizedBox(width: 8),

        // ======================================================
        // AIR
        // ======================================================
        Expanded(
          child: UtilityDashboardOverviewDailyChart(
            facId: widget.facId,
            month: widget.month,

            rows: vm.air,

            loading: vm.loading,
            error: vm.error,

            onRetry: _retry,

            theme: ChartThemes.air,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SILENT REFRESH
  // ============================================================

  Widget _buildRefreshIndicator() {
    return Positioned(
      top: 0,
      left: 8,
      right: 8,
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: const LinearProgressIndicator(minHeight: 2),
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    // Vô hiệu callback post-frame chưa chạy.
    _startGeneration++;

    super.dispose();
  }
}

// ============================================================
// VIEW MODEL
// ============================================================

class _DailyDashboardVm {
  final bool loading;
  final bool refreshing;

  final Object? error;

  final List<UtilityDailyElectricityPoint> electricity;

  final List<UtilityDailyPoint> water;

  final List<UtilityDailyPoint> air;

  const _DailyDashboardVm({
    required this.loading,
    required this.refreshing,
    required this.error,
    required this.electricity,
    required this.water,
    required this.air,
  });

  factory _DailyDashboardVm.fromProvider(
    UtilityDailyDashboardProvider provider,
  ) {
    return _DailyDashboardVm(
      loading: provider.loading,
      refreshing: provider.refreshing,
      error: provider.error,

      electricity: provider.electricity,
      water: provider.water,
      air: provider.air,
    );
  }

  // ============================================================
  // DERIVED STATE
  // ============================================================

  bool get hasData {
    return electricity.isNotEmpty || water.isNotEmpty || air.isNotEmpty;
  }

  bool get isInitialLoading {
    return loading && !hasData;
  }

  bool get hasBlockingError {
    return error != null && !hasData;
  }

  // ============================================================
  // SELECTOR COMPARISON
  // ============================================================

  bool shouldRebuild(_DailyDashboardVm next) {
    return loading != next.loading ||
        refreshing != next.refreshing ||
        error != next.error ||
        !identical(electricity, next.electricity) ||
        !identical(water, next.water) ||
        !identical(air, next.air);
  }
}
