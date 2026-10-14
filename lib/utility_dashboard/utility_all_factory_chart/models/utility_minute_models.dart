import '../../shared/charts/series_math.dart';
import '../../shared/charts/signal_thresholds.dart';
import '../../utility_catalog/models/signal_history_models.dart';
import '../../utility_catalog/widgets/signal_chart/signal_chart_gaps.dart'
    show kSignalGapBreakThreshold;
import 'series_history_response.dart';

/// Do rong bucket cua tab Minutes.
const Duration kMinuteBucket = Duration(minutes: 1);

/// Do rong moi cot usage cua signal COUNTER.
const Duration kMinuteUsageStep = Duration(minutes: 5);

/// Mot bucket 1 phut da chuan hoa. Bucket rong (count == 0) giu lai voi moi
/// gia tri null.
class MinutePoint {
  /// Dau phut, gio dia phuong.
  final DateTime ts;

  /// Gia tri ve theo kind: ANALOG = avg, STATUS = last (fallback avg),
  /// COUNTER = so tich luy cuoi phut (khong dung de ve cot).
  final double? value;
  final double? min;
  final double? max;

  /// COUNTER: muc tang trong phut; cot 5 phut cong cac delta nay.
  final double? delta;
  final int? count;

  const MinutePoint({
    required this.ts,
    required this.value,
    required this.min,
    required this.max,
    required this.delta,
    required this.count,
  });

  bool get hasValue => value != null;
}

/// Mot cot usage 5 phut cua signal COUNTER.
class MinuteUsageBar {
  final DateTime start;
  final DateTime end;

  /// Tong delta cac phut co du lieu; null = khong ve.
  final double? value;

  /// Khac null khi khoang dang dien ra: du lieu moi tinh den thoi diem nay.
  final DateTime? until;

  const MinuteUsageBar({
    required this.start,
    required this.end,
    required this.value,
    this.until,
  });

  DateTime get center => start.add(kMinuteUsageStep ~/ 2);
}

class MinuteSignalSeries {
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

  /// Moi bucket trong cua so (da gap-fill).
  final List<MinutePoint> points;

  /// [points] sau khi bo khoang rong ngan (<= 3 phut): duong noi qua; khoang
  /// dai giu diem null de ngat duong.
  final List<MinutePoint> plotPoints;

  final String? parseError;

  const MinuteSignalSeries({
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
    required this.points,
    required this.plotPoints,
    this.parseError,
  });

  factory MinuteSignalSeries.fromDto(
    SeriesHistorySignalDto dto, {
    required DateTime windowTo,
  }) {
    final kind = parseSignalKind(dto.kind);

    final raw = dropIncompleteEmptyBuckets(
      dto.points,
      bucket: kMinuteBucket,
      reference: windowTo,
    )..sort((a, b) => a.ts.compareTo(b.ts));

    final points = <MinutePoint>[
      for (final point in raw)
        if (point.count == 0)
          MinutePoint(
            ts: point.ts,
            value: null,
            min: null,
            max: null,
            delta: null,
            count: 0,
          )
        else
          MinutePoint(
            ts: point.ts,
            value: switch (kind) {
              SignalKind.analog => point.avg,
              SignalKind.status => point.last ?? point.avg,
              SignalKind.counter => point.last ?? point.avg,
            },
            min: point.min,
            max: point.max,
            delta: point.delta,
            count: point.count,
          ),
    ];

    return MinuteSignalSeries(
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
      points: List<MinutePoint>.unmodifiable(points),
      plotPoints: List<MinutePoint>.unmodifiable(
        dropShortGaps(
          points,
          hasValue: (point) => point.hasValue,
          step: kMinuteBucket,
          threshold: kSignalGapBreakThreshold,
        ),
      ),
      parseError: dto.parseError,
    );
  }

  /// Signal "slave multifunction meter" khong hien the.
  bool get hidden => name.toLowerCase().contains('slave multifunction meter');

  /// Bucket moi nhat co du lieu.
  MinutePoint? get latest {
    for (final point in points.reversed) {
      if (point.hasValue) return point;
    }
    return null;
  }

  /// Nguong `thresholds[]` chi ap cho ANALOG (avg / min / max); backend
  /// khong tinh nguong tren delta cua COUNTER, STATUS ve ma trang thai.
  bool get showThresholds =>
      kind == SignalKind.analog && thresholds.isNotEmpty;

  /// Badge "N breaches": chi ANALOG.
  int get visibleBreachCount => kind == SignalKind.analog ? breachCount : 0;

  /// Level cao nhat ma mot phut vuot (ANALOG / line).
  int? breachLevel(MinutePoint point) {
    if (!showThresholds || !point.hasValue) return null;

    final analog = kind == SignalKind.analog;

    return thresholdBreachLevel(
      thresholds,
      value: point.value!,
      min: analog ? point.min : null,
      max: analog ? point.max : null,
    );
  }

  /// Level cao nhat ma mot cot usage vuot.
  int? barBreachLevel(MinuteUsageBar bar) {
    final value = bar.value;
    if (!showThresholds || value == null) return null;

    return thresholdBreachLevel(thresholds, value: value);
  }

  /// COUNTER: tong usage cua cua so = tong delta cac phut.
  double? get usageTotal {
    double? total;

    for (final point in points) {
      final delta = point.delta;
      if (delta == null || !delta.isFinite) continue;
      total = (total ?? 0) + delta;
    }

    return total;
  }

  /// COUNTER: cot 5 phut (gio dia phuong) = tong delta cac phut trong khoang.
  /// Khoang khong co delta nao: khong ve cot. Khoang chua du (ket thuc sau
  /// [windowTo]) co [MinuteUsageBar.until] = cuoi phut cuoi cung co delta.
  List<MinuteUsageBar> usageBars(DateTime windowTo) {
    if (points.isEmpty) return const <MinuteUsageBar>[];

    DateTime floor(DateTime time) => DateTime(
      time.year,
      time.month,
      time.day,
      time.hour,
      time.minute - time.minute % kMinuteUsageStep.inMinutes,
    );

    final totals = <DateTime, double>{};
    final lastTs = <DateTime, DateTime>{};

    for (final point in points) {
      final delta = point.delta;
      if (delta == null || !delta.isFinite) continue;

      final bucket = floor(point.ts);
      totals[bucket] = (totals[bucket] ?? 0) + delta;

      final current = lastTs[bucket];
      if (current == null || point.ts.isAfter(current)) {
        lastTs[bucket] = point.ts;
      }
    }

    final first = floor(points.first.ts);
    final last = floor(points.last.ts);
    final bars = <MinuteUsageBar>[];

    for (
      var start = first;
      !start.isAfter(last);
      start = start.add(kMinuteUsageStep)
    ) {
      final end = start.add(kMinuteUsageStep);
      final value = totals[start];

      bars.add(
        MinuteUsageBar(
          start: start,
          end: end,
          value: value,
          until: end.isAfter(windowTo) && value != null
              ? lastTs[start]!.add(kMinuteBucket)
              : null,
        ),
      );
    }

    return bars;
  }
}
