import 'dart:async';

import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/monthly_air_card.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/monthly_electricity_card.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/monthly_metric_widgets.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/monthly_water_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_dashboard_fac_details/api/utility_facade_service.dart';
import '../../utility_catalog/providers/latest_provider.dart';
import '../../shared/polling/polling_coordinator.dart';
import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_common/data_health.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../../utility_dashboard_fac_details/screens/utility_fac_detail_screen.dart';
import '../models/energy_monthly_summary.dart';
import '../providers/monthly_summary_store.dart';
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
  // ANIMATION
  // ============================================================

  late final UtilityInfoBoxFx _fx;

  late final AnimationController _highlightController;

  late final Animation<double> _highlightOpacity;

  // ============================================================
  // STATE
  // ============================================================

  /// Du lieu dung chung voi panel SUMMARY; polling do task MAP cua store.
  late final MonthlySummaryStore _store;

  bool _loading = true;

  Object? _error;

  DataHealthResult? _health;

  List<EnergyMonthlySummary> _items = const [];

  // ============================================================
  // GETTERS
  // ============================================================

  bool get _hasValidSource {
    return widget.facId.trim().isNotEmpty && widget.month.trim().isNotEmpty;
  }

  String get _healthKey => 'Monthly_${widget.facId}_${widget.headerTitle}';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _initializeAnimation();

    _store = context.read<MonthlySummaryStore>();
    _store.addListener(_onStoreChanged);
    _watch(widget);
    _syncFromStore();

    if (widget.isActive) {
      _scheduleLoad();
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

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void didUpdateWidget(covariant UtilityOverviewMonthlyBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    _handleHighlightChange(oldWidget);

    final sourceChanged = _handleSourceChange(oldWidget);

    if (!widget.isActive) {
      return;
    }

    if (sourceChanged) {
      _scheduleLoad();
    } else if (!oldWidget.isActive) {
      // Quay lai MAP: chi tai khi chua co du lieu, lam moi do polling MAP.
      _scheduleLoad(onlyIfMissing: true);
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

    _unwatch(oldWidget);
    _watch(widget);

    // Key moi co the da co trong cache: hien ngay.
    _syncFromStore();

    return true;
  }

  // ============================================================
  // STORE
  // ============================================================

  void _watch(UtilityOverviewMonthlyBox source) {
    if (source.facId.trim().isEmpty || source.month.trim().isEmpty) return;

    _store.watch(source.facId, source.month);
  }

  void _unwatch(UtilityOverviewMonthlyBox source) {
    if (source.facId.trim().isEmpty || source.month.trim().isEmpty) return;

    _store.unwatch(source.facId, source.month);
  }

  void _onStoreChanged() {
    if (!mounted) return;

    if (_syncFromStore()) {
      setState(() {});
    }
  }

  /// Doc trang thai key hien tai tu store; tra ve true neu co thay doi.
  bool _syncFromStore() {
    final valid = _hasValidSource;

    final items = valid
        ? _store.rowsOf(widget.facId, widget.month)
        : const <EnergyMonthlySummary>[];

    final loaded = valid && _store.hasLoaded(widget.facId, widget.month);

    final storeError = valid
        ? _store.errorOf(widget.facId, widget.month)
        : null;

    final loading = !loaded && storeError == null;

    // Neu da co data cu thi van giu lai de hien thi.
    final error = items.isEmpty ? storeError : null;

    final itemsChanged = !identical(items, _items);

    if (!itemsChanged && loading == _loading && error == _error) {
      return false;
    }

    if (itemsChanged) {
      _health = loaded ? _buildHealth(items) : null;
    }

    _items = items;
    _loading = loading;
    _error = error;

    return true;
  }

  // ============================================================
  // LOAD
  // ============================================================

  void _scheduleLoad({bool onlyIfMissing = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive) {
        return;
      }

      unawaited(_load(onlyIfMissing: onlyIfMissing));
    });
  }

  /// Cache con han (10 phut) hoac request dang chay cung key: khong goi API.
  Future<void> _load({bool force = false, bool onlyIfMissing = false}) async {
    if (!_hasValidSource) {
      return;
    }

    if (onlyIfMissing && _store.hasLoaded(widget.facId, widget.month)) {
      return;
    }

    await _store.get(widget.facId, widget.month, force: force);
  }

  Future<void> _retry() => _load(force: true);

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
    final pollingCoordinator = context.read<PollingCoordinator>();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          return ChangeNotifierProvider<LatestProvider>.value(
            value: latestProvider,

            child: UtilityFacDetailScreen(
              facId: widget.facId,

              service: service,

              pollingCoordinator: pollingCoordinator,
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

                onRetry: _retry,
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
    _store.removeListener(_onStoreChanged);
    _unwatch(widget);

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
        color: Colors.white.withValues(alpha: .1),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: Colors.white.withValues(alpha: .08)),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .6),

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
            facilityColor: headerColor.withValues(alpha: .3),

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
