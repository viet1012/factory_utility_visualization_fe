import '../../shared/charts/signal_thresholds.dart';
import '../../utility_catalog/models/signal_history_models.dart';
import 'series_history_response.dart';

/// Mot ngay (bucket=1d, source DAILY) da chuan hoa.
class DailyPoint {
  /// 00:00 cua ngay, gio dia phuong.
  final DateTime day;

  /// Gia tri ve theo kind: ANALOG = avg (fallback last), COUNTER = delta
  /// cua ngay, STATUS = last (fallback avg). Null = ngay khong co du lieu.
  final double? value;
  final double? min;
  final double? max;

  /// Gia tri cuoi ngay; COUNTER la so tich luy (khong dung de ve cot).
  final double? last;
  final double? delta;
  final int count;

  const DailyPoint({
    required this.day,
    required this.value,
    required this.min,
    required this.max,
    required this.last,
    required this.delta,
    required this.count,
  });

  bool get hasValue => value != null;

  bool get hasRange => min != null && max != null;
}

class DailySignalSeries {
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

  /// Cac ngay co du lieu, theo thoi gian.
  final List<DailyPoint> points;

  final String? parseError;

  const DailySignalSeries({
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
    this.parseError,
  });

  bool get isCounter => kind == SignalKind.counter;

  factory DailySignalSeries.fromDto(SeriesHistorySignalDto dto) {
    final kind = parseSignalKind(dto.kind);

    final points = <DailyPoint>[];

    for (final point in dto.points) {
      if (point.count == 0) continue;

      final local = point.ts.toLocal();

      final value = switch (kind) {
        SignalKind.analog => point.avg ?? point.last,
        SignalKind.counter => point.delta,
        SignalKind.status => point.last ?? point.avg,
      };

      if (value == null || !value.isFinite) continue;

      points.add(
        DailyPoint(
          day: DateTime(local.year, local.month, local.day),
          value: value,
          min: point.min,
          max: point.max,
          last: point.last,
          delta: point.delta,
          count: point.count ?? 0,
        ),
      );
    }

    points.sort((a, b) => a.day.compareTo(b.day));

    return DailySignalSeries(
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
      points: List<DailyPoint>.unmodifiable(points),
      parseError: dto.parseError,
    );
  }

  /// Nguong `thresholds[]` chi ap cho ANALOG (avg / min / max); backend
  /// khong tinh nguong tren delta cua COUNTER, STATUS khong ap.
  bool get showThresholds =>
      kind == SignalKind.analog && thresholds.isNotEmpty;

  /// Badge "N breaches": chi ANALOG.
  int get visibleBreachCount => kind == SignalKind.analog ? breachCount : 0;

  /// Level cao nhat ma mot ngay vuot (null = trong nguong).
  int? breachLevel(DailyPoint point) {
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
