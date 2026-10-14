import 'dart:math' as math;

import '../../../shared/charts/signal_thresholds.dart';
import '../../models/signal_history_models.dart';

/// Mot cot cua bieu do cot (24h theo gio, 7d theo ngay).
class SignalBar {
  /// Dau gio / dau ngay (gio dia phuong).
  final DateTime start;
  final DateTime end;

  /// ANALOG: avg. COUNTER: tong delta. Null = khong co du lieu, khong ve cot.
  final double? value;
  final double? min;
  final double? max;

  /// So mau (24h: count cua bucket; 7d: so snapshot trong ngay).
  final int count;

  /// Khac null khi cot chua du thoi gian (gio / ngay hien tai): du lieu
  /// moi tinh den thoi diem nay.
  final DateTime? until;

  const SignalBar({
    required this.start,
    required this.end,
    required this.value,
    required this.min,
    required this.max,
    required this.count,
    this.until,
  });

  bool get hasData => value != null;
}

/// Gop diem cua [series] thanh cot theo [period].
///
/// - hour (24h, API tra RAW 1h): moi bucket = 1 cot; ANALOG lay avg / min /
///   max / count that tu API, COUNTER lay delta cua bucket.
/// - day (7d, API tra HOURLY_SNAPSHOT): gop snapshot theo ngay local;
///   avg = trung binh snapshot, min / max = min / max snapshot, count = so
///   snapshot; COUNTER = tong delta khac null cua ngay.
/// Ngay / gio khong co du lieu van giu cho (cot rong), khong to xam.
List<SignalBar> buildSignalBars(
  SignalHistorySeries series,
  SignalBarPeriod period, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();

  return switch (period) {
    SignalBarPeriod.hour => _hourBars(series, current),
    SignalBarPeriod.day => _dayBars(series, current),
  };
}

List<SignalBar> _hourBars(SignalHistorySeries series, DateTime now) {
  final isCounter = series.kind == SignalKind.counter;
  final step = series.bucket ?? const Duration(hours: 1);

  return [
    for (final point in series.points)
      _hourBar(point, step, now, isCounter: isCounter),
  ];
}

SignalBar _hourBar(
  SignalHistoryPoint point,
  Duration step,
  DateTime now, {
  required bool isCounter,
}) {
  final end = point.ts.add(step);
  final value = isCounter ? point.delta : point.value;

  return SignalBar(
    start: point.ts,
    end: end,
    value: value,
    min: isCounter ? null : point.min,
    max: isCounter ? null : point.max,
    count: point.count ?? (point.value == null ? 0 : 1),
    until: end.isAfter(now) && value != null ? now : null,
  );
}

List<SignalBar> _dayBars(SignalHistorySeries series, DateTime now) {
  if (series.points.isEmpty) return const <SignalBar>[];

  final isCounter = series.kind == SignalKind.counter;

  final byDay = <DateTime, List<SignalHistoryPoint>>{};

  for (final point in series.points) {
    final local = point.ts.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    byDay.putIfAbsent(day, () => <SignalHistoryPoint>[]).add(point);
  }

  final days = byDay.keys.toList()..sort();
  final first = days.first;
  final last = days.last;

  final bars = <SignalBar>[];

  // Lien tuc tu ngay dau den ngay cuoi: ngay thieu van co cho (cot rong).
  for (
    var day = first;
    !day.isAfter(last);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    final end = DateTime(day.year, day.month, day.day + 1);
    final points = byDay[day] ?? const <SignalHistoryPoint>[];

    bars.add(
      isCounter
          ? _counterDay(day, end, points, now)
          : _analogDay(day, end, points, now),
    );
  }

  return bars;
}

SignalBar _analogDay(
  DateTime day,
  DateTime end,
  List<SignalHistoryPoint> points,
  DateTime now,
) {
  final values = <double>[];
  DateTime? lastTs;

  for (final point in points) {
    final value = point.value;
    if (value == null || !value.isFinite) continue;

    values.add(value);
    if (lastTs == null || point.ts.isAfter(lastTs)) lastTs = point.ts;
  }

  if (values.isEmpty) {
    return SignalBar(
      start: day,
      end: end,
      value: null,
      min: null,
      max: null,
      count: 0,
    );
  }

  return SignalBar(
    start: day,
    end: end,
    value: values.reduce((a, b) => a + b) / values.length,
    min: values.reduce(math.min),
    max: values.reduce(math.max),
    count: values.length,
    // Hom nay chua du: du lieu den snapshot cuoi cung.
    until: end.isAfter(now) ? lastTs : null,
  );
}

SignalBar _counterDay(
  DateTime day,
  DateTime end,
  List<SignalHistoryPoint> points,
  DateTime now,
) {
  double? total;
  var count = 0;
  DateTime? lastTs;

  for (final point in points) {
    final delta = point.delta;
    if (delta == null || !delta.isFinite) continue;

    total = (total ?? 0) + delta;
    count++;
    if (lastTs == null || point.ts.isAfter(lastTs)) lastTs = point.ts;
  }

  return SignalBar(
    start: day,
    end: end,
    value: total,
    min: null,
    max: null,
    count: count,
    until: end.isAfter(now) && total != null ? lastTs : null,
  );
}

/// Level vuot nguong cao nhat cua cot ANALOG voi [lines]
/// (= SignalHistorySeries.chartThresholds): max > HIGH hoac min < LOW
/// (thieu min / max thi dung avg). Null = trong nguong / COUNTER.
int? barBreachLevel(List<SignalThreshold> lines, SignalBar bar) {
  final value = bar.value;
  if (value == null || lines.isEmpty) return null;

  return thresholdBreachLevel(
    lines,
    value: value,
    min: bar.min,
    max: bar.max,
  );
}
