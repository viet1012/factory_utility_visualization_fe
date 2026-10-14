import 'dart:math' as math;

import 'chart_config.dart';
import 'signal_chart_spec.dart';
import 'signal_thresholds.dart';
import 'value_format.dart';

class AxisThreshold {
  final double value;
  final bool isHigh;

  /// Level 1..3 tu `thresholds[]` (null = nguong don cu, mau mac dinh).
  final int? level;
  final String? label;

  const AxisThreshold({
    required this.value,
    required this.isHigh,
    this.level,
    this.label,
  });

  AxisThreshold.of(SignalThreshold line)
    : value = line.value,
      isHigh = line.isHigh,
      level = line.level,
      label = line.label;
}

/// Truc Y da tinh san: min / max / interval luon ro rang khi co du lieu, de
/// Syncfusion khong tu chon interval (xem [axisIsFlat]).
class AxisPlan {
  final double? min;
  final double? max;
  final double? interval;
  final int decimals;

  /// Nguong se ve (da loc nguong tam thuong / qua xa du lieu).
  final List<AxisThreshold> thresholds;

  /// Nguong khong nam trong truc (xa du lieu, xem [thresholdNearData], hoac
  /// ngoai khung co dinh): khong keo truc, hien nhan ▲ / ▼ o mep chart
  /// (xem chart_thresholds.dart).
  final List<AxisThreshold> offscale;

  const AxisPlan({
    this.min,
    this.max,
    this.interval,
    required this.decimals,
    this.thresholds = const [],
    this.offscale = const [],
  });

  AxisPlan _withOffscale(List<AxisThreshold> lines) {
    if (lines.isEmpty) return this;
    return AxisPlan(
      min: min,
      max: max,
      interval: interval,
      decimals: decimals,
      thresholds: thresholds,
      offscale: List.unmodifiable(lines),
    );
  }

  String label(num value) => formatValue(value, decimals: decimals);
}

/// So nhan toi da tren truc Y (gom ca hai dau).
const int _maxLabels = 6;

const List<double> _niceMantissas = [1, 2, 2.5, 5];

/// Tinh truc Y tu [values] (gia tri + min/max cua dai neu co) va [spec].
///
/// [thresholdLow] / [thresholdHigh]: truyen null khi signal khong ap nguong.
/// [thresholds]: nguong da loc (trivial = false) tu `thresholds[]` cua
/// backend; khac null thi thay cho [thresholdLow] / [thresholdHigh] va ve
/// bat ke [SignalChartSpec.showThreshold].
AxisPlan planAxis({
  required Iterable<double?> values,
  required SignalChartSpec spec,
  double? thresholdLow,
  double? thresholdHigh,
  List<SignalThreshold>? thresholds,
}) {
  final offscale = <AxisThreshold>[];
  final lines = thresholds != null
      ? [for (final line in thresholds) AxisThreshold.of(line)]
      : spec.showThreshold
      ? [
          if (thresholdHigh != null)
            AxisThreshold(value: thresholdHigh, isHigh: true),
          if (thresholdLow != null)
            AxisThreshold(value: thresholdLow, isHigh: false),
        ]
      : const <AxisThreshold>[];

  return _planAxis(
    values,
    spec,
    lines,
    offscale,
    hideTrivialLow: thresholds == null && spec.hideTrivialLowerThreshold,
  )._withOffscale(offscale);
}

AxisPlan _planAxis(
  Iterable<double?> values,
  SignalChartSpec spec,
  List<AxisThreshold> lines,
  List<AxisThreshold> offscale, {
  required bool hideTrivialLow,
}) {
  double? lo;
  double? hi;

  for (final value in values) {
    if (value == null || !value.isFinite) continue;
    if (lo == null || value < lo) lo = value;
    if (hi == null || value > hi) hi = value;
  }

  if (lo == null || hi == null) {
    if (spec.axis == AxisMode.fixed &&
        spec.fixedMin != null &&
        spec.fixedMax != null) {
      return _nicePlan(spec.fixedMin!, spec.fixedMax!, spec, const []);
    }
    return AxisPlan(decimals: spec.decimals);
  }

  // STATUS: moi ma mot nac, nua nac dem hai dau.
  if (spec.style == ChartStyle.step) {
    return AxisPlan(
      min: lo.floorToDouble() - .5,
      max: hi.ceilToDouble() + .5,
      interval: 1,
      decimals: 0,
    );
  }

  final nonNegative = lo >= 0;

  // Nguong chi keo vao truc khi gan du lieu (xem [ChartConfig]); nguong
  // khong vao truc luon vao [offscale] de hien nhan o mep.
  final thresholds = <AxisThreshold>[];

  for (final line in lines) {
    if (!line.value.isFinite) continue;

    final trivial =
        !line.isHigh && hideTrivialLow && line.value == 0 && nonNegative;
    if (trivial) continue;

    if (spec.axis == AxisMode.fixed) {
      final inFixed =
          (spec.fixedMin == null || line.value >= spec.fixedMin!) &&
          (spec.fixedMax == null || line.value <= spec.fixedMax!);
      (inFixed ? thresholds : offscale).add(line);
      continue;
    }

    if (thresholdNearData(line.value, lo, hi)) {
      thresholds.add(line);
    } else {
      offscale.add(line);
    }
  }

  var axisLo = lo;
  var axisHi = hi;
  for (final line in thresholds) {
    axisLo = math.min(axisLo, line.value);
    axisHi = math.max(axisHi, line.value);
  }

  switch (spec.axis) {
    case AxisMode.fixed:
      // Du lieu vuot khung co dinh thi noi khung, khong cat mat diem.
      axisLo = math.min(spec.fixedMin ?? axisLo, axisLo);
      axisHi = math.max(spec.fixedMax ?? axisHi, axisHi);
      if (axisIsFlat(axisLo, axisHi)) {
        final flat = _flatSpan(axisLo, axisHi);
        axisLo -= flat;
        axisHi += flat;
      }
      return _nicePlan(axisLo, axisHi, spec, thresholds);

    case AxisMode.zeroBased:
      final floorAtZero = axisLo >= 0;
      if (floorAtZero) axisLo = 0;
      final flat = axisIsFlat(axisLo, axisHi);
      final span = flat ? _flatSpan(axisLo, axisHi) : axisHi - axisLo;
      // Phang (toan 0): mo truc len them mot bien do gia dinh.
      axisHi += flat ? span : span * .1;
      if (!floorAtZero) axisLo -= span * .1;
      return _nicePlan(
        axisLo,
        axisHi,
        spec,
        thresholds,
        floorAtZero: floorAtZero,
      );

    case AxisMode.fitData:
      final pad = axisIsFlat(axisLo, axisHi)
          ? _flatSpan(axisLo, axisHi)
          : (axisHi - axisLo) * .1;
      final floorAtZero = axisLo >= 0;
      axisLo -= pad;
      axisHi += pad;
      if (floorAtZero && axisLo < 0) axisLo = 0;
      return _nicePlan(
        axisLo,
        axisHi,
        spec,
        thresholds,
        floorAtZero: floorAtZero,
      );
  }
}

