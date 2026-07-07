import 'dart:async';
import 'dart:ui';

import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/voltage_card.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/voltage_detail_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../utility_models/utility_facade_service.dart';
import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_common/data_health.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../../utility_dashboard_fac_details/layout/utility_fac_layout_screen.dart';
import '../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';
import '../utility_dashboard_overview_widgets/utility_glow_card.dart';
import '../utility_dashboard_overview_widgets/utility_info_box_header.dart';

class EnergyMonthlySummary {
  final String cate;
  final String name;
  final String month;

  final double? minValue;
  final double? maxValue;
  final double? prevMinValue;
  final double? prevMaxValue;

  final double? value;
  final double? avgValue;
  final double? vndCost;
  final double? usdCost;
  final double? prevValue;
  final double? prevAvgValue;
  final double? prevVndCost;
  final double? prevUsdCost;
  final double? deltaValue;
  final double? deltaPercent;
  final String unit;
  final DateTime? pickAt;

  const EnergyMonthlySummary({
    required this.cate,
    required this.name,
    required this.month,
    required this.minValue,
    required this.maxValue,
    required this.prevMinValue,
    required this.prevMaxValue,
    required this.value,
    required this.avgValue,
    required this.vndCost,
    required this.usdCost,
    required this.prevValue,
    required this.prevAvgValue,
    required this.prevVndCost,
    required this.prevUsdCost,
    required this.deltaValue,
    required this.deltaPercent,
    required this.unit,
    required this.pickAt,
  });

  factory EnergyMonthlySummary.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic v) => (v as num?)?.toDouble();

    return EnergyMonthlySummary(
      cate: (json['cate'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      month: (json['month'] ?? '').toString(),

      minValue: toDouble(json['minValue']),
      maxValue: toDouble(json['maxValue']),
      prevMinValue: toDouble(json['prevMinValue']),
      prevMaxValue: toDouble(json['prevMaxValue']),

      value: toDouble(json['value']),
      avgValue: toDouble(json['avgValue']),
      vndCost: toDouble(json['vndCost']),
      usdCost: toDouble(json['usdCost']),
      prevValue: toDouble(json['prevValue']),
      prevAvgValue: toDouble(json['prevAvgValue']),
      prevVndCost: toDouble(json['prevVndCost']),
      prevUsdCost: toDouble(json['prevUsdCost']),
      deltaValue: toDouble(json['deltaValue']),
      deltaPercent: toDouble(json['deltaPercent']),
      unit: (json['unit'] ?? '').toString(),
      pickAt: DateTime.tryParse((json['pickAt'] ?? '').toString())?.toLocal(),
    );
  }

  double get displayValue => value ?? avgValue ?? 0;

  double? get previousDisplayValue => prevValue ?? prevAvgValue;

  double? get currentCost => usdCost ?? vndCost;

  double? get previousCost => prevUsdCost ?? prevVndCost;
}

final NumberFormat _numFmt = NumberFormat('#,##0');
final NumberFormat _moneyFmt = NumberFormat('#,##0');

String _format(double v) => _numFmt.format(v);

String _formatMoney(double v) => _moneyFmt.format(v);

class UtilityOverviewMonthlyBox extends StatefulWidget {
  final double width;
  final double? height;
  final String facId;
  final String month;
  final String headerTitle;
  final bool isHighlighted;
  final void Function(String facId, VoltageStatus? status)?
  onVoltageAlarmChanged;
  final String? filterCate;

  const UtilityOverviewMonthlyBox({
    super.key,
    required this.facId,
    required this.month,
    required this.headerTitle,
    this.width = 300,
    this.height = 280,
    this.isHighlighted = true,
    this.onVoltageAlarmChanged,
    this.filterCate,
  });

  @override
  State<UtilityOverviewMonthlyBox> createState() =>
      _UtilityOverviewMonthlyBoxState();
}

