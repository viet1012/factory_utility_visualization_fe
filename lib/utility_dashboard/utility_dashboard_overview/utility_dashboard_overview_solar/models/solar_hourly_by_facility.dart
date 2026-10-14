/// Response cua GET /api/solar/hourly.
///
/// `kwh = null`: gio chua co du lieu (gio hien tai / tuong lai cua hom nay),
/// khong ve cot va khong tinh vao tong.
class SolarHourlyByFacility {
  final DateTime date;
  final String facId;
  final List<SolarFacilityHourly> facilities;
  final List<SolarHourKwh> totalHours;
  final double totalKwh;
  final double? peakKwh;
  final int? peakHour;

  const SolarHourlyByFacility({
    required this.date,
    required this.facId,
    required this.facilities,
    required this.totalHours,
    required this.totalKwh,
    required this.peakKwh,
    required this.peakHour,
  });

  factory SolarHourlyByFacility.fromJson(Map<String, dynamic> json) {
    final facRaw = json['facilities'];

    return SolarHourlyByFacility(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      facId: json['facId']?.toString() ?? '',
      facilities: facRaw is List
          ? facRaw
                .whereType<Map>()
                .map(
                  (e) => SolarFacilityHourly.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList(growable: false)
          : const [],
      totalHours: _hours(json['totalHours']),
      totalKwh: _numOrNull(json['totalKwh']) ?? 0,
      peakKwh: _numOrNull(json['peakKwh']),
      peakHour: _intOrNull(json['peakHour']),
    );
  }

  /// Gio dinh cua [totalHours] (bo qua gio null). null khi chua co gio nao.
  SolarHourKwh? get totalPeak => _peakOf(totalHours);
}

class SolarFacilityHourly {
  final String facId;
  final double totalKwh;
  final double? peakKwh;
  final int? peakHour;
  final List<SolarHourKwh> hours;

  const SolarFacilityHourly({
    required this.facId,
    required this.totalKwh,
    required this.peakKwh,
    required this.peakHour,
    required this.hours,
  });

  factory SolarFacilityHourly.fromJson(Map<String, dynamic> json) {
    return SolarFacilityHourly(
      facId: json['facId']?.toString() ?? '',
      totalKwh: _numOrNull(json['totalKwh']) ?? 0,
      peakKwh: _numOrNull(json['peakKwh']),
      peakHour: _intOrNull(json['peakHour']),
      hours: _hours(json['hours']),
    );
  }

  /// kWh cua gio [hour]; null khi chua co du lieu.
  double? kwhAt(int hour) {
    for (final h in hours) {
      if (h.hour == hour) return h.kwh;
    }
    return null;
  }
}

class SolarHourKwh {
  /// 0..23
  final int hour;

  final double? kwh;

  const SolarHourKwh({required this.hour, required this.kwh});

  factory SolarHourKwh.fromJson(Map<String, dynamic> json) {
    return SolarHourKwh(
      hour: _intOrNull(json['hour']) ?? 0,
      kwh: _numOrNull(json['kwh']),
    );
  }
}

SolarHourKwh? _peakOf(List<SolarHourKwh> hours) {
  SolarHourKwh? peak;

  for (final h in hours) {
    final kwh = h.kwh;
    if (kwh == null) continue;
    if (peak == null || kwh > peak.kwh!) peak = h;
  }

  return peak;
}

List<SolarHourKwh> _hours(dynamic raw) {
  if (raw is! List) return const [];

  return raw
      .whereType<Map>()
      .map((e) => SolarHourKwh.fromJson(Map<String, dynamic>.from(e)))
      .toList(growable: false);
}

double? _numOrNull(dynamic value) {
  if (value == null) return null;

  if (value is num) return value.toDouble();

  return double.tryParse(value.toString());
}

int? _intOrNull(dynamic value) {
  if (value == null) return null;

  if (value is int) return value;

  if (value is num) return value.toInt();

  return int.tryParse(value.toString());
}
