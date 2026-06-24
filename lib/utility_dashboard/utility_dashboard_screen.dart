import 'package:dio/dio.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_catalog/utility_catalog_tabs_screen.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_api/utility_dashboard_overview_api.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_widgets/industrial_side_tab_bar.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/utility_dashboard_setting_screens/utility_setting_screen.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/utility_para_api.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/utility_scada_api.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/utility_scada_channel_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utility_alarm/utility_alarm_center_screen.dart';
import '../utility_api/dio_client.dart';
import '../utility_api/utility_api.dart';
import '../utility_models/utility_facade_service.dart';
import '../utility_state/chart_catalog_provider.dart';
import '../utility_state/latest_provider.dart';
import '../utility_state/minute_series_provider.dart';
import '../utility_state/sum_compare_provider.dart';
import '../utility_state/tree_latest_provider.dart';
import 'ultility_dashboard_chart/utility_minute_chart_screen.dart';
import 'utility_dashboard_overview/utility_dashboard_overview.dart';

class UtilityDashboardScreen extends StatefulWidget {
  const UtilityDashboardScreen({super.key});

  @override
  State<UtilityDashboardScreen> createState() => _UtilityDashboardScreenState();
}

class _UtilityDashboardScreenState extends State<UtilityDashboardScreen>
    with SingleTickerProviderStateMixin {
  final String mainImageUrl = 'assets/images/SPC2.png';

  late final Dio dio;
  late final UtilityApi api;
  late final UtilityFacadeService facade;

  late final UtilityScadaChannelApi scadaChannelApi;
  late final UtilityScadaApi scadaApi;
  late final UtilityParaApi paraApi;

  late final MinuteSeriesProvider minuteSeriesProvider;
  late final SumCompareProvider sumCompareProvider;
  late final ChartCatalogProvider chartCatalogProvider;
  late final LatestProvider latestProvider;
  late final TreeLatestProvider treeLatestProvider;

  late final TabController _tabController;

  bool _sideExpanded = true;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();

    const baseUrl = 'http://192.168.122.16:9093';
    // const baseUrl = 'http://localhost:9999';

    DioClient.init(baseUrl: baseUrl);

    dio = DioClient.dio;
    api = UtilityApi(dio: dio);
    facade = UtilityFacadeService(dio);

    scadaChannelApi = UtilityScadaChannelApi(baseUrl: baseUrl);
    scadaApi = UtilityScadaApi(baseUrl: baseUrl);
    paraApi = UtilityParaApi(baseUrl: baseUrl);

    minuteSeriesProvider = MinuteSeriesProvider(
      api: api,
      interval: const Duration(seconds: 30),
      window: const Duration(minutes: 60),
    )..startPolling();

    sumCompareProvider = SumCompareProvider(
      api: api,
      interval: const Duration(seconds: 30),
    );

    chartCatalogProvider = ChartCatalogProvider(api);
    latestProvider = LatestProvider(api: api);

    treeLatestProvider = TreeLatestProvider(facade);

    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabIndex == _tabController.index) return;

    setState(() {
      _tabIndex = _tabController.index;
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();

    minuteSeriesProvider.dispose();
    sumCompareProvider.dispose();
    chartCatalogProvider.dispose();
    latestProvider.dispose();
    treeLatestProvider.dispose();

    scadaChannelApi.dispose();
    scadaApi.dispose();

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

        Provider<UtilityScadaChannelApi>.value(value: scadaChannelApi),
        Provider<UtilityScadaApi>.value(value: scadaApi),

        ChangeNotifierProvider<MinuteSeriesProvider>.value(
          value: minuteSeriesProvider,
        ),
        ChangeNotifierProvider<ChartCatalogProvider>.value(
          value: chartCatalogProvider,
        ),
        ChangeNotifierProvider<LatestProvider>.value(value: latestProvider),
        ChangeNotifierProvider<TreeLatestProvider>.value(
          value: treeLatestProvider,
        ),
      ],
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF03111F), // navy rất đậm
                const Color(0xFF051A2E), // dark blue
                const Color(0xFF020814), // gần đen// Đen xanh sâu
              ],
            ),

            border: Border.all(color: const Color(0xFF00CFFF).withOpacity(.35)),

            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00CFFF).withOpacity(.10),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),

          child: SafeArea(
            child: Row(
              children: [
                IndustrialSideTabBar(
                  controller: _tabController,
                  expanded: _sideExpanded,
                  onToggle: () {
                    setState(() {
                      _sideExpanded = !_sideExpanded;
                    });
                  },
                  tabs: const [
                    IndustrialSideTabItem(
                      icon: Icons.map_outlined,
                      text: 'MAP',
                    ),
                    // IndustrialSideTabItem(
                    //   icon: Icons.grid_view_outlined,
                    //   text: 'OVERVIEW',
                    // ),
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
                    IndustrialSideTabItem(
                      icon: Icons.settings,
                      text: 'SETTING',
                    ),
                  ],
                ),
                Expanded(
                  child: IndexedStack(
                    index: _tabIndex,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: UtilityDashboardOverview(
                          mainImageUrl: mainImageUrl,
                        ),
                      ),
                      // UtilityOverviewCommandScreen(),
                      const RepaintBoundary(
                        child: UtilityAllFactoriesChartsScreen(),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: UtilityCatalogTabsScreen(),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: SignalHealthMatrixScreen(),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: UtilityScadaSettingScreen(
                          scadaApi: scadaApi,
                          channelApi: scadaChannelApi,
                          paraApi: paraApi,
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
    );
  }
}
