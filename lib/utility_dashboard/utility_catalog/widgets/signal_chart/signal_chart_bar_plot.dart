import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../shared/charts/axis_planner.dart';
import '../../../shared/charts/chart_animation.dart';
import '../../../shared/charts/chart_hover_style.dart';
import '../../../shared/charts/chart_thresholds.dart';
import '../../../shared/charts/signal_chart_spec.dart';
import '../../../shared/charts/signal_thresholds.dart';
import '../../models/signal_history_models.dart';
import 'signal_chart_bar_data.dart';
import 'signal_chart_format.dart';
import 'signal_chart_palette.dart';

/// Bieu do cot cho range 24h (moi gio 1 cot) va 7d (moi ngay 1 cot).
///
/// - ANALOG: thanh noi min → max + cham avg; thanh vuot nguong mau level;
///   duong nguong (`thresholds[]`) net dut giong chart line.
/// - COUNTER: cot = tong delta cua gio / ngay, truc ghi "unit/giờ|ngày".
/// - Cot khong co du lieu: de trong, khong to xam.
/// STATUS khong dung widget nay (van ve step chart).
class SignalChartBarPlot extends StatefulWidget {
  final SignalHistorySeries series;
  final SignalBarPeriod period;
  final Color barColor;

  /// The gon (Split): khong nhan truc / tieu de truc, khong chu tren duong
  /// nguong; tooltip van day du.
  final bool compact;

  const SignalChartBarPlot({
    super.key,
    required this.series,
    required this.period,
    required this.barColor,
    this.compact = false,
  });

  @override
  State<SignalChartBarPlot> createState() => _SignalChartBarPlotState();
}

class _SignalChartBarPlotState extends State<SignalChartBarPlot> {
  late final TrackballBehavior _trackball;
  final FirstPaintAnimation _animation = FirstPaintAnimation();

  /// Cot theo category key de trackball tra lai cot tu x.
  Map<String, SignalBar> _barsByKey = const {};

