import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../models/signal_history_models.dart';
import 'signal_chart_format.dart';
import 'signal_chart_palette.dart';

/// Phan truc Y + nguong dung chung cho chart line (signal_chart_plot.dart)
/// va chart cot (signal_chart_bar_plot.dart).

class ThresholdLine {
  final double value;
  final bool isHigh;

  const ThresholdLine(this.value, {required this.isHigh});
}

/// Truc Y: bao du lieu; nguong chi duoc keo vao truc khi nam GAN dai du lieu
/// (khoang cach ngoai dai <= [nearFactor] x bien do du lieu). Nguong xa hon
/// khong ve duong, chi hien nhan o mep chart.
class YAxisPlan {
  static const double nearFactor = 2;

  final double? min;
  final double? max;
  final List<ThresholdLine> visibleThresholds;
  final ThresholdLine? offscaleHigh;
  final ThresholdLine? offscaleLow;

  const YAxisPlan({
    this.min,
    this.max,
    this.visibleThresholds = const <ThresholdLine>[],
    this.offscaleHigh,
    this.offscaleLow,
  });

  /// [values]: moi gia tri can nam trong truc (avg, min, max, delta...).
  /// [zeroBaseline]: truc chua 0 va bat dau tu 0 khi du lieu khong am
  /// (cot COUNTER).
  factory YAxisPlan.fromValues(
    Iterable<double?> values, {
    required SignalHistorySeries series,
    required bool showThresholds,
    bool zeroBaseline = false,
  }) {
    double? lo;
    double? hi;

    void include(double? value) {
      if (value == null || !value.isFinite) return;
      if (lo == null || value < lo!) lo = value;
      if (hi == null || value > hi!) hi = value;
    }

    if (zeroBaseline) include(0);
    values.forEach(include);

    final dataLo = lo;
    final dataHi = hi;

    if (dataLo == null || dataHi == null) return const YAxisPlan();

    /*
     * Bien do "gan bang 0" phai xu ly nhu bang 0. Tin hieu dung yen
     * (vd 40.2999) qua bucket 5m/15m co avg lech vai ulp so voi min/max
     * (40.29990000000001), bien do ~1e-14 != 0. Neu dua dai do vao truc,
     * Syncfusion chon interval nho hon buoc lam tron double tai gia tri do,
     * vong `current += visibleInterval` (numeric_axis.dart:583-586) khong
     * bao gio tang -> treo main thread (ket skeleton, khong co loi console).
     */
    final rawSpan = dataHi - dataLo;
    final span = _isFlat(rawSpan, dataLo, dataHi)
        ? _flatSpan(dataLo, dataHi)
        : rawSpan;

    final visible = <ThresholdLine>[];
    ThresholdLine? offHigh;
    ThresholdLine? offLow;

    if (showThresholds) {
      for (final line in [
        if (series.thresholdHigh case final high?)
          ThresholdLine(high, isHigh: true),
        if (series.thresholdLow case final low?)
          ThresholdLine(low, isHigh: false),
      ]) {
        final distance = line.value > dataHi
            ? line.value - dataHi
            : line.value < dataLo
            ? dataLo - line.value
            : 0.0;

        if (distance <= span * nearFactor) {
          visible.add(line);
          include(line.value);
        } else if (line.isHigh) {
          offHigh = line;
        } else {
          offLow = line;
        }
      }
    }

    final axisLo = lo!;
    final axisHi = hi!;

    if (series.kind == SignalKind.status) {
      return YAxisPlan(
        min: axisLo.floorToDouble() - .5,
        max: axisHi.ceilToDouble() + .5,
        visibleThresholds: visible,
        offscaleHigh: offHigh,
        offscaleLow: offLow,
      );
    }

    final axisSpan = axisHi - axisLo;
    final pad = _isFlat(axisSpan, axisLo, axisHi)
        ? _flatSpan(axisLo, axisHi)
        : axisSpan * .12;

    return YAxisPlan(
      min: zeroBaseline && axisLo >= 0 ? 0 : axisLo - pad,
      max: axisHi + pad,
      visibleThresholds: visible,
      offscaleHigh: offHigh,
      offscaleLow: offLow,
    );
  }

  /// Phang khi bien do <= max(1e-9 x |gia tri|, 1e-6): nho hon do phan giai
  /// cua DB (decimal(18,6)) hoac chi la sai so dau phay dong
  /// (ulp cua double ~2.2e-16 lan do lon).
  static bool _isFlat(double span, double lo, double hi) {
    final magnitude = math.max(lo.abs(), hi.abs());

    return span.abs() <= math.max(magnitude * 1e-9, 1e-6);
  }

  /// Bien do gia dinh cho tin hieu phang: 10% gia tri, toi thieu 1.
  static double _flatSpan(double lo, double hi) {
    return math.max(math.max(lo.abs(), hi.abs()) * .1, 1.0);
  }
}

/// Nhan truc Y: moi so di qua ham format chung voi bang.
ChartAxisLabel signalValueAxisLabel(AxisLabelRenderDetails details) {
  return ChartAxisLabel(
    formatSignalValue(details.value.toDouble()),
    const TextStyle(color: SignalChartColors.mutedText, fontSize: 10.5),
  );
}

String thresholdText(ThresholdLine line, String? unit) {
  return '${line.isHigh ? 'High' : 'Low'} '
      '${formatSignalValueWithUnit(line.value, unit)}';
}

/// Duong nguong ngang net dut + nhan.
PlotBand thresholdPlotBand(ThresholdLine line, String? unit) {
  return PlotBand(
    start: line.value,
    end: line.value,
    color: Colors.transparent,
    borderColor: SignalChartColors.thresholdLine,
    borderWidth: 1,
    dashArray: const <double>[4, 3],
    shouldRenderAboveSeries: true,
    text: thresholdText(line, unit),
    textStyle: const TextStyle(
      color: SignalChartColors.thresholdLine,
      fontSize: 9.5,
      fontWeight: FontWeight.w800,
    ),
    horizontalTextAlignment: TextAnchor.end,
    // Nhan High nam tren duong, Low nam duoi duong.
    verticalTextAlignment: line.isHigh ? TextAnchor.end : TextAnchor.start,
  );
}

/// Nguong qua xa dai du lieu: khong keo truc, chi hien nhan o mep chart.
Widget withOffscaleThresholds(Widget chart, YAxisPlan axis, String? unit) {
  if (axis.offscaleHigh == null && axis.offscaleLow == null) {
    return chart;
  }

  return Stack(
    children: [
      Positioned.fill(child: chart),
      if (axis.offscaleHigh case final high?)
        Positioned(
          top: 2,
          right: 8,
          child: _OffscaleLabel(text: '▲ ${thresholdText(high, unit)}'),
        ),
      if (axis.offscaleLow case final low?)
        Positioned(
          bottom: 22,
          right: 8,
          child: _OffscaleLabel(text: '▼ ${thresholdText(low, unit)}'),
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
          color: SignalChartColors.thresholdLine,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
