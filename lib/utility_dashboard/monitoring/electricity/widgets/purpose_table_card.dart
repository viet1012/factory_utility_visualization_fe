import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/power_usage.dart';
import '../model/purpose_catalog.dart';
import 'electricity_style.dart';
import 'factory_cards.dart';
import 'power_usage_header.dart';

typedef OpenMeterCallback = void Function(String facId, String boxDeviceId);

enum _CompareMode { volume, change }

/// Dong co changePct > nguong nay duoc to cam.
const double _highlightPct = 5;

const int _flexPurpose = 24;
const int _flexValues = 17;
const int _flexBars = 27;
const int _flexLast7 = 16;
const int _flexChange = 12;

class PurposeTableCard extends StatefulWidget {
  final PowerUsageResponse data;
  final PowerPeriod period;
  final OpenMeterCallback? onOpenMeter;

  const PurposeTableCard({
    super.key,
    required this.data,
    required this.period,
    this.onOpenMeter,
  });

  @override
  State<PurposeTableCard> createState() => _PurposeTableCardState();
}

class _PurposeTableCardState extends State<PurposeTableCard> {
  _CompareMode _mode = _CompareMode.volume;
  bool _compressedExpanded = true;

  String get _valuesHeader => switch (widget.period) {
    PowerPeriod.day => 'Today / yest.',
    PowerPeriod.week => 'This wk / last',
    PowerPeriod.month => 'This mo / last',
  };

  @override
  Widget build(BuildContext context) {
    final rows = resolvePurposeRows(widget.data.byPurpose);

    var maxVolume = 0.0;
    var maxChange = 0.0;
    for (final row in rows) {
      final p = row.purpose;
      if (p == null) continue;
      maxVolume = math.max(maxVolume, math.max(p.kwh ?? 0, p.prevKwh ?? 0));
      maxChange = math.max(maxChange, (p.changePct ?? 0).abs());
    }

    return ElectricityCard(
      title: 'Change by purpose',
      trailing: SegmentToggle<_CompareMode>(
        values: _CompareMode.values,
        selected: _mode,
        labelOf: (m) => m == _CompareMode.volume ? 'Volume' : 'Change',
        onChanged: (m) => setState(() => _mode = m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.data.purposeConfigured)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Purposes are not configured yet',
                style: TextStyle(
                  color: ElectricityColors.textFaint,
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          _HeaderRow(valuesHeader: _valuesHeader, mode: _mode),
          const Divider(height: 1, color: ElectricityColors.cardBorder),
          for (final row in rows) ...[
            _PurposeRow(
              row: row,
              mode: _mode,
              maxVolume: maxVolume,
              maxChange: maxChange,
              expandable: row.slot == PurposeSlot.compressedAir && row.mapped,
              expanded: _compressedExpanded,
              onToggle: () =>
                  setState(() => _compressedExpanded = !_compressedExpanded),
            ),
            if (row.slot == PurposeSlot.compressedAir &&
                row.mapped &&
                _compressedExpanded)
              _CompressedAirDetail(
                purpose: row.purpose!,
                factories: widget.data.byFactory,
                maxVolume: maxVolume,
                onOpenMeter: widget.onOpenMeter,
              ),
          ],
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final String valuesHeader;
  final _CompareMode mode;

  const _HeaderRow({required this.valuesHeader, required this.mode});

  @override
  Widget build(BuildContext context) {
    Widget cell(String text, int flex, {TextAlign align = TextAlign.left}) {
      return Expanded(
        flex: flex,
        child: Text(
          text,
          textAlign: align,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: ElectricityColors.textFaint,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 8, 6),
      child: Row(
        children: [
          cell('Purpose', _flexPurpose),
          cell(valuesHeader, _flexValues),
          cell(
            mode == _CompareMode.volume ? 'Volume compared' : 'Change compared',
            _flexBars,
          ),
          cell('Last 7 days', _flexLast7),
          cell('Change', _flexChange, align: TextAlign.right),
        ],
      ),
    );
  }
}

class _PurposeRow extends StatelessWidget {
  final PurposeRowData row;
  final _CompareMode mode;
  final double maxVolume;
  final double maxChange;
  final bool expandable;
  final bool expanded;
  final VoidCallback onToggle;

  const _PurposeRow({
    required this.row,
    required this.mode,
    required this.maxVolume,
    required this.maxChange,
    required this.expandable,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final p = row.purpose;
    final color = purposeColor(row.slot);
    final highlight = (p?.changePct ?? 0) > _highlightPct;

    Widget compare;
    if (p == null) {
      compare = const Text(
        'No meter mapped yet',
        style: TextStyle(
          color: ElectricityColors.textDim,
          fontSize: 11.5,
          fontStyle: FontStyle.italic,
        ),
      );
    } else if (mode == _CompareMode.volume) {
      compare = CompareBars(
        current: p.kwh,
        previous: p.prevKwh,
        max: maxVolume,
        color: color,
      );
    } else {
      compare = _DivergingBar(value: p.changePct, max: maxChange);
    }

    final content = Container(
      padding: const EdgeInsets.fromLTRB(9, 9, 8, 9),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: highlight ? ElectricityColors.up : Colors.transparent,
            width: 3,
          ),
          bottom: const BorderSide(color: ElectricityColors.cardBorder),
        ),
        gradient: highlight
            ? LinearGradient(
                colors: [
                  ElectricityColors.up.withValues(alpha: .14),
                  ElectricityColors.up.withValues(alpha: 0),
                ],
              )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: _flexPurpose,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    row.slot.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ElectricityColors.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (expandable)
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: ElectricityColors.textDim,
                  ),
              ],
            ),
          ),
          Expanded(
            flex: _flexValues,
            child: _ValuesText(current: p?.kwh, previous: p?.prevKwh),
          ),
          Expanded(
            flex: _flexBars,
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: compare,
            ),
          ),
          Expanded(
            flex: _flexLast7,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: p == null || p.last7.isEmpty
                  ? const Text(
                      '—',
                      style: TextStyle(color: ElectricityColors.textDim),
                    )
                  : Sparkline(values: p.last7, color: color),
            ),
          ),
          Expanded(
            flex: _flexChange,
            child: Align(
              alignment: Alignment.centerRight,
              child: ChangeBadge(changePct: p?.changePct),
            ),
          ),
        ],
      ),
    );

    final body = expandable
        ? InkWell(onTap: onToggle, child: content)
        : content;

    return row.mapped ? body : Opacity(opacity: .45, child: body);
  }
}

