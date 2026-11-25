import '../../shared/json/json_read.dart';

class UtilityDailyDashboardResponse {
  final List<UtilityDailyElectricityPoint> electricity;
  final List<UtilityDailyPoint> water;
  final List<UtilityDailyPoint> air;

  const UtilityDailyDashboardResponse({
    required this.electricity,
    required this.water,
    required this.air,
  });

  factory UtilityDailyDashboardResponse.fromJson(Map<String, dynamic> json) {
    return UtilityDailyDashboardResponse(
      electricity: (json['electricity'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(UtilityDailyElectricityPoint.fromJson)
          .toList(growable: false),

      water: (json['water'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(UtilityDailyPoint.fromJson)
          .toList(growable: false),

      air: (json['air'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(UtilityDailyPoint.fromJson)
          .toList(growable: false),
    );
  }
}

class UtilityDailyElectricityPoint {
  final DateTime date;

  /// Điện lưới thực tế
  final double gridKwh;

  /// Điện Solar
  final double solarKwh;

  /// Grid + Solar
  final double totalKwh;

  /// Dien luoi official: so EVN neu co, khong thi so do; null khi BE chua tra.
  final double? officialGridKwh;

  /// `EVN` | `MEASURED` (nguon cua [officialGridKwh]); null khi BE chua tra.
  final String? source;

  /// Tong official = officialGridKwh + solarKwh (BE tinh, lam tron 1 so).
  /// BE cu chua tra field nay thi fallback [displayGridKwh] + [solarKwh].
  final double officialTotalKwh;

  const UtilityDailyElectricityPoint({
    required this.date,
    required this.gridKwh,
    required this.solarKwh,
    required this.totalKwh,
    required this.officialTotalKwh,
    this.officialGridKwh,
    this.source,
  });

  /// Cot grid tren chart: official, thieu thi so do.
  double get displayGridKwh => officialGridKwh ?? gridKwh;

  /// Ngay chua co so EVN (dang dung so do sub-meter).
  bool get isMeasured => source == 'MEASURED';

  bool get isEvn => source == 'EVN';

  factory UtilityDailyElectricityPoint.fromJson(Map<String, dynamic> json) {
    final source = json['source']?.toString().trim().toUpperCase();
    final gridKwh = _toDouble(json['gridKwh']);
    final solarKwh = _toDouble(json['solarKwh']);
    final officialGridKwh = jsonDouble(json['officialGridKwh']);
    return UtilityDailyElectricityPoint(
      date: DateTime.parse(
        json['date']?.toString() ?? json['recordDate']?.toString() ?? '',
      ),
      gridKwh: gridKwh,
      solarKwh: solarKwh,
      totalKwh: _toDouble(json['totalKwh']),
      officialGridKwh: officialGridKwh,
      // Fallback cho BE cu chua tra officialTotalKwh.
      officialTotalKwh:
          jsonDouble(json['officialTotalKwh']) ??
          (officialGridKwh ?? gridKwh) + solarKwh,
      source: source == null || source.isEmpty ? null : source,
    );
  }
}

class UtilityDailyPoint {
  final DateTime date;
  final double value;

  const UtilityDailyPoint({required this.date, required this.value});

  factory UtilityDailyPoint.fromJson(Map<String, dynamic> json) {
    return UtilityDailyPoint(
      date: DateTime.parse(
        json['date']?.toString() ?? json['recordDate']?.toString() ?? '',
      ),
      value: _toDouble(json['value']),
    );
  }
}

double _toDouble(dynamic value) => jsonDouble(value) ?? 0;
