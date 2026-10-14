import '../../shared/charts/series_math.dart';
import '../../shared/charts/signal_thresholds.dart';
import '../../utility_catalog/models/signal_history_models.dart';
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
  HistoryWindow windowAt(DateTime now) {
    final to = DateTime(now.year, now.month, now.day, now.hour, now.minute);

    return switch (this) {
      UtilityHourlyRange.today => HistoryWindow(
        from: DateTime(to.year, to.month, to.day),
        to: to,
      ),
      UtilityHourlyRange.last24h => HistoryRange.h24.windowEndingAt(to),
      // 00:00 cua 6 ngay truoc: 7 ngay lich, van < 7 x 24h.
      UtilityHourlyRange.last7d => HistoryRange.d7.windowEndingAt(to),
    };
  }
}

// ============================================================
// SIGNAL
// ============================================================

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

  /// Ma signal backend (vd E_Temp), dung chon SignalChartSpec.
  final String code;
  final String unit;
  final SignalKind kind;

  /// Gia tri goc cua backend (da dung de dung [thresholds] khi thieu).
  final double? thresholdLow;
  final double? thresholdHigh;
  final String? alertLevel;

  /// Nguong se ve (trivial = false), theo level.
  final List<SignalThreshold> thresholds;

  final int breachCount;
  final DateTime? lastBreachAt;

  /// true = HOURLY_SNAPSHOT (7d): khong co min/max.
  final bool isSnapshot;

  final List<HourlyPoint> points;
  final String? parseError;

  const HourlySignalSeries({
    required this.boxDeviceId,
    required this.plcAddress,
    required this.name,
    required this.code,
    required this.unit,
    required this.kind,
    this.thresholdLow,
    this.thresholdHigh,
    this.alertLevel,
    required this.thresholds,
    required this.breachCount,
    required this.lastBreachAt,
    required this.isSnapshot,
    required this.points,
    this.parseError,
  });

  /// Dai min–max chi co nghia khi backend tra MIN_AVG_MAX.
  bool get showRangeBand =>
      kind == SignalKind.analog &&
      !isSnapshot &&
      points.any((point) => point.hasRange);

  Iterable<HourlyPoint> get valuedPoints =>
      points.where((point) => point.hasValue);

  factory HourlySignalSeries.fromDto(
    SeriesHistorySignalDto dto, {
    required bool isSnapshot,
    required DateTime windowTo,
  }) {
    final kind = parseSignalKind(dto.kind);

    // Gio hien tai chua co mau: bo. Bucket rong o giua van giu (value null)
    // de chart ngat duong.
    final raw = dropIncompleteEmptyBuckets(
      dto.points,
      bucket: const Duration(hours: 1),
      reference: windowTo,
    )..sort((a, b) => a.ts.compareTo(b.ts));

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
        SignalKind.analog => avg,
        SignalKind.counter => delta,
        SignalKind.status => last ?? avg,
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
      code: dto.code,
      unit: dto.unit,
      kind: kind,
      thresholdLow: dto.thresholdLow,
      thresholdHigh: dto.thresholdHigh,
      alertLevel: dto.alertLevel,
      thresholds: dto.visibleThresholds,
      breachCount: dto.breachCount,
      lastBreachAt: dto.lastBreachAt,
      isSnapshot: isSnapshot,
      points: List<HourlyPoint>.unmodifiable(points),
      parseError: dto.parseError,
    );
  }

  /// Nguong `thresholds[]` chi ap cho ANALOG (avg / min / max); backend
  /// khong tinh nguong tren delta cua COUNTER, STATUS ve ma trang thai.
  bool get showThresholds =>
      kind == SignalKind.analog && thresholds.isNotEmpty;

  /// Badge "N breaches": chi ANALOG.
  int get visibleBreachCount => kind == SignalKind.analog ? breachCount : 0;

  /// Level cao nhat ma bucket vuot (null = trong nguong).
  ///
  /// Xet ca max / min cua bucket (ANALOG), cham dat tai gia tri vi pham.
  int? breachLevel(HourlyPoint point) {
    if (!showThresholds || !point.hasValue) return null;

    final analog = kind == SignalKind.analog;

    return thresholdBreachLevel(
      thresholds,
      value: point.value!,
      min: analog ? point.min : null,
      max: analog ? point.max : null,
    );
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
    double? total;

    var statusChanges = 0;
    int? previousCode;

    for (final point in series.valuedPoints) {
      final value = point.value!;

      latest = point;

      if (series.kind == SignalKind.counter) {
        total = _round6((total ?? 0) + value);
      }

      if (series.kind == SignalKind.status) {
        final code = value.round();
        if (previousCode != null && code != previousCode) statusChanges++;
        previousCode = code;
      }
    }

    // Trung binh theo so mau khi co (RAW), snapshot thi moi bucket 1 mau.
    final envelope = ValueEnvelope.of(
      series.valuedPoints.map((point) {
        final value = point.value!;

        return (
          value: value,
          low: point.min ?? value,
          high: point.max ?? value,
          weight: (point.count ?? 0) > 0 ? point.count! : 1,
        );
      }),
    );

    final avg = envelope.avg;

    return HourlySeriesSummary(
      latest: latest,
      min: envelope.min,
      max: envelope.max,
      avg: avg == null ? null : _round6(avg),
      total: total,
      statusChanges: statusChanges,
    );
  }
}

double _round6(double value) => (value * 1e6).roundToDouble() / 1e6;
