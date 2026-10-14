/// Nguong cua signal theo `thresholds[]` cua /series/history.
library;

import 'package:flutter/material.dart';

/// Mot duong nguong (mot phia LOW hoac HIGH) da tach tu `thresholds[]`.
///
/// Moi rule cua backend co dang
/// ```text
/// { level: 1|2|3, low, high, ruleName, description, trivial }
/// ```
/// va duoc tach thanh toi da hai [SignalThreshold] (low / high khac null).
class SignalThreshold {
  final double value;
  final bool isHigh;

  /// 1 = vang, 2 = cam, 3 = do (xem [thresholdLevelColor]).
  final int level;

  /// Backend danh dau nguong tam thuong (vd Low = 0): khong ve.
  final bool trivial;

  /// Nhan rieng cho duong nguong (null = "High L3 60 °C").
  final String? label;

  final String? ruleName;
  final String? description;

  const SignalThreshold({
    required this.value,
    required this.isHigh,
    required this.level,
    this.trivial = false,
    this.label,
    this.ruleName,
    this.description,
  });

  @override
  String toString() =>
      'SignalThreshold(${isHigh ? 'HIGH' : 'LOW'} $value L$level'
      '${trivial ? ' trivial' : ''})';

  /// Cac duong nguong cua mot rule; rong khi rule khong co low / high hop
  /// le. Van nhan dang cu `{ type, value }`.
  static List<SignalThreshold> parseRule(Map<String, dynamic> json) {
    final level = _readLevel(json['level']) ?? 3;
    final rawTrivial = json['trivial'];
    final trivial =
        rawTrivial == true || '$rawTrivial'.trim().toLowerCase() == 'true';
    final ruleName = _readText(json['ruleName']);
    final description = _readText(json['description']);
    final label = _readText(json['label']);

    SignalThreshold line(double value, bool isHigh) => SignalThreshold(
      value: value,
      isHigh: isHigh,
      level: level,
      trivial: trivial,
      label: label,
      ruleName: ruleName,
      description: description,
    );

    final type = _readText(json['type'])?.toUpperCase();
    final legacyValue = _readNumber(json['value']);
    if ((type == 'HIGH' || type == 'LOW') && legacyValue != null) {
      return [line(legacyValue, type == 'HIGH')];
    }

    final low = _readNumber(json['low']);
    final high = _readNumber(json['high']);

    return [
      if (high != null) line(high, true),
      if (low != null) line(low, false),
    ];
  }
}

/// Nguong cua mot signal, MOT cho dung chung cho Minutes / Hourly / Daily va
/// SCADA TABLE (qua SeriesHistorySignalDto).
///
/// [raw] = `thresholds[]` cua backend. Rong / null / khong rule nao hop le
/// ma co [low] / [high]: dung mot rule tu chung (level = [alertLevel],
/// mac dinh 3; trivial = false).
List<SignalThreshold> resolveSignalThresholds(
  dynamic raw, {
  required double? low,
  required double? high,
  required Object? alertLevel,
}) {
  final parsed = <SignalThreshold>[
    if (raw is List)
      for (final item in raw.whereType<Map>())
        ...SignalThreshold.parseRule(Map<String, dynamic>.from(item)),
  ];

  if (parsed.isNotEmpty) return List<SignalThreshold>.unmodifiable(parsed);

  final level = _readLevel(alertLevel) ?? 3;

  return List<SignalThreshold>.unmodifiable([
    if (high != null && high.isFinite)
      SignalThreshold(value: high, isHigh: true, level: level),
    if (low != null && low.isFinite)
      SignalThreshold(value: low, isHigh: false, level: level),
  ]);
}

/// Hai danh sach nguong giong nhau (gia tri, phia, level, trivial; theo thu
/// tu).
bool sameThresholds(List<SignalThreshold> a, List<SignalThreshold> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;

  for (var i = 0; i < a.length; i++) {
    final x = a[i];
    final y = b[i];

    if (x.value != y.value ||
        x.isHigh != y.isHigh ||
        x.level != y.level ||
        x.trivial != y.trivial) {
      return false;
    }
  }

  return true;
}

double? _readNumber(dynamic raw) {
  final value = raw is num
      ? raw.toDouble()
      : double.tryParse('${raw ?? ''}'.trim());
  return (value == null || !value.isFinite) ? null : value;
}

/// Level 1..3; null khi khong doc duoc so.
int? _readLevel(Object? raw) {
  final value = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}'.trim());
  return value?.clamp(1, 3);
}

String? _readText(dynamic raw) {
  final value = raw?.toString().trim();
  return (value == null || value.isEmpty) ? null : value;
}

const Color kThresholdLevel3Color = Color(0xFFEF4444);
const Color kThresholdLevel2Color = Color(0xFFF97316);
const Color kThresholdLevel1Color = Color(0xFFFACC15);

/// 3 do, 2 cam, 1 vang.
Color thresholdLevelColor(int level) {
  return switch (level) {
    >= 3 => kThresholdLevel3Color,
    2 => kThresholdLevel2Color,
    _ => kThresholdLevel1Color,
  };
}

/// Level cao nhat ma bucket vuot (null = trong nguong).
///
/// HIGH so voi [max] (fallback [value]), LOW so voi [min] (fallback [value]),
/// de bat ca dinh ngan trong bucket ma avg da lam phang.
int? thresholdBreachLevel(
  List<SignalThreshold> thresholds, {
  required double value,
  double? min,
  double? max,
}) {
  int? level;

  for (final line in thresholds) {
    final breached = line.isHigh
        ? (max ?? value) > line.value
        : (min ?? value) < line.value;

    if (breached && (level == null || line.level > level)) level = line.level;
  }

  return level;
}

/// Mau badge "N breaches": level cao nhat da vuot trong [breachedLevels];
/// khong co (vd vuot chi tinh o backend) thi level cao nhat cua [thresholds].
Color breachBadgeColor(
  Iterable<int?> breachedLevels,
  List<SignalThreshold> thresholds,
) {
  var level = 0;

  for (final value in breachedLevels) {
    if (value != null && value > level) level = value;
  }

  if (level == 0) {
    for (final line in thresholds) {
      if (line.level > level) level = line.level;
    }
  }

  return thresholdLevelColor(level == 0 ? 3 : level);
}

/// Gia tri dai dien cua lan vuot nguong [level]: dinh (max) khi vuot HIGH,
/// day (min) khi vuot LOW, de cham to mau nam dung cho vi pham.
double breachMarkValue(
  List<SignalThreshold> thresholds,
  int level, {
  required double value,
  double? min,
  double? max,
}) {
  final high = thresholds.any(
    (line) => line.level == level && line.isHigh && (max ?? value) > line.value,
  );

  return high ? (max ?? value) : (min ?? value);
}
