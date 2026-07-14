import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../utility_dashboard_overview_hourly/utility_dashboard_overview_hourly_widgets/CoolingTankTemperaturePanel.dart';
import '../utility_dashboard_overview_hourly/utility_dashboard_overview_hourly_widgets/utility_dashboard_overview_hourly_compare.dart';
import '../utility_dashboard_overview_hourly/utility_dashboard_overview_hourly_widgets/utility_dashboard_overview_hourly_header.dart';
import '../utility_dashboard_overview_minutely/utility_minute_dashboard_section.dart';
import '../utility_dashboard_overview_models/utility_hourly_dashboard_response.dart';
import '../utility_dashboard_overview_provider/utility_hourly_dashboard_provider.dart';
import '../utility_dashboard_overview_widgets/chart_state_widgets.dart';
import '../utility_dashboard_overview_widgets/scada_tab_button.dart';

class UtilityRealtimeTabPanel extends StatefulWidget {
  final String selectedFac;
  final String nowStr;
  final String yStr;

  const UtilityRealtimeTabPanel({
    super.key,
    required this.selectedFac,
    required this.nowStr,
    required this.yStr,
  });

  @override
  State<UtilityRealtimeTabPanel> createState() =>
      _UtilityRealtimeTabPanelState();
}

class _UtilityRealtimeTabPanelState extends State<UtilityRealtimeTabPanel> {
  int selectedTab = 0;

  bool _builtMinutes = true;
  bool _builtHourly = false;

  void _selectTab(int index) {
    if (selectedTab == index) return;

    setState(() {
      selectedTab = index;

      if (index == 0) {
        _builtMinutes = true;
      } else {
        _builtHourly = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _tabHeader(),
        const SizedBox(height: 6),
        Expanded(
          child: IndexedStack(
            index: selectedTab,
            children: [
              TickerMode(
                enabled: selectedTab == 0,
                child: _builtMinutes ? _minutesView() : const SizedBox.shrink(),
              ),
              TickerMode(
                enabled: selectedTab == 1,
                child: _builtHourly ? _hourlyView() : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScadaTabButton(
          label: 'MINUTELY',
          selected: selectedTab == 0,
          onTap: () => _selectTab(0),
        ),
        const SizedBox(width: 8),
        ScadaTabButton(
          label: 'HOURLY',
          selected: selectedTab == 1,
          onTap: () => _selectTab(1),
        ),
      ],
    );
  }

  Widget _minutesView() {
    return UtilityMinuteDashboardSection(
      key: const PageStorageKey<String>('minutes_view'),
      facId: widget.selectedFac,
      minutes: 60,
    );
  }

  Widget _hourlyView() {
    return Column(
      key: const PageStorageKey<String>('hourly_view'),
      children: [
        UtilityDashboardOverviewHourlyHeader(
          title: '[HOURLY COMPARE]',
          subtitle: 'Today: ${widget.nowStr}  •  Prev: ${widget.yStr}',
        ),
        const SizedBox(height: 6),
        Expanded(
          child: UtilityHourlyDashboardSection(facId: widget.selectedFac),
        ),
      ],
    );
  }
}

// ============================================================
// HOURLY DASHBOARD SECTION
// ============================================================

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

  @override
  void initState() {
    super.initState();

    _provider = context.read<UtilityHourlyDashboardProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      unawaited(_provider.start(facId: widget.facId));
    });
  }

  @override
  void didUpdateWidget(covariant UtilityHourlyDashboardSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.facId == widget.facId) {
      return;
    }

    unawaited(_provider.start(facId: widget.facId));
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
            onRetry: () {
              unawaited(_provider.load());
            },
          );
        }

        return Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: UtilityDashboardOverviewHourlyCompare(
                    rows: vm.electricity,
                    facId: widget.facId,
                    title: 'Electricity Hourly',
                    theme: ChartThemes.power,
                    loading: vm.loading,
                    error: vm.error,
                    onRetry: () {
                      unawaited(_provider.load());
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: CoolingTankTemperaturePanel(
                    rows: vm.water,
                    facId: widget.facId,
                    theme: ChartThemes.water,
                    utilityType: 'WATER',
                    loading: vm.loading,
                    error: vm.error,
                    onRetry: () {
                      unawaited(_provider.load());
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: CoolingTankTemperaturePanel(
                    rows: vm.air,
                    facId: widget.facId,
                    theme: ChartThemes.air,
                    utilityType: 'AIR',
                    loading: vm.loading,
                    error: vm.error,
                    onRetry: () {
                      unawaited(_provider.load());
                    },
                  ),
                ),
              ],
            ),

            // Silent refresh:
            // giữ dữ liệu/chart cũ và chỉ hiện thanh nhỏ.
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

// ============================================================
// VIEW MODEL
// ============================================================

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
