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
  static const String mapSolarMonthly = 'map.solar-monthly';
  static const String mapWeather = 'map.weather';

  static String mapMonthlyBox(String facId) {
    return 'map.monthly-box.${facId.trim()}';
  }
}
