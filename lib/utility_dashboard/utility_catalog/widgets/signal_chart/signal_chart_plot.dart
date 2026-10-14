import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../shared/charts/axis_planner.dart';
import '../../../shared/charts/chart_animation.dart';
import '../../../shared/charts/chart_downsample.dart';
import '../../../shared/charts/chart_hover_style.dart';
import '../../../shared/charts/chart_thresholds.dart';
import '../../../shared/charts/signal_chart_spec.dart';
import '../../../shared/charts/signal_thresholds.dart';
import '../../models/signal_history_models.dart';
import 'signal_chart_format.dart';
import 'signal_chart_gaps.dart';
import 'signal_chart_palette.dart';

/// Bieu do cua MOT signal (mot don vi, mot truc Y), kieu ve theo
/// SignalChartSpec:
/// - lineBand: line theo avg (+ dai min..max khi MIN_AVG_MAX);
/// - area: area tu 0 theo avg;
/// - step (STATUS): bac thang theo last, to mau theo ma;
/// - bar (COUNTER): cot theo delta (delta null -> khong ve cot);
/// - khoang null chi ngat duong + to xam khi dai hon kSignalGapBreakThreshold;
/// - nguong (`thresholds[]`, chi ANALOG): duong net dut + nhan mau theo
///   level, nhan ▲ / ▼ o mep khi ngoai truc; diem vuot nguong cham mau level.
class SignalChartPlot extends StatefulWidget {
  final SignalHistorySeries series;
  final Color lineColor;

  /// The gon (Split): khong nhan truc, khong chu tren duong nguong, luoi
  /// toi gian; tooltip van day du.
  final bool compact;

  const SignalChartPlot({
    super.key,
    required this.series,
    required this.lineColor,
    this.compact = false,
  });

  @override
  State<SignalChartPlot> createState() => _SignalChartPlotState();
}

class _SignalChartPlotState extends State<SignalChartPlot> {
  late final TrackballBehavior _trackball;
  final FirstPaintAnimation _animation = FirstPaintAnimation();

  /// Diem theo ts (ms) de trackball tra lai diem goc tu x.
  Map<int, SignalHistoryPoint> _pointsByTime = const {};

