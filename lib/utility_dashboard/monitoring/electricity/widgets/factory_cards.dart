import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/power_usage.dart';
import '../model/purpose_catalog.dart';
import 'electricity_style.dart';

Color purposeColor(PurposeSlot slot) => switch (slot) {
  PurposeSlot.machining => const Color(0xFFF59E0B),
  PurposeSlot.heatFurnace => const Color(0xFFEF4444),
  PurposeSlot.airConditioning => const Color(0xFF10B981),
  PurposeSlot.compressedAir => ElectricityColors.compressedAir,
  PurposeSlot.lighting => const Color(0xFFFDE047),
  PurposeSlot.other => ElectricityColors.other,
};

class _Segment {
  final String label;
  final Color color;
  final double current;
  final double previous;

  const _Segment(this.label, this.color, this.current, this.previous);
}

// ============================================================
// PERIOD VS PERIOD
// ============================================================

/// 2 cot chong (Previous | Current). Tam thoi chong theo fac cho den khi co
/// >= 3 purpose duoc map meter.
class PeriodCompareCard extends StatelessWidget {
  final PowerUsageResponse data;

  const PeriodCompareCard({super.key, required this.data});

  /// Ca cot (nhan tong + thanh + caption); thanh tu co theo phan con lai.
  static const double _chartHeight = 186;

  List<_Segment> _segments(bool byPurpose) {
    if (byPurpose) {
      return [
        for (final row in resolvePurposeRows(data.byPurpose))
          if (row.mapped)
            _Segment(
              row.slot.label,
              purposeColor(row.slot),
              row.purpose!.kwh ?? 0,
              row.purpose!.prevKwh ?? 0,
            ),
      ];
    }
    return [
      for (final f in data.byFactory)
        _Segment(
          f.facId,
          ElectricityColors.factory(f.facId),
          f.kwh ?? 0,
          f.prevKwh ?? 0,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final mappedPurposes = resolvePurposeRows(
      data.byPurpose,
    ).where((r) => r.mapped).length;
    final byPurpose = data.purposeConfigured && mappedPurposes >= 3;
    final segments = _segments(byPurpose);

    final prevTotal = segments.fold<double>(0, (s, e) => s + e.previous);
    final curTotal = segments.fold<double>(0, (s, e) => s + e.current);
    final maxTotal = math.max(prevTotal, curTotal);

    return ElectricityCard(
      title: 'Period vs period',
      trailing: Text(
        byPurpose ? 'by purpose' : 'by factory',
        style: const TextStyle(
          color: ElectricityColors.textFaint,
          fontSize: 11,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _StackedColumn(
                    caption: 'Previous',
                    total: prevTotal,
                    maxTotal: maxTotal,
                    values: [for (final s in segments) (s.color, s.previous)],
                    dimmed: true,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _StackedColumn(
                    caption: 'Current',
                    total: curTotal,
                    maxTotal: maxTotal,
                    values: [for (final s in segments) (s.color, s.current)],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Current ',
                style: TextStyle(
                  color: ElectricityColors.textDim,
                  fontSize: 12,
                ),
              ),
              Text(
                fmtSignedPct(data.total.changePct),
                style: TextStyle(
                  color: (data.total.changePct ?? 0) > 0
                      ? ElectricityColors.up
                      : (data.total.changePct ?? 0) < 0
                      ? ElectricityColors.down
                      : ElectricityColors.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (final s in segments)
                _LegendDot(color: s.color, label: s.label),
            ],
          ),
        ],
      ),
    );
  }
}

class _StackedColumn extends StatelessWidget {
  final String caption;
  final double total;
  final double maxTotal;
  final List<(Color, double)> values;
  final bool dimmed;

  const _StackedColumn({
    required this.caption,
    required this.total,
    required this.maxTotal,
    required this.values,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final parts = values.where((v) => v.$2 > 0).toList();

    // Cot cao nhat lap day phan con lai sau nhan tong + caption: khong tran
    // du font / text scale thay doi.
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final barHeight = maxTotal > 0
                  ? math.max(0.0, box.maxHeight - 20) * total / maxTotal
                  : 0.0;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _totalLabel(),
                  const SizedBox(height: 4),
                  _bar(parts, barHeight),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          maxLines: 1,
          style: const TextStyle(
            color: ElectricityColors.textDim,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _totalLabel() {
    return SizedBox(
      height: 16,
      child: Text(
        '${fmtKwh(total)} kWh',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: ElectricityColors.text,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _bar(List<(Color, double)> parts, double barHeight) {
    return SizedBox(
      height: barHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Column(
          children: [
            // Phan tu dau tien nam tren cung.
            for (final part in parts.reversed)
              Expanded(
                flex: math.max(1, (part.$2 * 1000 / total).round()),
                child: Container(
                  width: double.infinity,
                  color: part.$1.withValues(alpha: dimmed ? .55 : .95),
                  alignment: Alignment.center,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      if (box.maxHeight < 14) return const SizedBox();
                      return Text(
                        fmtPct(part.$2 / total * 100),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: ElectricityColors.textDim,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// BY FACTORY
// ============================================================

class FactoryDonutCard extends StatelessWidget {
  final PowerUsageResponse data;

  const FactoryDonutCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final factories = data.byFactory;
    PowerFactoryUsage? largest;
    for (final f in factories) {
      if (largest == null || (f.sharePct ?? 0) > (largest.sharePct ?? 0)) {
        largest = f;
      }
    }

    return ElectricityCard(
      title: 'By factory',
      child: Row(
        children: [
          SizedBox(
            width: 104,
            height: 104,
            child: CustomPaint(
              painter: _DonutPainter([
                for (final f in factories)
                  (ElectricityColors.factory(f.facId), f.sharePct ?? 0),
              ]),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fmtPct(largest?.sharePct),
                      style: const TextStyle(
                        color: ElectricityColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (largest != null)
                      Text(
                        largest.facId,
                        style: TextStyle(
                          color: ElectricityColors.factory(largest.facId),
                          fontSize: 10.5,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final f in factories)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: ElectricityColors.factory(f.facId),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            f.facId,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ElectricityColors.text,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          fmtPct(f.sharePct),
                          style: const TextStyle(
                            color: ElectricityColors.textDim,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        ChangeBadge(changePct: f.changePct, fontSize: 10.5),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(Color, double)> slices;

  _DonutPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - stroke / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      paint..color = ElectricityColors.track,
    );

    final sum = slices.fold<double>(0, (s, e) => s + e.$2);
    if (sum <= 0) return;

    var start = -math.pi / 2;
    const gap = 0.03;
    for (final (color, value) in slices) {
      if (value <= 0) continue;
      final sweep = value / sum * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        math.max(0, sweep - gap),
        false,
        paint..color = color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) => true;
}
