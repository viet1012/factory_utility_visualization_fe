abstract final class DashboardPollingIntervals {
  static const Duration scadaLatestTree = Duration(minutes: 1);
  static const Duration facilityLatest = Duration(minutes: 1);
  static const Duration mapMinuteDashboard = Duration(seconds: 50);
  static const Duration mapHourlyDashboard = Duration(minutes: 30);
  static const Duration signalHealthMap = Duration(minutes: 5);
  static const Duration signalHealthAlarms = Duration(minutes: 1);
  static const Duration mapDailyDashboard = Duration(hours: 1);
  static const Duration mapMonthlySummary = Duration(hours: 6);
  static const Duration chartsMinuteSeries = Duration(minutes: 1);
  static const Duration mapSolarMonthly = Duration(minutes: 1);
  static const Duration mapMonthlyBox = Duration(hours: 1);
  static const Duration mapWeather = Duration(minutes: 45);
}
