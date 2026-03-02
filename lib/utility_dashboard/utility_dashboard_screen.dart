import 'package:dio/dio.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_catalog/utility_catalog_tabs_screen.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_common/industrial_tab_bar.dart';
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
import '../utility_state/latest_provider.dart';
import '../utility_state/minute_series_provider.dart';
import '../utility_state/sum_compare_provider.dart';
import '../utility_state/tree_latest_provider.dart';
import 'ultility_dashboard_chart/utility_minute_chart_screen.dart';
import 'utility_dashboard_widgets/utility_dashboard_map.dart';

class UtilityDashboardScreen extends StatefulWidget {
  const UtilityDashboardScreen({super.key});

  @override
  State<UtilityDashboardScreen> createState() => _UtilityDashboardScreenState();
}

class _UtilityDashboardScreenState extends State<UtilityDashboardScreen> {
  final String mainImageUrl = 'assets/images/SPC2.png';

  late final UtilityApi api;
  late final Dio dio;
  late final UtilityFacadeService facade;
  late final AlarmApi alarmApi;

  @override
  void initState() {
    super.initState();

    const baseUrl = 'http://localhost:9999';

    DioClient.init(baseUrl: baseUrl);

    dio = DioClient.dio; // ✅ gán dio
    api = UtilityApi(dio: dio); // ✅ gán api

    facade = UtilityFacadeService(dio); // ✅ giờ mới an toàn
    alarmApi = AlarmApi(dio);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Dio>.value(value: dio),
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
            final p = LatestProvider(
              api: api,
              interval: const Duration(seconds: 30),
            );
            p.startPolling();
            return p;
          },
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

        ChangeNotifierProvider(
          create: (_) => TreeSeriesProvider(api), // ✅ khỏi read để tránh nhầm
        ),

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
        ChangeNotifierProvider(
          create: (_) =>
              TreeLatestProvider(facade), // hoặc UtilityFacadeService
        ),
      ],
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0a0e27),
                  Color(0xFF1a1a2e),
                  Color(0xFF16213e),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  IndustrialTabBar(
                    tabs: const [
                      IndustrialTabItem(icon: Icons.map_outlined, text: 'MAP'),
                      IndustrialTabItem(icon: Icons.show_chart, text: 'CHARTS'),
                      IndustrialTabItem(
                        icon: Icons.table_view,
                        text: 'SCADA TABLE',
                      ),
                      IndustrialTabItem(
                        icon: Icons.notifications_active,
                        text: 'ALARMS',
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: UtilityDashboardMap(
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
      ),
    );
  }
}
