abstract final class PollingTaskIds {
  static const String scadaLatestTree = 'scada.latest-tree';
  static const String facilityLatest = 'facility.latest';
  static const String mapMinuteDashboard = 'map.minute-dashboard';
  static const String mapHourlyDashboard = 'map.hourly-dashboard';
  static const String signalHealthMap = 'map.signal-health';
  static const String signalHealthAlarms = 'alarms.signal-health';
  static const String mapDailyDashboard = 'map.daily-dashboard';
  static const String mapMonthlySummary = 'map.monthly-summary';
  static const String chartsMinuteSeries = 'charts.minute-series';
  static const String chartsHourlySeries = 'charts.hourly-series';
  static const String mapSolarMonthly = 'map.solar-monthly';
  static const String mapWeather = 'map.weather';

  /// Moi instance mot id: route co the duoc push hai lan (bam dup).
  static String solarDetail(Object owner) {
    return 'solar.detail.${identityHashCode(owner)}';
  }

  /// Chart thiet bi o SCADA TABLE; interval doi theo range.
  static String catalogDeviceChart(Object owner) {
    return 'scada.device-chart.${identityHashCode(owner)}';
  }

  static String mapMonthlyBox(String facId) {
    return 'map.monthly-box.${facId.trim()}';
  }
}
