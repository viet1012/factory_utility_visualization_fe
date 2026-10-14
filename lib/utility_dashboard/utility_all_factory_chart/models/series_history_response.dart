/// Response cua `GET /api/utility/series/history`.
///
/// ```text
/// { from, to, bucket, source: "RAW"|"HOURLY_SNAPSHOT",
///   aggregation: "MIN_AVG_MAX"|"SNAPSHOT",
///   signals: [{ boxDeviceId, plcAddress, name, code, unit,
///               kind: "ANALOG"|"STATUS"|"COUNTER",
///               thresholdLow, thresholdHigh, alertLevel,
///               points: [{ ts, min, avg, max, count, delta }] }] }
/// ```
///
/// Moi timestamp co offset (vd: +07:00) va duoc doi sang gio dia phuong.
class SeriesHistoryResponse {
  /// Chuoi bucket nguyen ban cua backend (vd: "1m", "15m", "1h").
  final String bucket;

  /// "RAW" | "HOURLY_SNAPSHOT".
  final String source;

  /// "MIN_AVG_MAX" | "SNAPSHOT".
  final String aggregation;

  final List<SeriesHistorySignalDto> signals;

  const SeriesHistoryResponse({
    required this.bucket,
    required this.source,
    required this.aggregation,
    required this.signals,
  });

  bool get isSnapshot => aggregation.toUpperCase() == 'SNAPSHOT';

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
    this.parseError,
  });

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

    return SeriesHistorySignalDto(
      boxDeviceId: _readString(json['boxDeviceId']),
      plcAddress: _readString(json['plcAddress']),
      name: _readString(json['name']),
      code: _readString(json['code']),
      unit: _readString(json['unit']),
      kind: _readString(json['kind']).toUpperCase(),
      thresholdLow: _readDouble(json['thresholdLow']),
      thresholdHigh: _readDouble(json['thresholdHigh']),
      alertLevel: (alertLevel == null || alertLevel.isEmpty)
          ? null
          : alertLevel,
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

/// Nhan "1m", "5m", "15m", "1h", "60min", "PT15M", "PT1H"; khac -> null.
Duration? parseSeriesBucket(String raw) {
  final value = raw.trim().toUpperCase();
  if (value.isEmpty) return null;

  final match = RegExp(
    r'^(?:PT)?(\d+)\s*(M|MIN|MINS|MINUTE|MINUTES|H|HR|HOUR|HOURS)$',
  ).firstMatch(value);

  if (match == null) return null;

  final amount = int.parse(match.group(1)!);
  if (amount <= 0) return null;

  return match.group(2)!.startsWith('H')
      ? Duration(hours: amount)
      : Duration(minutes: amount);
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
