import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_common/data_health.dart';
import '../utility_dashboard_overview_models/'
    'utility_daily_dashboard_response.dart';
import 'daily_chart_common.dart';

// ============================================================
// PREPARED DATA
// ============================================================

class _ElectricityChartData {
  final List<UtilityDailyElectricityPoint> points;

  final DailyChartRange range;

  const _ElectricityChartData({required this.points, required this.range});

  factory _ElectricityChartData.from({
    required List<UtilityDailyElectricityPoint> rows,
    required String month,
  }) {
    final points = List<UtilityDailyElectricityPoint>.from(rows)
      ..sort((a, b) => a.date.compareTo(b.date));

    final range = DailyChartUtils.calculateRange(
      month: month,

      // Tổng chiều cao =
      // Grid + Solar
      // API trả totalKwh sẵn.
      values: points.map((point) => point.totalKwh),
    );

    return _ElectricityChartData(
      points: List.unmodifiable(points),

      range: range,
    );
  }
}

// ============================================================
// WIDGET
// ============================================================

class UtilityDashboardOverviewDailyElectricityChart extends StatefulWidget {
  final List<UtilityDailyElectricityPoint> rows;

  final String facId;
  final String month;

  final ChartTheme theme;

  final bool loading;
  final Object? error;

  final double width;
  final double? height;

  final bool showHeader;

  final VoidCallback? onRetry;

  const UtilityDashboardOverviewDailyElectricityChart({
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
  State<UtilityDashboardOverviewDailyElectricityChart> createState() =>
      _UtilityDashboardOverviewDailyElectricityChartState();
}

class _UtilityDashboardOverviewDailyElectricityChartState
    extends State<UtilityDashboardOverviewDailyElectricityChart> {
  _ElectricityChartData? _chartData;

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
  void didUpdateWidget(
    covariant UtilityDashboardOverviewDailyElectricityChart oldWidget,
  ) {
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
    if (widget.rows.isEmpty || !_hasRequired) {
      _chartData = null;
      return;
    }

    _chartData = _ElectricityChartData.from(
      rows: widget.rows,
      month: widget.month,
    );
  }

  void _prepareHealth() {
    _health = DataHealthAnalyzer.analyze(
      key: 'Daily_Electricity_${widget.facId}',

      loading: widget.loading,

      error: widget.error,

      values: widget.rows
          .map((item) => item.totalKwh)
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

    final latest = DailyChartUtils.resolveLatest<UtilityDailyElectricityPoint>(
      rows: widget.rows,

      month: widget.month,

      dateOf: (item) => item.date,
    );

    _latestValue =
        '${DailyChartUtils.formatValue(latest.totalKwh)} '
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
          key: 'Daily_Electricity_${widget.facId}',
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

      valueLabel: 'Total Electricity',

      value: _latestValue,

      valueTimestamp: _latestTimestamp,

      width: widget.width,

      height: widget.height ?? 320,

      showHeader: widget.showHeader,

      onRetry: widget.onRetry,

      emptyTitle: 'No Daily Data',

      emptyMessage: 'No electricity data available for this month.',

      chart: _chartData == null
          ? null
          : _ElectricityStackedChart(theme: widget.theme, data: _chartData!),
    );
  }
}

// ============================================================
// ELECTRICITY STACKED CHART
// ============================================================

class _ElectricityStackedChart extends StatelessWidget {
  final ChartTheme theme;

  final _ElectricityChartData data;

  const _ElectricityStackedChart({required this.theme, required this.data});

  @override
  Widget build(BuildContext context) {
    return SfCartesianChart(
      margin: const EdgeInsets.fromLTRB(6, 8, 8, 2),

      plotAreaBorderWidth: 1,

      plotAreaBorderColor: Colors.white.withOpacity(.12),

      // ========================================================
      // LEGEND
      // ========================================================
      legend: Legend(
        isVisible: true,

        position: LegendPosition.top,

        alignment: ChartAlignment.far,

        overflowMode: LegendItemOverflowMode.wrap,

        iconHeight: 12,

        iconWidth: 12,

        textStyle: TextStyle(
          color: Colors.white.withOpacity(.72),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),

      // ========================================================
      // TOOLTIP
      // ========================================================
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

      // ========================================================
      // X
      // ========================================================
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

          fontSize: 14,

          fontWeight: FontWeight.w600,
        ),

        edgeLabelPlacement: EdgeLabelPlacement.hide,
      ),

      // ========================================================
      // Y
      // ========================================================
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
          text: theme.unit.trim().isEmpty ? 'kWh' : theme.unit,

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

      // ========================================================
      // SERIES
      // ========================================================
      series: [
        // ======================================================
        // GRID
        // ======================================================
        StackedColumnSeries<UtilityDailyElectricityPoint, DateTime>(
          name: 'Electricity',

          dataSource: data.points,

          xValueMapper: (point, _) => point.date,

          yValueMapper: (point, _) => point.gridKwh,

          animationDuration: 450,

          width: .95,

          spacing: .14,

          gradient: LinearGradient(
            begin: Alignment.topCenter,

            end: Alignment.bottomCenter,

            colors: [theme.fillTop, theme.fillBottom],
          ),

          borderColor: theme.line.withOpacity(.95),

          borderWidth: .8,

          enableTooltip: true,
        ),

        // ======================================================
        // SOLAR
        // ======================================================
        StackedColumnSeries<UtilityDailyElectricityPoint, DateTime>(
          name: 'Solar',

          dataSource: data.points,

          xValueMapper: (point, _) => point.date,

          yValueMapper: (point, _) => point.solarKwh,

          animationDuration: 450,

          width: .95,

          spacing: .14,

          gradient: const LinearGradient(
            begin: Alignment.topCenter,

            end: Alignment.bottomCenter,

            colors: [Color(0xA176FF03), Color(0x0010B981)],
          ),

          borderColor: const Color(0xB276FF03),

          borderWidth: .8,

          enableTooltip: true,
        ),
      ],
    );
  }
}
