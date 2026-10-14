import '../../shared/charts/signal_thresholds.dart';

/// Response cua `GET /api/utility/series/history`.
///
/// ```text
/// { from, to, bucket, source: "RAW"|"HOURLY_SNAPSHOT"|"DAILY",
///   aggregation: <chuoi mo ta, chi de log>,
///   signals: [{ boxDeviceId, plcAddress, name, code, unit,
///               kind: "ANALOG"|"STATUS"|"COUNTER",
///               thresholdLow, thresholdHigh, alertLevel,
///               thresholds: [{ level, low, high, ruleName, description,
///                              trivial }],
///               breachCount, lastBreachAt,
///               points: [{ ts, min, avg, max, last, count, delta }] }] }
/// ```
///
/// Request nhieu box (`boxDeviceId` CSV) tra signal cua moi box trong cung
/// mot response; ghep theo (boxDeviceId, plcAddress).
///
/// Cach gop nhan biet qua [source], KHONG qua [aggregation] (backend co the
/// doi chuoi aggregation bat ky luc nao).
///
/// COUNTER o moi bucket: ve theo `delta`; `last` la so tich luy, khong dung
/// de ve cot.
///
/// Moi timestamp co offset (vd: +07:00) va duoc doi sang gio dia phuong.
class SeriesHistoryResponse {
  static const String sourceRaw = 'RAW';
  static const String sourceHourlySnapshot = 'HOURLY_SNAPSHOT';
  static const String sourceDaily = 'DAILY';

  /// Chuoi bucket nguyen ban cua backend (vd: "1m", "15m", "1h", "1d").
  final String bucket;

  /// "RAW" | "HOURLY_SNAPSHOT" | "DAILY".
  final String source;

  /// Chuoi mo ta cua backend; chi de log, khong dung de re nhanh.
  final String aggregation;

  final List<SeriesHistorySignalDto> signals;

  const SeriesHistoryResponse({
    required this.bucket,
    required this.source,
    required this.aggregation,
    required this.signals,
  });

  String get _normalizedSource => source.trim().toUpperCase();

  /// HOURLY_SNAPSHOT: avg = gia tri snapshot, min / max = null.
  bool get isSnapshot => _normalizedSource == sourceHourlySnapshot;

  /// DAILY: moi diem la mot ngay.
  bool get isDaily => _normalizedSource == sourceDaily;

  /// [bucket] doi sang Duration; null neu khong nhan dang duoc dinh dang.
  Duration? get bucketDuration => parseSeriesBucket(bucket);

  factory SeriesHistoryResponse.fromJson(Map<String, dynamic> json) {
    final rawSignals = json['signals'];

    return SeriesHistoryResponse(
      bucket: _readString(json['bucket']),
      source: _readString(json['source']),
      aggregation: _readString(json['aggregation']),
      signals: rawSignals is List
          ? List<SeriesHistorySignalDto>.unmodifiable(
              rawSignals.whereType<Map>().map(
                (item) => SeriesHistorySignalDto.safeFromJson(
                  Map<String, dynamic>.from(item),
                ),
              ),
            )
          : const <SeriesHistorySignalDto>[],
    );
  }
}

class SeriesHistorySignalDto {
  final String boxDeviceId;
  final String plcAddress;
  final String name;
  final String code;
  final String unit;

  /// "ANALOG" | "STATUS" | "COUNTER".
  final String kind;

  final double? thresholdLow;
  final double? thresholdHigh;
  final String? alertLevel;

  /// Moi nguong backend tra (ke ca trivial); ve dung [visibleThresholds].
  final List<SignalThreshold> thresholds;

  /// So bucket vuot nguong trong range (backend tinh).
  final int breachCount;
  final DateTime? lastBreachAt;

  final List<SeriesHistoryPointDto> points;

  /// Khac null khi signal nay parse loi; cac signal khac van dung duoc.
  final String? parseError;

  const SeriesHistorySignalDto({
    required this.boxDeviceId,
    required this.plcAddress,
    required this.name,
    required this.code,
    required this.unit,
    required this.kind,
    required this.thresholdLow,
    required this.thresholdHigh,
    required this.alertLevel,
    required this.points,
    this.thresholds = const <SignalThreshold>[],
    this.breachCount = 0,
    this.lastBreachAt,
    this.parseError,
  });

  /// Nguong se ve: trivial = false.
  List<SignalThreshold> get visibleThresholds => [
    for (final line in thresholds)
      if (!line.trivial) line,
  ];

  /// Nhu [SeriesHistorySignalDto.fromJson] nhung khong nem loi: neu parse
  /// hong thi tra ve signal rong kem [parseError], giu boxDeviceId /
  /// plcAddress de van ghep dung the.
  factory SeriesHistorySignalDto.safeFromJson(Map<String, dynamic> json) {
    try {
      return SeriesHistorySignalDto.fromJson(json);
    } catch (error) {
      return SeriesHistorySignalDto(
        boxDeviceId: _readString(json['boxDeviceId']),
        plcAddress: _readString(json['plcAddress']),
        name: '',
        code: '',
        unit: '',
        kind: '',
        thresholdLow: null,
        thresholdHigh: null,
        alertLevel: null,
        points: const <SeriesHistoryPointDto>[],
        parseError: '$error',
      );
    }
  }

