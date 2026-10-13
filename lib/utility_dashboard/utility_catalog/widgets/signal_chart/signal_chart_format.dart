import '../../../shared/charts/chart_hover_style.dart';
import '../../../shared/charts/signal_chart_spec.dart';
import '../../../shared/charts/signal_chart_spec_registry.dart';
import '../../models/signal_history_models.dart';

/// Spec hien thi cua mot series lich su (chart panel device va Filter results).
SignalChartSpec signalSpecOf(SignalHistorySeries series) {
  return SignalChartSpecRegistry.resolve(
    code: series.code,
    unit: series.unit,
    kind: series.kind.name.toUpperCase(),
    name: series.name,
  );
}

HoverKind hoverKindOf(SignalKind kind) {
  return switch (kind) {
    SignalKind.analog => HoverKind.analog,
    SignalKind.counter => HoverKind.counter,
    SignalKind.status => HoverKind.status,
  };
}

/// dd/MM/yyyy HH:mm, gio dia phuong.
String formatSignalTimestamp(DateTime time) {
  final local = time.toLocal();

  String two(int value) => value.toString().padLeft(2, '0');

  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
