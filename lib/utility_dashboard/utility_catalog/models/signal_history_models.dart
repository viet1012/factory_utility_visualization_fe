/// Model lich su signal cho che do Chart cua panel chi tiet thiet bi.
///
/// Doc lap voi model cua bang (LatestSignalDto / CatalogTableRow): bang van
/// dung API latest nhu cu, chart chi doc qua SignalHistoryRepository.
library;

import '../../shared/charts/series_math.dart';
import '../../shared/charts/signal_thresholds.dart';

enum SignalKind { analog, status, counter }

/// Kind cua backend ("ANALOG" | "STATUS" | "COUNTER").
SignalKind parseSignalKind(String? raw) {
  switch (raw?.trim().toUpperCase()) {
    case 'STATUS':
      return SignalKind.status;
    case 'COUNTER':
      return SignalKind.counter;
    default:
      // ANALOG hoac thieu: ve line, an toan nhat.
      return SignalKind.analog;
  }
}

/// Cach backend gop diem trong mot bucket, suy ra tu `source` cua response
/// (SeriesHistoryResponse.isSnapshot), khong tu chuoi aggregation.
enum HistoryAggregation {
  /// RAW: moi bucket co min / avg / max / count.
  minAvgMax,

  /// HOURLY_SNAPSHOT: avg = gia tri snapshot, min / max = null.
  snapshot,
}

/// Nguon thuc te cua mot lan fetch lich su (ghi trong log debug).
/// Hien chi co API; them gia tri moi khi co nguon khac.
enum DataSource { api }

/// Ket qua cua SignalHistoryRepository.fetchHistory.
class SignalHistoryResult {
  final List<SignalHistorySeries> series;
  final DataSource source;
  final HistoryAggregation aggregation;

  /// Do rong bucket backend da chon (null neu khong xac dinh duoc).
  final Duration? bucket;

  const SignalHistoryResult({
    required this.series,
    required this.source,
    this.aggregation = HistoryAggregation.minAvgMax,
    this.bucket,
  });
}

enum HistoryRange {
  h1('1h', Duration(hours: 1), 'auto'),
  h6('6h', Duration(hours: 6), 'auto'),
  // 24h: RAW 1h co min/avg/max/count -> 24 cot.
  h24('24h', Duration(hours: 24), '1h'),
  // 7d: HOURLY_SNAPSHOT 1h, FE gop theo ngay -> 7 cot.
  d7('7d', Duration(days: 7), 'auto');

  final String label;
  final Duration duration;

  /// Gia tri tham so `bucket` gui len /api/utility/series/history.
  final String requestBucket;

  const HistoryRange(this.label, this.duration, this.requestBucket);

  /// Cua so thoi gian ket thuc o [now].
  ///
  /// 7d gop theo ngay local: bat dau tu 00:00 cua 6 ngay truoc -> dung 7
  /// ngay (6 ngay du + hom nay chua du). Cua so van > 24h nen bucket=auto
  /// cua backend van tra HOURLY_SNAPSHOT.
  HistoryWindow windowEndingAt(DateTime now) {
    if (this == HistoryRange.d7) {
      return HistoryWindow(
        from: DateTime(now.year, now.month, now.day - 6),
        to: now,
      );
    }

    return HistoryWindow(from: now.subtract(duration), to: now);
  }

  /// Range ve bang cot (tru STATUS): 24h theo gio, 7d theo ngay.
  SignalBarPeriod? get barPeriod => switch (this) {
    HistoryRange.h24 => SignalBarPeriod.hour,
    HistoryRange.d7 => SignalBarPeriod.day,
    _ => null,
  };
}

/// Do rong moi cot cua bieu do cot.
enum SignalBarPeriod { hour, day }

/// Khoang thoi gian da resolve de goi repository.
class HistoryWindow {
  final DateTime from;
  final DateTime to;

  const HistoryWindow({required this.from, required this.to});

  @override
  bool operator ==(Object other) {
    return other is HistoryWindow && other.from == from && other.to == to;
  }

  @override
  int get hashCode => Object.hash(from, to);
}

class SignalHistoryPoint {
  final DateTime ts;

  /// Gia tri dai dien cua bucket (avg). Null = bucket rong / mat du lieu.
  final double? value;
  final double? min;
  final double? max;

  /// Gia tri mau cuoi cung trong bucket (STATUS ve theo gia tri nay).
  final double? last;

  /// So mau trong bucket (RAW). Null khi nguon khong tra ve.
  final int? count;

  /// COUNTER: muc tang so voi bucket truoc. Null = khong tinh duoc.
  final double? delta;

  const SignalHistoryPoint({
    required this.ts,
    required this.value,
    this.min,
    this.max,
    this.last,
    this.count,
    this.delta,
  });
}

class SignalHistorySeries {
  final String signalId;
  final String plc;
  final String name;
  final String? code;
  final String? unit;
  final SignalKind kind;
  final double? thresholdLow;
  final double? thresholdHigh;
  final String? alertLevel;

  /// `thresholds[]` da tach theo phia (ke ca trivial), cung nguon voi tab
  /// CHARTS (xem resolveSignalThresholds).
  final List<SignalThreshold> thresholds;
  final int breachCount;
  final DateTime? lastBreachAt;

