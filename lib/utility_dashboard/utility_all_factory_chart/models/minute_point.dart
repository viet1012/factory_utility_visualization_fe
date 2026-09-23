class MinutePointDto {
  final DateTime ts;
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

  MinutePointDto({
    required this.ts,
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
