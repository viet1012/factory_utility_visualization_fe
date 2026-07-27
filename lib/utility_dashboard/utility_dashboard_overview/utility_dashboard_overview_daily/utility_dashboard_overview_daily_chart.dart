import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_common/data_health.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../utility_dashboard_overview_models/'
    'utility_daily_dashboard_response.dart';
import '../utility_dashboard_overview_widgets/'
    'chart_state_widgets.dart';
import '../utility_dashboard_overview_widgets/'
    'common_chart_title_bar.dart';
import '../utility_dashboard_overview_widgets/'
    'scada_chart_panel.dart';

// ============================================================
// CHART POINT
// ============================================================

class _DailyBarPoint {
  final DateTime ts;
  final double value;
  final double? costUsd;

  const _DailyBarPoint({
    required this.ts,
    required this.value,
    required this.costUsd,
  });
}

// ============================================================
// PREPARED CHART DATA
// ============================================================

class _DailyChartData {
  final List<_DailyBarPoint> points;

  final DateTime minX;
  final DateTime maxX;

  final double maxY;
  final double yInterval;

  final double maxCostY;
  final double costInterval;

  final bool hasCost;

  final double? latestCost;
  final double totalCost;

  const _DailyChartData({
    required this.points,
    required this.minX,
    required this.maxX,
    required this.maxY,
    required this.yInterval,
    required this.maxCostY,
    required this.costInterval,
    required this.hasCost,
    required this.latestCost,
    required this.totalCost,
  });

  factory _DailyChartData.from({
    required List<UtilityDailyPoint> rows,
    required String month,
  }) {
    final points =
        rows
            .map(
              (item) => _DailyBarPoint(
                ts: item.date.toLocal(),
                value: item.value,
                costUsd: item.costUsd,
              ),
            )
            .where(
              (point) =>
                  point.value.isFinite || (point.costUsd?.isFinite ?? false),
            )
            .toList(growable: true)
          ..sort((first, second) => first.ts.compareTo(second.ts));

    final year = int.parse(month.substring(0, 4));

    final monthNumber = int.parse(month.substring(4, 6));

    final firstDay = DateTime(year, monthNumber, 1);

    final lastDay = DateTime(
      year,
      monthNumber + 1,
      1,
    ).subtract(const Duration(days: 1));

    double maxDataValue = 0;
    double maxCostValue = 0;
    double totalCost = 0;

    double? latestCost;
    var hasCost = false;

    for (final point in points) {
      if (point.value.isFinite && point.value > maxDataValue) {
        maxDataValue = point.value;
      }

      final cost = point.costUsd;

      if (cost == null || !cost.isFinite || cost < 0) {
        continue;
      }

      hasCost = true;
      totalCost += cost;
      latestCost = cost;

      if (cost > maxCostValue) {
        maxCostValue = cost;
      }
    }

    final rawMaxY = maxDataValue <= 0 ? 1.0 : maxDataValue * 1.15;

    final yInterval = _niceStep(rawMaxY / 5);

    final maxY = _niceCeil(rawMaxY, yInterval);

    final rawMaxCost = maxCostValue <= 0 ? 1.0 : maxCostValue * 1.15;

    final costInterval = _niceStep(rawMaxCost / 5);

    final maxCostY = _niceCeil(rawMaxCost, costInterval);

    return _DailyChartData(
      points: List<_DailyBarPoint>.unmodifiable(points),
      minX: firstDay.subtract(const Duration(hours: 12)),
      maxX: lastDay.add(const Duration(hours: 12)),
      maxY: maxY,
      yInterval: yInterval,
      maxCostY: maxCostY,
      costInterval: costInterval,
      hasCost: hasCost,
      latestCost: latestCost,
      totalCost: totalCost,
    );
  }

  static double _niceStep(double rawStep) {
    if (rawStep <= 0 || !rawStep.isFinite) {
      return 1;
    }

    final exponent = (log(rawStep) / ln10).floor();

    final base = pow(10, exponent).toDouble();

    final fraction = rawStep / base;

    if (fraction <= 1) {
      return base;
    }

    if (fraction <= 2) {
      return 2 * base;
    }

    if (fraction <= 5) {
      return 5 * base;
    }

    return 10 * base;
  }

