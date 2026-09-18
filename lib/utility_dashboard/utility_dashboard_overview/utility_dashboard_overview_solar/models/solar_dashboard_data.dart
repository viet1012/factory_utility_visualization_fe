class SolarDashboardData {
  final String facId;
  final DateTime? generatedAt;

  final double currentPowerKw;

  final double solarKwh;
  final double gridKwh;
  final double totalKwh;
  final double solarSharePercent;

  final double todayCo2Kg;
  final double todayCo2Ton;
  final double todayEquivalentTrees;

  const SolarDashboardData({
    required this.facId,
    required this.generatedAt,
    required this.currentPowerKw,
    required this.solarKwh,
    required this.gridKwh,
    required this.totalKwh,
    required this.solarSharePercent,
    required this.todayCo2Kg,
    required this.todayCo2Ton,
    required this.todayEquivalentTrees,
  });

  factory SolarDashboardData.fromJson(Map<String, dynamic> json) {
    return SolarDashboardData(
      facId: json['facId']?.toString() ?? 'KVH',
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? ''),
      currentPowerKw: _toDouble(json['currentPowerKw']),
      solarKwh: _toDouble(json['solarKwh']),
      gridKwh: _toDouble(json['gridKwh']),
      totalKwh: _toDouble(json['totalKwh']),
      solarSharePercent: _toDouble(json['solarSharePercent']),
      todayCo2Kg: _toDouble(json['todayCo2Kg']),
      todayCo2Ton: _toDouble(json['todayCo2Ton']),
      todayEquivalentTrees: _toDouble(json['todayEquivalentTrees']),
    );
  }

  double get gridSharePercent {
    return (100 - solarSharePercent).clamp(0, 100).toDouble();
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
