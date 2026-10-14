import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../shared/charts/axis_planner.dart';
import '../../../../shared/charts/chart_animation.dart';
import '../../../../shared/charts/chart_downsample.dart';
import '../../../../shared/charts/chart_hover_style.dart';
import '../../../../shared/charts/chart_thresholds.dart';
import '../../../../shared/charts/signal_chart_spec.dart';
import '../../../../shared/charts/signal_chart_spec_registry.dart';
import '../../../../shared/charts/signal_thresholds.dart';
import '../../../../shared/charts/value_format.dart';
import '../../../models/signal_history_models.dart';
import '../../signal_chart/signal_chart_gaps.dart';
import '../../signal_chart/signal_chart_palette.dart';
import 'filter_chart_groups.dart';

/// Chart chung cho mot nhom nhieu device (cung code + unit), kieu ve / truc /
/// so le theo SignalChartSpec cua nhom:
/// - ANALOG: moi device mot duong avg (area khi spec la area va nhom chi co
///   1 device), mot truc Y,
///   duong nguong net dut khi ca nhom cung nguong;
/// - COUNTER: cot nhom theo delta, bat dau tu 0.
/// Tooltip (trackball) hien gia tri moi device tai cung thoi diem.
class FilterChartCartesian extends StatefulWidget {
  final FilterChartGroup group;

  /// Device dang ve (da bo device bi an qua legend), co series.
  final List<FilterChartMember> members;

  const FilterChartCartesian({
    super.key,
    required this.group,
    required this.members,
  });

  @override
  State<FilterChartCartesian> createState() => _FilterChartCartesianState();
}

class _FilterChartCartesianState extends State<FilterChartCartesian> {
  late final TrackballBehavior _trackball;
  final FirstPaintAnimation _animation = FirstPaintAnimation();

  /// Device theo dung thu tu series dang ve (de doi seriesIndex -> device).
  List<FilterChartMember> _drawn = const <FilterChartMember>[];
  SignalChartSpec _spec = SignalChartSpecRegistry.fallback;