/// Nguong [value] du gan dai du lieu [lo]–[hi] de keo truc chua no:
/// |value − gia tri gan nhat| <= [ChartConfig.thresholdAxisPullRatio] ×
/// max(|gia tri gan nhat|, 1). Nguong nam trong dai luon dat.
bool thresholdNearData(double value, double lo, double hi) {
  final nearest = value > hi
      ? hi
      : value < lo
      ? lo
      : value;

  return (value - nearest).abs() <=
      ChartConfig.thresholdAxisPullRatio * math.max(nearest.abs(), 1.0);
}

/// Phang khi bien do <= max(1e-9 x |gia tri|, 1e-6).
///
/// Bien do ~1e-14 do sai so double neu dua vao truc se lam Syncfusion chon
/// interval nho hon buoc lam tron double -> vong lap label khong tang ->
/// treo main thread. Cung quy tac voi YAxisPlan._isFlat ben utility_catalog.
bool axisIsFlat(double lo, double hi) {
  final magnitude = math.max(lo.abs(), hi.abs());
  return (hi - lo).abs() <= math.max(magnitude * 1e-9, 1e-6);
}

/// Bien do gia dinh cho tin hieu phang: 10% gia tri, toi thieu 1.
double _flatSpan(double lo, double hi) {
  return math.max(math.max(lo.abs(), hi.abs()) * .1, 1.0);
}

/// Lam tron [lo]–[hi] ra boi so cua interval "dep" (1 / 2 / 2.5 / 5 x 10^n)
/// nho nhat cho toi da [_maxLabels] nhan. Interval khong min hon so le cua
/// spec de nhan khong bi trung khi format.
AxisPlan _nicePlan(
  double lo,
  double hi,
  SignalChartSpec spec,
  List<AxisThreshold> thresholds, {
  bool floorAtZero = false,
}) {
  final span = hi - lo;
  final minStep = math.pow(10, -spec.decimals).toDouble();

  var exponent = (math.log(span / (_maxLabels - 1)) / math.ln10).floor() - 1;
  if (math.pow(10, exponent) * 10 < minStep) {
    exponent = (math.log(minStep) / math.ln10).floor() - 1;
  }

  for (var guard = 0; guard < 40; guard++, exponent++) {
    final magnitude = math.pow(10, exponent).toDouble();

    for (final mantissa in _niceMantissas) {
      final step = _clean(mantissa * magnitude);
      if (step < minStep - minStep * 1e-9) continue;
      if (!_isMultipleOf(step, minStep)) continue;

      var min = _clean((lo / step).floor() * step);
      final max = _clean((hi / step).ceil() * step);
      if (floorAtZero && min < 0) min = 0;

      final labels = ((max - min) / step).round() + 1;
      if (labels <= _maxLabels && max > min) {
        return AxisPlan(
          min: min,
          max: max,
          interval: step,
          decimals: spec.decimals,
          thresholds: thresholds,
        );
      }
    }
  }

  // Khong xay ra voi span huu han; van tra truc hop le.
  return AxisPlan(
    min: lo,
    max: hi,
    decimals: spec.decimals,
    thresholds: thresholds,
  );
}

bool _isMultipleOf(double value, double unit) {
  final ratio = value / unit;
  return (ratio - ratio.roundToDouble()).abs() < 1e-6;
}

/// Bo sai so double: 0.30000000000000004 -> 0.3.
double _clean(double value) => double.parse(value.toStringAsPrecision(12));
