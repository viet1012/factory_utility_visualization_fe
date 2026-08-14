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
// PREPARED DATA
// ============================================================

class _ElectricityChartData {
  final List<UtilityDailyElectricityPoint> points;

  final DateTime minX;
  final DateTime maxX;

  final double maxY;
  final double yInterval;

  const _ElectricityChartData({
    required this.points,
    required this.minX,
    required this.maxX,
    required this.maxY,
    required this.yInterval,
  });

  factory _ElectricityChartData.from({
    required List<UtilityDailyElectricityPoint> rows,
    required String month,
  }) {
    final points = List<UtilityDailyElectricityPoint>.from(rows)
      ..sort((a, b) => a.date.compareTo(b.date));

    final year = int.parse(month.substring(0, 4));

    final monthNumber = int.parse(month.substring(4, 6));

    final firstDay = DateTime(year, monthNumber, 1);

    final lastDay = DateTime(
      year,
      monthNumber + 1,
      1,
    ).subtract(const Duration(days: 1));

    double maxValue = 0;

    for (final point in points) {
      /*
       * Chiều cao toàn cột =
       *
       * Grid + Solar
       *
       * Dùng totalKwh nếu API đã tính sẵn.
       */
      final total = point.totalKwh;

      if (total.isFinite && total > maxValue) {
        maxValue = total;
      }
    }

    final rawMaxY = maxValue <= 0 ? 1.0 : maxValue * 1.15;

    final yInterval = _niceStep(rawMaxY / 5);

    final maxY = _niceCeil(rawMaxY, yInterval);

    return _ElectricityChartData(
      points: List<UtilityDailyElectricityPoint>.unmodifiable(points),
      minX: firstDay.subtract(const Duration(hours: 12)),
      maxX: lastDay.add(const Duration(hours: 12)),
      maxY: maxY,
      yInterval: yInterval,
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
// MAIN
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
    extends State<UtilityDashboardOverviewDailyElectricityChart>
    with TickerProviderStateMixin {
  late final UtilityInfoBoxFx fx;

  List<UtilityDailyElectricityPoint>? _cachedRowsReference;

  _ElectricityChartData? _cachedChartData;

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
          'Daily_Electricity_'
          '${widget.facId}',

      loading: widget.loading,

      error: widget.error,

      values: rows
          .map((item) => item.totalKwh)
          .where((value) => value.isFinite)
          .toList(growable: false),
    );

    if (rows.isEmpty || !_hasRequired) {
      _cachedChartData = null;

      _lastValue = '--';

      _lastTimestamp = '--';

      return;
    }

    _cachedChartData = _ElectricityChartData.from(
      rows: rows,
      month: widget.month,
    );

    final latest = _resolveLatestPoint(rows);

    _lastValue =
        '${_formatUtilityValue(latest.totalKwh)} '
        '${widget.theme.unit}';

    _lastTimestamp = DateFormat('yyyy-MM-dd').format(latest.date.toLocal());
  }

  UtilityDailyElectricityPoint _resolveLatestPoint(
    List<UtilityDailyElectricityPoint> rows,
  ) {
    final sorted = List<UtilityDailyElectricityPoint>.from(rows)
      ..sort((a, b) => a.date.compareTo(b.date));

    final now = DateTime.now();

    final currentMonth = DateFormat('yyyyMM').format(now);

    if (currentMonth != widget.month) {
      return sorted.last;
    }

    for (var i = sorted.length - 1; i >= 0; i--) {
      final date = sorted[i].date.toLocal();

      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return sorted[i];
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
              'Daily_Electricity_'
              '${widget.facId}',
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

            /*
             * Header = tổng điện
             * Grid + Solar.
             */
            valueLabel: 'Total Electricity',
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
                      'No electricity data '
                      'available for this month.',
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),

                    border: Border.all(color: Colors.white.withOpacity(.06)),

                    color: Colors.black.withOpacity(.05),
                  ),

                  child: RepaintBoundary(
                    child: _ElectricityStackedChart(
                      theme: widget.theme,
                      data: chartData,
                    ),
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
// ELECTRICITY STACKED COLUMN
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

          fontSize: 14,

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

      series: <CartesianSeries<UtilityDailyElectricityPoint, DateTime>>[
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

          // color: const Color(0xFFFFAB00),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xA176FF03), Color(0x10B981)],
          ),

          borderColor: const Color(0xB276FF03).withOpacity(.95),
          borderWidth: .8,

          // borderWidth: .8,
          // borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          enableTooltip: true,
        ),
      ],
    );
  }
}

// ============================================================
// FORMAT
// ============================================================

final NumberFormat _compactValueFormat = NumberFormat.compact(locale: 'en_US');

String _formatUtilityValue(double value) {
  if (!value.isFinite) {
    return '--';
  }

  final absolute = value.abs();

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
