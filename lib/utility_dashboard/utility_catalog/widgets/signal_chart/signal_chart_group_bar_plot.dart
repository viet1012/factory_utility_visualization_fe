import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../shared/charts/axis_planner.dart';
import '../../../shared/charts/chart_animation.dart';
import '../../../shared/charts/chart_hover_style.dart';
import '../../../shared/charts/chart_thresholds.dart';
import '../../../shared/charts/signal_chart_spec.dart';
import '../../../shared/charts/signal_thresholds.dart';
import '../../../shared/charts/value_format.dart';
import '../../models/signal_history_models.dart';
import '../filter_results/chart/filter_chart_groups.dart';
import 'signal_chart_bar_data.dart';
import 'signal_chart_bar_plot.dart' show formatBarDay;
import 'signal_chart_palette.dart';

/// Bieu do cot 24h / 7d cho mot the gop nhieu signal (cung code + unit):
/// - ANALOG: moi signal mot thanh noi min → max canh nhau trong moi gio /
///   ngay, mau theo signal; thanh vuot nguong to mau level;
/// - COUNTER: cot nhom theo tong delta, bat dau tu 0.
/// Nguong chung cua nhom (giong nhau giua cac signal) ve net dut.
class SignalChartGroupBarPlot extends StatefulWidget {
  final FilterChartGroup group;

  /// Signal dang ve (da bo signal bi an qua legend), co series.
  final List<FilterChartMember> members;
  final SignalBarPeriod period;
  final SignalChartSpec spec;

  const SignalChartGroupBarPlot({
    super.key,
    required this.group,
    required this.members,
    required this.period,
    required this.spec,
  });

  @override
  State<SignalChartGroupBarPlot> createState() =>
      _SignalChartGroupBarPlotState();
}

class _SignalChartGroupBarPlotState extends State<SignalChartGroupBarPlot> {
  late final TrackballBehavior _trackball;
  final FirstPaintAnimation _animation = FirstPaintAnimation();

  List<FilterChartMember> _drawn = const <FilterChartMember>[];

  /// Theo signal: category key -> cot.
  List<Map<String, SignalBar>> _barsByMember = const [];

  @override
  void initState() {
    super.initState();

    _trackball = ChartHoverStyle.trackball(
      markerColor: null,
      displayMode: TrackballDisplayMode.groupAllPoints,
      builder: (context, details) => _tooltip(details),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCounter = widget.group.kind == SignalKind.counter;
    final spec = widget.spec;
    final unit = spec.resolveUnit(widget.group.unit);
    final period = widget.period;

    _drawn = [
      for (final member in widget.members)
        if (member.series != null) member,
    ];

    final bars = [
      for (final member in _drawn) buildSignalBars(member.series!, period),
    ];

    _barsByMember = [
      for (final list in bars) {for (final bar in list) _key(bar): bar},
    ];

    // Moc gio / ngay chung cua moi signal, theo thoi gian.
    final starts = <String, DateTime>{
      for (final list in bars)
        for (final bar in list) _key(bar): bar.start,
    };
    final keys = starts.keys.toList()
      ..sort((a, b) => starts[a]!.compareTo(starts[b]!));

    final lines = isCounter
        ? const <SignalThreshold>[]
        : widget.group.commonThresholds ?? const <SignalThreshold>[];

    final axis = planAxis(
      values: [
        for (final list in bars)
          for (final bar in list) ...[
            bar.value,
            if (!isCounter) ...[bar.min, bar.max],
          ],
      ],
      spec: isCounter
          ? spec.copyWith(style: ChartStyle.bar, axis: AxisMode.zeroBased)
          : spec,
      thresholds: lines,
    );

    final animationMs = _animation.duration();
    const gap = EmptyPointSettings(mode: EmptyPointMode.gap);

    final chart = SfCartesianChart(
      margin: const EdgeInsets.fromLTRB(0, 6, 6, 0),
      plotAreaBorderWidth: 0,
      trackballBehavior: _trackball,
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: AxisLine(color: SignalChartColors.axisLine),
        majorTickLines: const MajorTickLines(size: 0),
        labelIntersectAction: AxisLabelIntersectAction.none,
        axisLabelFormatter: (details) => ChartAxisLabel(
          _axisLabel(starts[details.text], period),
          const TextStyle(color: SignalChartColors.mutedText, fontSize: 10.5),
        ),
      ),
      primaryYAxis: NumericAxis(
        minimum: axis.min,
        maximum: axis.max,
        interval: axis.interval,
        axisLabelFormatter: (details) => ChartAxisLabel(
          axis.label(details.value),
          const TextStyle(color: SignalChartColors.mutedText, fontSize: 10.5),
        ),
        majorGridLines: MajorGridLines(
          width: 1,
          color: SignalChartColors.gridLine,
        ),
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        plotBands: thresholdPlotBands(axis, unit),
      ),
      series: <CartesianSeries<String, String>>[
        for (var i = 0; i < _drawn.length; i++)
          if (isCounter)
            ColumnSeries<String, String>(
              name: _drawn[i].label,
              dataSource: keys,
              animationDuration: animationMs,
              color: _drawn[i].color,
              spacing: .1,
              xValueMapper: (key, _) => key,
              yValueMapper: (key, _) => _barsByMember[i][key]?.value,
              emptyPointSettings: gap,
            )
          else
            RangeColumnSeries<String, String>(
              name: _drawn[i].label,
              dataSource: keys,
              animationDuration: animationMs,
              spacing: .15,
              color: _drawn[i].color.withValues(alpha: .7),
              pointColorMapper: (key, _) {
                final bar = _barsByMember[i][key];
                final level = bar == null
                    ? null
                    : barBreachLevel(_drawn[i].thresholds, bar);
                return level == null
                    ? _drawn[i].color.withValues(alpha: .7)
                    : thresholdLevelColor(level).withValues(alpha: .8);
              },
              xValueMapper: (key, _) => key,
              lowValueMapper: (key, _) {
                final bar = _barsByMember[i][key];
                return bar == null || !bar.hasData
                    ? null
                    : (bar.min ?? bar.value);
              },
              highValueMapper: (key, _) {
                final bar = _barsByMember[i][key];
                return bar == null || !bar.hasData
                    ? null
                    : (bar.max ?? bar.value);
              },
              emptyPointSettings: gap,
            ),
      ],
    );

    return withOffscaleThresholds(chart, axis, unit);
  }

