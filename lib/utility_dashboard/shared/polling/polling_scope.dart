/// A lifecycle boundary for related polling tasks.
enum PollingScope {
  map,
  mapMinutely(parent: PollingScope.map),
  mapHourly(parent: PollingScope.map),
  charts,
  chartsMinutes(parent: PollingScope.charts),
  scadaTable,
  alarms,
  facilityDetail;

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