class _UtilityOverviewMonthlyBoxState extends State<UtilityOverviewMonthlyBox>
    with TickerProviderStateMixin {
  static const Duration _refreshInterval = Duration(seconds: 30);
  static const Duration _requestTimeout = Duration(seconds: 15);

  late final UtilityInfoBoxFx _fx;
  late final AnimationController _highlightController;
  late final Animation<double> _opacityAnimation;

  Timer? _refreshTimer;

  bool _loading = true;
  bool _loadingNow = false;
  bool _disposed = false;
  bool _screenActive = true;
  bool _wasAlarm = false;

  Object? _error;
  DataHealthResult? _cachedHealth;

  List<EnergyMonthlySummary> _items = const [];
  List<VoltageStatus> _voltageStatuses = const [];

  @override
  void initState() {
    super.initState();

    _fx = UtilityInfoBoxFx(this)..init();

    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.isHighlighted ? 1.0 : 0.55,
    );

    _opacityAnimation = CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeInOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed) return;
      _load();
    });

    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted || _disposed || !_screenActive) return;
      _load(silent: true);
    });
  }

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

    if (oldWidget.isHighlighted != widget.isHighlighted) {
      if (widget.isHighlighted) {
        _highlightController.forward();
      } else {
        _highlightController.reverse();
      }
    }

    final sourceChanged =
        oldWidget.facId != widget.facId || oldWidget.month != widget.month;

    if (!sourceChanged) return;

    _cachedHealth = null;
    _wasAlarm = false;

    setState(() {
      _loading = true;
      _error = null;
      _items = const [];
      _voltageStatuses = const [];
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed) return;
      _load();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _screenActive = false;
    _refreshTimer?.cancel();
    _fx.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_loadingNow || _disposed || !mounted || !_screenActive) return;

    final facId = widget.facId.trim();
    if (facId.isEmpty) return;

    _loadingNow = true;

    if (!silent && _items.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final api = context.read<UtilityDashboardOverviewApi>();

      final results = await Future.wait<dynamic>([
        api.getEnergyMonthlySummary(facId: facId, month: widget.month),
        api.getVoltageStatus(facId: facId),
      ]).timeout(_requestTimeout);

      if (!mounted || _disposed || !_screenActive) return;

      final parsedItems = (results[0] as List)
          .whereType<Map<String, dynamic>>()
          .map(EnergyMonthlySummary.fromJson)
          .toList(growable: false);

      final parsedVoltages = List<VoltageStatus>.from(
        results[1] as List<VoltageStatus>,
      );

      final alarmVoltages = parsedVoltages
          .where((e) => e.isAlarm)
          .toList(growable: false);

      final hasAlarmNow = alarmVoltages.isNotEmpty;

      final healthValues = <double>[
        ...parsedItems.map((e) => e.displayValue).where((v) => v != 0),
        ...parsedVoltages
            .expand((e) => [e.minVol, e.maxVol])
            .where((v) => v != 0),
      ];

      final nextHealth = DataHealthAnalyzer.analyze(
        key: 'Monthly_${widget.facId}_${widget.headerTitle}',
        loading: false,
        error: null,
        values: healthValues,
      );

      setState(() {
        _items = parsedItems;
        _voltageStatuses = parsedVoltages;
        _cachedHealth = nextHealth;
        _loading = false;
        _error = null;
      });

      if (_wasAlarm != hasAlarmNow) {
        widget.onVoltageAlarmChanged?.call(
          widget.facId,
          hasAlarmNow ? alarmVoltages.first : null,
        );
      }

      _wasAlarm = hasAlarmNow;
    } catch (e) {
      if (!mounted || _disposed || !_screenActive) return;

      setState(() {
        _error = e;
        _loading = false;
      });
    } finally {
      _loadingNow = false;
    }
  }

  void _openFacilityDetail() {
    final svc = context.read<UtilityFacadeService>();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UtilityFacDetailScreens(facId: widget.facId, svc: svc),
      ),
    );
  }

  List<EnergyMonthlySummary> _filteredItems() {
    final filter = widget.filterCate?.trim().toUpperCase();

    if (filter == null || filter.isEmpty) {
      return _items;
    }

    return _items
        .where((e) {
          final cate = e.cate.toUpperCase();

          if (filter == 'ELECTRICITY') {
            return cate.contains('ELECTRIC');
          }

          if (filter == 'WATER') {
            return cate.contains('WATER');
          }

          if (filter == 'AIR') {
            return cate.contains('AIR');
          }

          return cate.contains(filter);
        })
        .take(1)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final facColor = ChartThemes.colorFromFac(widget.headerTitle);

    final healthResult =
        _cachedHealth ??
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
            animation: Listenable.merge([_fx.listenable, _opacityAnimation]),
            builder: (_, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(scale: _fx.scale.value, child: child),
              );
            },
            child: _MonthlyShell(
              width: widget.width,
              height: widget.height ?? 220,
              facColor: facColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UtilityInfoBoxHeader.header(
                    facilityColor: facColor,
                    facTitle: widget.headerTitle,
                    healthResult: healthResult,
                  ),
                  Expanded(
                    child: _MonthlyBody(
                      loading: _loading,
                      error: _error,
                      // items: _items,
                      items: _filteredItems(),
                      voltageStatuses: _voltageStatuses,
                      facId: widget.facId,
                      onRetry: _load,
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

class _MonthlyShell extends StatelessWidget {
  final double width;
  final double height;
  final Color facColor;
  final Widget child;

  const _MonthlyShell({
    required this.width,
    required this.height,
    required this.facColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            /// Glass Blur
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: const SizedBox.expand(),
            ),

            /// Glass Background
            Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(.16),
                    const Color(0xff67CFFF).withOpacity(.08),
                    const Color(0xff0B1C2F).withOpacity(.18),
                  ],
                ),
              ),
            ),

            /// Top highlight
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      facColor.withOpacity(.18),
                      facColor.withOpacity(.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            /// Outer Border
            Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: Colors.white.withOpacity(.22),
                  width: 1.2,
                ),
              ),
            ),

            /// Cyan glow border
            Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: facColor.withOpacity(.18),
                    blurRadius: 18,
                    spreadRadius: -6,
                  ),
                ],
              ),
            ),

            /// Inner border
            Padding(
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(.08)),
                ),
              ),
            ),

            /// Top glass reflection
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(height: 1, color: Colors.white.withOpacity(.45)),
            ),

            /// Bottom glow
            Positioned(
              bottom: 0,
              left: 24,
              right: 24,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: facColor.withOpacity(.35),
                  boxShadow: [
                    BoxShadow(color: facColor.withOpacity(.45), blurRadius: 8),
                  ],
                ),
              ),
            ),

            /// Corner light
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(.9),
                  boxShadow: [
                    BoxShadow(color: facColor.withOpacity(.7), blurRadius: 8),
                  ],
                ),
              ),
            ),

            /// Content
            Padding(padding: const EdgeInsets.all(1), child: child),
          ],
        ),
      ),
    );
  }
}

