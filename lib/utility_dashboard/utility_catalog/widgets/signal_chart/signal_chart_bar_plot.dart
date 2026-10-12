import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../models/signal_history_models.dart';
import 'signal_chart_axis.dart';
import 'signal_chart_bar_data.dart';
import 'signal_chart_format.dart';
import 'signal_chart_palette.dart';

/// Bieu do cot cho range 24h (moi gio 1 cot) va 7d (moi ngay 1 cot).
///
/// - ANALOG: thanh noi min → max + cham avg; thanh vuot nguong mau do;
///   duong nguong net dut giong chart line.
/// - COUNTER: cot = tong delta cua gio / ngay, truc ghi "unit/giờ|ngày".
/// - Cot khong co du lieu: de trong, khong to xam.
/// STATUS khong dung widget nay (van ve step chart).
class SignalChartBarPlot extends StatefulWidget {
  final SignalHistorySeries series;
  final SignalBarPeriod period;
  final Color barColor;

  const SignalChartBarPlot({
    super.key,
    required this.series,
    required this.period,
    required this.barColor,
  });

  @override
  State<SignalChartBarPlot> createState() => _SignalChartBarPlotState();
}

class _SignalChartBarPlotState extends State<SignalChartBarPlot> {
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
        if (data is! SignalBar || !data.hasData) {
          return const SizedBox.shrink();
        }

        return _BarTooltip(
          bar: data,
          series: widget.series,
          period: widget.period,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    final period = widget.period;
    final isCounter = series.kind == SignalKind.counter;

    final bars = buildSignalBars(series, period);
    final barsByKey = <String, SignalBar>{
      for (final bar in bars) _categoryKey(bar): bar,
    };

    final showThresholds = !isCounter && series.hasThreshold;

    // Truc Y bam dai du lieu (avg + min / max cua thanh noi) va nguong.
    final axis = YAxisPlan.fromValues(
      [
        for (final bar in bars) ...[
          bar.value,
          if (!isCounter) ...[bar.min, bar.max],
        ],
      ],
      series: series,
      showThresholds: showThresholds,
      zeroBaseline: isCounter,
    );

    if (kDebugMode) {
      debugPrint(
        '[SIGNAL CHART] render bars plc=${series.plc} kind=${series.kind.name} '
        'period=${period.name} bars=${bars.where((b) => b.hasData).length}'
        '/${bars.length} y=[${axis.min}, ${axis.max}]',
      );
    }

    final chart = SfCartesianChart(
      margin: const EdgeInsets.fromLTRB(0, 6, 6, 0),
      plotAreaBorderWidth: 0,
      tooltipBehavior: _tooltipBehavior,
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: AxisLine(color: SignalChartColors.axisLine),
        majorTickLines: const MajorTickLines(size: 0),
        labelIntersectAction: AxisLabelIntersectAction.none,
        axisLabelFormatter: (details) => ChartAxisLabel(
          _axisLabel(barsByKey[details.text], period),
          const TextStyle(color: SignalChartColors.mutedText, fontSize: 10.5),
        ),
      ),
      primaryYAxis: NumericAxis(
        minimum: axis.min,
        maximum: axis.max,
        axisLabelFormatter: signalValueAxisLabel,
        title: isCounter
            ? AxisTitle(
                text: _counterUnit(series.unit, period),
                textStyle: const TextStyle(
                  color: SignalChartColors.mutedText,
                  fontSize: 10,
                ),
              )
            : const AxisTitle(),
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
      series: <CartesianSeries<SignalBar, String>>[
        if (isCounter)
          // COUNTER: cot dac tu 0 = tong delta cua gio / ngay.
          ColumnSeries<SignalBar, String>(
            dataSource: bars,
            animationDuration: 0,
            width: .6,
            color: widget.barColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            xValueMapper: (bar, _) => _categoryKey(bar),
            yValueMapper: (bar, _) => bar.value,
            // Cot khong co du lieu: de trong.
            emptyPointSettings: const EmptyPointSettings(
              mode: EmptyPointMode.gap,
            ),
          )
        else ...[
          /*
           * ANALOG: thanh noi tu min toi max (khong co gia tri 0 gia tao),
           * cham avg o giua. Ca hai la series duy nhat cua loai minh tren
           * truc category nen cung nam o tam o (khong bi chia lan).
           */
          RangeColumnSeries<SignalBar, String>(
            dataSource: bars,
            animationDuration: 0,
            width: .45,
            color: widget.barColor.withValues(alpha: .55),
            borderRadius: const BorderRadius.all(Radius.circular(2)),
            xValueMapper: (bar, _) => _categoryKey(bar),
            lowValueMapper: (bar, _) => bar.hasData ? (bar.min ?? bar.value) : null,
            highValueMapper: (bar, _) =>
                bar.hasData ? (bar.max ?? bar.value) : null,
            pointColorMapper: (bar, _) => barExceedsThreshold(series, bar)
                ? SignalChartColors.alert.withValues(alpha: .75)
                : widget.barColor.withValues(alpha: .55),
            // Gio / ngay khong co du lieu: de trong.
            emptyPointSettings: const EmptyPointSettings(
              mode: EmptyPointMode.gap,
            ),
          ),
          ScatterSeries<SignalBar, String>(
            dataSource: bars,
            animationDuration: 0,
            color: SignalChartColors.avgDot,
            xValueMapper: (bar, _) => _categoryKey(bar),
            yValueMapper: (bar, _) => bar.value,
            markerSettings: const MarkerSettings(
              height: 5,
              width: 5,
              shape: DataMarkerType.circle,
              borderWidth: 0,
            ),
            emptyPointSettings: const EmptyPointSettings(
              mode: EmptyPointMode.gap,
            ),
          ),
        ],
      ],
    );

    return withOffscaleThresholds(chart, axis, series.unit);
  }

