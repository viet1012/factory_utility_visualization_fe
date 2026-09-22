import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../../shared/polling/polling_coordinator.dart';
import '../../shared/polling/polling_task_ids.dart';
import '../models/utility_minute_dashboard_response.dart';
import '../providers/utility_minute_dashboard_provider.dart';
import '../../shared/widgets/chart_state_widgets.dart';
import 'utility_minutely_chart.dart';

class UtilityMinutelyDashboardSection extends StatefulWidget {
  final String facId;
  final int minutes;

  const UtilityMinutelyDashboardSection({
    super.key,
    required this.facId,
    this.minutes = 60,
  });

  @override
  State<UtilityMinutelyDashboardSection> createState() =>
      _UtilityMinutelyDashboardSectionState();
}

class _UtilityMinutelyDashboardSectionState
    extends State<UtilityMinutelyDashboardSection> {
  late final UtilityMinuteDashboardProvider _provider;
  late final PollingCoordinator _pollingCoordinator;

  @override
  void initState() {
    super.initState();

    _provider = context.read<UtilityMinuteDashboardProvider>();
    _pollingCoordinator = context.read<PollingCoordinator>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _configureAndStartPolling();
    });
  }

  @override
  void didUpdateWidget(covariant UtilityMinutelyDashboardSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    final changed =
        oldWidget.facId != widget.facId || oldWidget.minutes != widget.minutes;

    if (!changed) return;

    _configureAndStartPolling();
  }

  void _configureAndStartPolling() {
    _pollingCoordinator.stop(PollingTaskIds.mapMinuteDashboard);
    _provider.configure(facId: widget.facId, minutes: widget.minutes);
    _pollingCoordinator.start(PollingTaskIds.mapMinuteDashboard);
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
                  child: UtilityMinutelyChart(
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
                  child: UtilityMinutelyChart(
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
                  child: UtilityMinutelyChart(
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
                      backgroundColor: Colors.white.withValues(alpha: .04),
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
