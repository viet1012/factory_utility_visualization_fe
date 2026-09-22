import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/polling/polling_coordinator.dart';
import '../shared/polling/polling_scope.dart';
import 'hourly/utility_hourly_dashboard_section.dart';
import 'hourly/utility_hourly_header.dart';
import 'minutely/utility_minutely_dashboard_section.dart';
import '../shared/widgets/scada_tab_button.dart';

class UtilityRealtimeTabPanel extends StatefulWidget {
  /// MAP tab dang hien thi hay khong.
  final bool isActive;

  final String selectedFac;
  final String nowStr;
  final String yStr;

  const UtilityRealtimeTabPanel({
    super.key,
    required this.isActive,
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

  bool _builtMinutely = true;
  bool _builtHourly = false;

  int _syncToken = 0;

  @override
  void initState() {
    super.initState();

    _scheduleSyncPolling();
  }

  @override
  void didUpdateWidget(covariant UtilityRealtimeTabPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isActive == widget.isActive) return;

    _scheduleSyncPolling();
  }

  @override
  void dispose() {
    _syncToken++;
    super.dispose();
  }

  void _scheduleSyncPolling() {
    final token = ++_syncToken;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (token != _syncToken) return;

      _syncPolling();
    });
  }

  void _selectTab(int index) {
    if (selectedTab == index) return;

    setState(() {
      selectedTab = index;

      if (index == 0) {
        _builtMinutely = true;
      } else {
        _builtHourly = true;
      }
    });

    _scheduleSyncPolling();
  }

  void _syncPolling() {
    if (!mounted) return;

    final minuteActive = widget.isActive && selectedTab == 0;
    final hourlyActive = widget.isActive && selectedTab == 1;

    final coordinator = context.read<PollingCoordinator>();

    if (minuteActive) {
      coordinator.activateScope(PollingScope.mapMinutely);
    } else {
      coordinator.deactivateScope(PollingScope.mapMinutely);
    }

    if (hourlyActive) {
      coordinator.activateScope(PollingScope.mapHourly);
    } else {
      coordinator.deactivateScope(PollingScope.mapHourly);
    }
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
                child: _builtMinutely
                    ? _minutelyView()
                    : const SizedBox.shrink(),
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

  Widget _minutelyView() {
    return UtilityMinutelyDashboardSection(
      key: const PageStorageKey<String>('minutely_view'),
      facId: widget.selectedFac,
      minutes: 60,
    );
  }

  Widget _hourlyView() {
    return Column(
      key: const PageStorageKey<String>('hourly_view'),
      children: [
        UtilityHourlyHeader(
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
