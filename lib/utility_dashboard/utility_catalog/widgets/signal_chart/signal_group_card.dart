import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../shared/charts/chart_thresholds.dart';
import '../../../shared/charts/signal_chart_spec.dart';
import '../../../shared/charts/value_format.dart';
import '../../../shared/widgets/chart_loading_widgets.dart';
import '../../../shared/widgets/lazy_chart_gate.dart';
import '../../models/signal_history_models.dart';
import '../filter_results/chart/filter_chart_cartesian.dart';
import '../filter_results/chart/filter_chart_groups.dart';
import 'signal_chart_bar_plot.dart';
import 'signal_chart_group_bar_plot.dart';
import 'signal_chart_palette.dart';
import 'signal_chart_plot.dart';

/// The cua mot nhom signal cung (code, unit), dung chung cho panel device
/// (Merge) va Filter results › Chart. Chi hien thi: noi goi dua vao cac
/// member da co series.
///
/// - Header: ten chung (tooltip: code, kind), dong phu, chip nguong cua
///   signal gan nguong nhat (chi ANALOG).
/// - Legend: nhan rut gon + gia tri hien tai (do khi vuot nguong); bam de
///   an / hien duong; hover hien day du box / device / PLC.
/// - Chart: 1h / 6h moi signal mot duong (mau + kieu net) mot truc Y;
///   24h / 7d thanh / cot nhom; nhom 1 signal dung chart cua signal do.
class SignalGroupCard extends StatefulWidget {
  final FilterChartGroup group;

  /// Dong phu, vd "°C · 3 signals · 2 devices".
  final String subtitle;

  /// Range cua du lieu dang hien: 24h / 7d ve cot.
  final HistoryRange? range;

  /// Chieu cao chart; null = lap day the (grid co dinh chieu cao).
  final double? chartHeight;

  /// Chua co series nao va dang tai: skeleton.
  final bool loading;

  final VoidCallback? onRetry;

  /// Chip nguong ghi ten signal gan nguong nhat ("· VCH24-9 0.12 left").
  final bool chipWithSubject;

  /// Mau duong khi nhom chi co 1 signal (theo category).
  final Color singleLineColor;

  const SignalGroupCard({
    super.key,
    required this.group,
    required this.subtitle,
    required this.range,
    required this.singleLineColor,
    this.chartHeight,
    this.loading = false,
    this.onRetry,
    this.chipWithSubject = false,
  });

  @override
  State<SignalGroupCard> createState() => _SignalGroupCardState();
}

class _SignalGroupCardState extends State<SignalGroupCard> {
  /// signalId bi an qua legend.
  final Set<String> _hidden = <String>{};

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final members = group.members;
    final single = members.length == 1;

    final spec = filterGroupSpecOf(group);
    final unit = spec.resolveUnit(group.unit);

    // Chip nguong: signal gan nguong nhat cua nhom (chi ANALOG).
    final nearest = group.kind == SignalKind.analog
        ? nearestThresholdOfGroup<FilterChartMember>(
            members,
            thresholdsOf: (member) => member.thresholds,
            valueOf: (member) => member.row.value,
          )
        : null;

