import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_common/data_health.dart';
import '../utility_dashboard_overview_models/'
    'utility_daily_dashboard_response.dart';
import 'daily_chart_common.dart';

// ============================================================
// POINT
// ============================================================

class _DailyBarPoint {
  final DateTime date;
  final double value;

  const _DailyBarPoint({required this.date, required this.value});
}

// ============================================================
// PREPARED DATA
// ============================================================

class _DailyBarData {
  final List<_DailyBarPoint> points;

  final DailyChartRange range;

  const _DailyBarData({required this.points, required this.range});

  factory _DailyBarData.from({
    required List<UtilityDailyPoint> rows,
    required String month,
  }) {
    final points =
        rows
            .where((item) => item.value.isFinite)
            .map(
              (item) =>
                  _DailyBarPoint(date: item.date.toLocal(), value: item.value),
            )
            .toList(growable: true)
          ..sort((a, b) => a.date.compareTo(b.date));

    final range = DailyChartUtils.calculateRange(
      month: month,
      values: points.map((item) => item.value),
    );

    return _DailyBarData(points: List.unmodifiable(points), range: range);
  }
}

// ============================================================
// WIDGET
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
    extends State<UtilityDashboardOverviewDailyChart> {
  List<UtilityDailyPoint>? _rowsReference;

  _DailyBarData? _chartData;

  DataHealthResult? _health;

  String _latestValue = '--';
  String _latestTimestamp = '--';

  bool get _hasRequired {
    return DailyChartUtils.isValidSource(
      facId: widget.facId,
      month: widget.month,
    );
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _prepareAll();
  }

  // ============================================================
  // UPDATE
  // ============================================================

  @override
  void didUpdateWidget(covariant UtilityDashboardOverviewDailyChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    final rowsChanged = !identical(oldWidget.rows, widget.rows);

    final configChanged =
        oldWidget.facId != widget.facId ||
        oldWidget.month != widget.month ||
        oldWidget.theme.title != widget.theme.title ||
        oldWidget.theme.unit != widget.theme.unit;

    final healthChanged =
        rowsChanged ||
        oldWidget.loading != widget.loading ||
        oldWidget.error != widget.error;

    if (rowsChanged || configChanged) {
      _prepareChartData();
      _prepareLatest();
    }

    if (healthChanged || configChanged) {
      _prepareHealth();
    }
  }

  // ============================================================
  // PREPARE
  // ============================================================

  void _prepareAll() {
    _prepareChartData();
    _prepareLatest();
    _prepareHealth();
  }

  void _prepareChartData() {
    _rowsReference = widget.rows;

    if (widget.rows.isEmpty || !_hasRequired) {
      _chartData = null;
      return;
    }

    _chartData = _DailyBarData.from(rows: widget.rows, month: widget.month);
  }

  void _prepareHealth() {
    _health = DataHealthAnalyzer.analyze(
      key: 'Daily_${widget.facId}_${widget.theme.title}',

      loading: widget.loading,

      error: widget.error,

      values: widget.rows
          .map((item) => item.value)
          .where((value) => value.isFinite)
          .toList(growable: false),
    );
  }

  void _prepareLatest() {
    if (widget.rows.isEmpty || !_hasRequired) {
      _latestValue = '--';
      _latestTimestamp = '--';
      return;
    }

    final latest = DailyChartUtils.resolveLatest<UtilityDailyPoint>(
      rows: widget.rows,
      month: widget.month,
      dateOf: (item) => item.date,
    );

    _latestValue =
        '${DailyChartUtils.formatValue(latest.value)} '
        '${widget.theme.unit}';

    _latestTimestamp = DateFormat('yyyy-MM-dd').format(latest.date.toLocal());
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final health =
        _health ??
        DataHealthAnalyzer.analyze(
          key: 'Daily_${widget.facId}_${widget.theme.title}',
          loading: widget.loading,
          error: widget.error,
          values: const <double>[],
        );

    return DailyChartFrame(
      facId: widget.facId,

      month: widget.month,

      theme: widget.theme,

      loading: widget.loading,

      error: widget.error,

      hasData: widget.rows.isNotEmpty && _chartData != null,

      health: health,

      value: _latestValue,

      valueTimestamp: _latestTimestamp,

      width: widget.width,

      height: widget.height ?? 320,

      showHeader: widget.showHeader,

      onRetry: widget.onRetry,

      emptyTitle: 'No Daily Data',

      emptyMessage: 'No utility data available for this month.',

      chart: _chartData == null
          ? null
          : _DailyBarChart(theme: widget.theme, data: _chartData!),
    );
  }
}

// ============================================================
// CHART
// ============================================================

class _DailyBarChart extends StatelessWidget {
  final ChartTheme theme;

  final _DailyBarData data;

  const _DailyBarChart({required this.theme, required this.data});

  @override
  Widget build(BuildContext context) {
    return SfCartesianChart(
      margin: const EdgeInsets.fromLTRB(6, 8, 8, 2),

      plotAreaBorderWidth: 1,

      plotAreaBorderColor: Colors.white.withOpacity(.12),

      legend: const Legend(isVisible: false),

      tooltipBehavior: TooltipBehavior(
        enable: true,
        header: '',
        canShowMarker: false,
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),

      primaryXAxis: DateTimeAxis(
        minimum: data.range.minX,

        maximum: data.range.maxX,

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

        maximum: data.range.maxY,

        interval: data.range.yInterval,

        numberFormat: NumberFormat.compact(),

        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(.075),
          dashArray: const [4, 4],
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

        labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
      ),

      series: [
        ColumnSeries<_DailyBarPoint, DateTime>(
          name: theme.title,

          dataSource: data.points,

          xValueMapper: (point, _) => point.date,

          yValueMapper: (point, _) => point.value,

          animationDuration: 450,

          width: .9,

          spacing: .15,

          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.fillTop, theme.fillBottom],
          ),

          borderColor: theme.line.withOpacity(.95),

          borderWidth: .8,

          enableTooltip: true,
        ),
      ],
    );
  }
}
