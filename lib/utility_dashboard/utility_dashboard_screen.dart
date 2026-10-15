import 'dart:async';

import 'package:dio/dio.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_all_factory_chart/utility_chart_screen.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_all_factory_chart/api/utility_chart_api.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_catalog/api/api_signal_history_repository.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_catalog/api/signal_history_repository.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_catalog/api/utility_latest_api.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_catalog/providers/latest_provider.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_catalog/utility_catalog_tabs_screen.dart';
import 'package:factory_utility_visualization/utility_dashboard/signal_health/api/signal_health_api.dart';
import 'package:factory_utility_visualization/utility_dashboard/signal_health/controllers/signal_health_matrix_controller.dart';
import 'package:factory_utility_visualization/utility_dashboard/signal_health/screens/signal_health_matrix_screen.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/api/utility_dashboard_overview_api.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/providers/utility_daily_dashboard_provider.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/providers/utility_hourly_dashboard_provider.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/providers/utility_minute_dashboard_provider.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/providers/utility_monthly_summary_provider.dart';
import 'package:factory_utility_visualization/utility_dashboard/shared/navigation/industrial_side_tab_bar.dart';
import 'package:factory_utility_visualization/utility_dashboard/shared/polling/dashboard_polling_intervals.dart';
import 'package:factory_utility_visualization/utility_dashboard/shared/polling/polling_coordinator.dart';
import 'package:factory_utility_visualization/utility_dashboard/shared/polling/polling_scope.dart';
import 'package:factory_utility_visualization/utility_dashboard/shared/polling/polling_task_ids.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/utility_dashboard_setting_screens/utility_setting_screen.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/channel/api/utility_scada_channel_api.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/para/api/utility_para_api.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/scada/api/utility_scada_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../utility_api/api_config.dart';
import '../utility_api/dio_client.dart';
import 'utility_dashboard_fac_details/api/utility_facade_service.dart';
import 'shared/visibility/app_visibility.dart';
import 'utility_all_factory_chart/controllers/utility_chart_catalog_controller.dart';
import 'utility_all_factory_chart/controllers/utility_chart_controller.dart';
import 'utility_all_factory_chart/controllers/utility_daily_chart_controller.dart';
import 'utility_all_factory_chart/controllers/utility_hourly_chart_controller.dart';
import 'utility_all_factory_chart/controllers/utility_minute_chart_controller.dart';
import 'utility_dashboard_overview/utility_dashboard_overview.dart';
import 'water_check/api/water_check_api.dart';
import 'water_check/controllers/water_check_controller.dart';
import 'water_check/water_check_screen.dart';
import 'water_check/water_fullscreen.dart';
import 'water_check/widgets/water_signal_chart_dialog.dart';

class UtilityDashboardScreen extends StatefulWidget {
  const UtilityDashboardScreen({super.key});

  @override
  State<UtilityDashboardScreen> createState() => _UtilityDashboardScreenState();
}

