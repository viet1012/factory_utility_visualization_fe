import '../controllers/utility_chart_catalog_controller.dart';

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
