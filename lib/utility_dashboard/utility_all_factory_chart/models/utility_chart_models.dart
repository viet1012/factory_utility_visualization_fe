import '../controllers/utility_chart_catalog_controller.dart';

class CatalogBodyVm {
  final bool loading;
  final Object? error;
  final List<SignalChartConfig> charts;

  /// Request that produced [charts]. Null until a catalog response is applied.
  final String? loadedRequestSignature;

  /// Request currently in flight, if any.
  final String? loadingRequestSignature;

  const CatalogBodyVm({
    required this.loading,
    required this.error,
    required this.charts,
    this.loadedRequestSignature,
    this.loadingRequestSignature,
  });

  /// Whether [charts] belong to [desiredSignature].
  ///
  /// Guards against rendering a previous category's charts while the new
  /// category's catalog is still loading.
  bool matches(String desiredSignature) {
    return loadedRequestSignature == desiredSignature;
  }
}
