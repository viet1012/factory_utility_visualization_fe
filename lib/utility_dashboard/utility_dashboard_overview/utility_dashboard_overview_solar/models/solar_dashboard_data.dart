class SolarDashboardData {
  final double solarKwh;
  final double gridKwh;
  final double solarSharePercent;

  final double todayCo2Ton;
  final double todayEquivalentTrees;

  const SolarDashboardData({
    required this.solarKwh,
    required this.gridKwh,
    required this.solarSharePercent,
    required this.todayCo2Ton,
    required this.todayEquivalentTrees,
  });

  factory SolarDashboardData.fromJson(Map<String, dynamic> json) {
    return SolarDashboardData(
      solarKwh: _toDouble(json['solarKwh']),
      gridKwh: _toDouble(json['gridKwh']),
      solarSharePercent: _toDouble(json['solarSharePercent']),
      todayCo2Ton: _toDouble(json['todayCo2Ton']),
      todayEquivalentTrees: _toDouble(json['todayEquivalentTrees']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
