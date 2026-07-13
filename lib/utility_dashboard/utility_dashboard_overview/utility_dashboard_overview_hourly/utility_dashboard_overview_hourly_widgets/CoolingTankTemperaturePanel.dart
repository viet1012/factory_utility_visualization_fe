import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../utility_dashboard_common/chart_theme.dart';
import '../../../utility_dashboard_common/data_health.dart';
import '../../utility_dashboard_overview_models/utility_hourly_dashboard_response.dart';
import '../../utility_dashboard_overview_widgets/chart_state_widgets.dart';
import '../../utility_dashboard_overview_widgets/health_indicator.dart';
import '../../utility_dashboard_overview_widgets/scada_panel_frame.dart';

class _SensorPoint {
  final int hour;
  final double? value;

  const _SensorPoint({required this.hour, required this.value});
}

class _SensorChartData {
  final List<_SensorPoint> todayPoints;
  final List<_SensorPoint> yesterdayPoints;

  final double? current;
  final double? diff;
  final double? minToday;
  final double? maxToday;

  final double minY;
  final double maxY;
  final double interval;

  const _SensorChartData({
    required this.todayPoints,
    required this.yesterdayPoints,
    required this.current,
    required this.diff,
    required this.minToday,
    required this.maxToday,
    required this.minY,
    required this.maxY,
    required this.interval,
  });

  factory _SensorChartData.from(List<HourlySensorPoint> rows) {
    final byHour = <int, HourlySensorPoint>{};

    for (final row in rows) {
      if (row.scaleHour < 0 || row.scaleHour > 23) {
        continue;
      }

      byHour[row.scaleHour] = row;
    }

    final todayPoints = <_SensorPoint>[];
    final yesterdayPoints = <_SensorPoint>[];

    final todayValues = <double>[];
    final allValues = <double>[];

    HourlySensorPoint? latest;

    for (var hour = 0; hour < 24; hour++) {
      final row = byHour[hour];

      final today = _sanitize(row?.today);
      final yesterday = _sanitize(row?.yesterday);

      todayPoints.add(_SensorPoint(hour: hour, value: today));

      yesterdayPoints.add(_SensorPoint(hour: hour, value: yesterday));

      if (today != null) {
        todayValues.add(today);
        allValues.add(today);
        latest = row;
      }

      if (yesterday != null) {
        allValues.add(yesterday);
      }
    }

    final current = _sanitize(latest?.today);
    final previous = _sanitize(latest?.yesterday);

    final diff = current == null || previous == null
        ? null
        : current - previous;

    final minToday = todayValues.isEmpty ? null : todayValues.reduce(min);

    final maxToday = todayValues.isEmpty ? null : todayValues.reduce(max);

    if (allValues.isEmpty) {
      return _SensorChartData(
        todayPoints: List.unmodifiable(todayPoints),
        yesterdayPoints: List.unmodifiable(yesterdayPoints),
        current: current,
        diff: diff,
        minToday: minToday,
        maxToday: maxToday,
        minY: 0,
        maxY: 1,
        interval: .2,
      );
    }

    final minValue = allValues.reduce(min);
    final maxValue = allValues.reduce(max);

    final range = maxValue - minValue;
    final padding = max(range * .18, .5);

    final minY = minValue - padding;
    final maxY = maxValue + padding;
    final interval = max((maxY - minY) / 5, .1);

    return _SensorChartData(
      todayPoints: List.unmodifiable(todayPoints),
      yesterdayPoints: List.unmodifiable(yesterdayPoints),
      current: current,
      diff: diff,
      minToday: minToday,
      maxToday: maxToday,
      minY: minY,
      maxY: maxY,
      interval: interval,
    );
  }

  static double? _sanitize(double? value) {
    if (value == null || value.isNaN || value.isInfinite) {
      return null;
    }

    return value;
  }
}

class CoolingTankTemperaturePanel extends StatefulWidget {
  final List<HourlySensorPoint> rows;

  final String facId;
  final ChartTheme theme;
  final String utilityType;

  final bool loading;
  final Object? error;

  final VoidCallback? onRetry;