  /// Tooltip: moc gio / ngay + gia tri (avg / tong delta) cua moi signal.
  Widget _tooltip(TrackballDetails details) {
    final info = details.groupingModeInfo;
    if (info == null || info.points.isEmpty) return const SizedBox.shrink();

    final key = '${info.points.first.x}';
    final isCounter = widget.group.kind == SignalKind.counter;
    final unit = widget.spec.resolveUnit(widget.group.unit);

    final rows = <(String, String)>[];
    final swatches = <Color?>[];
    final alerts = <int>{};
    DateTime? start;

    for (var i = 0; i < _drawn.length; i++) {
      final bar = _barsByMember[i][key];
      if (bar == null || !bar.hasData) continue;

      start ??= bar.start;

      if (!isCounter && barBreachLevel(_drawn[i].thresholds, bar) != null) {
        alerts.add(rows.length);
      }

      swatches.add(_drawn[i].color);
      rows.add((
        _drawn[i].label,
        isCounter
            ? 'Δ ${formatWithUnit(bar.value, unit, decimals: widget.spec.decimals)}'
            : '${formatWithUnit(bar.value, unit, decimals: widget.spec.decimals)}'
                  '${bar.min != null && bar.max != null ? '  (${formatValue(bar.min, decimals: widget.spec.decimals)} – ${formatValue(bar.max, decimals: widget.spec.decimals)})' : ''}',
      ));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return ChartHoverCard(
      title: _title(start!),
      rows: rows,
      swatches: swatches,
      alerts: alerts,
    );
  }

  String _title(DateTime start) {
    String two(int v) => v.toString().padLeft(2, '0');

    return switch (widget.period) {
      SignalBarPeriod.hour =>
        '${two(start.day)}/${two(start.month)} '
            '${two(start.hour)}:00–${two(start.add(const Duration(hours: 1)).hour)}:00',
      SignalBarPeriod.day => formatBarDay(start),
    };
  }

  static String _key(SignalBar bar) => bar.start.toIso8601String();

  /// 24h: gio 00, 03, 06... 7d: "T2 12/10".
  static String _axisLabel(DateTime? start, SignalBarPeriod period) {
    if (start == null) return '';

    return switch (period) {
      SignalBarPeriod.hour =>
        start.hour % 3 == 0 ? start.hour.toString().padLeft(2, '0') : '',
      SignalBarPeriod.day => formatBarDay(start),
    };
  }
}
