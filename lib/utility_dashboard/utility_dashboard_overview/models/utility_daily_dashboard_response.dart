class UtilityDailyDashboardResponse {
  final String facId;
  final String month;

  final List<UtilityDailyElectricityPoint> electricity;
  final List<UtilityDailyPoint> water;
  final List<UtilityDailyPoint> air;

  const UtilityDailyDashboardResponse({
    required this.facId,
    required this.month,
    required this.electricity,
    required this.water,
    required this.air,
  });

  factory UtilityDailyDashboardResponse.fromJson(Map<String, dynamic> json) {
    return UtilityDailyDashboardResponse(
      facId: json['facId']?.toString() ?? '',
      month: json['month']?.toString() ?? '',

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

  const UtilityDailyElectricityPoint({
    required this.date,
    required this.gridKwh,
    required this.solarKwh,
    required this.totalKwh,
  });

  factory UtilityDailyElectricityPoint.fromJson(Map<String, dynamic> json) {
    return UtilityDailyElectricityPoint(
      date: DateTime.parse(
        json['date']?.toString() ?? json['recordDate']?.toString() ?? '',
      ),
      gridKwh: _toDouble(json['gridKwh']),
      solarKwh: _toDouble(json['solarKwh']),
      totalKwh: _toDouble(json['totalKwh']),
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

double _toDouble(dynamic value) {
  if (value == null) return 0;

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString()) ?? 0;
}