  static String _categoryKey(SignalBar bar) => bar.start.toIso8601String();

  /// 24h: gio 00, 03, 06... (cac gio khac de trong). 7d: "T2 12/10".
  static String _axisLabel(SignalBar? bar, SignalBarPeriod period) {
    if (bar == null) return '';

    final start = bar.start;

    return switch (period) {
      SignalBarPeriod.hour => start.hour % 3 == 0 ? _two(start.hour) : '',
      SignalBarPeriod.day => formatBarDay(start),
    };
  }
}

/// "T2 12/10" (thu viet tat tieng Viet + ngay/thang).
String formatBarDay(DateTime day) {
  const weekdays = <int, String>{
    DateTime.monday: 'T2',
    DateTime.tuesday: 'T3',
    DateTime.wednesday: 'T4',
    DateTime.thursday: 'T5',
    DateTime.friday: 'T6',
    DateTime.saturday: 'T7',
    DateTime.sunday: 'CN',
  };

  return '${weekdays[day.weekday]} ${_two(day.day)}/${_two(day.month)}';
}

String _counterUnit(String? unit, SignalBarPeriod period) {
  final base = (unit?.trim().isNotEmpty ?? false) ? unit!.trim() : 'Δ';
  return '$base/${period == SignalBarPeriod.hour ? 'giờ' : 'ngày'}';
}

String _two(int value) => value.toString().padLeft(2, '0');

class _BarTooltip extends StatelessWidget {
  final SignalBar bar;
  final SignalHistorySeries series;
  final SignalBarPeriod period;

  const _BarTooltip({
    required this.bar,
    required this.series,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    final isCounter = series.kind == SignalKind.counter;
    final exceeds = barExceedsThreshold(series, bar);

    final until = bar.until;

    final title = switch (period) {
      SignalBarPeriod.hour =>
        '${_two(bar.start.day)}/${_two(bar.start.month)} '
            '${_two(bar.start.hour)}:00–${_two(bar.end.hour)}:00',
      SignalBarPeriod.day => formatBarDay(bar.start),
    };

    final primary = isCounter
        ? '${formatSignalValue(bar.value)} ${_counterUnit(series.unit, period)}'
        : 'avg ${formatSignalValueWithUnit(bar.value, series.unit)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      constraints: const BoxConstraints(maxWidth: 230),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            until == null
                ? title
                : '$title (đến ${_two(until.hour)}:${_two(until.minute)})',
            style: const TextStyle(
              color: SignalChartColors.subText,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            primary,
            style: TextStyle(
              color: exceeds ? SignalChartColors.alert : SignalChartColors.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (!isCounter && bar.min != null && bar.max != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'min–max ${formatSignalValue(bar.min)} – '
                '${formatSignalValueWithUnit(bar.max, series.unit)}',
                style: const TextStyle(
                  color: SignalChartColors.mutedText,
                  fontSize: 10.5,
                ),
              ),
            ),
          Text(
            '${bar.count} samples',
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