  final HistoryAggregation aggregation;

  /// Do rong bucket; null thi chart tu suy ra tu khoang cach giua cac diem.
  final Duration? bucket;

  final List<SignalHistoryPoint> points;

  /// Khac null khi rieng signal nay khong lay duoc lich su; the cua no hien
  /// loi, cac the khac van hien binh thuong.
  final String? error;

  const SignalHistorySeries({
    required this.signalId,
    required this.plc,
    required this.name,
    required this.code,
    required this.unit,
    required this.kind,
    required this.thresholdLow,
    required this.thresholdHigh,
    required this.points,
    this.alertLevel,
    this.thresholds = const <SignalThreshold>[],
    this.breachCount = 0,
    this.lastBreachAt,
    this.aggregation = HistoryAggregation.minAvgMax,
    this.bucket,
    this.error,
  });

  /// Nguong ve tren chart (chart device / Filter results): `thresholds[]`
  /// bo trivial, chi ANALOG (cung quy uoc voi tab CHARTS).
  List<SignalThreshold> get chartThresholds => kind == SignalKind.analog
      ? [
          for (final line in thresholds)
            if (!line.trivial) line,
        ]
      : const <SignalThreshold>[];

  bool isOutOfRange(double value) {
    final low = thresholdLow;
    final high = thresholdHigh;

    return (low != null && value < low) || (high != null && value > high);
  }

  /// Gia tri dung de VE [point]: STATUS lay `last` (trang thai cuoi bucket,
  /// avg cua trang thai khong co nghia), thieu last thi fallback avg.
  /// Kind khac: avg.
  double? plotValue(SignalHistoryPoint point) {
    if (point.value == null) return null;

    return kind == SignalKind.status ? (point.last ?? point.value) : point.value;
  }

  /// Level vuot nguong cao nhat cua [point] voi [lines] (= [chartThresholds],
  /// truyen vao de khong dung lai danh sach moi diem); null = trong nguong.
  ///
  /// MIN_AVG_MAX: so max voi HIGH va min voi LOW (fallback avg), de bat ca
  /// dinh ngan trong bucket ma avg da lam phang. SNAPSHOT: chi co avg.
  int? breachLevel(SignalHistoryPoint point, List<SignalThreshold> lines) {
    final avg = point.value;
    if (lines.isEmpty || avg == null) return null;

    final useEnvelope = aggregation == HistoryAggregation.minAvgMax;

    return thresholdBreachLevel(
      lines,
      value: avg,
      min: useEnvelope ? point.min : null,
      max: useEnvelope ? point.max : null,
    );
  }

  /// Gia tri dat cham vuot nguong [level] cua [point] (dinh / day vi pham).
  double breachValue(
    SignalHistoryPoint point,
    List<SignalThreshold> lines,
    int level,
  ) {
    final useEnvelope = aggregation == HistoryAggregation.minAvgMax;

    return breachMarkValue(
      lines,
      level,
      value: point.value!,
      min: useEnvelope ? point.min : null,
      max: useEnvelope ? point.max : null,
    );
  }
}

/// Thong ke cua range cho dong duoi gia tri lon tren the.
class SignalHistoryStats {
  final double? min;
  final double? avg;
  final double? max;

  /// COUNTER: tong delta trong range.
  final double? total;

  const SignalHistoryStats({this.min, this.avg, this.max, this.total});

  /// - COUNTER: tong cac delta khac null.
  /// - MIN_AVG_MAX: min cua cac min, max cua cac max, avg co trong so theo
  ///   count (count null -> trong so 1).
  /// - SNAPSHOT: min / avg / max tren chinh cac gia tri snapshot.
  factory SignalHistoryStats.of(SignalHistorySeries series) {
    if (series.kind == SignalKind.counter) {
      double? total;

      for (final point in series.points) {
        final delta = point.delta;
        if (delta == null || !delta.isFinite) continue;

        total = (total ?? 0) + delta;
      }

      return SignalHistoryStats(total: total);
    }

    final envelope = series.aggregation == HistoryAggregation.minAvgMax;

    final stats = ValueEnvelope.of(
      series.points
          .where((point) {
            final value = point.value;
            return value != null && value.isFinite && (point.count ?? 1) > 0;
          })
          .map((point) {
            final value = point.value!;

            return (
              value: value,
              low: envelope ? (point.min ?? value) : value,
              high: envelope ? (point.max ?? value) : value,
              weight: envelope ? (point.count ?? 1) : 1,
            );
          }),
    );

    return SignalHistoryStats(min: stats.min, avg: stats.avg, max: stats.max);
  }
}

/// Id on dinh cua mot signal, dung chung giua UI va repository.
///
/// TODO(api): khi backend co signal id rieng (vd: id trong master), doi sang
/// dung id do thay vi ghep tu cac truong cua cay latest.
String buildSignalHistoryId({
  required String fac,
  required String cate,
  required String scadaId,
  required String boxId,
  required String boxDeviceId,
  required String plcAddress,
}) {
  return [
    fac,
    cate,
    scadaId,
    boxId,
    boxDeviceId,
    plcAddress,
  ].map((part) => part.trim()).join('|');
}
