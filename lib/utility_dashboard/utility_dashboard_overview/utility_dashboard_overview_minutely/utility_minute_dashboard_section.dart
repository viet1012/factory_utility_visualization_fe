import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../utility_dashboard_overview_models/utility_minute_dashboard_response.dart';
import '../utility_dashboard_overview_provider/utility_minute_dashboard_provider.dart';
import '../utility_dashboard_overview_widgets/chart_state_widgets.dart';
import 'utility_dashboard_overview_minutes_chart.dart';

class UtilityMinuteDashboardSection extends StatefulWidget {
  final String facId;
  final int minutes;

  const UtilityMinuteDashboardSection({
    super.key,
    required this.facId,
    this.minutes = 60,
  });

  @override
  State<UtilityMinuteDashboardSection> createState() =>
      _UtilityMinuteDashboardSectionState();
}

class _UtilityMinuteDashboardSectionState
    extends State<UtilityMinuteDashboardSection> {
  late final UtilityMinuteDashboardProvider _provider;

  @override
  void initState() {
    super.initState();

    _provider = context.read<UtilityMinuteDashboardProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      unawaited(_provider.start(facId: widget.facId, minutes: widget.minutes));
    });
  }

  @override
  void didUpdateWidget(covariant UtilityMinuteDashboardSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    final changed =
        oldWidget.facId != widget.facId || oldWidget.minutes != widget.minutes;

    if (!changed) return;

    unawaited(_provider.start(facId: widget.facId, minutes: widget.minutes));
  }

  @override
  Widget build(BuildContext context) {
    return Selector<UtilityMinuteDashboardProvider, _MinuteDashboardVm>(
      selector: (_, provider) {
        return _MinuteDashboardVm(
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
          return Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: ChartThemes.power.line,
              ),
            ),
          );
        }

        if (vm.error != null && !hasData) {
          return ChartApiErrorState(
            color: ChartThemes.power.line,
            onRetry: () {
              unawaited(_provider.load(force: true));
            },
          );
        }

        return Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: UtilityDashboardOverviewMinutesChart(
                    facId: widget.facId,
                    rows: vm.electricity,
                    loading: vm.loading,
                    error: vm.error,
                    onRetry: () {
                      unawaited(_provider.load(force: true));
                    },
                    theme: ChartThemes.power,
                    utilityType: 'ELECTRICITY',
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: UtilityDashboardOverviewMinutesChart(
                    facId: widget.facId,
                    rows: vm.water,
                    loading: vm.loading,
                    error: vm.error,
                    onRetry: () {
                      unawaited(_provider.load(force: true));
                    },
                    theme: ChartThemes.water,
                    utilityType: 'WATER',
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: UtilityDashboardOverviewMinutesChart(
                    facId: widget.facId,
                    rows: vm.air,
                    loading: vm.loading,
                    error: vm.error,
                    onRetry: () {
                      unawaited(_provider.load(force: true));
                    },
                    theme: ChartThemes.air,
                    utilityType: 'AIR',
                  ),
                ),
              ],
            ),
            if (vm.refreshing)
              Positioned(
                top: 0,
                left: 8,
                right: 8,
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: ChartThemes.power.line,
                      backgroundColor: Colors.white.withOpacity(.04),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MinuteDashboardVm {
  final bool loading;
  final bool refreshing;
  final Object? error;

  final List<OverviewMinutePointDto> electricity;
  final List<OverviewMinutePointDto> water;
  final List<OverviewMinutePointDto> air;

  const _MinuteDashboardVm({
    required this.loading,
    required this.refreshing,
    required this.error,
    required this.electricity,
    required this.water,
    required this.air,
  });
}
