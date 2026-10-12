import 'dart:math' as math;

import 'series_history_response.dart';

// ============================================================
// RANGE
// ============================================================

/// Khoang thoi gian cua tab Hourly.
///
/// Backend (bucket=1h): range <= 24h -> RAW (min/avg/max that);
/// range > 24h -> HOURLY_SNAPSHOT (avg = snapshot, min/max = null); toi da 7d.
enum UtilityHourlyRange {
  today(label: 'Today'),
  last24h(label: '24h'),
  last7d(label: '7d');

  final String label;

  const UtilityHourlyRange({required this.label});

  bool get isMultiDay => this == UtilityHourlyRange.last7d;

  /// [from, to] lam tron xuong phut, gio dia phuong.
  HourlyWindow windowAt(DateTime now) {
    final to = DateTime(now.year, now.month, now.day, now.hour, now.minute);

    final from = switch (this) {
      UtilityHourlyRange.today => DateTime(to.year, to.month, to.day),
      UtilityHourlyRange.last24h => to.subtract(const Duration(hours: 24)),
      // 00:00 cua 6 ngay truoc: 7 ngay lich, van < 7 x 24h.
      UtilityHourlyRange.last7d => DateTime(to.year, to.month, to.day - 6),
    };

    return HourlyWindow(from: from, to: to);
  }
}

class HourlyWindow {
  final DateTime from;
  final DateTime to;

  const HourlyWindow({required this.from, required this.to});
}

// ============================================================
// SIGNAL
// ============================================================

enum HourlySignalKind { analog, counter, status }

HourlySignalKind hourlySignalKindOf(String raw) {
  switch (raw.trim().toUpperCase()) {
    case 'COUNTER':
      return HourlySignalKind.counter;
    case 'STATUS':
      return HourlySignalKind.status;
    default:
      // ANALOG hoac thieu: ve line, an toan nhat.
      return HourlySignalKind.analog;
  }
}

/// Mot bucket 1h da chuan hoa. Gia tri da duoc model lam tron 6 chu so
/// (xem _readMeasure trong series_history_response.dart).
///
/// Bucket rong (count == 0) giu lai voi moi gia tri null de chart ngat duong.
class HourlyPoint {
  final DateTime ts;
  final double? min;
  final double? avg;
  final double? max;
  final double? last;
  final double? delta;
  final int? count;

  /// Gia tri ve chinh theo kind: ANALOG = avg, COUNTER = delta,
  /// STATUS = last (fallback avg: snapshot / backend cu).
  final double? value;

  const HourlyPoint({
    required this.ts,
    required this.min,
    required this.avg,
    required this.max,
    required this.last,
    required this.delta,
    required this.count,
    required this.value,
  });

  bool get hasValue => value != null;

  bool get hasRange => min != null && max != null;
}

class HourlySignalSeries {
  final String boxDeviceId;
  final String plcAddress;
  final String name;
  final String unit;
  final HourlySignalKind kind;

  final double? thresholdLow;
  final double? thresholdHigh;

  /// true = HOURLY_SNAPSHOT (7d): khong co min/max.
  final bool isSnapshot;

  final List<HourlyPoint> points;
  final String? parseError;

  const HourlySignalSeries({
    required this.boxDeviceId,
    required this.plcAddress,
    required this.name,
    required this.unit,
    required this.kind,
    required this.thresholdLow,
    required this.thresholdHigh,
    required this.isSnapshot,
    required this.points,
    this.parseError,
  });

  bool get hasThreshold => thresholdLow != null || thresholdHigh != null;

  /// Dai min–max chi co nghia khi backend tra MIN_AVG_MAX.
  bool get showRangeBand =>
      kind == HourlySignalKind.analog &&
      !isSnapshot &&
      points.any((point) => point.hasRange);

  Iterable<HourlyPoint> get valuedPoints =>
      points.where((point) => point.hasValue);

