/// Format gia tri signal cua bang SCADA TABLE (bang device, Filter results):
/// boc [formatValue] voi SignalChartSpec cua signal, de bang va card chart
/// luon hien cung mot con so (cung so le, thieu du lieu `—`).
library;

import '../shared/charts/signal_chart_spec.dart';
import '../shared/charts/value_format.dart';

/// Gan them unit (hoac unitOverride cua spec). Khong gan unit khi gia tri
/// thieu.
String formatCatalogValueWithUnit(
  double? value,
  String? unit,
  SignalChartSpec spec,
) {
  return formatWithUnit(
    value,
    spec.resolveUnit(unit),
    decimals: spec.decimals,
  );
}