  static double _niceCeil(double value, double step) {
    if (step <= 0 || !step.isFinite) {
      return value;
    }

    return (value / step).ceil() * step;
  }
}

// ============================================================
// MAIN WIDGET
// ============================================================

class UtilityDashboardOverviewDailyChart extends StatefulWidget {
  final List<UtilityDailyPoint> rows;

  final String facId;
  final String month;

  final ChartTheme theme;

  final bool loading;
  final Object? error;

  final double width;
  final double? height;

  final bool showHeader;

  final VoidCallback? onRetry;

  const UtilityDashboardOverviewDailyChart({
    super.key,
    required this.rows,
    required this.facId,
    required this.month,
    required this.theme,
    required this.loading,
    required this.error,
    this.onRetry,
    this.width = 520,
    this.height,
    this.showHeader = true,
  });

  @override
  State<UtilityDashboardOverviewDailyChart> createState() =>
      _UtilityDashboardOverviewDailyChartState();
}

class _UtilityDashboardOverviewDailyChartState
    extends State<UtilityDashboardOverviewDailyChart>
    with TickerProviderStateMixin {
  late final UtilityInfoBoxFx fx;

  List<UtilityDailyPoint>? _cachedRowsReference;

  _DailyChartData? _cachedChartData;

  DataHealthResult? _cachedHealth;

  String _lastValue = '--';
  String _lastTimestamp = '--';

  bool get _hasRequired {
    final fac = widget.facId.trim();
    final month = widget.month.trim();

    return fac.isNotEmpty && RegExp(r'^\d{6}$').hasMatch(month);
  }

  @override
  void initState() {
    super.initState();

    fx = UtilityInfoBoxFx(this)..init();

    _prepareData();
  }

  @override
  void didUpdateWidget(covariant UtilityDashboardOverviewDailyChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    final rowsChanged = !identical(oldWidget.rows, widget.rows);

    final configChanged =
        oldWidget.facId != widget.facId ||
        oldWidget.month != widget.month ||
        oldWidget.theme.title != widget.theme.title ||
        oldWidget.theme.unit != widget.theme.unit;

    final stateChanged =
        oldWidget.loading != widget.loading || oldWidget.error != widget.error;

    if (rowsChanged || configChanged || stateChanged) {
      _prepareData(force: true);
    }
  }

  void _prepareData({bool force = false}) {
    if (!force && identical(_cachedRowsReference, widget.rows)) {
      return;
    }

    _cachedRowsReference = widget.rows;

    final rows = widget.rows;

    _cachedHealth = DataHealthAnalyzer.analyze(
      key:
          'Daily_${widget.facId}_'
          '${widget.theme.title}',
      loading: widget.loading,
      error: widget.error,
      values: rows
          .map((item) => item.value)
          .where((value) => value.isFinite)
          .toList(growable: false),
    );

    if (rows.isEmpty || !_hasRequired) {
      _cachedChartData = null;
      _lastValue = '--';
      _lastTimestamp = '--';
      return;
    }

    _cachedChartData = _DailyChartData.from(rows: rows, month: widget.month);

    final latest = _resolveLatestPoint(rows);

    _lastValue =
        '${_formatUtilityValue(latest.value)} '
        '${widget.theme.unit}';

    _lastTimestamp = DateFormat('yyyy-MM-dd').format(latest.date.toLocal());
  }

  UtilityDailyPoint _resolveLatestPoint(List<UtilityDailyPoint> rows) {
    final sorted = List<UtilityDailyPoint>.from(rows)
      ..sort((first, second) => first.date.compareTo(second.date));

    final now = DateTime.now();

    final isCurrentMonth = DateFormat('yyyyMM').format(now) == widget.month;

    if (!isCurrentMonth) {
      return sorted.last;
    }

    for (var index = sorted.length - 1; index >= 0; index--) {
      final item = sorted[index];
      final date = item.date.toLocal();

      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return item;
      }
    }

    return sorted.last;
  }

  @override
  void dispose() {
    fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final health =
        _cachedHealth ??
        DataHealthAnalyzer.analyze(
          key:
              'Daily_${widget.facId}_'
              '${widget.theme.title}',
          loading: widget.loading,
          error: widget.error,
          values: const <double>[],
        );

    return SlideTransition(
      position: fx.slide,
      child: MouseRegion(
        onEnter: (_) => fx.onHover(true),
        onExit: (_) => fx.onHover(false),
        child: AnimatedBuilder(
          animation: fx.listenable,
          builder: (context, child) {
            return Transform.scale(scale: fx.scale.value, child: child);
          },
          child: _DailyChartShell(
            width: widget.width,
            height: widget.height ?? 320,
            facilityColor: widget.theme.line,
            child: _buildBody(health),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(DataHealthResult health) {
    if (!_hasRequired) {
      return const EmptyChartState(
        icon: Icons.warning_amber_rounded,
        title: 'Invalid Parameters',
        message: 'Missing facId or invalid month format.',
      );
    }

    if (widget.loading && widget.rows.isEmpty) {
      return Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: widget.theme.line,
          ),
        ),
      );
    }

    if (widget.error != null && widget.rows.isEmpty) {
      return ChartApiErrorState(
        color: widget.theme.line,
        onRetry: widget.onRetry ?? () {},
      );
    }

    final chartData = _cachedChartData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader) ...[
          CommonChartTitleBar(
            title: widget.theme.title,
            health: health,
            value: _lastValue,
            valueTs: _lastTimestamp,
            backgroundColor: Colors.transparent,
            borderColor: widget.theme.line.withOpacity(.44),
          ),

          const SizedBox(height: 6),
        ],

        Expanded(
          child: widget.rows.isEmpty || chartData == null
              ? const EmptyChartState(
                  title: 'No Daily Data',
                  message:
                      'No utility data available '
                      'for this month.',
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(.06)),
                    color: Colors.black.withOpacity(.05),
                  ),
                  child: RepaintBoundary(
                    child: _DailyBarChart(theme: widget.theme, data: chartData),
                  ),
                ),
        ),
      ],
    );
  }
}

