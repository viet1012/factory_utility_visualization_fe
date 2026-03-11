import 'package:dio/dio.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_api/utility_dashboard_overview_api.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_widgets/industrial_side_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utility_alarm/alarm_api.dart';
import '../utility_alarm/alarm_provider.dart';
import '../utility_alarm/utility_alarm_center_screen.dart';
import '../utility_api/dio_client.dart';
import '../utility_api/utility_api.dart';
import '../utility_models/utility_facade_service.dart';
import '../utility_state/chart_catalog_provider.dart';
import '../utility_state/hourly_series_provider.dart';
import '../utility_state/minute_series_provider.dart';
import '../utility_state/sum_compare_provider.dart';
import '../utility_state/tree_latest_provider.dart';
import 'ultility_dashboard_chart/utility_minute_chart_screen.dart';
import 'utility_catalog/utility_catalog_tabs_screen.dart';
import 'utility_dashboard_overview/utility_dashboard_overview.dart';

class UtilityDashboardScreen extends StatefulWidget {
  const UtilityDashboardScreen({super.key});

  @override
  State<UtilityDashboardScreen> createState() => _UtilityDashboardScreenState();
}

class _UtilityDashboardScreenState extends State<UtilityDashboardScreen>
    with SingleTickerProviderStateMixin {
  final String mainImageUrl = 'assets/images/SPC2.png';

  late final UtilityApi api;
  late final Dio dio;
  late final UtilityFacadeService facade;
  late final AlarmApi alarmApi;

  bool _sideExpanded = true; // ✅ mở/đóng sidebar
  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    // const baseUrl = 'http://192.168.122.16:9093';
    const baseUrl = 'http://localhost:9999';
    DioClient.init(baseUrl: baseUrl);
    _tabController = TabController(length: 4, vsync: this);
    dio = DioClient.dio;
    api = UtilityApi(dio: dio);

    facade = UtilityFacadeService(dio);
    alarmApi = AlarmApi(dio);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Dio>.value(value: dio),

        Provider<UtilityDashboardOverviewApi>.value(
          value: UtilityDashboardOverviewApi(dio),
        ),

        Provider<UtilityApi>.value(value: api),
        Provider<UtilityFacadeService>.value(value: facade),
        Provider<AlarmApi>.value(value: alarmApi),

        ChangeNotifierProvider(
          create: (_) => SumCompareProvider(
            api: api,
            interval: const Duration(seconds: 30),
          ),
        ),

        ChangeNotifierProvider(
          create: (_) {
            final p = MinuteSeriesProvider(
              api: api,
              interval: const Duration(seconds: 30),
              window: const Duration(minutes: 60),
            );
            p.startPolling();
            return p;
          },
        ),

        ChangeNotifierProvider(create: (_) => TreeSeriesProvider(api)),
        ChangeNotifierProvider(create: (_) => ChartCatalogProvider(api)),

        ChangeNotifierProvider(
          create: (_) {
            final p = AlarmProvider(
              api: alarmApi,
              interval: const Duration(seconds: 15),
            );
            p.startPolling();
            return p;
          },
        ),

        ChangeNotifierProvider(create: (_) => TreeLatestProvider(facade)),
      ],
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0a0e27), Color(0xFF1a1a2e), Color(0xFF16213e)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                // ✅ SIDEBAR TAB DỌC
                IndustrialSideTabBar(
                  controller: _tabController,
                  expanded: _sideExpanded,
                  onToggle: () =>
                      setState(() => _sideExpanded = !_sideExpanded),
                  tabs: const [
                    IndustrialSideTabItem(
                      icon: Icons.map_outlined,
                      text: 'MAP',
                    ),
                    IndustrialSideTabItem(
                      icon: Icons.show_chart,
                      text: 'CHARTS',
                    ),
                    IndustrialSideTabItem(
                      icon: Icons.table_view,
                      text: 'SCADA TABLE',
                    ),
                    IndustrialSideTabItem(
                      icon: Icons.notifications_active,
                      text: 'ALARMS',
                    ),
                  ],
                ),

                // ✅ CONTENT
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: UtilityDashboardOverview(
                          mainImageUrl: mainImageUrl,
                        ),
                      ),
                      const UtilityAllFactoriesChartsScreen(),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: UtilityCatalogTabsScreen(),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: UtilityAlarmCenterScreen(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