class _MonthlyBody extends StatefulWidget {
  final bool loading;
  final Object? error;
  final List<EnergyMonthlySummary> items;
  final List<VoltageStatus> voltageStatuses;
  final String facId;
  final Future<void> Function() onRetry;

  const _MonthlyBody({
    required this.loading,
    required this.error,
    required this.items,
    required this.voltageStatuses,
    required this.facId,
    required this.onRetry,
  });

  @override
  State<_MonthlyBody> createState() => _MonthlyBodyState();
}

class _MonthlyBodyState extends State<_MonthlyBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flowController;

  @override
  void initState() {
    super.initState();

    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _flowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading && widget.items.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (widget.error != null && widget.items.isEmpty) {
      return _InlineState(
        icon: Icons.cloud_off_rounded,
        title: 'API Error',
        message: 'Tap to retry',
        onTap: widget.onRetry,
      );
    }

    if (widget.items.isEmpty) {
      return const _InlineState(
        icon: Icons.dataset_outlined,
        title: 'No Data',
        message: 'No monthly utility data.',
      );
    }

    final alarms = widget.voltageStatuses
        .where((e) => e.isAlarm)
        .toList(growable: false);

    return Column(
      children: [
        if (alarms.isNotEmpty) ...[
          RepaintBoundary(
            child: _AlarmBanner(alarms: alarms, facId: widget.facId),
          ),
          const SizedBox(height: 8),
        ],

        const _SoftDivider(),
        const SizedBox(height: 5),

        // Expanded(
        //   child: ListView.separated(
        //     padding: EdgeInsets.zero,
        //     physics: const NeverScrollableScrollPhysics(),
        //     itemCount: widget.items.length,
        //     separatorBuilder: (_, __) => const SizedBox(height: 8),
        //     itemBuilder: (_, index) {
        //       final item = widget.items[index];
        //       final theme = ChartThemes.byCate(item.cate);
        //       final color = theme.iconColor;
        //
        //       return RepaintBoundary(
        //         child: ScadaPanelFrame(
        //           color: color,
        //           child: _EnergyRow(item: item, animation: _flowController),
        //         ),
        //       );
        //     },
        //   ),
        // ),
        Expanded(
          child: widget.items.length == 1
              ? Center(
                  child: RepaintBoundary(
                    child: _EnergyRow(
                      item: widget.items.first,
                      animation: _flowController,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final item = widget.items[index];
                    final theme = ChartThemes.byCate(item.cate);
                    final color = theme.iconColor;

                    return _EnergyRow(item: item, animation: _flowController);
                  },
                ),
        ),
      ],
    );
  }
}

