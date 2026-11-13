class HourlyEnergyPoint {
  final int scaleHour;

  final double? today;
  final double? yesterday;

  /// null khi gio do khong co bang gia.
  final double? todayUsd;
  final double? yesterdayUsd;

  /// Co gio khong co bang gia -> USD chi mot phan. Lay tu diem hoac tu
  /// `priceMissing` cap response.
  final bool priceMissing;

  const HourlyEnergyPoint({
    required this.scaleHour,
    required this.today,
    required this.yesterday,
    required this.todayUsd,
    required this.yesterdayUsd,
    this.priceMissing = false,
  });

  factory HourlyEnergyPoint.fromJson(
    Map<String, dynamic> json, {
    bool priceMissing = false,
  }) {
    double? toDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();

      return double.tryParse(value.toString());
    }

    int toInt(dynamic value) {
      if (value is num) return value.toInt();

      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return HourlyEnergyPoint(
      scaleHour: toInt(json['scaleHour']),
      today: toDouble(json['today']),
      yesterday: toDouble(json['yesterday']),
      todayUsd: toDouble(json['todayUsd']),
      yesterdayUsd: toDouble(json['yesterdayUsd']),
      priceMissing: priceMissing || json['priceMissing'] == true,
    );
  }
}

class HourlySensorPoint {
  final int scaleHour;

  final double? today;
  final double? yesterday;

  const HourlySensorPoint({
    required this.scaleHour,
    required this.today,
    required this.yesterday,
  });

  factory HourlySensorPoint.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();

      return double.tryParse(value.toString());
    }

    int toInt(dynamic value) {
      if (value is num) return value.toInt();

      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return HourlySensorPoint(
      scaleHour: toInt(json['scaleHour']),
      today: toDouble(json['today']),
      yesterday: toDouble(json['yesterday']),
    );
  }
}

class UtilityHourlyDashboardResponse {
  final List<HourlyEnergyPoint> electricity;
  final List<HourlySensorPoint> water;
  final List<HourlySensorPoint> air;

  const UtilityHourlyDashboardResponse({
    required this.electricity,
    required this.water,
    required this.air,
  });

  factory UtilityHourlyDashboardResponse.fromJson(Map<String, dynamic> json) {
    final priceMissing = json['priceMissing'] == true;

    List<HourlyEnergyPoint> parseEnergy(dynamic raw) {
      if (raw is! List) return const [];

      final result =
          raw
              .whereType<Map>()
              .map(
                (item) => HourlyEnergyPoint.fromJson(
                  Map<String, dynamic>.from(item),
                  priceMissing: priceMissing,
                ),
              )
              .where((item) => item.scaleHour >= 0 && item.scaleHour <= 23)
              .toList()
            ..sort((a, b) => a.scaleHour.compareTo(b.scaleHour));

      return List<HourlyEnergyPoint>.unmodifiable(result);
    }

    List<HourlySensorPoint> parseSensor(dynamic raw) {
      if (raw is! List) return const [];

      final result =
          raw
              .whereType<Map>()
              .map(
                (item) =>
                    HourlySensorPoint.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => item.scaleHour >= 0 && item.scaleHour <= 23)
              .toList()
            ..sort((a, b) => a.scaleHour.compareTo(b.scaleHour));

      return List<HourlySensorPoint>.unmodifiable(result);
    }

    return UtilityHourlyDashboardResponse(
      electricity: parseEnergy(json['electricity']),
      water: parseSensor(json['water']),
      air: parseSensor(json['air']),
    );
  }
}
