import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'axis_planner.dart';
import 'value_format.dart';

/// Mau duong / nhan nguong dung chung moi chart.
const Color kThresholdColor = Color(0xFFFCA5A5);

/// "High 30 °C" / "Low 0.85".
String thresholdText(AxisThreshold line, String? unit, int decimals) {
  return '${line.isHigh ? 'High' : 'Low'} '
      '${formatWithUnit(line.value, unit, decimals: decimals)}';
}

/// Duong nguong ngang net dut + nhan (High nam tren duong, Low nam duoi).
PlotBand thresholdPlotBand(AxisThreshold line, String? unit, int decimals) {
  return PlotBand(
    start: line.value,
    end: line.value,
    color: Colors.transparent,
    borderColor: kThresholdColor,
    borderWidth: 1,
    dashArray: const <double>[4, 3],
    shouldRenderAboveSeries: true,
    text: thresholdText(line, unit, decimals),
    textStyle: const TextStyle(
      color: kThresholdColor,
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

/// Nguong qua xa dai du lieu ([AxisPlan.offscale]): khong keo truc, chi hien
/// nhan ▲ / ▼ o mep chart.
Widget withOffscaleThresholds(Widget chart, AxisPlan axis, String? unit) {
  if (axis.offscale.isEmpty) return chart;

  AxisThreshold? high;
  AxisThreshold? low;
  for (final line in axis.offscale) {
    if (line.isHigh) {
      high = line;
    } else {
      low = line;
    }
  }

  return Stack(
    children: [
      Positioned.fill(child: chart),
      if (high != null)
        Positioned(
          top: 2,
          right: 8,
          child: _OffscaleLabel(
            text: '▲ ${thresholdText(high, unit, axis.decimals)}',
          ),
        ),
      if (low != null)
        Positioned(
          bottom: 22,
          right: 8,
          child: _OffscaleLabel(
            text: '▼ ${thresholdText(low, unit, axis.decimals)}',
          ),
        ),
    ],
  );
}

class _OffscaleLabel extends StatelessWidget {
  final String text;

  const _OffscaleLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Text(
        text,
        style: const TextStyle(
          color: kThresholdColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
