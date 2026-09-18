import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../models/utility_hourly_dashboard_response.dart';
import '../providers/utility_hourly_dashboard_provider.dart';
import '../utility_dashboard_overview_widgets/chart_state_widgets.dart';
import 'utility_hourly_compare.dart';
import 'widgets/utility_hourly_sensor_panel.dart';

class UtilityHourlyDashboardSection extends StatefulWidget {
  final String facId;

  const UtilityHourlyDashboardSection({super.key, required this.facId});

  @override
  State<UtilityHourlyDashboardSection> createState() =>
      _UtilityHourlyDashboardSectionState();
}

class _UtilityHourlyDashboardSectionState
    extends State<UtilityHourlyDashboardSection> {
  late final UtilityHourlyDashboardProvider _provider;

  int _scheduleToken = 0;

  @override
  void initState() {
    super.initState();
    _provider = context.read<UtilityHourlyDashboardProvider>();
    _scheduleStart(facId: widget.facId);
  }

  @override
  void didUpdateWidget(covariant UtilityHourlyDashboardSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldFacId = oldWidget.facId.trim();
    final newFacId = widget.facId.trim();
    if (oldFacId == newFacId) return;

    _scheduleStart(facId: widget.facId);
  }

  void _scheduleStart({required String facId}) {
    final token = ++_scheduleToken;
    final nextFacId = facId.trim();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (token != _scheduleToken) return;

      unawaited(_provider.start(facId: nextFacId));
    });
  }

  void _retry() {
    unawaited(_provider.load());
  }

  @override
  void dispose() {
    _scheduleToken++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<UtilityHourlyDashboardProvider, _HourlyDashboardVm>(
      selector: (_, provider) {
        return _HourlyDashboardVm(
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
            onRetry: _retry,
          );
        }

        return Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: UtilityHourlyCompare(
                    rows: vm.electricity,
                    facId: widget.facId,
                    title: 'Electricity Hourly',
                    theme: ChartThemes.power,
                    loading: vm.loading,
                    error: vm.error,
                    onRetry: _retry,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: UtilityHourlySensorPanel(
                    rows: vm.water,
                    facId: widget.facId,
                    theme: ChartThemes.water,
                    utilityType: 'WATER',
                    loading: vm.loading,
                    error: vm.error,
                    onRetry: _retry,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: UtilityHourlySensorPanel(
                    rows: vm.air,
                    facId: widget.facId,
                    theme: ChartThemes.air,
                    utilityType: 'AIR',
                    loading: vm.loading,
                    error: vm.error,
                    onRetry: _retry,
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

class _HourlyDashboardVm {
  final bool loading;
  final bool refreshing;
  final Object? error;

  final List<HourlyEnergyPoint> electricity;
  final List<HourlySensorPoint> water;
  final List<HourlySensorPoint> air;

  const _HourlyDashboardVm({
    required this.loading,
    required this.refreshing,
    required this.error,
    required this.electricity,
    required this.water,
    required this.air,
  });
}