// ============================================================
// SHELL
// ============================================================

class _DailyChartShell extends StatelessWidget {
  final double width;
  final double height;

  final Color facilityColor;
  final Widget child;

  const _DailyChartShell({
    required this.width,
    required this.height,
    required this.facilityColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ScadaChartPanel(
      width: width,
      height: height,
      color: facilityColor,
      child: Padding(padding: const EdgeInsets.all(8), child: child),
    );
  }
}

// ============================================================
// DAILY CHART
// ============================================================

class _DailyBarChart extends StatelessWidget {
  final ChartTheme theme;
  final _DailyChartData data;

  const _DailyBarChart({required this.theme, required this.data});

  @override
  Widget build(BuildContext context) {
    return SfCartesianChart(
      margin: const EdgeInsets.fromLTRB(6, 8, 8, 2),

      plotAreaBorderWidth: 1,
      plotAreaBorderColor: Colors.white.withOpacity(.12),

      legend: Legend(
        isVisible: data.hasCost,
        position: LegendPosition.top,
        alignment: ChartAlignment.far,
        overflowMode: LegendItemOverflowMode.wrap,
        iconHeight: 9,
        iconWidth: 9,
        textStyle: TextStyle(
          color: Colors.white.withOpacity(.68),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),

      tooltipBehavior: TooltipBehavior(
        enable: true,
        shared: true,
        canShowMarker: true,
        header: '',
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),

      primaryXAxis: DateTimeAxis(
        minimum: data.minX,
        maximum: data.maxX,
        intervalType: DateTimeIntervalType.days,
        interval: 1,
        labelRotation: 45,
        dateFormat: DateFormat('dd'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(.07),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(.15), width: 1),
        majorTickLines: const MajorTickLines(size: 3),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(.70),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        edgeLabelPlacement: EdgeLabelPlacement.hide,
      ),

      primaryYAxis: NumericAxis(
        minimum: 0,
        maximum: data.maxY,
        interval: data.yInterval,
        numberFormat: NumberFormat.compact(),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(.075),
          dashArray: const <double>[4, 4],
        ),
        title: AxisTitle(
          text: theme.unit,
          alignment: ChartAlignment.center,
          textStyle: TextStyle(
            color: Colors.white.withOpacity(.72),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(.15), width: 1),
        majorTickLines: const MajorTickLines(size: 0),
        labelStyle: TextStyle(color: Colors.white70, fontSize: 14),
      ),

      axes: data.hasCost
          ? <ChartAxis>[
              NumericAxis(
                name: 'costAxis',
                opposedPosition: true,
                minimum: 0,
                maximum: data.maxCostY,
                interval: data.costInterval,
                axisLabelFormatter: (AxisLabelRenderDetails details) {
                  return ChartAxisLabel(
                    _formatUsd(details.value.toDouble()),
                    details.textStyle,
                  );
                },
                majorGridLines: const MajorGridLines(width: 0),
                majorTickLines: const MajorTickLines(size: 0),
                title: AxisTitle(
                  text: 'USD',
                  alignment: ChartAlignment.center,
                  textStyle: TextStyle(
                    color: const Color(0xFF34D399).withOpacity(.85),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                axisLine: AxisLine(
                  color: const Color(0xFF34D399).withOpacity(.35),
                  width: .8,
                ),
                labelStyle: const TextStyle(
                  color: Color(0xFF6EE7B7),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]
          : const <ChartAxis>[],

      series: _buildSeries(),
    );
  }

  List<CartesianSeries<_DailyBarPoint, DateTime>> _buildSeries() {
    final result = <CartesianSeries<_DailyBarPoint, DateTime>>[
      ColumnSeries<_DailyBarPoint, DateTime>(
        name: theme.title,
        animationDuration: 500,
        dataSource: data.points,
        xValueMapper: (point, _) => point.ts,
        yValueMapper: (point, _) => point.value,
        width: .82,
        spacing: .18,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.fillTop, theme.fillBottom],
        ),
        borderColor: theme.line.withOpacity(.95),
        borderWidth: .8,
        enableTooltip: true,
      ),
    ];

    if (data.hasCost) {
      result.add(
        SplineSeries<_DailyBarPoint, DateTime>(
          name: 'Cost USD',
          dataSource: data.points,
          xValueMapper: (point, _) => point.ts,
          yValueMapper: (point, _) => point.costUsd,
          yAxisName: 'costAxis',
          color: const Color(0xFF34D399),
          width: 2.4,
          animationDuration: 500,
          enableTooltip: true,
          markerSettings: const MarkerSettings(
            isVisible: true,
            width: 6,
            height: 6,
            shape: DataMarkerType.circle,
            color: Color(0xFF34D399),
            borderColor: Color(0xFF0B1727),
            borderWidth: 1.5,
          ),
        ),
      );
    }

    return result;
  }
}

// ============================================================
// FORMATTERS
// ============================================================

// ============================================================
// FORMATTERS
// ============================================================

/// Formatter compact dùng chung cho cả trục chart và giá trị "Last".
/// Đảm bảo 2 chỗ hiển thị luôn đồng nhất 1 kiểu số.
final NumberFormat _compactValueFormat = NumberFormat.compact(locale: 'en_US');

String _formatUtilityValue(double value) {
  if (!value.isFinite) {
    return '--';
  }

  final absolute = value.abs();

  // Từ 1000 trở lên: dùng đúng compact format giống trục Y (K, M, ...)
  if (absolute >= 1000) {
    return _compactValueFormat.format(value);
  }

  if (absolute >= 100) {
    return value.toStringAsFixed(1);
  }

  if (absolute >= 10) {
    return value.toStringAsFixed(2);
  }

  return value.toStringAsFixed(3);
}

String _formatUsd(double? value) {
  if (value == null || !value.isFinite) {
    return '--';
  }

  final absolute = value.abs();

  if (absolute >= 1000000) {
    return '\$${(value / 1000000).toStringAsFixed(2)}M';
  }

  if (absolute >= 1000) {
    return '\$${(value / 1000).toStringAsFixed(2)}K';
  }

  if (absolute >= 100) {
    return '\$${value.toStringAsFixed(1)}';
  }

  return '\$${value.toStringAsFixed(2)}';
}