    final chart = _buildChart(spec);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 10),
      decoration: BoxDecoration(
        color: SignalChartColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: group.overCount > 0
              ? SignalChartColors.alert.withValues(alpha: .35)
              : SignalChartColors.cardBorder,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Tooltip(
                  message: [
                    if (group.code.isNotEmpty) group.code,
                    _kindLabel(group.kind),
                  ].join(' · '),
                  child: Text(
                    group.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SignalChartColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  color: SignalChartColors.mutedText,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (nearest != null)
                Flexible(
                  child: ThresholdChip(
                    thresholds: nearest.thresholds,
                    value: nearest.row.value,
                    unit: unit,
                    decimals: spec.decimals,
                    subject: widget.chipWithSubject && !single
                        ? nearest.label
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 26,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final member in members)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _LegendChip(
                      member: member,
                      // Nhom 1 signal: duong mau theo category, khong an.
                      color: single ? widget.singleLineColor : member.color,
                      dash: single ? null : member.dash,
                      decimals: spec.decimals,
                      hidden: _hidden.contains(member.signalId),
                      onToggle: single
                          ? null
                          : () => setState(() {
                              if (!_hidden.remove(member.signalId)) {
                                _hidden.add(member.signalId);
                              }
                            }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (widget.chartHeight == null)
            Expanded(child: chart)
          else
            SizedBox(height: widget.chartHeight, child: chart),
        ],
      ),
    );
  }

  Widget _buildChart(SignalChartSpec spec) {
    final group = widget.group;
    final members = group.members;

    final withSeries = [
      for (final member in members)
        if (member.series != null && member.series!.error == null) member,
    ];

    if (withSeries.isEmpty) {
      if (widget.loading) {
        // Skeleton chi o lan tai dau cua nhom.
        return Shimmer.fromColors(
          baseColor: SignalChartColors.skeleton,
          highlightColor: SignalChartColors.skeletonHighlight,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }

      // Ca nhom loi: hien loi + Retry.
      final error = members
          .map((member) => member.series?.error)
          .whereType<String>()
          .firstOrNull;
      final failed = error != null || members.any((m) => m.hasError);

      return _CardMessage(
        message:
            error ??
            (failed
                ? 'Unable to load history for this group'
                : 'No data in this range'),
        onRetry: failed ? widget.onRetry : null,
      );
    }

    final isCounter = group.kind == SignalKind.counter;
    final hasPoints = withSeries.any(
      (member) => member.series!.points.any(
        (point) => (isCounter ? point.delta : point.value) != null,
      ),
    );

    if (!hasPoints) return const _CardMessage(message: 'No data in this range');

    final drawn = [
      for (final member in withSeries)
        if (!_hidden.contains(member.signalId)) member,
    ];

    if (drawn.isEmpty) return const _CardMessage(message: 'All lines hidden');

    final period = widget.range?.barPeriod;
    final lineColor = widget.singleLineColor;

    return LazyChartGate(
      placeholder: ChartBodySkeleton(color: lineColor, withSummary: false),
      builder: (_) {
        if (members.length == 1) {
          final series = drawn.single.series!;

          return period != null
              ? SignalChartBarPlot(
                  series: series,
                  period: period,
                  barColor: lineColor,
                )
              : SignalChartPlot(series: series, lineColor: lineColor);
        }

        return period != null
            ? SignalChartGroupBarPlot(
                group: group,
                members: drawn,
                period: period,
                spec: spec,
              )
            : FilterChartCartesian(group: group, members: drawn);
      },
    );
  }

  static String _kindLabel(SignalKind kind) => switch (kind) {
    SignalKind.analog => 'Analog',
    SignalKind.counter => 'Counter',
    SignalKind.status => 'Status',
  };
}

/// Chip legend: mau duong + nhan rut gon + gia tri hien tai.
class _LegendChip extends StatelessWidget {
  final FilterChartMember member;
  final Color color;
  final List<double>? dash;
  final int decimals;
  final bool hidden;

  /// Null: khong an / hien duoc (the 1 signal).
  final VoidCallback? onToggle;

  const _LegendChip({
    required this.member,
    required this.color,
    required this.dash,
    required this.decimals,
    required this.hidden,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final row = member.row;

    final valueColor = member.overThreshold
        ? SignalChartColors.alert
        : row.isStale
        ? SignalChartColors.stale
        : SignalChartColors.text;

    final chip = Opacity(
      opacity: hidden ? .45 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: SignalChartColors.chipIdle,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: member.overThreshold
                ? SignalChartColors.alert.withValues(alpha: .45)
                : SignalChartColors.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LegendLineSwatch(color: color, dash: dash, crossed: hidden),
            const SizedBox(width: 6),
            Text(
              member.label,
              style: const TextStyle(
                color: SignalChartColors.subText,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              formatValue(row.value, decimals: decimals),
              style: TextStyle(
                color: valueColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (member.hasError) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.warning_amber_rounded,
                size: 13,
                color: SignalChartColors.stale,
              ),
            ],
          ],
        ),
      ),
    );

    final tooltip = [
      member.fullLabel,
      'Updated ${row.displayTime}',
      if (member.hasError)
        member.series?.error ?? 'Unable to load history for this signal',
      if (onToggle != null) hidden ? 'Click to show' : 'Click to hide',
    ].join('\n');

    return Tooltip(
      message: tooltip,
      child: onToggle == null
          ? chip
          : InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(7),
              child: chip,
            ),
    );
  }
}

/// Mau duong (mau + kieu net) tren legend; [crossed] = dang an.
class LegendLineSwatch extends StatelessWidget {
  final Color color;
  final List<double>? dash;
  final bool crossed;

  const LegendLineSwatch({
    super.key,
    required this.color,
    required this.dash,
    this.crossed = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 10,
      child: CustomPaint(
        painter: _SwatchPainter(color, dash, crossed: crossed),
      ),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  final Color color;
  final List<double>? dash;
  final bool crossed;

  _SwatchPainter(this.color, this.dash, {required this.crossed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final y = size.height / 2;
    final pattern = dash;

    if (pattern == null || pattern.isEmpty) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    } else {
      var x = 0.0;
      var i = 0;
      while (x < size.width) {
        final length = pattern[i % pattern.length];
        if (i.isEven) {
          canvas.drawLine(
            Offset(x, y),
            Offset((x + length).clamp(0, size.width), y),
            paint,
          );
        }
        x += length;
        i++;
      }
    }

    if (crossed) {
      canvas.drawLine(
        Offset.zero,
        Offset(size.width, size.height),
        Paint()
          ..color = SignalChartColors.subText
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SwatchPainter old) {
    return old.color != color || old.dash != dash || old.crossed != crossed;
  }
}

class _CardMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _CardMessage({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: SignalChartColors.mutedText,
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