class _InlineState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function()? onTap;

  const _InlineState({
    required this.icon,
    required this.title,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.55), size: 22),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.84),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          message,
          style: TextStyle(
            color: Colors.white.withOpacity(0.52),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    if (onTap == null) {
      return Center(child: content);
    }

    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(10), child: content),
      ),
    );
  }
}

class _AlarmBanner extends StatelessWidget {
  final List<VoltageStatus> alarms;
  final String facId;

  const _AlarmBanner({required this.alarms, required this.facId});

  void _openDetail(BuildContext context) {
    final api = context.read<UtilityDashboardOverviewApi>();

    showDialog(
      context: context,
      builder: (_) => VoltageChartDialog(api: api, facId: facId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alarm = alarms.first;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => _openDetail(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.14),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.red.withOpacity(0.45), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.22),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.red,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alarms.length == 1
                      ? '${alarm.boxDeviceId} voltage alarm'
                      : '${alarms.length} voltage issues detected',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.16),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _EnergyRow extends StatelessWidget {
  final EnergyMonthlySummary item;
  final Animation<double> animation;

  const _EnergyRow({required this.item, required this.animation});

  String _titleByCate(ChartTheme theme) {
    final cate = item.cate.toUpperCase();

    if (cate.contains('ELECTRIC')) return 'Total Energy';
    if (cate.contains('WATER')) return 'Water';
    if (cate.contains('AIR')) return 'Air';

    return item.name.trim().isNotEmpty ? item.name.trim() : theme.title;
  }

  String _prevText(String unit) {
    final prev = item.previousDisplayValue;
    if (prev == null) return '--';
    return '${_format(prev)} $unit';
  }

  String _valueTypeLabel() {
    final cate = item.cate.toUpperCase();

    if (cate.contains('ELECTRIC')) {
      final raw = item.month;

      if (raw.length == 6) {
        final year = raw.substring(0, 4);
        final month = int.parse(raw.substring(4, 6));

        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];

        return '${months[month - 1]} $year MTD';
      }

      return 'Monthly';
    }

    if (cate.contains('WATER')) {
      return 'Monthly Avg';
    }

    if (cate.contains('AIR')) {
      return 'Monthly Avg';
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChartThemes.byCate(item.cate);
    final color = theme.iconColor;
    final icon = theme.icon;

    final title = _titleByCate(theme);
    final unit = item.unit.trim().isNotEmpty ? item.unit.trim() : theme.unit;

    final value = item.displayValue;
    final delta = item.deltaPercent;

    final isUp = delta != null && delta > 0;
    final isDown = delta != null && delta < 0;

    final cate = item.cate.toUpperCase();

    final isElectricity = cate.contains('ELECTRIC');
    final isWater = cate.contains('WATER');
    final isAir = cate.contains('AIR');

    final deltaColor = delta == null
        ? Colors.white54
        : isElectricity
        ? (isDown ? Colors.greenAccent : Colors.redAccent)
        : (isUp ? Colors.redAccent : Colors.greenAccent);

    final deltaIcon = isUp
        ? Icons.arrow_upward_rounded
        : isDown
        ? Icons.arrow_downward_rounded
        : Icons.remove_rounded;

    final content = Row(
      children: [
        _MetricIcon(icon: icon, color: color, animation: animation),

        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// title + delta
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.88),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .2,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: color.withOpacity(.35)),
                    ),
                    child: Text(
                      _valueTypeLabel(),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),

                  if (delta != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: deltaColor.withOpacity(.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: deltaColor.withOpacity(.45)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(deltaIcon, color: deltaColor, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            '${delta.abs().toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: deltaColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 6),

              /// main value
              Row(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: value),
                    duration: const Duration(milliseconds: 750),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) {
                      return Text(
                        '${_format(v)} $unit',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.45,
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _MiniMetric(
                      value: _prevText(unit),
                      color: Colors.white70,
                      icon: Icons.history_rounded,
                    ),
                  ),
                ],
              ),

              const Spacer(),
              // const SizedBox(height: 6),

              /// sub info
              if (isElectricity)
                Row(
                  children: [
                    Expanded(
                      child: _MiniMetric(
                        value: '\$${_formatMoney(item.currentCost!)}',
                        color: Colors.orangeAccent,
                        icon: Icons.monetization_on_outlined,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _MiniMetric(
                        value: '\$${_formatMoney(item.previousCost!)}',
                        color: Colors.white70,
                        icon: Icons.history_rounded,
                      ),
                    ),
                  ],
                )
              else
                const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
    if (isElectricity) {
      return UtilityGlowCard.electricity(color: color, child: content);
    } else if (isWater) {
      return UtilityGlowCard.water(color: color, child: content);
    } else if (isAir) {
      return UtilityGlowCard.air(color: color, child: content);
    }

    // fallback: loại không xác định, vẫn dùng bản electricity làm mặc định
    return UtilityGlowCard.electricity(color: color, child: content);
    // return Container(
    //   padding: const EdgeInsets.all(4),
    //   decoration: BoxDecoration(
    //     borderRadius: BorderRadius.circular(14),
    //     gradient: LinearGradient(
    //       begin: Alignment.topLeft,
    //       end: Alignment.bottomRight,
    //       colors: [
    //         Colors.black.withOpacity(.5),
    //         color.withOpacity(.1),
    //         Colors.black.withOpacity(.5),
    //       ],
    //     ),
    //     border: Border.all(color: color.withOpacity(.35), width: 1),
    //     boxShadow: [
    //       BoxShadow(
    //         color: color.withOpacity(.14),
    //         blurRadius: 14,
    //         spreadRadius: -4,
    //       ),
    //     ],
    //   ),
    //   child: Row(
    //     children: [
    //       _MetricIcon(icon: icon, color: color, animation: animation),
    //
    //       const SizedBox(width: 8),
    //
    //       Expanded(
    //         child: Column(
    //           crossAxisAlignment: CrossAxisAlignment.start,
    //           children: [
    //             /// title + delta
    //             Row(
    //               children: [
    //                 Expanded(
    //                   child: Text(
    //                     title,
    //                     maxLines: 1,
    //                     overflow: TextOverflow.ellipsis,
    //                     style: TextStyle(
    //                       color: Colors.white.withOpacity(.88),
    //                       fontSize: 14,
    //                       fontWeight: FontWeight.w900,
    //                       letterSpacing: .2,
    //                     ),
    //                   ),
    //                 ),
    //                 Container(
    //                   padding: const EdgeInsets.symmetric(
    //                     horizontal: 7,
    //                     vertical: 2,
    //                   ),
    //                   decoration: BoxDecoration(
    //                     color: color.withOpacity(.14),
    //                     borderRadius: BorderRadius.circular(999),
    //                     border: Border.all(color: color.withOpacity(.35)),
    //                   ),
    //                   child: Text(
    //                     _valueTypeLabel(),
    //                     style: TextStyle(
    //                       color: color,
    //                       fontSize: 11,
    //                       fontWeight: FontWeight.bold,
    //                     ),
    //                   ),
    //                 ),
    //                 const SizedBox(width: 3),
    //
    //                 if (delta != null)
    //                   Container(
    //                     padding: const EdgeInsets.symmetric(
    //                       horizontal: 3,
    //                       vertical: 3,
    //                     ),
    //                     decoration: BoxDecoration(
    //                       color: deltaColor.withOpacity(.12),
    //                       borderRadius: BorderRadius.circular(999),
    //                       border: Border.all(
    //                         color: deltaColor.withOpacity(.45),
    //                       ),
    //                     ),
    //                     child: Row(
    //                       mainAxisSize: MainAxisSize.min,
    //                       children: [
    //                         Icon(deltaIcon, color: deltaColor, size: 12),
    //                         const SizedBox(width: 2),
    //                         Text(
    //                           '${delta.abs().toStringAsFixed(1)}%',
    //                           style: TextStyle(
    //                             color: deltaColor,
    //                             fontSize: 10.5,
    //                             fontWeight: FontWeight.bold,
    //                           ),
    //                         ),
    //                       ],
    //                     ),
    //                   ),
    //               ],
    //             ),
    //
    //             const SizedBox(height: 6),
    //
    //             /// main value
    //             Row(
    //               children: [
    //                 TweenAnimationBuilder<double>(
    //                   tween: Tween<double>(begin: 0, end: value),
    //                   duration: const Duration(milliseconds: 750),
    //                   curve: Curves.easeOutCubic,
    //                   builder: (_, v, __) {
    //                     return Text(
    //                       '${_format(v)} $unit',
    //                       maxLines: 1,
    //                       overflow: TextOverflow.ellipsis,
    //                       style: TextStyle(
    //                         color: color,
    //                         fontSize: 20,
    //                         fontWeight: FontWeight.bold,
    //                         letterSpacing: -0.45,
    //                         shadows: [
    //                           Shadow(
    //                             color: color.withOpacity(.45),
    //                             blurRadius: 8,
    //                           ),
    //                         ],
    //                       ),
    //                     );
    //                   },
    //                 ),
    //                 SizedBox(width: 8),
    //
    //                 Expanded(
    //                   child: _MiniMetric(
    //                     value: _prevText(unit),
    //                     color: Colors.white70,
    //                     icon: Icons.history_rounded,
    //                   ),
    //                 ),
    //               ],
    //             ),
    //
    //             const Spacer(),
    //             // const SizedBox(height: 6),
    //
    //             /// sub info
    //             if (isElectricity)
    //               Row(
    //                 children: [
    //                   Expanded(
    //                     child: _MiniMetric(
    //                       value: '\$${_formatMoney(item.currentCost!)}',
    //                       color: Colors.orangeAccent,
    //                       icon: Icons.payments_rounded,
    //                     ),
    //                   ),
    //                   const SizedBox(width: 6),
    //                   Expanded(
    //                     child: _MiniMetric(
    //                       value: '\$${_formatMoney(item.previousCost!)}',
    //                       color: Colors.orangeAccent,
    //                       icon: Icons.history_rounded,
    //                     ),
    //                   ),
    //                 ],
    //               )
    //             else
    //               const SizedBox(height: 24),
    //           ],
    //         ),
    //       ),
    //     ],
    //   ),
    // );
  }
}

class _MetricIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Animation<double> animation;

  const _MetricIcon({
    required this.icon,
    required this.color,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final glow = 0.25 + (animation.value * 0.25);

        return Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(.30),
                color.withOpacity(.08),
                Colors.black.withOpacity(.10),
              ],
            ),
            border: Border.all(color: color.withOpacity(.55)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(glow),
                blurRadius: 14,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
            shadows: [Shadow(color: color.withOpacity(.7), blurRadius: 10)],
          ),
        );
      },
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String value;
  final Color color;
  final IconData icon;

