class MinutePointDto {
  /// Minute-bucket timestamp. This is the chart's X-axis value and the key
  /// used for merge/dedupe - it is always aligned to the start of the minute
  /// (e.g. `11:15:00`).
  final DateTime ts;

  /// Wall-clock time of the raw sample the backend selected for this bucket
  /// (e.g. `11:15:46.473` inside the `11:15:00` bucket).
  ///
  /// Null when the backend has not sent the field (older deployments); use
  /// [realSampleTime] instead of reading this directly.
  final DateTime? sampleRecordedAt;

  final double? value;

  final String boxDeviceId;
  final String plcAddress;

  final String? cateId;

  // ✅ NEW
  final String? nameEn;
  final String? nameVi;
  final String? fac;
  final String? cate;
  final String? unit;

  /// Timestamp to use for freshness / "how old is this reading" maths.
  ///
  /// Falls back to the bucket [ts] so behaviour is unchanged against a backend
  /// that does not yet return `sampleRecordedAt`.
  DateTime get realSampleTime => sampleRecordedAt ?? ts;

  MinutePointDto({
    required this.ts,
    this.sampleRecordedAt,
    required this.value,
    required this.boxDeviceId,
    required this.plcAddress,
    this.cateId,

    this.nameEn,
    this.nameVi,
    this.fac,
    this.cate,
    this.unit,
  });

  factory MinutePointDto.fromJson(Map<String, dynamic> json) {
    final raw = json['value'];
    double? v;
    if (raw == null) {
      v = null;
    } else if (raw is num) {
      v = raw.toDouble();
    } else {
      v = double.tryParse(raw.toString());
    }

    return MinutePointDto(
      ts: parseMinuteTimestamp(json['ts']),
      sampleRecordedAt: parseOptionalMinuteTimestamp(json['sampleRecordedAt']),
      value: v,
      boxDeviceId: (json['boxDeviceId'] ?? '').toString(),
      plcAddress: (json['plcAddress'] ?? '').toString(),
      cateId: json['cateId']?.toString(),
      nameEn: json['nameEn']?.toString(),
      nameVi: json['nameVi']?.toString(),
      fac: json['fac']?.toString(),
      cate: json['cate']?.toString(),
      unit: json['unit']?.toString(),
    );
  }
}

/// Parses a minute-series timestamp into **local** time.
///
/// Backend contract (verified against [UtilityChartApi]): `from`/`to` are sent
/// as ISO-8601 local wall-clock strings with no `Z` and no offset
/// (`_toIsoNoZ`), and responses come back in the same shape. `DateTime.parse`
/// already treats an offset-less string as local, so that case is preserved
/// exactly as before.
///
/// The only added behaviour is defensive: if the backend ever starts emitting
/// `Z` or an explicit offset, `DateTime.parse` would return a UTC instant and
/// every comparison against `DateTime.now()` would be skewed by the timezone
/// offset - making samples look permanently stale. Converting those back to
/// local keeps freshness maths correct either way.
DateTime parseMinuteTimestamp(dynamic raw) {
  final parsed = DateTime.parse(raw.toString());

  return parsed.isUtc ? parsed.toLocal() : parsed;
}

/// Nullable variant of [parseMinuteTimestamp] with identical local wall-clock
/// semantics.
///
/// Returns null when the field is absent, empty or unparseable, so a malformed
/// `sampleRecordedAt` degrades to the bucket `ts` fallback instead of throwing
/// and dropping the whole point.
DateTime? parseOptionalMinuteTimestamp(dynamic raw) {
  if (raw == null) return null;

  final text = raw.toString().trim();

  if (text.isEmpty) return null;

  final parsed = DateTime.tryParse(text);

  if (parsed == null) return null;

  return parsed.isUtc ? parsed.toLocal() : parsed;
}
