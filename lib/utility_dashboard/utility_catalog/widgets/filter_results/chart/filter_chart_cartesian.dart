import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../catalog_value_format.dart';
import '../../../models/signal_history_models.dart';
import '../../signal_chart/signal_chart_axis.dart';
import '../../signal_chart/signal_chart_gaps.dart';
import '../../signal_chart/signal_chart_palette.dart';
import 'filter_chart_groups.dart';

/// Chart chung cho mot nhom nhieu device:
/// - ANALOG: moi device mot duong avg (ca 24h / 7d, khong dung thanh noi),
///   mot truc Y, duong nguong net dut khi ca nhom cung nguong;
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

  /// Device theo dung thu tu series dang ve (de doi seriesIndex -> device).
  List<FilterChartMember> _drawn = const <FilterChartMember>[];

  @override
  void initState() {
    super.initState();

    _trackball = TrackballBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,
      tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
      lineColor: Colors.white.withValues(alpha: .25),
      lineWidth: 1,
      markerSettings: const TrackballMarkerSettings(
        markerVisibility: TrackballVisibilityMode.visible,
        height: 5,
        width: 5,
        borderWidth: 0,
      ),
      builder: (context, details) => _GroupTooltip(
        details: details,
        members: _drawn,
        group: widget.group,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final isCounter = group.kind == SignalKind.counter;

    _drawn = [
      for (final member in widget.members)
        if (member.series != null) member,
    ];

    // Noi qua lo ngan (chu ky ghi ~65s), chi ngat duong o khoang dai.
    final plotted = <FilterChartMember, List<SignalHistoryPoint>>{
      for (final member in _drawn)
        member: isCounter
            ? member.series!.points
            : SignalPlotData.of(
                member.series!.points,
                bucket: member.series!.bucket,
              ).points,
    };

    final common = group.commonThresholds;
    final showThresholds = !isCounter && common != null;

    final axis = YAxisPlan.fromValues(
      [
        for (final entry in plotted.entries)
          for (final point in entry.value)
            isCounter ? point.delta : entry.key.series!.plotValue(point),
      ],
      series: SignalHistorySeries(
        signalId: group.key,
        plc: '',
        name: group.title,
        code: null,
        unit: group.unit,
        kind: group.kind,
        thresholdLow: common?.low,
        thresholdHigh: common?.high,
        points: const <SignalHistoryPoint>[],
      ),
      showThresholds: showThresholds,
      zeroBaseline: isCounter,
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
        axisLabelFormatter: signalValueAxisLabel,
        title: isCounter
            ? AxisTitle(
                text: group.unit.isEmpty ? 'Δ / bucket' : '${group.unit} / bucket',
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
            thresholdPlotBand(line, group.unit),
        ],
      ),
      series: <CartesianSeries<SignalHistoryPoint, DateTime>>[
        for (final member in _drawn)
          if (isCounter)
            ColumnSeries<SignalHistoryPoint, DateTime>(
              name: member.label,
              dataSource: plotted[member]!,
              animationDuration: 0,
              color: member.color,
              spacing: .1,
              xValueMapper: (point, _) => point.ts,
              yValueMapper: (point, _) => point.delta,
              emptyPointSettings: const EmptyPointSettings(
                mode: EmptyPointMode.gap,
              ),
            )
          else
            LineSeries<SignalHistoryPoint, DateTime>(
              name: member.label,
              dataSource: plotted[member]!,
              animationDuration: 0,
              color: member.overThreshold
                  ? Color.lerp(member.color, SignalChartColors.alert, .35)
                  : member.color,
              width: member.overThreshold ? 2.2 : 1.6,
              dashArray: member.dash,
              xValueMapper: (point, _) => point.ts,
              yValueMapper: (point, _) => member.series!.plotValue(point),
              emptyPointSettings: const EmptyPointSettings(
                mode: EmptyPointMode.gap,
              ),
            ),
      ],
    );

    return withOffscaleThresholds(chart, axis, group.unit);
  }
}

/// Tooltip cua trackball: thoi diem + gia tri moi device trong nhom.
class _GroupTooltip extends StatelessWidget {
  final TrackballDetails details;
  final List<FilterChartMember> members;
  final FilterChartGroup group;

  const _GroupTooltip({
    required this.details,
    required this.members,
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    final info = details.groupingModeInfo;
    if (info == null || info.points.isEmpty) return const SizedBox.shrink();

    final isCounter = group.kind == SignalKind.counter;
    final x = info.points.first.x;
    final time = x is DateTime ? x : null;

    final lines = <Widget>[];

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
          ((member.thresholdHigh != null && value > member.thresholdHigh!) ||
              (member.thresholdLow != null && value < member.thresholdLow!));

      lines.add(
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, color: member.color),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  member.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SignalChartColors.subText,
                    fontSize: 10.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${isCounter ? 'Δ ' : ''}'
                '${formatCatalogValueWithUnit(value, group.unit)}',
                style: TextStyle(
                  color: out ? SignalChartColors.alert : SignalChartColors.text,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: SignalChartColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SignalChartColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (time != null)
            Text(
              DateFormat('dd/MM HH:mm').format(time.toLocal()),
              style: const TextStyle(
                color: SignalChartColors.mutedText,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ...lines,
        ],
      ),
    );
  }
}