  const _MiniMetric({
    super.key,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      // padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color.withOpacity(.9)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// class _EnergyRow extends StatelessWidget {
//   final EnergyMonthlySummary item;
//   final Animation<double> animation;
//
//   const _EnergyRow({required this.item, required this.animation});
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = ChartThemes.getThemeByCate(item.cate);
//     final icon = ChartThemes.cateIcon(item.cate);
//     final color = ChartThemes.cateIconColor(item.cate, theme);
//
//     final title = item.name.trim().isNotEmpty ? item.name.trim() : theme.title;
//     final unit = item.unit.trim().isNotEmpty ? item.unit.trim() : theme.unit;
//
//     return Container(
//       padding: const EdgeInsets.all(6),
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(0.18),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: color.withOpacity(0.20)),
//         boxShadow: [
//           BoxShadow(
//             color: color.withOpacity(0.08),
//             blurRadius: 14,
//             offset: const Offset(0, 6),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           ScadaEnergyIcon(
//             icon: icon,
//             color: color,
//             cate: item.cate,
//             animation: animation,
//           ),
//
//           const SizedBox(width: 10),
//
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: TextStyle(
//                     color: Colors.white.withOpacity(0.70),
//                     fontSize: 13,
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 TweenAnimationBuilder<double>(
//                   tween: Tween<double>(begin: 0, end: item.value),
//                   duration: const Duration(milliseconds: 750),
//                   curve: Curves.easeOutCubic,
//                   builder: (_, value, __) {
//                     return Text(
//                       '${_format(value)} $unit',
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: TextStyle(
//                         color: color,
//                         fontSize: 16,
//                         fontWeight: FontWeight.w900,
//                         letterSpacing: -0.25,
//                       ),
//                     );
//                   },
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