  @override
  void initState() {
    super.initState();

    _trackball = ChartHoverStyle.trackball(
      markerColor: widget.barColor,
      builder: (context, details) {
        final bar = _barsByKey['${details.point?.x}'];
        if (bar == null || !bar.hasData) return const SizedBox.shrink();

        return _BarTooltip(
          bar: bar,
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

    final spec = signalSpecOf(series);
    final unit = spec.resolveUnit(series.unit);

    final bars = buildSignalBars(series, period);
    final barsByKey = <String, SignalBar>{
      for (final bar in bars) _categoryKey(bar): bar,
    };
    _barsByKey = barsByKey;

    // Nguong `thresholds[]` chi ap cho ANALOG (rong voi COUNTER / STATUS).
    final lines = isCounter
        ? const <SignalThreshold>[]
        : series.chartThresholds;

    Color barColor(SignalBar bar) {
      final level = barBreachLevel(lines, bar);
      return level == null
          ? widget.barColor.withValues(alpha: .55)
          : thresholdLevelColor(level).withValues(alpha: .75);
    }

    // Truc Y bam dai du lieu (avg + min / max cua thanh noi) va nguong.
    // Cot COUNTER luon bat dau tu 0.
    final axis = planAxis(
      values: [
        for (final bar in bars) ...[
          bar.value,
          if (!isCounter) ...[bar.min, bar.max],
        ],
      ],
      spec: isCounter && spec.axis != AxisMode.zeroBased
          ? SignalChartSpec(
              style: ChartStyle.bar,
              axis: AxisMode.zeroBased,
              decimals: spec.decimals,
              showThreshold: false,
            )
          : spec,
      thresholds: lines,
    );

    final animationMs = _animation.duration();
    final compact = widget.compact;

    final chart = SfCartesianChart(
      margin: compact
          ? const EdgeInsets.fromLTRB(0, 4, 0, 0)
          : const EdgeInsets.fromLTRB(0, 6, 6, 0),
      plotAreaBorderWidth: 0,
      trackballBehavior: _trackball,
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: AxisLine(color: SignalChartColors.axisLine),
        majorTickLines: const MajorTickLines(size: 0),
        labelIntersectAction: AxisLabelIntersectAction.none,
        labelStyle: compact ? kCompactAxisLabelStyle : null,
        axisLabelFormatter: compact
            ? compactAxisLabel
            : (details) => ChartAxisLabel(
                _axisLabel(barsByKey[details.text], period),
                const TextStyle(
                  color: SignalChartColors.mutedText,
                  fontSize: 10.5,
                ),
              ),
      ),
      primaryYAxis: NumericAxis(
        minimum: axis.min,
        maximum: axis.max,
        interval: axis.interval,
        labelStyle: compact ? kCompactAxisLabelStyle : null,
        axisLabelFormatter: compact
            ? compactAxisLabel
            : (details) => ChartAxisLabel(
                axis.label(details.value),
                const TextStyle(
                  color: SignalChartColors.mutedText,
                  fontSize: 10.5,
                ),
              ),
        title: isCounter && !compact
            ? AxisTitle(
                text: _counterUnit(unit, period),
                textStyle: const TextStyle(
                  color: SignalChartColors.mutedText,
                  fontSize: 10,
                ),
              )
            : const AxisTitle(),
        majorGridLines: MajorGridLines(
          width: compact ? .6 : 1,
          color: SignalChartColors.gridLine,
        ),
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        plotBands: thresholdPlotBands(axis, unit, showText: !compact),
      ),
      series: <CartesianSeries<SignalBar, String>>[
        if (isCounter)
          // COUNTER: cot dac tu 0 = tong delta cua gio / ngay.
          ColumnSeries<SignalBar, String>(
            dataSource: bars,
            animationDuration: animationMs,
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
            animationDuration: animationMs,
            width: .45,
            color: widget.barColor.withValues(alpha: .55),
            borderRadius: const BorderRadius.all(Radius.circular(2)),
            xValueMapper: (bar, _) => _categoryKey(bar),
            lowValueMapper: (bar, _) =>
                bar.hasData ? (bar.min ?? bar.value) : null,
            highValueMapper: (bar, _) =>
                bar.hasData ? (bar.max ?? bar.value) : null,
            pointColorMapper: (bar, _) => barColor(bar),
            // Gio / ngay khong co du lieu: de trong.
            emptyPointSettings: const EmptyPointSettings(
              mode: EmptyPointMode.gap,
            ),
          ),
          ScatterSeries<SignalBar, String>(
            dataSource: bars,
            animationDuration: animationMs,
            // Cham avg nam cung o voi thanh noi: trackball chi bam thanh noi.
            enableTrackball: false,
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

    return withOffscaleThresholds(chart, axis, unit);
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
    final spec = signalSpecOf(series);
    final isCounter = series.kind == SignalKind.counter;
    final unit = spec.resolveUnit(series.unit);

    final until = bar.until;

    final title = switch (period) {
      SignalBarPeriod.hour =>
        '${_two(bar.start.day)}/${_two(bar.start.month)} '
            '${_two(bar.start.hour)}:00–${_two(bar.end.hour)}:00',
      SignalBarPeriod.day => formatBarDay(bar.start),
    };

    final rows = ChartHoverStyle.rows(
      kind: isCounter ? HoverKind.counter : HoverKind.analog,
      value: bar.value,
      unit: isCounter ? _counterUnit(unit, period) : unit,
      decimals: spec.decimals,
      min: isCounter ? null : bar.min,
      max: isCounter ? null : bar.max,
      samples: isCounter ? null : bar.count,
    );

    return ChartHoverCard(
      title: until == null
          ? title
          : '$title (đến ${_two(until.hour)}:${_two(until.minute)})',
      rows: rows,
      alerts: barBreachLevel(series.chartThresholds, bar) != null
          ? const {0}
          : const <int>{},
    );
  }
}