  @override
  void initState() {
    super.initState();

    _trackball = ChartHoverStyle.trackball(
      // Marker lay mau cua tung device.
      markerColor: null,
      displayMode: TrackballDisplayMode.groupAllPoints,
      builder: (context, details) => _GroupTooltip(
        details: details,
        members: _drawn,
        group: widget.group,
        spec: _spec,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final isCounter = group.kind == SignalKind.counter;

    final spec = filterGroupSpecOf(group);
    _spec = spec;

    final unit = spec.resolveUnit(group.unit);

    _drawn = [
      for (final member in widget.members)
        if (member.series != null) member,
    ];

    // Area chong nhau khi >= 2 device: ve line khong to nen (giu mau + kieu
    // net tung device). Nhom 1 device giu area.
    final style = isCounter
        ? ChartStyle.bar
        : spec.style == ChartStyle.area && _drawn.length >= 2
        ? ChartStyle.lineBand
        : spec.style;

    // Noi qua lo ngan (chu ky ghi ~65s), chi ngat duong o khoang dai.
    final plotted = <FilterChartMember, List<SignalHistoryPoint>>{
      for (final member in _drawn)
        member: downsampleMinMax(
          isCounter
              ? member.series!.points
              : SignalPlotData.of(
                  member.series!.points,
                  bucket: member.series!.bucket,
                ).points,
          value: isCounter
              ? (SignalHistoryPoint point) => point.delta
              : member.series!.plotValue,
        ),
    };

    // Nguong `thresholds[]` chung cua nhom (member.thresholds da chi ANALOG,
    // bo trivial); nguong khac nhau giua device thi khong ve.
    final lines = isCounter
        ? const <SignalThreshold>[]
        : group.commonThresholds ?? const <SignalThreshold>[];

    final axis = planAxis(
      values: [
        for (final entry in plotted.entries)
          for (final point in entry.value)
            isCounter ? point.delta : entry.key.series!.plotValue(point),
      ],
      spec: spec,
      thresholds: lines,
    );

    DateTime? first;
    DateTime? last;

    for (final points in plotted.values) {
      if (points.isEmpty) continue;
      if (first == null || points.first.ts.isBefore(first)) {
        first = points.first.ts;
      }
      if (last == null || points.last.ts.isAfter(last)) last = points.last.ts;
    }

    final multiDay =
        first != null &&
        last != null &&
        last.difference(first) > const Duration(days: 1);

    final animationMs = _animation.duration();
    const gap = EmptyPointSettings(mode: EmptyPointMode.gap);

    final chart = SfCartesianChart(
      margin: const EdgeInsets.fromLTRB(0, 6, 8, 0),
      plotAreaBorderWidth: 0,
      trackballBehavior: _trackball,
      primaryXAxis: DateTimeAxis(
        minimum: first,
        maximum: last,
        dateFormat: multiDay ? DateFormat('dd/MM') : DateFormat('HH:mm'),
        edgeLabelPlacement: EdgeLabelPlacement.shift,
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: AxisLine(color: SignalChartColors.axisLine),
        majorTickLines: const MajorTickLines(size: 0),
        labelStyle: const TextStyle(
          color: SignalChartColors.mutedText,
          fontSize: 10.5,
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
        title: isCounter
            ? AxisTitle(
                text: unit.isEmpty ? 'Δ / bucket' : '$unit / bucket',
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
        plotBands: thresholdPlotBands(axis, unit),
      ),
      series: <CartesianSeries<SignalHistoryPoint, DateTime>>[
        for (final member in _drawn)
          switch (style) {
            ChartStyle.bar => ColumnSeries<SignalHistoryPoint, DateTime>(
              name: member.label,
              dataSource: plotted[member]!,
              animationDuration: animationMs,
              color: member.color,
              spacing: .1,
              xValueMapper: (point, _) => point.ts,
              yValueMapper: (point, _) => point.delta,
              emptyPointSettings: gap,
            ),
            ChartStyle.area => AreaSeries<SignalHistoryPoint, DateTime>(
              name: member.label,
              dataSource: plotted[member]!,
              animationDuration: animationMs,
              color: member.color.withValues(alpha: .10),
              borderColor: _lineColor(member),
              borderWidth: member.overThreshold ? 2.2 : 1.6,
              borderDrawMode: BorderDrawMode.top,
              xValueMapper: (point, _) => point.ts,
              yValueMapper: (point, _) => member.series!.plotValue(point),
              emptyPointSettings: gap,
            ),
            ChartStyle.step => StepLineSeries<SignalHistoryPoint, DateTime>(
              name: member.label,
              dataSource: plotted[member]!,
              animationDuration: animationMs,
              color: _lineColor(member),
              width: 1.6,
              dashArray: member.dash,
              xValueMapper: (point, _) => point.ts,
              yValueMapper: (point, _) => member.series!.plotValue(point),
              emptyPointSettings: gap,
            ),
            ChartStyle.lineBand => LineSeries<SignalHistoryPoint, DateTime>(
              name: member.label,
              dataSource: plotted[member]!,
              animationDuration: animationMs,
              color: _lineColor(member),
              width: member.overThreshold ? 2.2 : 1.6,
              dashArray: member.dash,
              xValueMapper: (point, _) => point.ts,
              yValueMapper: (point, _) => member.series!.plotValue(point),
              emptyPointSettings: gap,
            ),
          },
      ],
    );

    return withOffscaleThresholds(chart, axis, unit);
  }

  static Color _lineColor(FilterChartMember member) {
    return member.overThreshold
        ? Color.lerp(member.color, SignalChartColors.alert, .35)!
        : member.color;
  }
}

/// Spec cua mot nhom chart theo code / unit / kind / ten chung.
SignalChartSpec filterGroupSpecOf(FilterChartGroup group) {
  return SignalChartSpecRegistry.resolve(
    code: group.code.isEmpty ? null : group.code,
    unit: group.unit,
    kind: group.kind.name.toUpperCase(),
    name: group.title,
  );
}

/// Tooltip cua trackball: thoi diem + gia tri moi device trong nhom.
class _GroupTooltip extends StatelessWidget {
  final TrackballDetails details;
  final List<FilterChartMember> members;
  final FilterChartGroup group;
  final SignalChartSpec spec;

  const _GroupTooltip({
    required this.details,
    required this.members,
    required this.group,
    required this.spec,
  });

  static final DateFormat _timeFormat = DateFormat('dd/MM HH:mm');

  @override
  Widget build(BuildContext context) {
    final info = details.groupingModeInfo;
    if (info == null || info.points.isEmpty) return const SizedBox.shrink();

    final isCounter = group.kind == SignalKind.counter;
    final unit = spec.resolveUnit(group.unit);
    final x = info.points.first.x;
    final time = x is DateTime ? x : null;

    final rows = <(String, String)>[];
    final swatches = <Color?>[];
    final alerts = <int>{};

    for (var i = 0; i < info.points.length; i++) {
      final seriesIndex = i < info.visibleSeriesIndices.length
          ? info.visibleSeriesIndices[i]
          : i;
      if (seriesIndex < 0 || seriesIndex >= members.length) continue;

      final member = members[seriesIndex];
      final y = info.points[i].y;
      final value = y is num ? y.toDouble() : null;

      final out =
          !isCounter &&
          value != null &&
          thresholdBreachLevel(member.thresholds, value: value) != null;

      if (out) alerts.add(rows.length);
      swatches.add(member.color);
      rows.add((
        member.label,
        '${isCounter ? 'Δ ' : ''}'
            '${formatWithUnit(value, unit, decimals: spec.decimals)}',
      ));
    }

    return ChartHoverCard(
      title: time == null ? '' : _timeFormat.format(time.toLocal()),
      rows: rows,
      swatches: swatches,
      alerts: alerts,
    );
  }
}
