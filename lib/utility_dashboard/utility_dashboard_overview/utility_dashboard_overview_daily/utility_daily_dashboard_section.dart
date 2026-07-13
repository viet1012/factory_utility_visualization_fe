import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../utility_dashboard_overview_models/utility_daily_dashboard_response.dart';
import '../utility_dashboard_overview_provider/utility_daily_dashboard_provider.dart';
import '../utility_dashboard_overview_widgets/chart_state_widgets.dart';
import 'utility_dashboard_overview_daily_chart.dart';

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
  late final UtilityDailyDashboardProvider _provider;

  @override
  void initState() {
    super.initState();

    _provider = context.read<UtilityDailyDashboardProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      unawaited(_provider.start(facId: widget.facId, month: widget.month));
    });
  }

  @override
  void didUpdateWidget(covariant UtilityDailyDashboardSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    final changed =
        oldWidget.facId != widget.facId || oldWidget.month != widget.month;

    if (!changed) return;

    unawaited(_provider.start(facId: widget.facId, month: widget.month));
  }

  @override
  Widget build(BuildContext context) {
    return Selector<UtilityDailyDashboardProvider, _DailyDashboardVm>(
      selector: (_, provider) {
        return _DailyDashboardVm(
          loading: provider.loading,
          refreshing: provider.refreshing,
          error: provider.error,
          electricity: provider.electricity,
          water: provider.water,
          air: provider.air,
        );
      },
      shouldRebuild: (previous, next) {
        return previous.loading != next.loading ||
            previous.refreshing != next.refreshing ||
            previous.error != next.error ||
            !identical(previous.electricity, next.electricity) ||
            !identical(previous.water, next.water) ||
            !identical(previous.air, next.air);
      },
      builder: (context, vm, _) {
        final hasData =
            vm.electricity.isNotEmpty ||
            vm.water.isNotEmpty ||
            vm.air.isNotEmpty;

        if (vm.loading && !hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (vm.error != null && !hasData) {
          return ChartApiErrorState(
            onRetry: () {
              unawaited(_provider.load());
            },
          );
        }

        return Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: UtilityDashboardOverviewDailyChart(
                    facId: widget.facId,
                    month: widget.month,
                    rows: vm.electricity,
                    loading: vm.loading,
                    error: vm.error,
                    onRetry: () {
                      unawaited(_provider.load());
                    },
                    theme: ChartThemes.power,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: UtilityDashboardOverviewDailyChart(
                    facId: widget.facId,
                    month: widget.month,
                    rows: vm.water,
                    loading: vm.loading,
                    error: vm.error,
                    onRetry: () {
                      unawaited(_provider.load());
                    },
                    theme: ChartThemes.water,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: UtilityDashboardOverviewDailyChart(
                    facId: widget.facId,
                    month: widget.month,
                    rows: vm.air,
                    loading: vm.loading,
                    error: vm.error,
                    onRetry: () {
                      unawaited(_provider.load());
                    },
                    theme: ChartThemes.air,
                  ),
                ),
              ],
            ),
            if (vm.refreshing)
              Positioned(
                top: 0,
                left: 8,
                right: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: const LinearProgressIndicator(minHeight: 2),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DailyDashboardVm {
  final bool loading;
  final bool refreshing;
  final Object? error;

  final List<UtilityDailyPoint> electricity;
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
}
