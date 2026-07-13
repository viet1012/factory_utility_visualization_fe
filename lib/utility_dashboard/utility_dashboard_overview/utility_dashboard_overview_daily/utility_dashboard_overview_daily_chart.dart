import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_common/data_health.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../utility_dashboard_overview_models/utility_daily_dashboard_response.dart';
import '../utility_dashboard_overview_widgets/chart_state_widgets.dart';
import '../utility_dashboard_overview_widgets/common_chart_title_bar.dart';
import '../utility_dashboard_overview_widgets/scada_chart_panel.dart';

class _BarPoint {
  final DateTime ts;
  final double value;

  const _BarPoint({required this.ts, required this.value});
}

class _DailyChartData {
  final List<_BarPoint> points;

  final DateTime minX;
  final DateTime maxX;

  final double maxY;
  final double yInterval;

  const _DailyChartData({
    required this.points,
    required this.minX,
    required this.maxX,
    required this.maxY,
    required this.yInterval,
  });

  factory _DailyChartData.from({
    required List<UtilityDailyPoint> rows,
    required String month,
  }) {
    final points =
        rows
            .map(
              (item) => _BarPoint(ts: item.date.toLocal(), value: item.value),
            )
            .toList()
          ..sort((a, b) => a.ts.compareTo(b.ts));

    final year = int.parse(month.substring(0, 4));

    final monthNumber = int.parse(month.substring(4, 6));

    final firstDay = DateTime(year, monthNumber, 1);

    final lastDay = DateTime(
      year,
      monthNumber + 1,
      1,
    ).subtract(const Duration(days: 1));

    double maxDataValue = 0;

    for (final point in points) {
      if (point.value > maxDataValue) {
        maxDataValue = point.value;
      }
    }

    final rawMaxY = maxDataValue <= 0 ? 1.0 : maxDataValue * 1.15;

    final interval = _niceStep(rawMaxY / 5);

    final maxY = _niceCeil(rawMaxY, interval);

    return _DailyChartData(
      points: List<_BarPoint>.unmodifiable(points),
      minX: firstDay.subtract(const Duration(hours: 12)),
      maxX: lastDay.add(const Duration(hours: 12)),
      maxY: maxY,
      yInterval: interval,
    );
  }

  static double _niceStep(double rawStep) {
    if (rawStep <= 0) return 1;

    final exponent = (log(rawStep) / ln10).floor();

    final base = pow(10, exponent).toDouble();

    final fraction = rawStep / base;

    if (fraction <= 1) return base;
    if (fraction <= 2) return 2 * base;
    if (fraction <= 5) return 5 * base;

    return 10 * base;
  }

  static double _niceCeil(double value, double step) {
    if (step <= 0) return value;

    return (value / step).ceil() * step;
  }
}

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

    if (rowsChanged || configChanged) {
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
      key: 'Daily_${widget.facId}_${widget.theme.title}',
      loading: widget.loading,
      error: widget.error,
      values: rows.map((item) => item.value).toList(growable: false),
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
        '${latest.value.toStringAsFixed(1)} '
        '${widget.theme.unit}';

    _lastTimestamp = DateFormat('yyyy-MM-dd').format(latest.date);
  }

  UtilityDailyPoint _resolveLatestPoint(List<UtilityDailyPoint> rows) {
    final now = DateTime.now();

    final isCurrentMonth = DateFormat('yyyyMM').format(now) == widget.month;

    if (!isCurrentMonth) {
      return rows.last;
    }

    for (var index = rows.length - 1; index >= 0; index--) {
      final item = rows[index];

      if (item.date.year == now.year &&
          item.date.month == now.month &&
          item.date.day == now.day) {
        return item;
      }
    }

    return rows.last;
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
          key: 'Daily_${widget.facId}_${widget.theme.title}',
          loading: widget.loading,
          error: widget.error,
          values: const [],
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
        const SizedBox(height: 6),
        Expanded(
          child: widget.rows.isEmpty || _cachedChartData == null
              ? const EmptyChartState(
                  title: 'No Daily Data',
                  message: 'No utility data available for this month.',
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(.06)),
                    color: Colors.black.withOpacity(.05),
                  ),
                  child: RepaintBoundary(
                    child: _DailyBarChart(
                      theme: widget.theme,
                      data: _cachedChartData!,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

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

class _DailyBarChart extends StatelessWidget {
  final ChartTheme theme;
  final _DailyChartData data;

  const _DailyBarChart({required this.theme, required this.data});

  @override
  Widget build(BuildContext context) {
    return SfCartesianChart(
      plotAreaBorderWidth: 1,
      plotAreaBorderColor: Colors.white.withOpacity(.12),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        canShowMarker: true,
        header: '',
        textStyle: const TextStyle(
          color: Colors.white,
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
          color: Colors.white.withOpacity(.08),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(.15), width: 1),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(.75),
          fontSize: 13,
        ),
        labelPosition: ChartDataLabelPosition.outside,
        edgeLabelPlacement: EdgeLabelPlacement.hide,
      ),
      primaryYAxis: NumericAxis(
        minimum: 0,
        maximum: data.maxY,
        interval: data.yInterval,
        numberFormat: NumberFormat('0.##'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(.08),
        ),
        title: AxisTitle(
          text: theme.unit,
          alignment: ChartAlignment.center,
          textStyle: TextStyle(
            color: Colors.white.withOpacity(.8),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(.15), width: 1),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(.75),
          fontSize: 13,
        ),
      ),
      series: <CartesianSeries<_BarPoint, DateTime>>[
        ColumnSeries<_BarPoint, DateTime>(
          animationDuration: 700,
          dataSource: data.points,
          xValueMapper: (point, _) => point.ts,
          yValueMapper: (point, _) => point.value,
          width: .85,
          spacing: .2,
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          color: theme.line,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.fillTop, theme.fillBottom],
          ),
          borderColor: theme.line.withOpacity(.95),
          borderWidth: .8,
        ),
      ],
    );
  }
}