  const CoolingTankTemperaturePanel({
    super.key,
    required this.rows,
    required this.facId,
    required this.theme,
    required this.utilityType,
    required this.loading,
    required this.error,
    this.onRetry,
  });

  @override
  State<CoolingTankTemperaturePanel> createState() =>
      _CoolingTankTemperaturePanelState();
}

class _CoolingTankTemperaturePanelState
    extends State<CoolingTankTemperaturePanel> {
  List<HourlySensorPoint>? _cachedRows;
  String? _cachedFac;
  String? _cachedType;
  bool? _cachedLoading;
  Object? _cachedError;

  _SensorChartData? _chartData;
  DataHealthResult? _health;

  @override
  void initState() {
    super.initState();

    _prepare();
  }

  @override
  void didUpdateWidget(covariant CoolingTankTemperaturePanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final changed =
        !identical(oldWidget.rows, widget.rows) ||
        oldWidget.facId != widget.facId ||
        oldWidget.utilityType != widget.utilityType ||
        oldWidget.loading != widget.loading ||
        oldWidget.error != widget.error;

    if (changed) {
      _prepare(force: true);
    }
  }

  void _prepare({bool force = false}) {
    if (!force &&
        identical(_cachedRows, widget.rows) &&
        _cachedFac == widget.facId &&
        _cachedType == widget.utilityType &&
        _cachedLoading == widget.loading &&
        _cachedError == widget.error) {
      return;
    }

    _cachedRows = widget.rows;
    _cachedFac = widget.facId;
    _cachedType = widget.utilityType;
    _cachedLoading = widget.loading;
    _cachedError = widget.error;

    _chartData = widget.rows.isEmpty
        ? null
        : _SensorChartData.from(widget.rows);

    final values = <double>[];

    for (final row in widget.rows) {
      if (row.today != null) {
        values.add(row.today!);
      }

      if (row.yesterday != null) {
        values.add(row.yesterday!);
      }
    }

    _health = DataHealthAnalyzer.analyze(
      key: 'UtilityHourly_${widget.facId}_${widget.utilityType}',
      loading: widget.loading,
      error: widget.error,
      values: values,
    );
  }

  @override
  Widget build(BuildContext context) {
    final health =
        _health ??
        DataHealthAnalyzer.analyze(
          key: 'UtilityHourly_${widget.facId}_${widget.utilityType}',
          loading: widget.loading,
          error: widget.error,
          values: const [],
        );

    return ScadaPanelFrame(
      color: widget.theme.line,
      child: _buildContent(health),
    );
  }

  Widget _buildContent(DataHealthResult health) {
    if (widget.loading && widget.rows.isEmpty) {
      return Center(
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
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

    final chartData = _chartData;

    if (widget.rows.isEmpty || chartData == null) {
      return EmptyChartState(
        icon: Icons.query_stats_rounded,
        title: 'No Hourly Data',
        message: 'No ${widget.theme.title.toLowerCase()} data found.',
      );
    }

    return _TemperatureTrendCard(
      theme: widget.theme,
      utilityType: widget.utilityType,
      data: chartData,
      health: health,
    );
  }
}

class _TemperatureTrendCard extends StatelessWidget {
  final ChartTheme theme;
  final String utilityType;

  final _SensorChartData data;
  final DataHealthResult health;

  const _TemperatureTrendCard({
    required this.theme,
    required this.utilityType,
    required this.data,
    required this.health,
  });

  String get _valueLabel {
    if (utilityType.toUpperCase() == 'AIR') {
      return 'AVG PRESSURE';
    }

    return 'AVG TEMPERATURE';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 5),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.line.withOpacity(.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.line.withOpacity(.22)),
                ),
                child: Icon(theme.icon, color: theme.line, size: 18),
              ),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _valueLabel,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        data.current == null
                            ? '--'
                            : data.current!.toStringAsFixed(1),
                        style: TextStyle(
                          color: theme.line,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        theme.unit,
                        style: TextStyle(
                          color: theme.line.withOpacity(.72),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 18),
              _CompactStat(label: 'Min', value: data.minToday, theme: theme),
              const SizedBox(width: 14),
              _CompactStat(label: 'Max', value: data.maxToday, theme: theme),
              const Spacer(),
              if (data.diff != null) ...[
                _DiffBadge(diff: data.diff!),
                const SizedBox(width: 10),
              ],
              HealthIndicator(
                result: health,
                size: 8,
                showLabel: false,
                enableTooltip: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: RepaintBoundary(
            child: _TempLineChart(theme: theme, data: data),
          ),
        ),
      ],
    );
  }
}

