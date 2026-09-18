import 'dart:async';

import 'package:dio/dio.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_all_factory_chart/utility_chart_screen.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_all_factory_chart/api/utility_chart_api.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_catalog/api/utility_latest_api.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_catalog/providers/latest_provider.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_catalog/utility_catalog_tabs_screen.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_alarm/SignalHealthMatrixController.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_alarm/api/signal_health_api.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_alarm/utility_alarm_center_screen.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/api/utility_dashboard_overview_api.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/providers/utility_daily_dashboard_provider.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/providers/utility_hourly_dashboard_provider.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/providers/utility_minute_dashboard_provider.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/providers/utility_monthly_summary_provider.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_widgets/industrial_side_tab_bar.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/utility_dashboard_setting_screens/utility_setting_screen.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/channel/api/utility_scada_channel_api.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/para/api/utility_para_api.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/scada/api/utility_scada_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utility_api/dio_client.dart';
import 'utility_dashboard_fac_details/api/utility_facade_service.dart';
import 'utility_all_factory_chart/controllers/utility_chart_catalog_controller.dart';
import 'utility_all_factory_chart/controllers/utility_daily_signal_controller.dart';
import 'utility_all_factory_chart/controllers/utility_minute_chart_controller.dart';
import 'utility_dashboard_overview/utility_dashboard_overview.dart';

class UtilityDashboardScreen extends StatefulWidget {
  const UtilityDashboardScreen({super.key});

  @override
  State<UtilityDashboardScreen> createState() => _UtilityDashboardScreenState();
}

