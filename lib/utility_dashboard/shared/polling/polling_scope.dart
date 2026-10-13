/// A lifecycle boundary for related polling tasks.
enum PollingScope {
  map,
  mapMinutely(parent: PollingScope.map),
  mapHourly(parent: PollingScope.map),
  charts,
  chartsMinutes(parent: PollingScope.charts),
  chartsHourly(parent: PollingScope.charts),
  scadaTable,
  alarms,
  facilityDetail,
  solarDetail;

  /// Scopes owned by the dashboard screen itself. They are held while a
  /// detail route (Facility detail, Solar detail) covers the dashboard; the
  /// detail scopes keep running.
  static const Set<PollingScope> dashboardScopes = {
    PollingScope.map,
    PollingScope.charts,
    PollingScope.scadaTable,
    PollingScope.alarms,
  };

  const PollingScope({this.parent});

  /// The scope that must also be active for this scope to be effective.
  final PollingScope? parent;

  Iterable<PollingScope> get selfAndAncestors sync* {
    PollingScope? current = this;
    while (current != null) {
      yield current;
      current = current.parent;
    }
  }
}
