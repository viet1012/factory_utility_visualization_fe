class SolarDetailData {
  final SolarDetailSummary summary;
  final List<SolarDailyTrend> dailyTrend;
  final SolarCostImpact costImpact;
  final SolarEnvironmentalImpact environmentalImpact;

  const SolarDetailData({
    required this.summary,
    required this.dailyTrend,
    required this.costImpact,
    required this.environmentalImpact,
  });

  factory SolarDetailData.fromJson(Map<String, dynamic> json) {
    final dailyRaw = json['dailyTrend'];

    return SolarDetailData(
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

  /// Solar + Grid cua ngay.
  final double totalKwh;

  /// Ty trong Solar (%) trong ngay; null khi ngay chua co tieu thu.
  final double? solarSharePercent;

  const SolarDailyTrend({
    required this.date,
    required this.solarKwh,
    required this.gridKwh,
    required this.totalKwh,
    required this.solarSharePercent,
  });

  factory SolarDailyTrend.fromJson(Map<String, dynamic> json) {
    final solar = _num(json['solarKwh']);
    final grid = _num(json['gridKwh']);
    final total = _numOrNull(json['totalKwh']) ?? solar + grid;

    return SolarDailyTrend(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime(2000),
      solarKwh: solar,
      gridKwh: grid,
      totalKwh: total,
      // Backend thieu field thi tu tinh tu solar / total.
      solarSharePercent:
          _numOrNull(json['solarSharePercent']) ??
          (total > 0 ? solar / total * 100 : null),
    );
  }
}

class SolarCostImpact {
  final double normalCostUsd;
  final double solarCostUsd;
  final double savingUsd;
  final double savingPercent;

  const SolarCostImpact({
    required this.normalCostUsd,
    required this.solarCostUsd,
    required this.savingUsd,
    required this.savingPercent,
  });

  factory SolarCostImpact.fromJson(Map<String, dynamic> json) {
    return SolarCostImpact(
      normalCostUsd: _num(json['normalCostUsd']),
      solarCostUsd: _num(json['solarCostUsd']),
      savingUsd: _num(json['savingUsd']),
      savingPercent: _num(json['savingPercent']),
    );
  }
}

class SolarEnvironmentalImpact {
  final double co2Ton;
  final double equivalentTrees;
  final double co2Factor;

  const SolarEnvironmentalImpact({
    required this.co2Ton,
    required this.equivalentTrees,
    required this.co2Factor,
  });

  factory SolarEnvironmentalImpact.fromJson(Map<String, dynamic> json) {
    return SolarEnvironmentalImpact(
      co2Ton: _num(json['co2Ton']),
      equivalentTrees: _num(json['equivalentTrees']),
      co2Factor: _num(json['co2Factor']),
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

double? _numOrNull(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString());
}