class _ValuesText extends StatelessWidget {
  final double? current;
  final double? previous;

  const _ValuesText({required this.current, required this.previous});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: fmtKwh(current),
            style: const TextStyle(
              color: ElectricityColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: ' / ${fmtKwh(previous)}',
            style: const TextStyle(color: ElectricityColors.textDim),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12),
    );
  }
}

/// Thanh lech tam: duong = cam (sang phai), am = xanh (sang trai).
class _DivergingBar extends StatelessWidget {
  final double? value;
  final double max;

  const _DivergingBar({required this.value, required this.max});

  @override
  Widget build(BuildContext context) {
    final v = value ?? 0;
    final fraction = max <= 0 ? 0.0 : (v.abs() / max).clamp(0.0, 1.0);
    final color = v >= 0 ? ElectricityColors.up : ElectricityColors.down;

    Widget half(bool active) => Expanded(
      child: Align(
        alignment: v >= 0 ? Alignment.centerLeft : Alignment.centerRight,
        child: active
            ? FractionallySizedBox(
                widthFactor: fraction,
                child: Container(height: 8, color: color),
              )
            : const SizedBox(height: 8),
      ),
    );

    return SizedBox(
      height: 12,
      child: Row(
        children: [
          half(v < 0),
          Container(width: 1, color: ElectricityColors.textFaint),
          half(v > 0),
        ],
      ),
    );
  }
}

// ============================================================
// COMPRESSED AIR DETAIL
// ============================================================

