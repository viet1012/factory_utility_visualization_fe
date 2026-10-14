import 'package:flutter/material.dart';

import '../../../shared/charts/chart_thresholds.dart';
import '../../../shared/charts/signal_thresholds.dart';
import '../../../shared/charts/value_format.dart';
import '../../../shared/widgets/chart_loading_widgets.dart';
import '../../../shared/widgets/lazy_chart_gate.dart';
import '../../catalog_view_models.dart';
import '../../models/signal_history_models.dart';
import 'signal_chart_bar_plot.dart';
import 'signal_chart_format.dart';
import 'signal_chart_palette.dart';
import 'signal_chart_plot.dart';

/// The cua mot signal: PLC + status, ten + code, gia tri hien tai,
/// min · avg · max cua range, va bieu do.
class SignalChartCard extends StatelessWidget {
  final SignalHistorySeries series;

  /// Dong tuong ung trong bang, dung cho gia tri / status realtime.
  final CatalogTableRow? current;

  /// Thu lai khi rieng signal nay loi (tai lai ca device).
  final VoidCallback? onRetry;

  /// Range cua [series]: 24h / 7d ve cot (tru STATUS), con lai ve line.
  final HistoryRange? range;

  const SignalChartCard({
    super.key,
    required this.series,
    this.current,
    this.onRetry,
    this.range,
  });

  @override
  Widget build(BuildContext context) {
    final row = current;
    final spec = signalSpecOf(series);
    final unit = spec.resolveUnit(series.unit);
    final stats = SignalHistoryStats.of(series);

    String fmt(double? value) => formatValue(value, decimals: spec.decimals);
    final isCounter = series.kind == SignalKind.counter;
    final hasPoints = series.points.any(
      (point) => (isCounter ? point.delta : point.value) != null,
    );

    /*
     * Chi lay tu dong cua bang (/api/utility/latest), khong fallback ve diem
     * cuoi cua series. So le / format theo SignalChartSpec cua signal.
     */
    final currentValue = row?.value;
    final hasValue = currentValue != null && currentValue.isFinite;

    // Nguong `thresholds[]` (chi ANALOG, bo trivial).
    final lines = series.chartThresholds;
    final outOfRange =
        hasValue &&
        thresholdBreachLevel(lines, value: currentValue) != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
      decoration: BoxDecoration(
        color: SignalChartColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SignalChartColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PlcBadge(
                plc: series.plc,
                color: SignalChartColors.category(row?.category ?? ''),
              ),
              const SizedBox(width: 8),
              _KindTag(kind: series.kind),
              const Spacer(),
              _StatusDot(row: row),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            series.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: SignalChartColors.text,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (series.code != null)
            Text(
              series.code!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SignalChartColors.mutedText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                fmt(currentValue),
                style: TextStyle(
                  color: outOfRange
                      ? SignalChartColors.alert
                      : SignalChartColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              // Khong gan unit sau gia tri thieu.
              if (hasValue && unit.isNotEmpty) ...[
                const SizedBox(width: 5),
                Text(
                  unit,
                  style: const TextStyle(
                    color: SignalChartColors.subText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              // ANALOG co nguong: khoang cach toi nguong gan nhat.
              if (hasValue && lines.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: ThresholdChip(
                    thresholds: lines,
                    value: currentValue,
                    unit: unit,
                    decimals: spec.decimals,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Flexible(
                child: Text(
                  isCounter
                      ? 'total ${formatWithUnit(stats.total, unit, decimals: spec.decimals)}'
                            ' in range'
                      : 'min ${fmt(stats.min)}'
                            '  ·  avg ${fmt(stats.avg)}'
                            '  ·  max ${fmt(stats.max)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SignalChartColors.mutedText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!isCounter &&
                  series.aggregation == HistoryAggregation.snapshot) ...[
                const SizedBox(width: 6),
                const Text(
                  'hourly values',
                  style: TextStyle(
                    color: SignalChartColors.mutedText,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: series.error != null
                ? _SignalErrorBody(message: series.error!, onRetry: onRetry)
                : hasPoints
                // Chart chi tao khi the vao khung nhin lan dau.
                ? LazyChartGate(
                    placeholder: ChartBodySkeleton(
                      color: SignalChartColors.line(row?.rawCategory ?? ''),
                      withSummary: false,
                    ),
                    builder: (_) => _signalPlot(
                      series,
                      range,
                      SignalChartColors.line(row?.rawCategory ?? ''),
                    ),
                  )
                : const Center(
                    child: Text(
                      'No data in this range',
                      style: TextStyle(
                        color: SignalChartColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 24h / 7d: cot (ANALOG, COUNTER). STATUS va 1h / 6h: chart line / step.
Widget _signalPlot(
  SignalHistorySeries series,
  HistoryRange? range,
  Color color,
) {
  final period = range?.barPeriod;

  if (period != null && series.kind != SignalKind.status) {
    return SignalChartBarPlot(series: series, period: period, barColor: color);
  }

  return SignalChartPlot(series: series, lineColor: color);
}

/// Loi rieng cua mot signal: chi vung chart cua the nay hien loi.
class _SignalErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _SignalErrorBody({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 22,
            color: SignalChartColors.alert,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: SignalChartColors.subText,
              fontSize: 12,
            ),
          ),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

/// Cung style voi cot PLC cua bang.
class _PlcBadge extends StatelessWidget {
  final String plc;
  final Color color;

  const _PlcBadge({required this.plc, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Text(
        plc.isEmpty ? '--' : plc,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _KindTag extends StatelessWidget {
  final SignalKind kind;

  const _KindTag({required this.kind});

  @override
  Widget build(BuildContext context) {
    return Text(
      switch (kind) {
        SignalKind.analog => 'ANALOG',
        SignalKind.status => 'STATUS',
        SignalKind.counter => 'COUNTER',
      },
      style: const TextStyle(
        color: SignalChartColors.mutedText,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: .5,
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final CatalogTableRow? row;

  const _StatusDot({required this.row});

  @override
  Widget build(BuildContext context) {
    final current = row;

    final color = current == null
        ? SignalChartColors.mutedText
        : current.isStale
        ? SignalChartColors.stale
        : SignalChartColors.online;

    final label = current?.statusLabel.toUpperCase() ?? 'UNKNOWN';

    return Tooltip(
      message: current == null
          ? 'No live value'
          : 'Updated ${current.displayTime}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
