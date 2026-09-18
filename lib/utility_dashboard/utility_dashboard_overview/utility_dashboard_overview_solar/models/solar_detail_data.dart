class SolarDetailData {
  final String facId;
  final String month;
  final DateTime? generatedAt;
  final SolarDetailSummary summary;
  final List<SolarDailyTrend> dailyTrend;
  final SolarCostImpact costImpact;
  final SolarEnvironmentalImpact environmentalImpact;
  final SolarHourlyProfile hourlyProfile;

  const SolarDetailData({
    required this.facId,
    required this.month,
    required this.generatedAt,
    required this.summary,
    required this.dailyTrend,
    required this.costImpact,
    required this.environmentalImpact,
    required this.hourlyProfile,
  });

  factory SolarDetailData.fromJson(Map<String, dynamic> json) {
    final dailyRaw = json['dailyTrend'];

    return SolarDetailData(
      facId: json['facId']?.toString() ?? '',
      month: json['month']?.toString() ?? '',
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? ''),
      summary: SolarDetailSummary.fromJson(_map(json['summary'])),
      dailyTrend: dailyRaw is List
          ? dailyRaw
                .whereType<Map>()
                .map(
                  (e) => SolarDailyTrend.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList(growable: false)
          : const [],
      costImpact: SolarCostImpact.fromJson(_map(json['costImpact'])),
      environmentalImpact: SolarEnvironmentalImpact.fromJson(
        _map(json['environmentalImpact']),
      ),
      hourlyProfile: SolarHourlyProfile.fromJson(_map(json['hourlyProfile'])),
    );
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const {};
  }
}

class SolarDetailSummary {
  final double currentPowerKw;
  final double solarKwh;
  final double gridKwh;
  final double totalKwh;
  final double solarSharePercent;

  const SolarDetailSummary({
    required this.currentPowerKw,
    required this.solarKwh,
    required this.gridKwh,
    required this.totalKwh,
    required this.solarSharePercent,
  });

  factory SolarDetailSummary.fromJson(Map<String, dynamic> json) {
    return SolarDetailSummary(
      currentPowerKw: _num(json['currentPowerKw']),
      solarKwh: _num(json['solarKwh']),
      gridKwh: _num(json['gridKwh']),
      totalKwh: _num(json['totalKwh']),
      solarSharePercent: _num(json['solarSharePercent']),
    );
  }
}

class SolarDailyTrend {
  final DateTime date;
  final double solarKwh;
  final double gridKwh;
  final double totalKwh;
  final double solarSharePercent;

  const SolarDailyTrend({
    required this.date,
    required this.solarKwh,
    required this.gridKwh,
    required this.totalKwh,
    required this.solarSharePercent,
  });

  factory SolarDailyTrend.fromJson(Map<String, dynamic> json) {
    return SolarDailyTrend(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime(2000),
      solarKwh: _num(json['solarKwh']),
      gridKwh: _num(json['gridKwh']),
      totalKwh: _num(json['totalKwh']),
      solarSharePercent: _num(json['solarSharePercent']),
    );
  }
}

class SolarCostImpact {
  final double solarEnergyKwh;
  final double normalCostVnd;
  final double solarCostVnd;
  final double savingVnd;
  final double normalCostUsd;
  final double solarCostUsd;
  final double savingUsd;
  final double savingPercent;

  const SolarCostImpact({
    required this.solarEnergyKwh,
    required this.normalCostVnd,
    required this.solarCostVnd,
    required this.savingVnd,
    required this.normalCostUsd,
    required this.solarCostUsd,
    required this.savingUsd,
    required this.savingPercent,
  });

  factory SolarCostImpact.fromJson(Map<String, dynamic> json) {
    return SolarCostImpact(
      solarEnergyKwh: _num(json['solarEnergyKwh']),
      normalCostVnd: _num(json['normalCostVnd']),
      solarCostVnd: _num(json['solarCostVnd']),
      savingVnd: _num(json['savingVnd']),
      normalCostUsd: _num(json['normalCostUsd']),
      solarCostUsd: _num(json['solarCostUsd']),
      savingUsd: _num(json['savingUsd']),
      savingPercent: _num(json['savingPercent']),
    );
  }
}

class SolarEnvironmentalImpact {
  final double co2Kg;
  final double co2Ton;
  final double equivalentTrees;
  final double co2Factor;

  const SolarEnvironmentalImpact({
    required this.co2Kg,
    required this.co2Ton,
    required this.equivalentTrees,
    required this.co2Factor,
  });

  factory SolarEnvironmentalImpact.fromJson(Map<String, dynamic> json) {
    return SolarEnvironmentalImpact(
      co2Kg: _num(json['co2Kg']),
      co2Ton: _num(json['co2Ton']),
      equivalentTrees: _num(json['equivalentTrees']),
      co2Factor: _num(json['co2Factor']),
    );
  }
}

class SolarHourlyProfile {
  final DateTime date;
  final double totalEnergyKwh;
  final double peakEnergyKwh;
  final int? peakHour;
  final List<SolarHourlyPoint> points;

  const SolarHourlyProfile({
    required this.date,
    required this.totalEnergyKwh,
    required this.peakEnergyKwh,
    required this.peakHour,
    required this.points,
  });

  factory SolarHourlyProfile.fromJson(Map<String, dynamic> json) {
    final raw = json['points'];

    return SolarHourlyProfile(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      totalEnergyKwh: _num(json['totalEnergyKwh']),
      peakEnergyKwh: _num(json['peakEnergyKwh']),
      peakHour: _intOrNull(json['peakHour']),
      points: raw is List
          ? raw
                .whereType<Map>()
                .map(
                  (e) =>
                      SolarHourlyPoint.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

class SolarHourlyPoint {
  final int hour;
  final double energyKwh;

  const SolarHourlyPoint({required this.hour, required this.energyKwh});

  factory SolarHourlyPoint.fromJson(Map<String, dynamic> json) {
    return SolarHourlyPoint(
      hour: _intOrNull(json['hour']) ?? 0,
      energyKwh: _num(json['energyKwh']),
    );
  }
}

double _num(dynamic value) {
  if (value == null) {
    return 0;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString()) ?? 0;
}

int? _intOrNull(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value.toString());
}
