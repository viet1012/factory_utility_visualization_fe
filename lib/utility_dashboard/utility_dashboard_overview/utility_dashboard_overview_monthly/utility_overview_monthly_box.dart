import 'dart:async';

import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/monthly_air_card.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/monthly_electricity_card.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/monthly_metric_widgets.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/monthly_water_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_dashboard_fac_details/api/utility_facade_service.dart';
import '../../utility_catalog/providers/latest_provider.dart';
import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_common/data_health.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../../utility_dashboard_fac_details/screens/utility_fac_detail_screen.dart';
import '../api/utility_dashboard_overview_api.dart';
import '../models/energy_monthly_summary.dart';
import '../utility_dashboard_overview_widgets/utility_info_box_header.dart';

// ============================================================
// MONTHLY BOX
// ============================================================

class UtilityOverviewMonthlyBox extends StatefulWidget {
  final bool isActive;
  final double width;
  final double? height;

  final String facId;
  final String month;
  final String headerTitle;

  final bool isHighlighted;

  final String? filterCate;

  const UtilityOverviewMonthlyBox({
    super.key,
    required this.isActive,
    required this.facId,
    required this.month,
    required this.headerTitle,
    this.width = 330,
    this.height,
    this.isHighlighted = true,
    this.filterCate,
  });

  @override
  State<UtilityOverviewMonthlyBox> createState() {
    return _UtilityOverviewMonthlyBoxState();
  }
}

// ============================================================
// STATE
// ============================================================

