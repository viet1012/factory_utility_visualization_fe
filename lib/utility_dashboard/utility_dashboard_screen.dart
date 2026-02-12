import 'package:dio/dio.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_catalog/utility_catalog_tabs_screen.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_common/industrial_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utility_api/utility_api.dart';
import '../utility_models/utility_facade_service.dart'; // ✅
import '../utility_state/latest_provider.dart';
import '../utility_state/minute_series_provider.dart';
import '../utility_state/sum_compare_provider.dart';
import 'ultility_dashboard_chart/utility_minute_chart_screen.dart';
import 'utility_dashboard_widgets/utility_dashboard_map.dart';

class UtilityDashboardScreen extends StatefulWidget {
  const UtilityDashboardScreen({super.key});

  @override
  State<UtilityDashboardScreen> createState() => _UtilityDashboardScreenState();
}

class _UtilityDashboardScreenState extends State<UtilityDashboardScreen> {
  final String mainImageUrl = 'assets/images/SPC2.png';

  late final UtilityApi api; // bạn đang dùng
  late final UtilityFacadeService facade; // ✅ thêm
  @override
  void initState() {
    super.initState();

    const baseUrl = 'http://localhost:9999';

    api = UtilityApi(baseUrl: baseUrl);

    // ✅ facade dùng Dio
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    facade = UtilityFacadeService(dio);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: facade), // ✅ cho tiện lấy ở mọi nơi

        ChangeNotifierProvider(
          create: (_) {
            final p = SumCompareProvider(
              api: api,
              interval: const Duration(seconds: 30),
            );
            p.startPolling();
            return p;
          },
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
      ],
      child: DefaultTabController(
        length: 3, // ✅ thêm tab Table
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
                  // const Padding(
                  //   padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                  //   child: ScadaTabBar(),
                  // ),
                  IndustrialTabBar(
                    tabs: const [
                      IndustrialTabItem(icon: Icons.map_outlined, text: 'MAP'),
                      IndustrialTabItem(icon: Icons.show_chart, text: 'CHARTS'),
                      IndustrialTabItem(
                        icon: Icons.table_view,
                        text: 'SCADA TABLE',
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

                        // ✅ XÀI ScadaTableSection ở đây
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Consumer<UtilityFacadeService>(
                            builder: (context, svc, _) {
                              return UtilityCatalogTabsScreen();
                            },
                          ),
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