class _UtilityDashboardScreenState extends State<UtilityDashboardScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  static const int _tabCount = 6;

  static const int _mapTab = 0;
  static const int _chartsTab = 1;
  static const int _waterCheckTab = 2;
  static const int _scadaTableTab = 3;
  static const int _alarmsTab = 4;
  static const int _settingTab = 5;

  static const List<IndustrialSideTabItem> _tabs = [
    IndustrialSideTabItem(icon: Icons.map_outlined, text: 'MAIN'),
    IndustrialSideTabItem(icon: Icons.show_chart, text: 'CHARTS'),
    IndustrialSideTabItem(icon: Icons.monitor_outlined, text: 'MONITORING'),
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

  /// Lich su signal dung chung (cache + dedupe) cho CHARTS (Minutes / Hourly /
  /// Daily) va SCADA TABLE.
  late final SignalHistoryRepository signalHistoryRepository;

  late final UtilityMinuteChartController minuteSeriesProvider;
  late final UtilityChartCatalogController chartCatalogProvider;
  late final LatestProvider latestProvider;
  late final PollingCoordinator pollingCoordinator;

  late final SignalHealthMatrixController signalHealthController;

  late final WaterCheckApi waterCheckApi;
  late final WaterCheckController waterCheckController;

  /// WATER CHECK › Open in Charts: CHARTS nghe va chon dung fac / box / device.
  final ValueNotifier<ChartFocusRequest?> _chartFocusRequest =
      ValueNotifier<ChartFocusRequest?>(null);

  late final UtilityMinuteDashboardProvider minuteDashboardProvider;
  late final UtilityHourlyDashboardProvider hourlyDashboardProvider;
  late final UtilityDailyDashboardProvider dailyDashboardProvider;
  late final UtilityMonthlySummaryProvider monthlySummaryProvider;

  late final UtilityDailyChartController dailySignalProvider;
  late final UtilityHourlyChartController hourlyChartProvider;

  late final TabController _tabController;

  bool _sideExpanded = true;
  int _tabIndex = 0;

  /// WATER CHECK › Full screen: an thanh tab chinh + fullscreen trinh duyet.
  bool _waterFullScreen = false;
  VoidCallback? _cancelFullscreenListener;

  @override
  void initState() {
    super.initState();

    _initializeNetwork();
    _initializeApis();
    _initializeProviders();
    _initializeTabController();

    AppVisibility.instance.addListener(_syncVisibility);
    _syncVisibility();

    _cancelFullscreenListener = BrowserFullscreen.listen(
      _handleBrowserFullscreenChanged,
    );
    HardwareKeyboard.instance.addHandler(_handleEscape);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncInitialTopLevelPollingScopes();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      appRouteObserver.subscribe(this, route);
    }
  }

  // ============================================================
  // VISIBILITY
  // ============================================================

  /// Facility detail / Solar detail duoc push len tren dashboard.
  @override
  void didPushNext() {
    AppVisibility.instance.setDashboardCovered(true);
  }

  /// Route che dashboard da dong.
  @override
  void didPopNext() {
    AppVisibility.instance.setDashboardCovered(false);
  }

  /// Tab trinh duyet an: dung moi polling. Dashboard bi che: dung scope cua
  /// dashboard (MAP, CHARTS, SCADA TABLE, ALARMS), scope cua route chi tiet
  /// van chay. Hien lai: PollingCoordinator chay ngay mot luot cho scope dang
  /// hien (task chu ky dai chi chay khi da qua han).
  void _syncVisibility() {
    final visibility = AppVisibility.instance;

    pollingCoordinator.setPaused(!visibility.pageVisible);
    pollingCoordinator.setSuppressed(
      PollingScope.dashboardScopes,
      visibility.dashboardCovered,
    );
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  void _initializeNetwork() {
    if (!DioClient.isInitialized) {
      DioClient.init(
        baseUrl: apiBaseUrl,
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
    waterCheckApi = WaterCheckApi(dio: dio);

    facade = UtilityFacadeService(dio);

    // Setting: cung Dio dung chung, timeout 30s rieng cho tung request.
    scadaChannelApi = UtilityScadaChannelApi(dio: dio);

    scadaApi = UtilityScadaApi(dio: dio);

    paraApi = UtilityParaApi(dio: dio);
  }

  void _initializeProviders() {
    latestProvider = LatestProvider(api: latestApi);

    signalHistoryRepository = ApiSignalHistoryRepository(
      api: chartApi,
      source: () => latestProvider.items,
      sourceVersion: () => latestProvider.dataVersion,
    );

    minuteSeriesProvider = UtilityMinuteChartController(
      repository: signalHistoryRepository,
      window: const Duration(minutes: 60),
      requestTimeout: const Duration(seconds: 15),
    );

    dailySignalProvider = UtilityDailyChartController(
      repository: signalHistoryRepository,
    );

    hourlyChartProvider = UtilityHourlyChartController(
      repository: signalHistoryRepository,
    );

    chartCatalogProvider = UtilityChartCatalogController(chartApi);

    signalHealthController = SignalHealthMatrixController(signalHealthApi);

    waterCheckController = WaterCheckController(api: waterCheckApi);

    minuteDashboardProvider = UtilityMinuteDashboardProvider(overviewApi);

    hourlyDashboardProvider = UtilityHourlyDashboardProvider(overviewApi);

    dailyDashboardProvider = UtilityDailyDashboardProvider(overviewApi);

    monthlySummaryProvider = UtilityMonthlySummaryProvider(overviewApi);

    pollingCoordinator = PollingCoordinator()
      ..register(
        id: PollingTaskIds.scadaLatestTree,
        scope: PollingScope.scadaTable,
        interval: DashboardPollingIntervals.scadaLatestTree,
        action: _refreshLatestFullTree,
        runImmediately: true,
      )
      ..register(
        id: PollingTaskIds.mapMinuteDashboard,
        scope: PollingScope.mapMinutely,
        interval: DashboardPollingIntervals.mapMinuteDashboard,
        action: minuteDashboardProvider.refresh,
        runImmediately: true,
      )
      ..register(
        id: PollingTaskIds.mapHourlyDashboard,
        scope: PollingScope.mapHourly,
        interval: DashboardPollingIntervals.mapHourlyDashboard,
        action: hourlyDashboardProvider.refresh,
        runImmediately: true,
      )
      ..register(
        id: PollingTaskIds.signalHealthMap,
        scope: PollingScope.map,
        interval: DashboardPollingIntervals.signalHealthMap,
        action: signalHealthController.refresh,
        runImmediately: true,
      )
      ..register(
        id: PollingTaskIds.signalHealthAlarms,
        scope: PollingScope.alarms,
        interval: DashboardPollingIntervals.signalHealthAlarms,
        action: signalHealthController.refresh,
        runImmediately: true,
      )
      ..register(
        id: PollingTaskIds.mapDailyDashboard,
        scope: PollingScope.map,
        interval: DashboardPollingIntervals.mapDailyDashboard,
        action: () => _refreshReportingErrors(
          dailyDashboardProvider.refresh,
          () => dailyDashboardProvider.error,
        ),
        runImmediately: true,
      )
      ..register(
        id: PollingTaskIds.mapMonthlySummary,
        scope: PollingScope.map,
        interval: DashboardPollingIntervals.mapMonthlySummary,
        action: () => _refreshReportingErrors(
          monthlySummaryProvider.refresh,
          () => monthlySummaryProvider.error,
        ),
        runImmediately: true,
      )
      ..register(
        id: PollingTaskIds.chartsMinuteSeries,
        scope: PollingScope.chartsMinutes,
        interval: DashboardPollingIntervals.chartsMinuteSeries,
        action: minuteSeriesProvider.poll,
        runImmediately: true,
      )
      // Tab Hourly tu tai khi mo (co cache 60s), polling chi lam moi dinh ky.
      ..register(
        id: PollingTaskIds.chartsHourlySeries,
        scope: PollingScope.chartsHourly,
        interval: DashboardPollingIntervals.chartsHourlySeries,
        action: hourlyChartProvider.poll,
      )
      // WATER CHECK: chi chay khi tab dang hien (scope rieng).
      ..register(
        id: PollingTaskIds.waterCheck,
        scope: PollingScope.waterCheck,
        interval: DashboardPollingIntervals.waterCheck,
        action: waterCheckController.refresh,
        runImmediately: true,
      )
      ..start(PollingTaskIds.signalHealthMap)
      ..start(PollingTaskIds.signalHealthAlarms)
      ..start(PollingTaskIds.chartsMinuteSeries)
      ..start(PollingTaskIds.chartsHourlySeries)
      ..start(PollingTaskIds.waterCheck);
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

    final wasMapTab = _tabIndex == _mapTab;
    final isMapTab = nextIndex == _mapTab;
    final wasChartsTab = _tabIndex == _chartsTab;
    final isChartsTab = nextIndex == _chartsTab;
    final wasWaterCheckTab = _tabIndex == _waterCheckTab;
    final isWaterCheckTab = nextIndex == _waterCheckTab;
    final wasScadaTableTab = _tabIndex == _scadaTableTab;
    final isScadaTableTab = nextIndex == _scadaTableTab;
    final wasAlarmsTab = _tabIndex == _alarmsTab;
    final isAlarmsTab = nextIndex == _alarmsTab;

    setState(() {
      _tabIndex = nextIndex;
    });

    if (wasMapTab && !isMapTab) {
      pollingCoordinator.deactivateScope(PollingScope.map);
    }
    if (wasChartsTab && !isChartsTab) {
      pollingCoordinator.deactivateScope(PollingScope.charts);
    }
    if (wasAlarmsTab && !isAlarmsTab) {
      pollingCoordinator.deactivateScope(PollingScope.alarms);
    }
    if (wasWaterCheckTab && !isWaterCheckTab) {
      pollingCoordinator.deactivateScope(PollingScope.waterCheck);
    }

    if (isMapTab) {
      pollingCoordinator.activateScope(PollingScope.map);
    }

    if (isChartsTab) {
      pollingCoordinator.activateScope(PollingScope.charts);
    }

    if (isAlarmsTab) {
      pollingCoordinator.activateScope(PollingScope.alarms);
    }

    if (isWaterCheckTab) {
      pollingCoordinator.activateScope(PollingScope.waterCheck);
    }

    if (isScadaTableTab) {
      pollingCoordinator.activateScope(PollingScope.scadaTable);
      pollingCoordinator.start(PollingTaskIds.scadaLatestTree);
    } else if (wasScadaTableTab) {
      pollingCoordinator.deactivateScope(PollingScope.scadaTable);
    }
  }

  /// Provider tu bat loi va giu data cu; nem lai loi de PollingCoordinator
  /// khong tinh la lan chay thanh cong. Task chu ky >= 1h dua vao lan thanh
  /// cong gan nhat de quyet dinh co tai ngay khi quay lai MAP hay khong.
  Future<void> _refreshReportingErrors(
    Future<void> Function() refresh,
    Object? Function() readError,
  ) async {
    await refresh();

    final error = readError();
    if (error != null) throw error;
  }

  Future<void> _refreshLatestFullTree() async {
    if (latestProvider.hasData) {
      await latestProvider.refreshAll();
    } else {
      await latestProvider.loadInitial();
    }
  }

  void _syncInitialTopLevelPollingScopes() {
    if (_tabIndex == _mapTab) {
      pollingCoordinator.deactivateScope(PollingScope.alarms);
      pollingCoordinator.activateScope(PollingScope.map);
    } else if (_tabIndex == _alarmsTab) {
      pollingCoordinator.deactivateScope(PollingScope.map);
      pollingCoordinator.activateScope(PollingScope.alarms);
    } else if (_tabIndex == _chartsTab) {
      pollingCoordinator.activateScope(PollingScope.charts);
    } else if (_tabIndex == _waterCheckTab) {
      pollingCoordinator.activateScope(PollingScope.waterCheck);
    }
  }

  // ============================================================
  // WATER CHECK FULL SCREEN
  // ============================================================

  void _toggleWaterFullScreen() {
    _setWaterFullScreen(!_waterFullScreen);
  }

  void _setWaterFullScreen(bool value) {
    if (_waterFullScreen == value) return;

    setState(() => _waterFullScreen = value);
    if (value) {
      BrowserFullscreen.enter();
    } else {
      BrowserFullscreen.exit();
    }
  }

  /// Trinh duyet thoat fullscreen (Esc / F11): hien lai thanh tab.
  void _handleBrowserFullscreenChanged() {
    if (!mounted) return;
    if (_waterFullScreen && !BrowserFullscreen.isActive) {
      setState(() => _waterFullScreen = false);
    }
  }

  /// Esc khi fullscreen trinh duyet bi tu choi (chi an thanh tab).
  bool _handleEscape(KeyEvent event) {
    if (!_waterFullScreen ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }

    _setWaterFullScreen(false);
    return true;
  }

  /// WATER CHECK › Open in Charts: chuyen sang CHARTS › Minutes tai signal.
  void _openInCharts(WaterSignalRef signal) {
    _setWaterFullScreen(false);
    _chartFocusRequest.value = ChartFocusRequest(
      facId: signal.facId,
      cate: 'Water',
      boxDeviceId: signal.boxDeviceId,
      plcAddress: signal.plcAddress,
    );
    _tabController.animateTo(_chartsTab);
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

        Provider<SignalHistoryRepository>.value(value: signalHistoryRepository),

        ChangeNotifierProvider<UtilityMinuteChartController>.value(
          value: minuteSeriesProvider,
        ),

        ChangeNotifierProvider<UtilityDailyChartController>.value(
          value: dailySignalProvider,
        ),

        ChangeNotifierProvider<UtilityHourlyChartController>.value(
          value: hourlyChartProvider,
        ),

        ChangeNotifierProvider<UtilityChartCatalogController>.value(
          value: chartCatalogProvider,
        ),

        ChangeNotifierProvider<LatestProvider>.value(value: latestProvider),

        Provider<PollingCoordinator>.value(value: pollingCoordinator),

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
                if (!_waterFullScreen)
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
                      _buildWaterCheckTab(),
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
      border: Border.all(color: const Color(0xFF00CFFF).withValues(alpha: .35)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF00CFFF).withValues(alpha: .10),
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
        isActive: _tabIndex == _mapTab,
        mainImageUrl: mainImageUrl,
        nightImageUrl: nightImageUrl,
      ),
    );
  }

  Widget _buildChartsTab() {
    return RepaintBoundary(
      child: UtilityChartScreen(
        isCurrentScreen: _tabIndex == _chartsTab,
        focusRequest: _chartFocusRequest,
      ),
    );
  }

  Widget _buildWaterCheckTab() {
    // IndexedStack khong tat ticker cua tab an: song nuoc cua bon chua dung
    // khi tab khong hien.
    return TickerMode(
      enabled: _tabIndex == _waterCheckTab,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: WaterCheckScreen(
          controller: waterCheckController,
          onOpenInCharts: _openInCharts,
          fullScreen: _waterFullScreen,
          onToggleFullScreen: _toggleWaterFullScreen,
        ),
      ),
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
      child: SignalHealthMatrixScreen(isActive: _tabIndex == _alarmsTab),
    );
  }

  Widget _buildSettingTab() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: UtilityScadaSettingScreen(
        isActive: _tabIndex == _settingTab,
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
    appRouteObserver.unsubscribe(this);
    _cancelFullscreenListener?.call();
    HardwareKeyboard.instance.removeHandler(_handleEscape);
    BrowserFullscreen.exit();
    AppVisibility.instance.removeListener(_syncVisibility);
    AppVisibility.instance.setDashboardCovered(false);

    _tabController.removeListener(_handleTabChanged);

    _tabController.dispose();

    minuteSeriesProvider.dispose();
    chartCatalogProvider.dispose();
    pollingCoordinator.dispose();
    latestProvider.dispose();
    dailySignalProvider.dispose();
    hourlyChartProvider.dispose();

    signalHealthController.dispose();
    waterCheckController.dispose();
    _chartFocusRequest.dispose();

    minuteDashboardProvider.dispose();
    hourlyDashboardProvider.dispose();
    dailyDashboardProvider.dispose();
    monthlySummaryProvider.dispose();

    super.dispose();
  }
}