  @override
  void initState() {
    super.initState();

    _trackball = ChartHoverStyle.trackball(
      markerColor: widget.lineColor,
      builder: (context, details) {
        final x = details.point?.x;
        final point = x is DateTime
            ? _pointsByTime[x.millisecondsSinceEpoch]
            : null;
        if (point == null) return const SizedBox.shrink();

        return _PointTooltip(point: point, series: widget.series);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    final spec = signalSpecOf(series);
    final style = series.kind == SignalKind.counter
        ? ChartStyle.bar
        : spec.style;
    final isBar = style == ChartStyle.bar;

    final plot = SignalPlotData.of(series.points, bucket: series.bucket);

    final hasBand =
        style == ChartStyle.lineBand &&
        series.kind == SignalKind.analog &&
        series.aggregation == HistoryAggregation.minAvgMax &&
        plot.points.any((point) => point.min != null && point.max != null);

    // Bar dung toan bo bucket (chi phu thuoc delta, khong noi duong).
    final points = downsampleMinMax(
      isBar ? series.points : plot.points,
      value: isBar
          ? (SignalHistoryPoint point) => point.delta
          : series.plotValue,
      low: hasBand
          ? (SignalHistoryPoint point) => point.min ?? point.value
          : null,
      high: hasBand
          ? (SignalHistoryPoint point) => point.max ?? point.value
          : null,
    );

    _pointsByTime = {
      for (final point in points) point.ts.millisecondsSinceEpoch: point,
    };

    // Nguong `thresholds[]` chi ap cho ANALOG (chartThresholds rong voi
    // COUNTER / STATUS).
    final lines = isBar ? const <SignalThreshold>[] : series.chartThresholds;

    final exceeded = <_ExceedMark>[
      for (final point in points)
        if (series.breachLevel(point, lines) case final level?)
          _ExceedMark(point, series.breachValue(point, lines, level), level),
    ];

    final axis = planAxis(
      values: [
        for (final point in points) ...[
          isBar ? point.delta : series.plotValue(point),
          if (hasBand) ...[point.min, point.max],
        ],
      ],
      spec: spec,
      thresholds: lines,
    );

    final unit = spec.resolveUnit(series.unit);
    final animationMs = _animation.duration();
    const gap = EmptyPointSettings(mode: EmptyPointMode.gap);
    final compact = widget.compact;

    final chart = SfCartesianChart(
      margin: compact
          ? const EdgeInsets.fromLTRB(0, 4, 0, 0)
          : const EdgeInsets.fromLTRB(0, 6, 6, 0),
      plotAreaBorderWidth: 0,
      trackballBehavior: _trackball,
      primaryXAxis: DateTimeAxis(
        minimum: series.points.isEmpty ? null : series.points.first.ts,
        maximum: series.points.isEmpty ? null : series.points.last.ts,
        dateFormat: _axisFormat(series.points),
        edgeLabelPlacement: EdgeLabelPlacement.shift,
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: AxisLine(color: SignalChartColors.axisLine),
        majorTickLines: const MajorTickLines(size: 0),
        axisLabelFormatter: compact ? compactAxisLabel : null,
        labelStyle: compact
            ? kCompactAxisLabelStyle
            : const TextStyle(
                color: SignalChartColors.mutedText,
                fontSize: 10.5,
              ),
        plotBands: <PlotBand>[
          for (final gap in plot.gaps)
            PlotBand(
              start: gap.start,
              end: gap.end,
              color: SignalChartColors.gapZone,
              borderWidth: 0,
            ),
        ],
      ),
      primaryYAxis: NumericAxis(
        minimum: axis.min,
        maximum: axis.max,
        interval: axis.interval,
        axisLabelFormatter: compact
            ? compactAxisLabel
            : (details) => ChartAxisLabel(
                axis.label(details.value),
                const TextStyle(
                  color: SignalChartColors.mutedText,
                  fontSize: 10.5,
                ),
              ),
        labelStyle: compact ? kCompactAxisLabelStyle : null,
        majorGridLines: MajorGridLines(
          width: compact ? .6 : 1,
          color: SignalChartColors.gridLine,
        ),
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        plotBands: thresholdPlotBands(axis, unit, showText: !compact),
      ),
      series: <CartesianSeries<dynamic, DateTime>>[
        if (hasBand)
          RangeAreaSeries<SignalHistoryPoint, DateTime>(
            dataSource: points,
            animationDuration: 0,
            enableTooltip: false,
            enableTrackball: false,
            color: widget.lineColor.withValues(alpha: .14),
            borderWidth: 0,
            xValueMapper: (point, _) => point.ts,
            highValueMapper: (point, _) =>
                point.value == null ? null : point.max,
            lowValueMapper: (point, _) =>
                point.value == null ? null : point.min,
            emptyPointSettings: gap,
          ),
        switch (style) {
          ChartStyle.bar => ColumnSeries<SignalHistoryPoint, DateTime>(
            dataSource: points,
            animationDuration: animationMs,
            color: widget.lineColor,
            width: .7,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            xValueMapper: (point, _) => point.ts,
            yValueMapper: (point, _) => point.delta,
            emptyPointSettings: gap,
          ),
          ChartStyle.step => StepLineSeries<SignalHistoryPoint, DateTime>(
            dataSource: points,
            animationDuration: animationMs,
            color: SignalChartColors.status,
            width: 1.8,
            xValueMapper: (point, _) => point.ts,
            // STATUS: trang thai cuoi bucket (last), thieu thi avg.
            yValueMapper: (point, _) => series.plotValue(point),
            // Moi doan to theo ma trang thai, cung mau voi badge / sparkline.
            pointColorMapper: (point, _) {
              final code = series.plotValue(point);
              return code == null
                  ? SignalChartColors.status
                  : statusCodeColor(code.round());
            },
            emptyPointSettings: gap,
          ),
          ChartStyle.area => AreaSeries<SignalHistoryPoint, DateTime>(
            dataSource: points,
            animationDuration: animationMs,
            gradient: LinearGradient(
              colors: [
                widget.lineColor.withValues(alpha: .38),
                widget.lineColor.withValues(alpha: .03),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderColor: widget.lineColor,
            borderWidth: 1.6,
            borderDrawMode: BorderDrawMode.top,
            xValueMapper: (point, _) => point.ts,
            yValueMapper: (point, _) => series.plotValue(point),
            emptyPointSettings: gap,
          ),
          ChartStyle.lineBand => LineSeries<SignalHistoryPoint, DateTime>(
            dataSource: points,
            animationDuration: animationMs,
            color: widget.lineColor,
            width: 1.6,
            xValueMapper: (point, _) => point.ts,
            yValueMapper: (point, _) => series.plotValue(point),
            emptyPointSettings: gap,
          ),
        },
        if (exceeded.isNotEmpty)
          ScatterSeries<_ExceedMark, DateTime>(
            dataSource: exceeded,
            animationDuration: 0,
            enableTrackball: false,
            color: SignalChartColors.alert,
            pointColorMapper: (mark, _) => thresholdLevelColor(mark.level),
            xValueMapper: (mark, _) => mark.point.ts,
            yValueMapper: (mark, _) => mark.value,
            markerSettings: const MarkerSettings(
              height: 5,
              width: 5,
              shape: DataMarkerType.circle,
              borderWidth: 0,
            ),
          ),
      ],
    );

    // Nguong qua xa dai du lieu: khong keo truc, chi hien nhan o mep.
    return withOffscaleThresholds(chart, axis, unit);
  }

  DateFormat _axisFormat(List<SignalHistoryPoint> points) {
    if (points.length < 2) return DateFormat('HH:mm');

    final span = points.last.ts.difference(points.first.ts);

    return span > const Duration(days: 1)
        ? DateFormat('dd/MM')
        : DateFormat('HH:mm');
  }
}

class _ExceedMark {
  final SignalHistoryPoint point;

  /// Gia tri da vuot nguong (max / min / avg tuy aggregation).
  final double value;
  final int level;

  const _ExceedMark(this.point, this.value, this.level);
}

class _PointTooltip extends StatelessWidget {
  final SignalHistoryPoint point;
  final SignalHistorySeries series;

  const _PointTooltip({required this.point, required this.series});

  @override
  Widget build(BuildContext context) {
    final spec = signalSpecOf(series);
    final isCounter = series.kind == SignalKind.counter;
    final envelope =
        !isCounter &&
        series.aggregation == HistoryAggregation.minAvgMax &&
        point.min != null &&
        point.max != null;

    final rows = ChartHoverStyle.rows(
      kind: hoverKindOf(series.kind),
      value: isCounter ? point.delta : series.plotValue(point),
      unit: spec.resolveUnit(series.unit),
      decimals: spec.decimals,
      min: envelope ? point.min : null,
      max: envelope ? point.max : null,
      samples: series.aggregation == HistoryAggregation.minAvgMax
          ? point.count
          : null,
      isSnapshot: series.aggregation == HistoryAggregation.snapshot,
    );

    final exceeding = series.breachLevel(point, series.chartThresholds);

    return ChartHoverCard(
      title: formatSignalTimestamp(point.ts),
      rows: rows,
      alerts: exceeding != null ? const {0} : const <int>{},
    );
  }
}