class _DiffBadge extends StatelessWidget {
  final double diff;

  const _DiffBadge({required this.diff});

  @override
  Widget build(BuildContext context) {
    final increased = diff >= 0;

    final color = increased ? const Color(0xFFFF6B6B) : const Color(0xFF22C55E);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(.20)),
      ),
      child: Row(
        children: [
          Icon(
            increased
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            diff.abs().toStringAsFixed(1),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String label;
  final double? value;
  final ChartTheme theme;

  const _CompactStat({
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(.40),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            // letterSpacing: .5,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value == null ? '--' : value!.toStringAsFixed(1),
          style: TextStyle(
            color: theme.line,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _TempLineChart extends StatelessWidget {
  final ChartTheme theme;
  final _SensorChartData data;

  const _TempLineChart({required this.theme, required this.data});

  @override
  Widget build(BuildContext context) {
    final validCount = [
      ...data.todayPoints,
      ...data.yesterdayPoints,
    ].where((point) => point.value != null).length;

    if (validCount < 2) {
      return Center(
        child: Text(
          'Not enough points',
          style: TextStyle(color: Colors.white.withOpacity(.60)),
        ),
      );
    }

    return SfCartesianChart(
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 0,
      legend: Legend(
        isVisible: true,
        position: LegendPosition.top,
        alignment: ChartAlignment.center,
        toggleSeriesVisibility: true,
        textStyle: TextStyle(
          color: Colors.white.withOpacity(.72),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      primaryXAxis: NumericAxis(
        minimum: 0,
        maximum: 23,
        interval: 2,
        decimalPlaces: 0,
        axisLabelFormatter: (args) {
          return ChartAxisLabel(
            args.value.toInt().toString(),
            TextStyle(
              color: Colors.white.withOpacity(.66),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          );
        },
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(.04),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(.10)),
      ),
      primaryYAxis: NumericAxis(
        minimum: data.minY,
        maximum: data.maxY,
        interval: data.interval,
        numberFormat: NumberFormat('0.0'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(.04),
        ),
        title: AxisTitle(
          text: theme.unit,
          alignment: ChartAlignment.center,
          textStyle: TextStyle(
            color: Colors.white.withOpacity(.76),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(.10)),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(.48),
          fontSize: 10,
        ),
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        decimalPlaces: 1,
        header: '',
        canShowMarker: true,
        format: 'Hour point.x : point.y ${theme.unit}',
      ),
      series: <CartesianSeries<_SensorPoint, num>>[
        AreaSeries<_SensorPoint, num>(
          name: 'Yesterday',
          dataSource: data.yesterdayPoints,
          xValueMapper: (point, _) => point.hour,
          yValueMapper: (point, _) => point.value,
          borderColor: const Color(0xFF9CA3AF),
          borderWidth: 2,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF9CA3AF).withOpacity(.18),
              const Color(0xFF9CA3AF).withOpacity(.02),
            ],
          ),
          emptyPointSettings: const EmptyPointSettings(
            mode: EmptyPointMode.gap,
          ),
          markerSettings: const MarkerSettings(isVisible: false),
        ),
        LineSeries<_SensorPoint, num>(
          name: 'Today',
          dataSource: data.todayPoints,
          xValueMapper: (point, _) => point.hour,
          yValueMapper: (point, _) => point.value,
          color: theme.line,
          width: 2.4,
          emptyPointSettings: const EmptyPointSettings(
            mode: EmptyPointMode.gap,
          ),
          markerSettings: MarkerSettings(
            isVisible: true,
            width: 4,
            height: 4,
            borderWidth: 1,
            borderColor: theme.line.withOpacity(.90),
          ),

          // Không hiện label toàn bộ điểm,
          // tránh rối và giảm render.
          dataLabelSettings: const DataLabelSettings(isVisible: false),
        ),
      ],
    );
  }
}