class _CompressedAirDetail extends StatelessWidget {
  final PowerPurposeUsage purpose;
  final List<PowerFactoryUsage> factories;
  final double maxVolume;
  final OpenMeterCallback? onOpenMeter;

  const _CompressedAirDetail({
    required this.purpose,
    required this.factories,
    required this.maxVolume,
    this.onOpenMeter,
  });

  @override
  Widget build(BuildContext context) {
    final facIds = <String>[
      for (final f in factories) normalizeFacId(f.facId),
      for (final pf in purpose.byFactory)
        if (!factories.any((f) => _sameFac(f.facId, pf.facId))) pf.facId,
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(6, 4, 0, 8),
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        color: ElectricityColors.compressedAir.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ElectricityColors.compressedAir.withValues(alpha: .25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final facId in facIds) ..._factoryBlock(facId),
        ],
      ),
    );
  }

  List<Widget> _factoryBlock(String facId) {
    PowerPurposeFactory? pf;
    for (final item in purpose.byFactory) {
      if (_sameFac(item.facId, facId)) pf = item;
    }
    PowerFactoryUsage? facTotal;
    for (final f in factories) {
      if (_sameFac(f.facId, facId)) facTotal = f;
    }

    final facColor = ElectricityColors.factory(facId);

    if (pf == null || pf.meters.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: facColor.withValues(alpha: .5),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$facId has no compressor meter',
                style: const TextStyle(
                  color: ElectricityColors.textDim,
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    final facKwh = facTotal?.kwh;
    final shareOfFac = (pf.kwh != null && facKwh != null && facKwh > 0)
        ? pf.kwh! / facKwh * 100
        : null;

    return [
      _DetailRow(
        indent: 0,
        dotColor: facColor,
        title: facId,
        subtitle: '${fmtPct(shareOfFac)} of Fac total',
        current: pf.kwh,
        previous: pf.prevKwh,
        changePct: pf.changePct,
        maxVolume: maxVolume,
        barColor: facColor,
        bold: true,
      ),
      for (final meter in pf.meters)
        _DetailRow(
          indent: 16,
          dotColor: ElectricityColors.compressedAir,
          title: meter.label.isEmpty ? meter.boxDeviceId : meter.label,
          subtitle: meter.boxDeviceId,
          current: meter.kwh,
          previous: meter.prevKwh,
          changePct: meter.changePct,
          maxVolume: maxVolume,
          barColor: ElectricityColors.compressedAir,
          onTap: onOpenMeter == null
              ? null
              : () => onOpenMeter!(facId, meter.boxDeviceId),
        ),
    ];
  }
}

bool _sameFac(String a, String b) =>
    normalizeFacId(a).toUpperCase() == normalizeFacId(b).toUpperCase();

class _DetailRow extends StatelessWidget {
  final double indent;
  final Color dotColor;
  final String title;
  final String subtitle;
  final double? current;
  final double? previous;
  final double? changePct;
  final double maxVolume;
  final Color barColor;
  final bool bold;
  final VoidCallback? onTap;

  const _DetailRow({
    required this.indent,
    required this.dotColor,
    required this.title,
    required this.subtitle,
    required this.current,
    required this.previous,
    required this.changePct,
    required this.maxVolume,
    required this.barColor,
    this.bold = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: _flexPurpose,
            child: Padding(
              padding: EdgeInsets.only(left: indent),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: title,
                            style: TextStyle(
                              color: ElectricityColors.text,
                              fontWeight: bold
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: '  $subtitle',
                            style: const TextStyle(
                              color: ElectricityColors.textFaint,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: _flexValues,
            child: _ValuesText(current: current, previous: previous),
          ),
          Expanded(
            flex: _flexBars,
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: CompareBars(
                current: current,
                previous: previous,
                max: maxVolume,
                color: barColor,
              ),
            ),
          ),
          const Spacer(flex: _flexLast7),
          Expanded(
            flex: _flexChange,
            child: Align(
              alignment: Alignment.centerRight,
              child: ChangeBadge(changePct: changePct, fontSize: 10.5),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Tooltip(message: 'Open in CHARTS › Hourly', child: row),
    );
  }
}
