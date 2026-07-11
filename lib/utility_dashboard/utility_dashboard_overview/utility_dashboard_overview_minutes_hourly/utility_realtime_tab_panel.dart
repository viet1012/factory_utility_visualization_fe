import 'package:flutter/material.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../utility_dashboard_overview_hourly/utility_dashboard_overview_hourly_widgets/CoolingTankTemperaturePanel.dart';
import '../utility_dashboard_overview_hourly/utility_dashboard_overview_hourly_widgets/utility_dashboard_overview_hourly_compare.dart';
import '../utility_dashboard_overview_hourly/utility_dashboard_overview_hourly_widgets/utility_dashboard_overview_hourly_header.dart';
import '../utility_dashboard_overview_minutely/utility_dashboard_overview_minutes_chart.dart';
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
    return Column(
      key: const PageStorageKey('minutes_view'),
      children: [
        // Container(color: Colors.orange),
        Expanded(
          child: UtilityDashboardOverviewMinutesChart(
            facId: widget.selectedFac,
            theme: ChartThemes.power,
            utilityType: 'ELECTRICITY',
          ),
        ),
        Expanded(
          child: UtilityDashboardOverviewMinutesChart(
            facId: widget.selectedFac,
            theme: ChartThemes.water,
            utilityType: 'WATER',
          ),
        ),
        Expanded(
          child: UtilityDashboardOverviewMinutesChart(
            facId: widget.selectedFac,
            theme: ChartThemes.air,
            utilityType: 'AIR',
          ),
        ),
      ],
    );
  }

  Widget _hourlyView() {
    return Column(
      key: const PageStorageKey('hourly_view'),
      children: [
        UtilityDashboardOverviewHourlyHeader(
          title: '[HOURLY COMPARE]',
          subtitle: 'Today: ${widget.nowStr}  •  Prev: ${widget.yStr}',
        ),
        Expanded(
          child: UtilityDashboardOverviewHourlyCompare(
            facId: widget.selectedFac,
            theme: ChartThemes.power,
          ),
        ),
        Expanded(
          child: CoolingTankTemperaturePanel(
            facId: widget.selectedFac,
            hours: 24,
            theme: ChartThemes.water,
            utilityType: 'WATER',
          ),
        ),
        Expanded(
          child: CoolingTankTemperaturePanel(
            facId: widget.selectedFac,
            hours: 24,
            theme: ChartThemes.air,
            utilityType: 'AIR',
          ),
        ),
      ],
    );
  }
}
