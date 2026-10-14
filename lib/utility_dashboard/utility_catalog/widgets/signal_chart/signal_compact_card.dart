import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../shared/charts/chart_thresholds.dart';
import '../../../shared/charts/signal_chart_spec.dart';
import '../../../shared/charts/signal_chart_spec_registry.dart';
import '../../../shared/charts/value_format.dart';
import '../../../shared/widgets/chart_loading_widgets.dart';
import '../../../shared/widgets/lazy_chart_gate.dart';
import '../../catalog_view_models.dart';
import '../../models/signal_history_models.dart';
import 'signal_chart_bar_plot.dart';
import 'signal_chart_format.dart';
import 'signal_chart_palette.dart';
import 'signal_chart_plot.dart';

/// The gon cua MOT signal, dung chung cho panel device (Split) va Filter
/// results (nhom 1 signal):
/// - dong 1: ten (tooltip: code, kind, PLC) + [subtitle] chu nho mo + cham
///   trang thai (tooltip: online / stale + thoi gian);
/// - dong 2: gia tri hien tai + don vi, chip nguong ben phai (chi ANALOG);
/// - chart khong nhan truc; hover hien thoi gian, avg, min–max, samples.
class SignalCompactCard extends StatelessWidget {
  /// Dong cua bang: gia tri / trang thai realtime, ten khi chua co series.
  final CatalogTableRow row;

  /// Null = chua tai (xem [loading]) hoac khong co lich su.
  final SignalHistorySeries? series;

  /// Chu nho canh ten: PLC (panel device) hoac ten device (Filter results).
  final String subtitle;
  final String? subtitleTooltip;

  /// Range cua [series]: 24h / 7d ve cot, con lai ve line.
  final HistoryRange? range;

  /// Chieu cao chart; null = lap day the (grid co dinh chieu cao).
  final double? chartHeight;

  final bool loading;
  final VoidCallback? onRetry;

  const SignalCompactCard({
    super.key,
    required this.row,
    required this.series,
    required this.subtitle,
    this.subtitleTooltip,
    this.range,
    this.chartHeight,
    this.loading = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final history = series;
    final spec = history != null ? signalSpecOf(history) : _rowSpec(row);
    final unit = spec.resolveUnit(history?.unit ?? row.normalizedUnit);
    final lineColor = SignalChartColors.line(row.rawCategory);

    /*
     * Chi lay tu dong cua bang (/api/utility/latest), khong fallback ve diem
     * cuoi cua series. So le / format theo SignalChartSpec cua signal.
     */
    final currentValue = row.value;
    final hasValue = currentValue != null && currentValue.isFinite;

    // Nguong `thresholds[]` (chi ANALOG, bo trivial).
    final lines = history?.chartThresholds ?? const [];
    final match = hasValue ? nearestThreshold(lines, currentValue) : null;
    final outOfRange = match?.breached ?? false;

    final name = history?.name ?? row.displaySignalName;
    final code = history?.code ?? row.normalizedCateId;

    final chart = _buildChart(history, lineColor);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 10, 8),
      decoration: BoxDecoration(
        color: SignalChartColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: outOfRange
              ? SignalChartColors.alert.withValues(alpha: .35)
              : SignalChartColors.cardBorder,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Tooltip(
                  message: [
                    if (code.isNotEmpty) code,
                    if (history != null) _kindLabel(history.kind),
                    'PLC ${row.plcAddress}',
                  ].join(' · '),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SignalChartColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Tooltip(
                  message: subtitleTooltip ?? '',
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SignalChartColors.mutedText,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              _StatusDot(row: row),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatValue(currentValue, decimals: spec.decimals),
                style: TextStyle(
                  color: outOfRange
                      ? SignalChartColors.alert
                      : SignalChartColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              // Khong gan unit sau gia tri thieu.
              if (hasValue && unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: const TextStyle(
                    color: SignalChartColors.subText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const Spacer(),
              if (match != null)
                Flexible(
                  flex: 3,
                  child: ThresholdChip(
                    thresholds: lines,
                    value: currentValue,
                    unit: unit,
                    decimals: spec.decimals,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (chartHeight == null)
            Expanded(child: chart)
          else
            SizedBox(height: chartHeight, child: chart),
        ],
      ),
    );
  }

  Widget _buildChart(SignalHistorySeries? history, Color lineColor) {
    if (history == null) {
      if (loading) {
        return Shimmer.fromColors(
          baseColor: SignalChartColors.skeleton,
          highlightColor: SignalChartColors.skeletonHighlight,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
      }

      return _ChartError(
        message: 'Unable to load history for this signal',
        onRetry: onRetry,
      );
    }

    if (history.error != null) {
      return _ChartError(message: history.error!, onRetry: onRetry);
    }

    final isCounter = history.kind == SignalKind.counter;
    final hasPoints = history.points.any(
      (point) => (isCounter ? point.delta : point.value) != null,
    );

    if (!hasPoints) {
      return const Center(
        child: Text(
          'No data in this range',
          style: TextStyle(color: SignalChartColors.mutedText, fontSize: 11.5),
        ),
      );
    }

    // Chart chi tao khi the vao khung nhin lan dau.
    return LazyChartGate(
      placeholder: ChartBodySkeleton(color: lineColor, withSummary: false),
      builder: (_) {
        final period = range?.barPeriod;

        // 24h / 7d: cot (ANALOG, COUNTER). STATUS va 1h / 6h: line / step.
        if (period != null && history.kind != SignalKind.status) {
          return SignalChartBarPlot(
            series: history,
            period: period,
            barColor: lineColor,
            compact: true,
          );
        }

        return SignalChartPlot(
          series: history,
          lineColor: lineColor,
          compact: true,
        );
      },
    );
  }

  static SignalChartSpec _rowSpec(CatalogTableRow row) {
    return SignalChartSpecRegistry.forKind(row.spec, row.kind);
  }

  static String _kindLabel(SignalKind kind) => switch (kind) {
    SignalKind.analog => 'Analog',
    SignalKind.counter => 'Counter',
    SignalKind.status => 'Status',
  };
}

/// Loi rieng cua mot signal: chi vung chart cua the nay hien loi.
class _ChartError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ChartError({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 16,
          color: SignalChartColors.alert,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: SignalChartColors.subText,
              fontSize: 11,
            ),
          ),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

/// Cham trang thai (khong chu); tooltip: online / stale + thoi gian.
class _StatusDot extends StatelessWidget {
  final CatalogTableRow row;

  const _StatusDot({required this.row});

  @override
  Widget build(BuildContext context) {
    final stale = row.isStale;

    return Tooltip(
      message: '${stale ? 'Stale' : 'Online'} · updated ${row.displayTime}',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: stale ? SignalChartColors.stale : SignalChartColors.online,
        ),
      ),
    );
  }
}
