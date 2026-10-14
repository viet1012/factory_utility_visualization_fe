import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'axis_planner.dart';
import 'chart_config.dart';
import 'signal_thresholds.dart';
import 'value_format.dart';

/// Mau duong / nhan nguong khong co level (nguong don cu).
const Color kThresholdColor = Color(0xFFFCA5A5);

/// Mau cua [line]: theo level (3 do, 2 cam, 1 vang), khong level thi mac dinh.
Color thresholdColor(AxisThreshold line) {
  final level = line.level;
  return level == null ? kThresholdColor : thresholdLevelColor(level);
}

/// "High 30 °C" / "Low 0.85"; co level: "High L2 30 °C"; backend co label
/// thi dung label kem gia tri.
String thresholdText(AxisThreshold line, String? unit, int decimals) {
  final value = formatWithUnit(line.value, unit, decimals: decimals);

  final label = line.label;
  if (label != null) return '$label $value';

  final side = line.isHigh ? 'High' : 'Low';
  final level = line.level;

  return level == null ? '$side $value' : '$side L$level $value';
}

/// Duong nguong ngang net dut + nhan (High nam tren duong, Low nam duoi).
PlotBand thresholdPlotBand(AxisThreshold line, String? unit, int decimals) {
  final color = thresholdColor(line);

  return PlotBand(
    start: line.value,
    end: line.value,
    color: Colors.transparent,
    borderColor: color,
    borderWidth: 1,
    dashArray: const <double>[4, 3],
    shouldRenderAboveSeries: true,
    text: thresholdText(line, unit, decimals),
    textStyle: TextStyle(
      color: color,
      fontSize: 9.5,
      fontWeight: FontWeight.w800,
    ),
    horizontalTextAlignment: TextAnchor.end,
    verticalTextAlignment: line.isHigh ? TextAnchor.end : TextAnchor.start,
  );
}

/// Cac PlotBand nguong cua [axis].
List<PlotBand> thresholdPlotBands(AxisPlan axis, String? unit) {
  return [
    for (final line in axis.thresholds)
      thresholdPlotBand(line, unit, axis.decimals),
  ];
}

/// Nguong khong nam trong truc ([AxisPlan.offscale]): luon hien nhan
/// "▲ High 60 °C" o mep tren / "▼ Low 198 V" o mep duoi, mau theo level
/// (nhieu nguong cung phia xep chong).
Widget withOffscaleThresholds(Widget chart, AxisPlan axis, String? unit) {
  if (axis.offscale.isEmpty) return chart;

  // Tren xuong duoi: High cao nhat truoc; Low gan du lieu truoc.
  final high = [
    for (final line in axis.offscale)
      if (line.isHigh) line,
  ]..sort((a, b) => b.value.compareTo(a.value));
  final low = [
    for (final line in axis.offscale)
      if (!line.isHigh) line,
  ]..sort((a, b) => b.value.compareTo(a.value));

  Widget labels(List<AxisThreshold> lines, String arrow) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final line in lines)
          _OffscaleLabel(
            text:
                '$arrow ${line.isHigh ? 'High' : 'Low'} '
                '${formatWithUnit(line.value, unit, decimals: axis.decimals)}',
            color: thresholdColor(line),
          ),
      ],
    );
  }

  // Chart la con khong dinh vi: Stack lay dung kich thuoc cua chart, nhan
  // luon nam trong khung chart (ke ca khi cha khong ep kich thuoc chat).
  return Stack(
    fit: StackFit.passthrough,
    children: [
      chart,
      if (high.isNotEmpty)
        Positioned(top: 2, right: 8, child: labels(high, '▲')),
      if (low.isNotEmpty)
        Positioned(bottom: 22, right: 8, child: labels(low, '▼')),
    ],
  );
}

/// Nhan nen toi: doc duoc ca khi de len duong / luoi cua chart.
class _OffscaleLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _OffscaleLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1728).withValues(alpha: .82),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: .45)),
        ),
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(
            color: color,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// THRESHOLD CHIP
// ============================================================

/// Nguong can hien tren the tom tat cho gia tri hien tai [value].
///
/// Dang vuot nguong nao thi lay nguong vuot co level cao nhat; khong vuot
/// thi lay nguong gan [value] nhat. Null khi khong co nguong.
({SignalThreshold line, double gap, bool breached})? nearestThreshold(
  List<SignalThreshold> thresholds,
  double value,
) {
  SignalThreshold? breached;
  SignalThreshold? nearest;

  for (final line in thresholds) {
    if (!line.value.isFinite) continue;

    final isBreached = line.isHigh ? value > line.value : value < line.value;

    if (isBreached) {
      if (breached == null || line.level > breached.level) breached = line;
      continue;
    }

    if (nearest == null ||
        (line.value - value).abs() < (nearest.value - value).abs()) {
      nearest = line;
    }
  }

  final line = breached ?? nearest;
  if (line == null) return null;

  return (
    line: line,
    gap: (line.value - value).abs(),
    breached: breached != null,
  );
}

/// Chip "High 60 °C · còn 29.8" canh gia tri hien tai (chi ANALOG).
///
/// Xam: binh thuong; cam: con cach nguong < [ChartConfig.thresholdNearRatio]
/// × max(|gia tri|, 1); do: dang vuot ("vượt").
class ThresholdChip extends StatelessWidget {
  final List<SignalThreshold> thresholds;
  final double? value;
  final String? unit;
  final int decimals;

  const ThresholdChip({
    super.key,
    required this.thresholds,
    required this.value,
    required this.unit,
    required this.decimals,
  });

  static const Color _normalColor = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final current = value;
    if (current == null || !current.isFinite) return const SizedBox.shrink();

    final match = nearestThreshold(thresholds, current);
    if (match == null) return const SizedBox.shrink();

    final line = match.line;
    final near =
        match.gap < ChartConfig.thresholdNearRatio * math.max(current.abs(), 1);

    final color = match.breached
        ? kThresholdLevel3Color
        : near
        ? kThresholdLevel2Color
        : _normalColor;

    final side = line.isHigh ? 'High' : 'Low';
    final text =
        '$side ${formatWithUnit(line.value, unit, decimals: decimals)} · '
        '${match.breached ? 'vượt' : 'còn'} '
        '${formatValue(match.gap, decimals: decimals)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .38)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
