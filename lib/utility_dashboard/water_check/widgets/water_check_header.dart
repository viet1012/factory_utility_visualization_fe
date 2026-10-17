import 'package:flutter/material.dart';

import '../models/water_check_models.dart';
import 'water_check_format.dart';

/// Header mot hang (36px): [subTabs] (Electricity | Water check) · "Water
/// check · Updated hh:mm" · icon info (chu giai trong tooltip) · pill tom
/// tat can phai (bam de loc) · nut Full screen cuoi hang.
class WaterCheckHeader extends StatelessWidget {
  final DateTime? generatedAt;
  final WaterCheckSummary summary;
  final WaterStatus? filter;
  final bool loading;
  final ValueChanged<WaterStatus> onToggleFilter;
  final bool fullScreen;
  final VoidCallback? onToggleFullScreen;

  /// Tab con cua MONITORING, cung hang tieu de (null khi full screen).
  final Widget? subTabs;

  const WaterCheckHeader({
    super.key,
    required this.generatedAt,
    required this.summary,
    required this.filter,
    required this.loading,
    required this.onToggleFilter,
    this.fullScreen = false,
    this.onToggleFullScreen,
    this.subTabs,
  });

  static const double height = 36;

  static const List<WaterStatus> _pillOrder = [
    WaterStatus.ok,
    WaterStatus.near,
    WaterStatus.over,
    WaterStatus.stale,
    WaterStatus.noThreshold,
    WaterStatus.stopped,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: height,
      child: Row(
        children: [
          if (subTabs != null) ...[
            subTabs!,
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: scheme.onSurfaceVariant.withValues(alpha: .3),
            ),
          ],
          const Icon(Icons.water_drop_rounded, color: kWaterAccent, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Water check',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .2,
                    ),
                  ),
                  TextSpan(
                    text: ' · Updated ${formatHhmm(generatedAt)}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 20,
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: kWaterAccent,
                      ),
                    ),
                  )
                : null,
          ),
          const _LegendInfo(),
          const Spacer(),
          for (final status in _pillOrder) ...[
            const SizedBox(width: 5),
            _StatusPill(
              status: status,
              count: summary.countOf(status),
              selected: filter == status,
              dimmed: filter != null && filter != status,
              onTap: () => onToggleFilter(status),
            ),
          ],
          if (onToggleFullScreen != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: fullScreen ? 'Exit full screen (Esc)' : 'Full screen',
              onPressed: onToggleFullScreen,
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              color: scheme.onSurfaceVariant,
              icon: Icon(
                fullScreen
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// LEGEND
// ============================================================

/// Thang: chi vung an toan xanh la, ngoai vung xam; do chi cho bat thuong
/// that (kim / gia tri / chip / vien cua hinh do).
const List<(String, Color, bool)> _legendItems = [
  ('Safe zone', kWaterOkColor, false),
  ('Outside safe zone', kWaterStaleColor, false),
  ('Near limit (chip only)', kWaterNearNeutralColor, true),
  ('Out of limit / sensor fault', kWaterOverColor, false),
  ('No limit set', kWaterStaleColor, true),
];

class _LegendSwatch extends StatelessWidget {
  final Color color;
  final bool outlined;

  const _LegendSwatch({required this.color, required this.outlined});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 6,
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: .8),
        borderRadius: BorderRadius.circular(3),
        border: outlined ? Border.all(color: color, width: 1) : null,
      ),
    );
  }
}

/// Chu giai mau: icon info, chu giai trong tooltip.
class _LegendInfo extends StatelessWidget {
  const _LegendInfo();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      richMessage: WidgetSpan(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (label, color, outlined) in _legendItems)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LegendSwatch(color: color, outlined: outlined),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(color: scheme.onSurface, fontSize: 11),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      child: Icon(
        Icons.info_outline_rounded,
        size: 16,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

// ============================================================
// PILL
// ============================================================

class _StatusPill extends StatelessWidget {
  final WaterStatus status;
  final int count;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  const _StatusPill({
    required this.status,
    required this.count,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = waterStatusColor(status);
    final outlined = status == WaterStatus.noThreshold;

    final background = outlined
        ? Colors.transparent
        : color.withValues(alpha: selected ? .32 : .14);
    final border = color.withValues(
      alpha: selected ? .95 : (outlined ? .7 : .4),
    );

    return Tooltip(
      message: selected
          ? 'Show all points'
          : 'Show only ${waterStatusLabel(status).toLowerCase()} points',
      child: Opacity(
        opacity: dimmed ? .45 : 1,
        child: Material(
          color: background,
          shape: StadiumBorder(
            side: BorderSide(color: border, width: selected ? 1.6 : 1),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WaterStatusDot(status: status, size: 7),
                  const SizedBox(width: 5),
                  Text(
                    '${waterStatusLabel(status)} $count',
                    style: TextStyle(
                      color: outlined
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
