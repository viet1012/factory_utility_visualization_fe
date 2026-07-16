import '../../utility_state/chart_catalog_provider.dart';

class CatalogScreenVm {
  final bool loading;
  final Object? error;

  final List<String> scadaIds;
  final List<String> boxIds;
  final List<String> boxDeviceIds;

  const CatalogScreenVm({
    required this.loading,
    required this.error,
    required this.scadaIds,
    required this.boxIds,
    required this.boxDeviceIds,
  });

  bool get hasCatalog {
    return scadaIds.isNotEmpty || boxIds.isNotEmpty || boxDeviceIds.isNotEmpty;
  }

  bool get initialLoading {
    return loading && !hasCatalog;
  }

  bool get refreshing {
    return loading && hasCatalog;
  }
}

// ============================================================
// CATALOG BODY
// ============================================================

class CatalogBodyVm {
  final bool loading;
  final Object? error;
  final List<SignalChartConfig> charts;

  const CatalogBodyVm({
    required this.loading,
    required this.error,
    required this.charts,
  });
}
