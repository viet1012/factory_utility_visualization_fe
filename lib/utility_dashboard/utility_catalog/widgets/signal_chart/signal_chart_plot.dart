import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../models/signal_history_models.dart';
import 'signal_chart_axis.dart';
import 'signal_chart_format.dart';
import 'signal_chart_gaps.dart';
import 'signal_chart_palette.dart';

/// Bieu do cua MOT signal (mot don vi, mot truc Y).
///
/// - ANALOG: LineSeries theo avg (+ dai min..max khi MIN_AVG_MAX);
/// - STATUS: StepLineSeries theo avg;
/// - COUNTER: ColumnSeries theo delta (delta null -> khong ve bar);
/// - khoang null chi ngat duong + to xam khi dai hon kSignalGapBreakThreshold;
/// - nguong: duong ngang net dut + nhan; diem vuot nguong cham do.
class SignalChartPlot extends StatefulWidget {
  final SignalHistorySeries series;
  final Color lineColor;

  const SignalChartPlot({
    super.key,
    required this.series,
    required this.lineColor,
  });

  @override
  State<SignalChartPlot> createState() => _SignalChartPlotState();
}

class _SignalChartPlotState extends State<SignalChartPlot> {
  late final TooltipBehavior _tooltipBehavior;

  @override
  void initState() {
    super.initState();

    _tooltipBehavior = TooltipBehavior(
      enable: true,
      color: SignalChartColors.card,
      borderColor: SignalChartColors.cardBorder,
      borderWidth: 1,
      elevation: 0,
      canShowMarker: false,
      tooltipPosition: TooltipPosition.auto,
      builder: (data, point, series, pointIndex, seriesIndex) {
        final source = data is _ExceedMark ? data.point : data;

        if (source is! SignalHistoryPoint) return const SizedBox.shrink();

        return _PointTooltip(point: source, series: widget.series);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    final isCounter = series.kind == SignalKind.counter;

    final plot = SignalPlotData.of(series.points, bucket: series.bucket);
    final points = plot.points;

    // Nguong ap dung cho gia tri do (avg), khong ap cho delta cua COUNTER.
    final showThresholds = !isCounter && series.hasThreshold;

    final exceeded = showThresholds
        ? <_ExceedMark>[
            for (final point in points)
              if (series.exceedingValue(point) case final value?)
                _ExceedMark(point, value),
          ]
        : const <_ExceedMark>[];

    final hasBand =
        series.kind == SignalKind.analog &&
        series.aggregation == HistoryAggregation.minAvgMax &&
        points.any((point) => point.min != null && point.max != null);

    final axis = YAxisPlan.fromValues(
      isCounter
          ? series.points.map((point) => point.delta)
          : [
              for (final point in points) ...[
                series.plotValue(point),
                if (hasBand) ...[point.min, point.max],
              ],
            ],
      series: series,
      showThresholds: showThresholds,
      // Bar COUNTER bat dau tu 0, khong dem xuong duoi.
      zeroBaseline: isCounter,
    );

    if (kDebugMode) {
      debugPrint(
        '[SIGNAL CHART] render plc=${series.plc} kind=${series.kind.name} '
        'points=${points.length}/${series.points.length} '
        'gaps=${plot.gaps.length} bucket=${plot.bucket.inMinutes}m '
        'y=[${axis.min}, ${axis.max}]',
      );
    }

    final chart = SfCartesianChart(
      margin: const EdgeInsets.fromLTRB(0, 6, 6, 0),
      plotAreaBorderWidth: 0,
      tooltipBehavior: _tooltipBehavior,
      primaryXAxis: DateTimeAxis(
        minimum: series.points.isEmpty ? null : series.points.first.ts,
        maximum: series.points.isEmpty ? null : series.points.last.ts,
        dateFormat: _axisFormat(series.points),
        edgeLabelPlacement: EdgeLabelPlacement.shift,
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: AxisLine(color: SignalChartColors.axisLine),
        majorTickLines: const MajorTickLines(size: 0),
        labelStyle: const TextStyle(
          color: SignalChartColors.mutedText,
          fontSize: 10.5,
        ),
        plotBands: [
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
        interval: series.kind == SignalKind.status ? 1 : null,
        // Moi so tren truc di qua ham format chung voi bang.
        axisLabelFormatter: signalValueAxisLabel,
        majorGridLines: MajorGridLines(
          width: 1,
          color: SignalChartColors.gridLine,
        ),
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        plotBands: [
          for (final line in axis.visibleThresholds)
            thresholdPlotBand(line, series.unit),
        ],
      ),
      series: <CartesianSeries<dynamic, DateTime>>[
        if (hasBand)
          RangeAreaSeries<SignalHistoryPoint, DateTime>(
            dataSource: points,
            animationDuration: 0,
            enableTooltip: false,
            color: widget.lineColor.withValues(alpha: .14),
            borderWidth: 0,
            xValueMapper: (point, _) => point.ts,
            highValueMapper: (point, _) =>
                point.value == null ? null : point.max,
            lowValueMapper: (point, _) =>
                point.value == null ? null : point.min,
            emptyPointSettings: const EmptyPointSettings(
              mode: EmptyPointMode.gap,
            ),
          ),
        if (isCounter)
          ColumnSeries<SignalHistoryPoint, DateTime>(
            // Dung toan bo bucket: bar chi phu thuoc delta, khong noi duong.
            dataSource: series.points,
            animationDuration: 0,
            color: widget.lineColor,
            width: .7,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            xValueMapper: (point, _) => point.ts,
            yValueMapper: (point, _) => point.delta,
            emptyPointSettings: const EmptyPointSettings(
              mode: EmptyPointMode.gap,
            ),
          )
        else if (series.kind == SignalKind.status)
          StepLineSeries<SignalHistoryPoint, DateTime>(
            dataSource: points,
            animationDuration: 0,
            color: SignalChartColors.status,
            width: 1.8,
            xValueMapper: (point, _) => point.ts,
            // STATUS: trang thai cuoi bucket (last), thieu thi avg.
            yValueMapper: (point, _) => series.plotValue(point),
            emptyPointSettings: const EmptyPointSettings(
              mode: EmptyPointMode.gap,
            ),
          )
        else
          LineSeries<SignalHistoryPoint, DateTime>(
            dataSource: points,
            animationDuration: 0,
            color: widget.lineColor,
            width: 1.6,
            xValueMapper: (point, _) => point.ts,
            yValueMapper: (point, _) => point.value,
            emptyPointSettings: const EmptyPointSettings(
              mode: EmptyPointMode.gap,
            ),
          ),
        if (exceeded.isNotEmpty)
          ScatterSeries<_ExceedMark, DateTime>(
            dataSource: exceeded,
            animationDuration: 0,
            color: SignalChartColors.alert,
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
    return withOffscaleThresholds(chart, axis, series.unit);
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

  const _ExceedMark(this.point, this.value);
}

class _PointTooltip extends StatelessWidget {
  final SignalHistoryPoint point;
  final SignalHistorySeries series;

  const _PointTooltip({required this.point, required this.series});

  @override
  Widget build(BuildContext context) {
    final isCounter = series.kind == SignalKind.counter;
    final isStatus = series.kind == SignalKind.status;
    final primary = isCounter ? point.delta : series.plotValue(point);

    final exceeding = isCounter ? null : series.exceedingValue(point);

    final primaryText = isCounter
        ? 'Δ ${formatSignalValueWithUnit(primary, series.unit)}'
        : isStatus && point.last != null
        ? 'last ${formatSignalValueWithUnit(primary, series.unit)}'
        : formatSignalValueWithUnit(primary, series.unit);

    final hasEnvelope =
        !isCounter &&
        series.aggregation == HistoryAggregation.minAvgMax &&
        point.min != null &&
        point.max != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      constraints: const BoxConstraints(maxWidth: 220),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatSignalTimestamp(point.ts),
            style: const TextStyle(
              color: SignalChartColors.subText,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            primaryText,
            style: TextStyle(
              color: exceeding != null
                  ? SignalChartColors.alert
                  : SignalChartColors.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (hasEnvelope)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'min ${formatSignalValue(point.min)}'
                ' · max ${formatSignalValue(point.max)}',
                style: const TextStyle(
                  color: SignalChartColors.mutedText,
                  fontSize: 10.5,
                ),
              ),
            ),
          if (point.count != null &&
              series.aggregation == HistoryAggregation.minAvgMax)
            Text(
              '${point.count} samples',
              style: const TextStyle(
                color: SignalChartColors.mutedText,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}
