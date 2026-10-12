import 'package:flutter/material.dart';

import '../../../models/signal_history_models.dart';
import '../../signal_chart/signal_chart_palette.dart';
import 'filter_chart_groups.dart';

/// Legend cua mot nhom: moi device mot chip.
/// - mau / net: bam de an / hien duong;
/// - ten ngan: bam de mo panel device;
/// - gia tri hien tai (latest), do khi vuot nguong; device loi co dau canh bao.
class FilterChartLegend extends StatelessWidget {
  final FilterChartGroup group;
  final List<FilterChartMember> members;
  final Set<String> hidden;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onOpenDevice;

  const FilterChartLegend({
    super.key,
    required this.group,
    required this.members,
    required this.hidden,
    required this.onToggle,
    required this.onOpenDevice,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final member in members)
          _LegendChip(
            member: member,
            isStatus: group.kind == SignalKind.status,
            hidden: hidden.contains(member.deviceKey),
            onToggle: () => onToggle(member.deviceKey),
            onOpen: () => onOpenDevice(member.deviceKey),
          ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final FilterChartMember member;
  final bool isStatus;
  final bool hidden;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  const _LegendChip({
    required this.member,
    required this.isStatus,
    required this.hidden,
    required this.onToggle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final value = member.row.value;
    final hasValue = value != null && value.isFinite;

    final valueText = !hasValue
        ? '--'
        : isStatus
        ? 'Code ${value.round()}'
        : member.row.displayValue;

    final valueColor = member.overThreshold
        ? SignalChartColors.alert
        : member.row.isStale
        ? SignalChartColors.stale
        : SignalChartColors.text;

    return Opacity(
      opacity: hidden ? .45 : 1,
      child: Container(
        height: 28,
        padding: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: SignalChartColors.chipIdle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: member.overThreshold
                ? SignalChartColors.alert.withValues(alpha: .45)
                : SignalChartColors.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: hidden ? 'Show line' : 'Hide line',
              child: InkWell(
                onTap: onToggle,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: isStatus
                      ? Icon(
                          hidden
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 14,
                          color: SignalChartColors.subText,
                        )
                      : SizedBox(
                          width: 18,
                          height: 10,
                          child: CustomPaint(
                            painter: _SwatchPainter(
                              member.color,
                              member.dash,
                              crossed: hidden,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Tooltip(
              message: 'Open ${member.row.boxDeviceId}',
              child: InkWell(
                onTap: onOpen,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    member.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SignalChartColors.subText,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: SignalChartColors.mutedText,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              valueText,
              style: TextStyle(
                color: valueColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (member.hasError) ...[
              const SizedBox(width: 6),
              Tooltip(
                message:
                    member.series?.error ??
                    'Unable to load history for this device',
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: SignalChartColors.stale,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mau duong: dung mau + kieu net cua device tren chart.
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
