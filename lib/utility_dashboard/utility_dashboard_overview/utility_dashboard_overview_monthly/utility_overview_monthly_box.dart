import 'dart:async';

import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/monthly_metric_widgets.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/monthly_water_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../utility_models/utility_facade_service.dart';
import '../../../utility_state/latest_provider.dart';
import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_common/data_health.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../../utility_dashboard_fac_details/screens/utility_fac_detail_screen.dart';
import '../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';
import '../utility_dashboard_overview_models/energy_monthly_summary.dart';
import '../utility_dashboard_overview_widgets/utility_glow_card.dart';
import '../utility_dashboard_overview_widgets/utility_info_box_header.dart';

// ============================================================
// MONTHLY BOX
// ============================================================

class UtilityOverviewMonthlyBox extends StatefulWidget {
  final double width;
  final double? height;

  final String facId;
  final String month;
  final String headerTitle;

  final bool isHighlighted;

  final String? filterCate;

  const UtilityOverviewMonthlyBox({
    super.key,
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
    return mounted && _screenActive;
  }

  bool get _hasValidSource {
    return widget.facId.trim().isNotEmpty && widget.month.trim().isNotEmpty;
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _initializeAnimation();

    _scheduleInitialLoad();

    _startRefreshTimer();
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

    _handleSourceChange(oldWidget);
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

  void _handleSourceChange(UtilityOverviewMonthlyBox oldWidget) {
    final oldFac = oldWidget.facId.trim();

    final newFac = widget.facId.trim();

    final oldMonth = oldWidget.month.trim();

    final newMonth = widget.month.trim();

    final changed = oldFac != newFac || oldMonth != newMonth;

    if (!changed) {
      return;
    }

    _invalidateRequests();

    setState(() {
      _items = const [];

      _health = null;

      _loading = true;

      _error = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canUpdate) {
        return;
      }

      unawaited(_load(force: true));
    });
  }

  // ============================================================
  // TIMER
  // ============================================================

  void _startRefreshTimer() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!_canUpdate || _fetching) {
        return;
      }

      unawaited(_load(silent: true));
    });
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
      key: 'Monthly_${widget.facId}_${widget.headerTitle}',

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
          key: 'Monthly_${widget.facId}_${widget.headerTitle}',

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

    _refreshTimer?.cancel();

    _refreshTimer = null;

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

    final waterItems = <EnergyMonthlySummary>[];

    final standardItems = <EnergyMonthlySummary>[];

    for (final item in items) {
      if (item.isWater) {
        waterItems.add(item);
      } else {
        standardItems.add(item);
      }
    }

    // ==========================================================
    // CONTENT
    // ==========================================================

    return Column(
      mainAxisSize: MainAxisSize.min,

      children: [
        for (var index = 0; index < standardItems.length; index++) ...[
          RepaintBoundary(child: _MonthlyEnergyRow(item: standardItems[index])),

          if (index < standardItems.length - 1 || waterItems.isNotEmpty)
            const SizedBox(height: 8),
        ],

        if (waterItems.isNotEmpty)
          RepaintBoundary(child: MonthlyWaterCard(items: waterItems)),
      ],
    );
  }
}

// ============================================================
// ELECTRICITY / AIR
// ============================================================

class _MonthlyEnergyRow extends StatelessWidget {
  final EnergyMonthlySummary item;

  const _MonthlyEnergyRow({required this.item});

  String get _title {
    if (item.isElectricity) {
      return 'Total Energy';
    }

    if (item.isAir) {
      return 'Compressed Air';
    }

    final name = item.name.trim();

    return name.isNotEmpty ? name : item.cate;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChartThemes.byCate(item.cate);

    final color = theme.iconColor;

    final unit = MonthlyMetricFormat.unit(item, theme);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),

      child: Column(
        mainAxisSize: MainAxisSize.min,

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          MonthlyMetricHeader(title: _title, color: theme.line),

          const SizedBox(height: 10),

          const MonthlyMetricColumnsHeader(),

          const SizedBox(height: 4),

          // ====================================================
          // ELECTRICITY COST
          // ====================================================
          if (item.isElectricity) ...[
            _MonthlyCostRow(item: item, color: color),

            const SizedBox(height: 3),

            Divider(
              height: 1,

              thickness: .5,

              color: Colors.white.withOpacity(.7),
            ),

            const SizedBox(height: 3),
          ],

          // ====================================================
          // VALUE
          // ====================================================
          _MonthlyUtilityValueRow(item: item, color: color, unit: unit),
        ],
      ),
    );

    if (item.isAir) {
      return UtilityGlowCard.air(color: color, child: content);
    }

    return UtilityGlowCard.electricity(color: color, child: content);
  }
}

// ============================================================
// COST ROW
// ============================================================

class _MonthlyCostRow extends StatelessWidget {
  final EnergyMonthlySummary item;

  final Color color;

  const _MonthlyCostRow({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    return MonthlyMetricComparisonRow(
      currentValue: MonthlyMetricFormat.money(item.currentCost),

      currentUnit: item.currentCostUnit,

      previousValue: MonthlyMetricFormat.money(item.previousCost),

      previousUnit: item.previousCostUnit,

      mode: MonthlyMetricFormat.mode(item),

      delta: item.costDeltaPercent,

      currentColor: color,
    );
  }
}

// ============================================================
// UTILITY VALUE ROW
// ============================================================

class _MonthlyUtilityValueRow extends StatelessWidget {
  final EnergyMonthlySummary item;

  final Color color;

  final String unit;

  const _MonthlyUtilityValueRow({
    required this.item,
    required this.color,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: item.displayValue),

      duration: const Duration(milliseconds: 650),

      curve: Curves.easeOutCubic,

      builder: (_, animatedValue, __) {
        return MonthlyMetricComparisonRow(
          currentValue: MonthlyMetricFormat.utility(item, animatedValue),

          currentUnit: unit,

          previousValue: MonthlyMetricFormat.utility(
            item,
            item.previousDisplayValue,
          ),

          previousUnit: unit,

          mode: MonthlyMetricFormat.mode(item),

          delta: item.deltaPercent,

          currentColor: color,
        );
      },
    );
  }
}
