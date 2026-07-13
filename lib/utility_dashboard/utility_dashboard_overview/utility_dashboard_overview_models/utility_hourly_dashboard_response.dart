class HourlyEnergyPoint {
  final int scaleHour;

  final double? today;
  final double? yesterday;

  final double? todayUsd;
  final double? yesterdayUsd;

  const HourlyEnergyPoint({
    required this.scaleHour,
    required this.today,
    required this.yesterday,
    required this.todayUsd,
    required this.yesterdayUsd,
  });

  factory HourlyEnergyPoint.fromJson(Map<String, dynamic> json) {
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
  final String facId;
  final DateTime? generatedAt;

  final List<HourlyEnergyPoint> electricity;
  final List<HourlySensorPoint> water;
  final List<HourlySensorPoint> air;

  const UtilityHourlyDashboardResponse({
    required this.facId,
    required this.generatedAt,
    required this.electricity,
    required this.water,
    required this.air,
  });

  factory UtilityHourlyDashboardResponse.fromJson(Map<String, dynamic> json) {
    List<HourlyEnergyPoint> parseEnergy(dynamic raw) {
      if (raw is! List) return const [];

      final result =
          raw
              .whereType<Map>()
              .map(
                (item) =>
                    HourlyEnergyPoint.fromJson(Map<String, dynamic>.from(item)),
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
      facId: (json['facId'] ?? '').toString().trim(),
      generatedAt: DateTime.tryParse((json['generatedAt'] ?? '').toString()),
      electricity: parseEnergy(json['electricity']),
      water: parseSensor(json['water']),
      air: parseSensor(json['air']),
    );
  }
}