class _UtilityDashboardScreenState extends State<UtilityDashboardScreen>
    with SingleTickerProviderStateMixin {
  // static const String _baseUrl = 'http://192.168.122.16:9093';

  static const _baseUrl = 'http://localhost:9999';

  static const int _tabCount = 5;

  static const List<IndustrialSideTabItem> _tabs = [
    IndustrialSideTabItem(icon: Icons.map_outlined, text: 'MAP'),
    IndustrialSideTabItem(icon: Icons.show_chart, text: 'CHARTS'),
    IndustrialSideTabItem(icon: Icons.table_view, text: 'SCADA TABLE'),
    IndustrialSideTabItem(icon: Icons.notifications_active, text: 'ALARMS'),
    IndustrialSideTabItem(icon: Icons.settings, text: 'SETTING'),
  ];

  final String mainImageUrl = 'assets/images/SPC2_AM.png';
  final String nightImageUrl = 'assets/images/SPC2_CyberBunk.jpg';

  late final Dio dio;

  late final UtilityChartApi chartApi;
  late final UtilityLatestApi latestApi;
  late final UtilityDashboardOverviewApi overviewApi;
  late final SignalHealthApi signalHealthApi;
  late final UtilityFacadeService facade;

  late final UtilityScadaChannelApi scadaChannelApi;
  late final UtilityScadaApi scadaApi;
  late final UtilityParaApi paraApi;

  late final UtilityMinuteChartController minuteSeriesProvider;
  late final UtilityChartCatalogController chartCatalogProvider;
  late final LatestProvider latestProvider;

  late final SignalHealthMatrixController signalHealthController;

  late final UtilityMinuteDashboardProvider minuteDashboardProvider;
  late final UtilityHourlyDashboardProvider hourlyDashboardProvider;
  late final UtilityDailyDashboardProvider dailyDashboardProvider;
  late final UtilityMonthlySummaryProvider monthlySummaryProvider;

  late final UtilityDailySignalController dailySignalProvider;

  late final TabController _tabController;

  bool _sideExpanded = true;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();

    _initializeNetwork();
    _initializeApis();
    _initializeProviders();
    _initializeTabController();
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  void _initializeNetwork() {
    if (!DioClient.isInitialized) {
      DioClient.init(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 30),
      );
    }

    dio = DioClient.dio;
  }

  void _initializeApis() {
    chartApi = UtilityChartApi(dio: dio);

    latestApi = UtilityLatestApi(dio: dio);

    overviewApi = UtilityDashboardOverviewApi();
    signalHealthApi = SignalHealthApi();

    facade = UtilityFacadeService(dio);

    scadaChannelApi = UtilityScadaChannelApi(baseUrl: _baseUrl);

    scadaApi = UtilityScadaApi(baseUrl: _baseUrl);

    paraApi = UtilityParaApi(baseUrl: _baseUrl);
  }

  void _initializeProviders() {
    minuteSeriesProvider = UtilityMinuteChartController(
      api: chartApi,
      interval: const Duration(seconds: 30),
      window: const Duration(minutes: 60),
      requestTimeout: const Duration(seconds: 15),
    );

    dailySignalProvider = UtilityDailySignalController(api: chartApi);

    chartCatalogProvider = UtilityChartCatalogController(chartApi);

    latestProvider = LatestProvider(api: latestApi);

    signalHealthController = SignalHealthMatrixController(signalHealthApi)
      ..startPolling();

    minuteDashboardProvider = UtilityMinuteDashboardProvider(overviewApi);

    hourlyDashboardProvider = UtilityHourlyDashboardProvider(overviewApi);

    dailyDashboardProvider = UtilityDailyDashboardProvider(overviewApi);

    monthlySummaryProvider = UtilityMonthlySummaryProvider(overviewApi);
  }

  void _initializeTabController() {
    _tabController = TabController(length: _tabCount, vsync: this);

    _tabController.addListener(_handleTabChanged);
  }

  // ============================================================
  // TAB EVENTS
  // ============================================================

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }

    final nextIndex = _tabController.index;

    if (_tabIndex == nextIndex) {
      return;
    }

    final wasMapTab = _tabIndex == 0;
    final isMapTab = nextIndex == 0;
    final wasScadaTableTab = _tabIndex == 2;
    final isScadaTableTab = nextIndex == 2;

    setState(() {
      _tabIndex = nextIndex;
    });

    if (isMapTab) {
      unawaited(minuteDashboardProvider.resume());
      unawaited(hourlyDashboardProvider.resume());
      unawaited(dailyDashboardProvider.resume());
      unawaited(monthlySummaryProvider.resume());
    } else if (wasMapTab) {
      minuteDashboardProvider.pause();
      hourlyDashboardProvider.pause();
      dailyDashboardProvider.pause();
      monthlySummaryProvider.pause();
    }

    if (isMapTab) {
      signalHealthController.startPolling();
    } else {
      signalHealthController.stopPolling();
    }

    if (isScadaTableTab) {
      unawaited(_activateLatestFullTreePolling());
    } else if (wasScadaTableTab) {
      latestProvider.stopPolling();
    }
  }

  Future<void> _activateLatestFullTreePolling() async {
    if (latestProvider.hasData) {
      await latestProvider.refreshAll();
    } else {
      await latestProvider.loadInitial();
    }

    if (!mounted || _tabIndex != 2) return;

    latestProvider.startPolling();
  }

  void _toggleSideBar() {
    setState(() {
      _sideExpanded = !_sideExpanded;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Dio>.value(value: dio),

        Provider<UtilityDashboardOverviewApi>.value(value: overviewApi),

        Provider<UtilityFacadeService>.value(value: facade),

        ChangeNotifierProvider<UtilityMinuteChartController>.value(
          value: minuteSeriesProvider,
        ),

        ChangeNotifierProvider<UtilityDailySignalController>.value(
          value: dailySignalProvider,
        ),

        ChangeNotifierProvider<UtilityChartCatalogController>.value(
          value: chartCatalogProvider,
        ),

        ChangeNotifierProvider<LatestProvider>.value(value: latestProvider),

        ChangeNotifierProvider<SignalHealthMatrixController>.value(
          value: signalHealthController,
        ),

        ChangeNotifierProvider<UtilityMinuteDashboardProvider>.value(
          value: minuteDashboardProvider,
        ),

        ChangeNotifierProvider<UtilityHourlyDashboardProvider>.value(
          value: hourlyDashboardProvider,
        ),

        ChangeNotifierProvider<UtilityDailyDashboardProvider>.value(
          value: dailyDashboardProvider,
        ),

        ChangeNotifierProvider<UtilityMonthlySummaryProvider>.value(
          value: monthlySummaryProvider,
        ),
      ],
      child: Scaffold(
        body: Container(
          decoration: _buildBackgroundDecoration(),
          child: SafeArea(
            child: Row(
              children: [
                IndustrialSideTabBar(
                  controller: _tabController,
                  expanded: _sideExpanded,
                  onToggle: _toggleSideBar,
                  tabs: _tabs,
                ),
                Expanded(
                  child: IndexedStack(
                    index: _tabIndex,
                    children: [
                      _buildOverviewTab(),
                      _buildChartsTab(),
                      _buildCatalogTab(),
                      _buildAlarmTab(),
                      _buildSettingTab(),
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

  BoxDecoration _buildBackgroundDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF03111F), Color(0xFF051A2E), Color(0xFF020814)],
      ),
      border: Border.all(color: const Color(0xFF00CFFF).withOpacity(.35)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF00CFFF).withOpacity(.10),
          blurRadius: 18,
          spreadRadius: 1,
        ),
      ],
    );
  }

  // ============================================================
  // TAB CONTENT
  // ============================================================

  Widget _buildOverviewTab() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: UtilityDashboardOverview(
        isActive: _tabIndex == 0,
        mainImageUrl: mainImageUrl,
        nightImageUrl: nightImageUrl,
      ),
    );
  }

  Widget _buildChartsTab() {
    return RepaintBoundary(
      child: UtilityChartScreen(isCurrentScreen: _tabIndex == 1),
    );
  }

  Widget _buildCatalogTab() {
    return const Padding(
      padding: EdgeInsets.all(8),
      child: UtilityCatalogTabsScreen(),
    );
  }

  Widget _buildAlarmTab() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SignalHealthMatrixScreen(isActive: _tabIndex == 3),
    );
  }

  Widget _buildSettingTab() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: UtilityScadaSettingScreen(
        isActive: _tabIndex == 4,
        scadaApi: scadaApi,
        channelApi: scadaChannelApi,
        paraApi: paraApi,
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);

    _tabController.dispose();

    minuteSeriesProvider.dispose();
    chartCatalogProvider.dispose();
    latestProvider.dispose();
    dailySignalProvider.dispose();

    signalHealthController.dispose();

    minuteDashboardProvider.dispose();
    hourlyDashboardProvider.dispose();
    dailyDashboardProvider.dispose();
    monthlySummaryProvider.dispose();

    scadaChannelApi.dispose();
    scadaApi.dispose();

    super.dispose();
  }
}
