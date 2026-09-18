import 'dart:async';

import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_alarm/SignalHealthHeader.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/daily/utility_daily_dashboard_section.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/map_category/utility_map_with_category_tabs.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_realtime_tab_panel.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly_summary/utility_dashboard_monthly_summary_screen.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_solar/solar_summary_card.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_widgets/utility_dashboard_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UtilityDashboardOverview extends StatefulWidget {
  final bool isActive;
  final String mainImageUrl;
  final String nightImageUrl;

  const UtilityDashboardOverview({
    super.key,
    required this.isActive,
    required this.mainImageUrl,
    required this.nightImageUrl,
  });

  @override
  State<UtilityDashboardOverview> createState() =>
      _UtilityDashboardOverviewState();
}

class _UtilityDashboardOverviewState extends State<UtilityDashboardOverview> {
  String selectedFac = 'KVH';
  DateTime selectedMonth = DateTime.now();

  Timer? _monthChangeTimer;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    selectedMonth = DateTime(now.year, now.month, 1);

    _startMonthWatcher();
  }

  void _startMonthWatcher() {
    _monthChangeTimer?.cancel();

    _monthChangeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;

      _checkAndUpdateCurrentMonth();
    });

    // Kiểm tra ngay khi bắt đầu, không cần chờ 1 phút.
    _checkAndUpdateCurrentMonth();
  }

  void _checkAndUpdateCurrentMonth() {
    if (!mounted) return;

    final now = DateTime.now();

    final currentMonth = DateTime(now.year, now.month, 1);

    final monthChanged =
        selectedMonth.year != currentMonth.year ||
        selectedMonth.month != currentMonth.month;

    if (!monthChanged) {
      return;
    }

    setState(() {
      selectedMonth = currentMonth;
    });

    debugPrint(
      '[MONTH WATCHER] Changed to '
      '${currentMonth.year}-'
      '${currentMonth.month.toString().padLeft(2, '0')}',
    );
  }

  @override
  void dispose() {
    _monthChangeTimer?.cancel();
    _monthChangeTimer = null;

    super.dispose();
  }

  String toYYYYMM(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}';

  bool shouldHighlight(String facId) {
    if (selectedFac == 'KVH') return true;
    return selectedFac == facId;
  }

  // 🔥 HANDLE ALARM (NO POPUP)
  @override
  Widget build(BuildContext context) {
    final nowStr = DateFormat('d/M/yyyy').format(DateTime.now());
    final yStr = DateFormat(
      'd/M/yyyy',
    ).format(DateTime.now().subtract(const Duration(days: 1)));

    final monthKey = toYYYYMM(selectedMonth);

    return Column(
      children: [
        UtilityDashboardTopBar(
          selectedFac: selectedFac,
          selectedMonth: selectedMonth,
          onFacChanged: (v) => setState(() => selectedFac = v),
          onMonthChanged: (m) =>
              setState(() => selectedMonth = DateTime(m.year, m.month, 1)),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),

                child: Column(
                  children: [
                    /// ===== TOP =====
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          /// LEFT CHART
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: LayoutBuilder(
                                builder: (context, _) {
                                  return Column(
                                    children: [
                                      Expanded(
                                        flex: 270,
                                        child: MonthlySummaryScreen(
                                          facId: selectedFac,
                                          month: monthKey,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Expanded(
                                        flex: 185,
                                        child: SolarSummaryCard(
                                          isActive: widget.isActive,
                                          facId: selectedFac,
                                          month: monthKey,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Expanded(
                                        flex: 138,
                                        child: const SignalHealthKpiScreen(),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),

                          /// MAP
                          Expanded(
                            flex: 2,
                            child: UtilityMapWithCategoryTabs(
                              isActive: widget.isActive,
                              mainImageUrl: widget.mainImageUrl,
                              monthKey: monthKey,
                              shouldHighlight: shouldHighlight,
                              nightImageUrl: widget.nightImageUrl,
                            ),
                          ),

                          Expanded(
                            child: UtilityRealtimeTabPanel(
                              selectedFac: selectedFac,
                              nowStr: nowStr,
                              yStr: yStr,
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// ===== BOTTOM =====
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: UtilityDailyDashboardSection(
                              facId: selectedFac,
                              month: monthKey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
