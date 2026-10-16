import 'package:flutter/material.dart';

import '../models/water_check_models.dart';
import 'water_check_format.dart';

/// Header mot hang (~44px): "Water check" · "Updated hh:mm" · chu giai mau
/// (thieu cho thi thu thanh icon "?") · pill tom tat (bam de loc) · nut
/// Full screen.
class WaterCheckHeader extends StatelessWidget {
  final DateTime? generatedAt;
  final WaterCheckSummary summary;
  final WaterStatus? filter;
  final bool loading;
  final ValueChanged<WaterStatus> onToggleFilter;
  final bool fullScreen;
  final VoidCallback? onToggleFullScreen;

  const WaterCheckHeader({
    super.key,
    required this.generatedAt,
    required this.summary,
    required this.filter,
    required this.loading,
    required this.onToggleFilter,
    this.fullScreen = false,
    this.onToggleFullScreen,
  });

  static const double height = 44;

  /// Be rong toi thieu de hien chu giai day du ben canh tieu de + pill.
  static const double _legendBreakpoint = 1260;

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fullLegend = constraints.maxWidth >= _legendBreakpoint;

          return Row(
            children: [
              const Icon(
                Icons.water_drop_rounded,
                color: kWaterAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Water check',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .2,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Updated ${formatHhmm(generatedAt)}',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                width: 22,
                child: loading
                    ? const Center(
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: kWaterAccent,
                          ),
                        ),
                      )
                    : null,
              ),
              if (fullLegend)
                const Flexible(child: _ColorLegend())
              else
                const _LegendHelp(),
              const Spacer(),
              for (final status in _pillOrder) ...[
                const SizedBox(width: 6),
                _StatusPill(
                  status: status,
                  count: summary.countOf(status),
                  selected: filter == status,
                  dimmed: filter != null && filter != status,
                  onTap: () => onToggleFilter(status),
                ),
              ],
              if (onToggleFullScreen != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: fullScreen
                      ? 'Exit full screen (Esc)'
                      : 'Full screen',
                  onPressed: onToggleFullScreen,
                  visualDensity: VisualDensity.compact,
                  color: scheme.onSurfaceVariant,
                  icon: Icon(
                    fullScreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// LEGEND
// ============================================================

const List<(String, Color, bool)> _legendItems = [
  ('Safe zone', kWaterOkColor, false),
  ('Near limit', kWaterNearColor, false),
  ('Out of limit', kWaterOverColor, false),
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

/// Chu giai mau day du tren cung hang.
class _ColorLegend extends StatelessWidget {
  const _ColorLegend();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          for (final (label, color, outlined) in _legendItems) ...[
            const SizedBox(width: 12),
            _LegendSwatch(color: color, outlined: outlined),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chu giai thu gon: icon "?" voi tooltip.
class _LegendHelp extends StatelessWidget {
  const _LegendHelp();

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
        Icons.help_outline_rounded,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WaterStatusDot(status: status, size: 7),
                  const SizedBox(width: 6),
                  Text(
                    '${waterStatusLabel(status)} $count',
                    style: TextStyle(
                      color: outlined
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
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