  factory SeriesHistorySignalDto.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];

    final alertLevel = json['alertLevel']?.toString().trim();
    final thresholdLow = _readDouble(json['thresholdLow']);
    final thresholdHigh = _readDouble(json['thresholdHigh']);
    final breachCount = json['breachCount'];

    return SeriesHistorySignalDto(
      boxDeviceId: _readString(json['boxDeviceId']),
      plcAddress: _readString(json['plcAddress']),
      name: _readString(json['name']),
      code: _readString(json['code']),
      unit: _readString(json['unit']),
      kind: _readString(json['kind']).toUpperCase(),
      thresholdLow: thresholdLow,
      thresholdHigh: thresholdHigh,
      alertLevel: (alertLevel == null || alertLevel.isEmpty)
          ? null
          : alertLevel,
      thresholds: resolveSignalThresholds(
        json['thresholds'],
        low: thresholdLow,
        high: thresholdHigh,
        alertLevel: json['alertLevel'],
      ),
      breachCount: breachCount is num
          ? breachCount.toInt()
          : int.tryParse('${breachCount ?? ''}') ?? 0,
      lastBreachAt: _readDateTime(json['lastBreachAt']),
      points: rawPoints is List
          ? List<SeriesHistoryPointDto>.unmodifiable(
              rawPoints
                  .whereType<Map>()
                  .map(
                    (item) => SeriesHistoryPointDto.tryParse(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .whereType<SeriesHistoryPointDto>(),
            )
          : const <SeriesHistoryPointDto>[],
    );
  }
}

class SeriesHistoryPointDto {
  /// Dau bucket, gio dia phuong.
  final DateTime ts;
  final double? min;
  final double? avg;
  final double? max;

  /// Gia tri mau cuoi cung trong bucket. Nullable: backend cu chua tra.
  final double? last;

  /// 0 = bucket rong (backend da gap-fill).
  final int? count;
  final double? delta;

  const SeriesHistoryPointDto({
    required this.ts,
    required this.min,
    required this.avg,
    required this.max,
    required this.count,
    required this.delta,
    this.last,
  });

  /// Null khi ts thieu / sai dinh dang: bo diem do thay vi lam hong ca series.
  static SeriesHistoryPointDto? tryParse(Map<String, dynamic> json) {
    final ts = _readDateTime(json['ts']);
    if (ts == null) return null;

    final count = json['count'];

    return SeriesHistoryPointDto(
      ts: ts,
      min: _readMeasure(json['min']),
      avg: _readMeasure(json['avg']),
      max: _readMeasure(json['max']),
      last: _readMeasure(json['last']),
      count: count is num ? count.toInt() : int.tryParse('${count ?? ''}'),
      delta: _readMeasure(json['delta']),
    );
  }
}

/// Bo bucket chua du thoi gian (ts + [bucket] > [reference]) ma count == 0:
/// chua co mau, khong ve va khong tinh la gap. Bucket da co mau (count > 0)
/// va bucket rong o giua van giu nguyen.
List<SeriesHistoryPointDto> dropIncompleteEmptyBuckets(
  List<SeriesHistoryPointDto> points, {
  required Duration bucket,
  required DateTime reference,
}) {
  return [
    for (final point in points)
      if (!(point.count == 0 && point.ts.add(bucket).isAfter(reference))) point,
  ];
}

/// Gia tri do: lam tron toi 6 chu so thap phan (DB la decimal(18,6)).
///
/// avg / delta tinh bang double o backend co the lech vai ulp
/// (40.29990000000001); lam tron ve dung luoi 1e-6 cua DB de cac gia tri
/// bang nhau that su bang nhau o FE.
double? _readMeasure(dynamic value) {
  final parsed = _readDouble(value);
  if (parsed == null) return null;

  // roundToDouble: khong qua int, an toan voi gia tri lon (tranh tran int64).
  return (parsed * 1e6).roundToDouble() / 1e6;
}

/// Nhan "1m", "5m", "15m", "1h", "60min", "1d", "PT15M", "PT1H", "P1D";
/// khac -> null.
Duration? parseSeriesBucket(String raw) {
  final value = raw.trim().toUpperCase();
  if (value.isEmpty) return null;

  final match = RegExp(
    r'^(?:PT?)?(\d+)\s*(M|MIN|MINS|MINUTE|MINUTES|H|HR|HOUR|HOURS|D|DAY|DAYS)$',
  ).firstMatch(value);

  if (match == null) return null;

  final amount = int.parse(match.group(1)!);
  if (amount <= 0) return null;

  final unit = match.group(2)!;

  if (unit.startsWith('D')) return Duration(days: amount);
  if (unit.startsWith('H')) return Duration(hours: amount);
  return Duration(minutes: amount);
}

String _readString(dynamic value) => value?.toString().trim() ?? '';

double? _readDouble(dynamic value) {
  if (value == null) return null;

  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value.toString());

  return (parsed == null || !parsed.isFinite) ? null : parsed;
}

/// ISO-8601 kem offset -> gio dia phuong. Chuoi khong offset giu nguyen
/// (DateTime.parse da hieu la gio dia phuong).
DateTime? _readDateTime(dynamic value) {
  if (value == null) return null;

  final parsed = DateTime.tryParse(value.toString().trim());
  if (parsed == null) return null;

  return parsed.isUtc ? parsed.toLocal() : parsed;
}