  factory HourlySignalSeries.fromDto(
    SeriesHistorySignalDto dto, {
    required bool isSnapshot,
    required DateTime windowTo,
  }) {
    final kind = hourlySignalKindOf(dto.kind);

    /*
     * Bo bucket chua du gio ma count == 0: gio hien tai chua co mau.
     * Bucket rong o giua van giu (value null) de chart ngat duong.
     */
    final raw =
        dto.points
            .where((point) {
              final incomplete = point.ts
                  .add(const Duration(hours: 1))
                  .isAfter(windowTo);
              return !(incomplete && point.count == 0);
            })
            .toList(growable: false)
          ..sort((a, b) => a.ts.compareTo(b.ts));

    final points = <HourlyPoint>[];

    for (final point in raw) {
      final empty = point.count == 0;

      // COUNTER: dung delta backend tra ve ca o snapshot; null -> khong ve cot.
      final delta = empty ? null : point.delta;
      final min = empty ? null : point.min;
      final avg = empty ? null : point.avg;
      final max = empty ? null : point.max;
      final last = empty ? null : point.last;

      final value = switch (kind) {
        HourlySignalKind.analog => avg,
        HourlySignalKind.counter => delta,
        HourlySignalKind.status => last ?? avg,
      };

      points.add(
        HourlyPoint(
          ts: point.ts,
          min: min,
          avg: avg,
          max: max,
          last: last,
          delta: delta,
          count: point.count,
          value: value,
        ),
      );
    }

    return HourlySignalSeries(
      boxDeviceId: dto.boxDeviceId,
      plcAddress: dto.plcAddress,
      name: dto.name.isNotEmpty ? dto.name : dto.code,
      unit: dto.unit,
      kind: kind,
      thresholdLow: dto.thresholdLow,
      thresholdHigh: dto.thresholdHigh,
      isSnapshot: isSnapshot,
      points: List<HourlyPoint>.unmodifiable(points),
      parseError: dto.parseError,
    );
  }

  /// Nguong ap cho gia tri do (ANALOG), khong ap cho delta cua COUNTER hay
  /// ma STATUS (cung quy uoc voi chart catalog).
  bool get showThresholds => kind == HourlySignalKind.analog && hasThreshold;

  /// Gia tri vuot nguong cua mot bucket (null = trong nguong).
  ///
  /// Xet ca max / min cua bucket, cham do dat tai gia tri vi pham.
  double? breachValue(HourlyPoint point) {
    if (!showThresholds || !point.hasValue) return null;

    final high = thresholdHigh;
    final low = thresholdLow;

    final top = point.max ?? point.value!;
    final bottom = point.min ?? point.value!;

    if (high != null && top > high) return top;
    if (low != null && bottom < low) return bottom;

    return null;
  }
}

// ============================================================
// SUMMARY
// ============================================================

class HourlySeriesSummary {
  final HourlyPoint? latest;

  final double? min;
  final double? max;
  final double? avg;

  /// COUNTER: tong delta cua range.
  final double? total;

  /// STATUS: so lan doi trang thai trong range.
  final int statusChanges;

  const HourlySeriesSummary({
    required this.latest,
    required this.min,
    required this.max,
    required this.avg,
    required this.total,
    required this.statusChanges,
  });

  factory HourlySeriesSummary.of(HourlySignalSeries series) {
    HourlyPoint? latest;
    double? lo;
    double? hi;
    double? total;

    var weightedSum = 0.0;
    var weight = 0;
    var statusChanges = 0;
    int? previousCode;

    for (final point in series.points) {
      final value = point.value;
      if (value == null) continue;

      latest = point;

      final pointLo = point.min ?? value;
      final pointHi = point.max ?? value;
      if (lo == null || pointLo < lo) lo = pointLo;
      if (hi == null || pointHi > hi) hi = pointHi;

      // Trung binh theo so mau khi co (RAW), snapshot thi moi bucket 1 mau.
      final samples = (point.count ?? 0) > 0 ? point.count! : 1;
      weightedSum += value * samples;
      weight += samples;

      if (series.kind == HourlySignalKind.counter) {
        total = _round6((total ?? 0) + value);
      }

      if (series.kind == HourlySignalKind.status) {
        final code = value.round();
        if (previousCode != null && code != previousCode) statusChanges++;
        previousCode = code;
      }
    }

    return HourlySeriesSummary(
      latest: latest,
      min: lo,
      max: hi,
      avg: weight == 0 ? null : _round6(weightedSum / weight),
      total: total,
      statusChanges: statusChanges,
    );
  }
}

// ============================================================
// AXIS
// ============================================================

/// Phang khi bien do <= max(1e-9 x |gia tri|, 1e-6).
///
/// Cung quy tac voi YAxisPlan._isFlat ben utility_catalog (ham do private va
/// gan voi model cua module kia nen khong import duoc). Bien do ~1e-14 do sai
/// so double neu dua vao truc se lam Syncfusion chon interval nho hon buoc
/// lam tron double -> vong lap label khong tang -> treo main thread.
bool hourlyIsFlat(double lo, double hi) {
  final magnitude = math.max(lo.abs(), hi.abs());
  return (hi - lo).abs() <= math.max(magnitude * 1e-9, 1e-6);
}

double _round6(double value) => (value * 1e6).roundToDouble() / 1e6;