class _UtilityOverviewMonthlyBoxState extends State<UtilityOverviewMonthlyBox>
    with TickerProviderStateMixin {
  // ============================================================
  // CONFIG
  // ============================================================

  static const Duration _refreshInterval = Duration(hours: 1);

  static const Duration _requestTimeout = Duration(seconds: 30);

  // ============================================================
  // ANIMATION
  // ============================================================

  late final UtilityInfoBoxFx _fx;

  late final AnimationController _highlightController;

  late final Animation<double> _highlightOpacity;

  // ============================================================
  // STATE
  // ============================================================

  Timer? _refreshTimer;

  bool _screenActive = true;
  bool _loadOnActivation = false;

  bool _loading = true;
  bool _fetching = false;

  int _requestId = 0;

  Object? _error;

  DataHealthResult? _health;

  List<EnergyMonthlySummary> _items = const [];

  // ============================================================
  // GETTERS
  // ============================================================

  bool get _canUpdate {
    return mounted && _screenActive && widget.isActive;
  }

  bool get _hasValidSource {
    return widget.facId.trim().isNotEmpty && widget.month.trim().isNotEmpty;
  }

  String get _healthKey =>
      'Monthly_${widget.facId}_${widget.headerTitle}';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _initializeAnimation();

    if (widget.isActive) {
      _scheduleInitialLoad();
      _startRefreshTimer();
    } else {
      _loadOnActivation = true;
    }
  }

  void _initializeAnimation() {
    _fx = UtilityInfoBoxFx(this)..init();

    _highlightController = AnimationController(
      vsync: this,

      duration: const Duration(milliseconds: 280),

      value: widget.isHighlighted ? 1 : .55,
    );

    _highlightOpacity = CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeInOut,
    );
  }

  void _scheduleInitialLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canUpdate) {
        return;
      }

      unawaited(_load());
    });
  }

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void activate() {
    super.activate();

    _screenActive = true;
  }

  @override
  void deactivate() {
    _screenActive = false;

    super.deactivate();
  }

  @override
  void didUpdateWidget(covariant UtilityOverviewMonthlyBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    _handleHighlightChange(oldWidget);

    final sourceChanged = _handleSourceChange(oldWidget);

    if (!widget.isActive) {
      if (oldWidget.isActive) {
        _loadOnActivation = _loadOnActivation || _fetching || _items.isEmpty;
        _stopRefreshTimer();
        _invalidateRequests();
      }

      if (sourceChanged) {
        _loadOnActivation = true;
      }

      return;
    }

    if (!oldWidget.isActive) {
      _startRefreshTimer();

      if (_loadOnActivation || sourceChanged || _items.isEmpty) {
        _loadOnActivation = false;
        _scheduleLoad(force: sourceChanged);
      }

      return;
    }

    if (sourceChanged) {
      _scheduleLoad(force: true);
    }
  }

  // ============================================================
  // HIGHLIGHT
  // ============================================================

  void _handleHighlightChange(UtilityOverviewMonthlyBox oldWidget) {
    if (oldWidget.isHighlighted == widget.isHighlighted) {
      return;
    }

    if (widget.isHighlighted) {
      _highlightController.forward();
    } else {
      _highlightController.reverse();
    }
  }

  // ============================================================
  // SOURCE CHANGE
  // ============================================================

  bool _handleSourceChange(UtilityOverviewMonthlyBox oldWidget) {
    final oldFac = oldWidget.facId.trim();

    final newFac = widget.facId.trim();

    final oldMonth = oldWidget.month.trim();

    final newMonth = widget.month.trim();

    final changed = oldFac != newFac || oldMonth != newMonth;

    if (!changed) {
      return false;
    }

    _invalidateRequests();

    setState(() {
      _items = const [];

      _health = null;

      _loading = true;

      _error = null;
    });

    return true;
  }

  void _scheduleLoad({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canUpdate) {
        return;
      }

      unawaited(_load(force: force));
    });
  }

  // ============================================================
  // TIMER
  // ============================================================

  void _startRefreshTimer() {
    _stopRefreshTimer();

    if (!widget.isActive) {
      return;
    }

    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!_canUpdate || !widget.isActive || _fetching) {
        return;
      }

      unawaited(_load(silent: true));
    });
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  // ============================================================
  // LOAD
  // ============================================================
  Future<void> _load({bool silent = false, bool force = false}) async {
    if (!_canUpdate || !_hasValidSource) {
      return;
    }

    if (_fetching && !force) {
      return;
    }

    final facId = widget.facId.trim();
    final month = widget.month.trim();

    final requestId = ++_requestId;

    _fetching = true;

    if (!silent && _items.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final api = context.read<UtilityDashboardOverviewApi>();

      final result = await api
          .getMonthlySummary(facId: facId, month: month)
          .timeout(_requestTimeout);

      if (!_isCurrentRequest(requestId)) {
        return;
      }

      final nextItems = List<EnergyMonthlySummary>.unmodifiable(result);

      final nextHealth = _buildHealth(nextItems);

      setState(() {
        _items = nextItems;
        _health = nextHealth;

        _loading = false;
        _error = null;
      });
    } on TimeoutException catch (exception, stackTrace) {
      _handleLoadError(
        requestId,
        exception,
        '[MONTHLY TIMEOUT]',
        stackTrace: stackTrace,
      );
    } catch (exception, stackTrace) {
      _handleLoadError(
        requestId,
        exception,
        '[MONTHLY ERROR]',
        stackTrace: stackTrace,
      );
    } finally {
      if (_isCurrentRequest(requestId)) {
        _fetching = false;
      }
    }
  }

  // ============================================================
  // HEALTH
  // ============================================================

  DataHealthResult _buildHealth(List<EnergyMonthlySummary> items) {
    final values = items
        .map((item) => item.displayValue)
        .where((value) => value.isFinite && value != 0)
        .toList(growable: false);

    return DataHealthAnalyzer.analyze(
      key: _healthKey,

      loading: false,

      error: null,

      values: values,
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _handleLoadError(
    int requestId,
    Object exception,
    String tag, {
    StackTrace? stackTrace,
  }) {
    if (!_isCurrentRequest(requestId)) {
      return;
    }

    debugPrint('$tag $exception');

    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }

    setState(() {
      _loading = false;

      // Nếu đã có data cũ thì
      // vẫn giữ lại để hiển thị.
      _error = _items.isEmpty ? exception : null;
    });
  }

  bool _isCurrentRequest(int requestId) {
    return _canUpdate && requestId == _requestId;
  }

  void _invalidateRequests() {
    _requestId++;

    _fetching = false;
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<EnergyMonthlySummary> _filteredItems() {
    final filter = widget.filterCate?.trim().toUpperCase();

    if (filter == null || filter.isEmpty) {
      return _items;
    }

    return _items
        .where((item) {
          switch (filter) {
            case 'ELECTRICITY':
              return item.isElectricity;

            case 'WATER':
              return item.isWater;

            case 'AIR':
              return item.isAir;

            default:
              return item.cate.trim().toUpperCase().contains(filter);
          }
        })
        .toList(growable: false);
  }

  // ============================================================
  // THEME
  // ============================================================

  ChartTheme _resolveTheme(List<EnergyMonthlySummary> displayItems) {
    final filter = widget.filterCate?.trim();

    if (filter != null && filter.isNotEmpty) {
      return ChartThemeResolver.theme(filter);
    }

    if (displayItems.isNotEmpty) {
      return ChartThemeResolver.theme(displayItems.first.cate);
    }

    return ChartThemes.power;
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _openFacilityDetail() {
    final service = context.read<UtilityFacadeService>();

    final latestProvider = context.read<LatestProvider>();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          return ChangeNotifierProvider<LatestProvider>.value(
            value: latestProvider,

            child: UtilityFacDetailScreen(
              facId: widget.facId,

              service: service,
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final displayItems = _filteredItems();

    final theme = _resolveTheme(displayItems);

    final health =
        _health ??
        DataHealthAnalyzer.analyze(
          key: _healthKey,

          loading: _loading,

          error: _error,

          values: const [],
        );

    return GestureDetector(
      onTap: _openFacilityDetail,

      child: RepaintBoundary(
        child: SlideTransition(
          position: _fx.slide,

          child: AnimatedBuilder(
            animation: Listenable.merge([_fx.listenable, _highlightOpacity]),

            builder: (_, child) {
              return Opacity(
                opacity: _highlightOpacity.value,

                child: Transform.scale(scale: _fx.scale.value, child: child),
              );
            },

            child: _MonthlyContainer(
              width: widget.width,

              height: widget.height,

              title: widget.headerTitle,

              headerColor: theme.iconColor,

              health: health,

              child: _MonthlyBody(
                loading: _loading,

                error: _error,

                items: displayItems,

                onRetry: _load,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _screenActive = false;

    _requestId++;

    _stopRefreshTimer();

    _fx.dispose();

    _highlightController.dispose();

    super.dispose();
  }
}

// ============================================================
// CONTAINER
// ============================================================

class _MonthlyContainer extends StatelessWidget {
  final double width;
  final double? height;

  final String title;

  final Color headerColor;

  final DataHealthResult health;

  final Widget child;

  const _MonthlyContainer({
    required this.width,
    required this.height,
    required this.title,
    required this.headerColor,
    required this.health,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,

      height: height,

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.1),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: Colors.white.withOpacity(.08)),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.6),

            blurRadius: 16,

            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          UtilityInfoBoxHeader.header(
            facilityColor: headerColor.withOpacity(.3),

            facTitle: title,

            healthResult: health,
          ),

          child,
        ],
      ),
    );
  }
}

// ============================================================
// BODY
// ============================================================

class _MonthlyBody extends StatelessWidget {
  final bool loading;

  final Object? error;

  final List<EnergyMonthlySummary> items;

  final Future<void> Function() onRetry;

  const _MonthlyBody({
    required this.loading,
    required this.error,
    required this.items,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // ==========================================================
    // LOADING
    // ==========================================================

    if (loading && items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),

        child: Center(
          child: SizedBox.square(
            dimension: 18,

            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // ==========================================================
    // ERROR
    // ==========================================================

    if (error != null && items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),

        child: MonthlyInlineState(
          icon: Icons.cloud_off_rounded,

          title: 'API Error',

          message: 'Tap to retry',

          onTap: onRetry,
        ),
      );
    }

    // ==========================================================
    // EMPTY
    // ==========================================================

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),

        child: MonthlyInlineState(
          icon: Icons.dataset_outlined,

          title: 'No Data',

          message: 'No monthly utility data.',
        ),
      );
    }

    // ==========================================================
    // SPLIT
    // ==========================================================

    final electricityItems = <EnergyMonthlySummary>[];
    final waterItems = <EnergyMonthlySummary>[];
    final airItems = <EnergyMonthlySummary>[];

    for (final item in items) {
      if (item.isElectricity) {
        electricityItems.add(item);
      } else if (item.isWater) {
        waterItems.add(item);
      } else if (item.isAir) {
        airItems.add(item);
      }
    }

    // ==========================================================
    // CONTENT
    // ==========================================================

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < electricityItems.length; index++) ...[
          RepaintBoundary(
            child: MonthlyElectricityCard(item: electricityItems[index]),
          ),
          if (index < electricityItems.length - 1 ||
              waterItems.isNotEmpty ||
              airItems.isNotEmpty)
            const SizedBox(height: 8),
        ],
        if (waterItems.isNotEmpty) ...[
          RepaintBoundary(child: MonthlyWaterCard(items: waterItems)),
          if (airItems.isNotEmpty) const SizedBox(height: 8),
        ],
        for (var index = 0; index < airItems.length; index++) ...[
          RepaintBoundary(child: MonthlyAirCard(item: airItems[index])),
          if (index < airItems.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}
