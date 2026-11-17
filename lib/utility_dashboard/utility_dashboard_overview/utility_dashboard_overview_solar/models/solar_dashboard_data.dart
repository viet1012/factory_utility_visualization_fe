import '../../../shared/json/json_read.dart';

class SolarDashboardData {
  final double solarKwh;
  final double gridKwh;
  final double solarSharePercent;

  final double todayCo2Ton;
  final double todayEquivalentTrees;

  /// Dien luoi official (EVN neu co, khong thi so do); null khi BE chua tra.
  /// [solarSharePercent] van tinh theo load do.
  final double? officialGridKwh;

  const SolarDashboardData({
    required this.solarKwh,
    required this.gridKwh,
    required this.solarSharePercent,
    required this.todayCo2Ton,
    required this.todayEquivalentTrees,
    this.officialGridKwh,
  });

  /// So MAINS hien thi: official, thieu thi gridKwh do.
  double get mainsKwh => officialGridKwh ?? gridKwh;

  factory SolarDashboardData.fromJson(Map<String, dynamic> json) {
    return SolarDashboardData(
      solarKwh: _toDouble(json['solarKwh']),
      gridKwh: _toDouble(json['gridKwh']),
      officialGridKwh: jsonDouble(json['officialGridKwh']),
      solarSharePercent: _toDouble(json['solarSharePercent']),
      todayCo2Ton: _toDouble(json['todayCo2Ton']),
      todayEquivalentTrees: _toDouble(json['todayEquivalentTrees']),
    );
  }

  static double _toDouble(dynamic value) => jsonDouble(value) ?? 0;
}
