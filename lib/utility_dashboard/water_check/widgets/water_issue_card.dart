import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/charts/value_format.dart';
import '../models/water_check_models.dart';
import 'water_check_format.dart';

/// "To check" dang MOT hang chip ngang (cao [height]): moi issue mot chip
/// "● Fac · ten ngan · gia tri (nguong) · thoi gian", mau theo trang thai.
/// Khong du cho thi chip cuoi "+N" mo danh sach day du. Khong co issue: chip
/// xanh "All normal". Bam chip -> cuon / nhap nhay diem do.
class WaterIssueCard extends StatelessWidget {
  final List<WaterIssue> issues;
  final String Function(WaterIssue issue) deviceNameOf;
  final int Function(WaterIssue issue) decimalsOf;

  /// Ten ngan cua diem do (bo phan trung ten nhom).
  final String Function(WaterIssue issue) shortNameOf;
  final ValueChanged<WaterIssue> onFocus;
  final ValueChanged<WaterIssue> onOpenChart;

  const WaterIssueCard({
    super.key,
    required this.issues,
    required this.deviceNameOf,
    required this.decimalsOf,
    required this.shortNameOf,
    required this.onFocus,
    required this.onOpenChart,
  });

  /// Chieu cao co dinh cua hang chip.
  static const double height = 28;

  /// Dong trong danh sach day du.
  static const double rowHeight = 26;

  static const double _chipGap = 6;
  static const double _chipFont = 12;

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) {
      return const SizedBox(
        height: height,
        child: Align(
          alignment: Alignment.centerLeft,
          child: _Chip(
            color: kWaterOkColor,
            icon: Icons.check_circle_rounded,
            text: 'All normal',
          ),
        ),
      );
    }

    final now = DateTime.now();
    final labels = [for (final issue in issues) _chipText(issue, now)];

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shown = _fitCount(labels, constraints.maxWidth);
          final rest = issues.length - shown;

          return Row(
            children: [
              Text(
                'To check',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: _chipFont,
                  fontWeight: FontWeight.w900,
                ),
              ),
              for (var i = 0; i < shown; i++) ...[
                const SizedBox(width: _chipGap),
                Flexible(
                  child: _Chip(
                    color: waterStatusColor(issues[i].status),
                    dot: true,
                    text: labels[i],
                    tooltip: 'Show on the board · ${issues[i].name}',
                    onTap: () => onFocus(issues[i]),
                  ),
                ),
              ],
              if (rest > 0) ...[
                const SizedBox(width: _chipGap),
                _Chip(
                  color: kWaterAccent,
                  text: '+$rest',
                  tooltip: 'Show all ${issues.length} points to check',
                  onTap: () => _showAll(context),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// "Fac_A · Tank 1A · 36.2 °C (max 35 °C) · 12 min".
  String _chipText(WaterIssue issue, DateTime now) {
    final decimals = decimalsOf(issue);
    final String reading;
    final DateTime? from;

    if (issue.status == WaterStatus.stale) {
      reading = 'No data';
      from = issue.lastSeenAt;
    } else {
      final value = formatWithUnit(issue.value, issue.unit, decimals: decimals);
      reading = issue.thresholdText.isEmpty
          ? value
          : '$value (${issue.thresholdText})';
      from = issue.since;
    }

    final name = shortNameOf(issue);
    return [
      issue.facId,
      if (name.isNotEmpty) name,
      reading,
      if (from != null) formatAge(from, now),
    ].join(' · ');
  }

  /// So chip vua hang; khong du thi chua cho chip "+N".
  int _fitCount(List<String> labels, double maxWidth) {
    double widthOf(String text, {bool dot = false}) =>
        _Chip.widthOf(text, dot: dot, fontSize: _chipFont);

    final title = _Chip.textWidth('To check', _chipFont, FontWeight.w900);
    var used = title;
    var count = 0;

    for (var i = 0; i < labels.length; i++) {
      final chip = _chipGap + widthOf(labels[i], dot: true);
      final more = i == labels.length - 1
          ? 0.0
          : _chipGap + widthOf('+${labels.length - i - 1}');
      if (used + chip + more > maxWidth) break;
      used += chip;
      count++;
    }

    // It nhat mot chip (chu co the bi cat) de hang khong rong.
    return math.max(count, math.min(1, labels.length));
  }

  Widget _row(WaterIssue issue, DateTime now, {VoidCallback? beforeAction}) {
    return SizedBox(
      height: rowHeight,
      child: _IssueRow(
        issue: issue,
        deviceName: deviceNameOf(issue),
        decimals: decimalsOf(issue),
        now: now,
        onTap: () {
          beforeAction?.call();
          onFocus(issue);
        },
        onOpenChart: () {
          beforeAction?.call();
          onOpenChart(issue);
        },
      ),
    );
  }

  /// Danh sach day du; chon mot dong thi dong panel roi cuon / mo chart.
  void _showAll(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .5),
      builder: (dialogContext) {
        void close() => Navigator.of(dialogContext).pop();

        // Dialog nam ngoai cay cua tab: cap lai theme toi cua Water check.
        return Theme(
          data: theme,
          child: Dialog(
            backgroundColor: const Color(0xFF071425),
            insetPadding: const EdgeInsets.all(40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: kWaterNearColor.withValues(alpha: .4)),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980, maxHeight: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'To check · ${issues.length}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: close,
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemExtent: rowHeight + 2,
                        itemCount: issues.length,
                        itemBuilder: (_, index) =>
                            _row(issues[index], now, beforeAction: close),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _IssueRow extends StatelessWidget {
  final WaterIssue issue;
  final String deviceName;
  final int decimals;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onOpenChart;

  const _IssueRow({
    required this.issue,
    required this.deviceName,
    required this.decimals,
    required this.now,
    required this.onTap,
    required this.onOpenChart,
  });

  @override
  Widget build(BuildContext context) {
    final title = [
      issue.facId,
      if (deviceName.isNotEmpty) deviceName,
      issue.name,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            WaterStatusDot(status: issue.status),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: _valueText()),
            const SizedBox(width: 12),
            Text(
              _rightText(),
              maxLines: 1,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            IconButton(
              tooltip: '1h chart',
              onPressed: onOpenChart,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 24),
              iconSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              icon: const Icon(Icons.show_chart_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _valueText() {
    if (issue.status == WaterStatus.stale) {
      return Text(
        _staleText(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: kWaterStaleColor,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: formatWithUnit(issue.value, issue.unit, decimals: decimals),
            style: TextStyle(
              color: waterValueColor(issue.status),
              fontWeight: FontWeight.w900,
            ),
          ),
          if (issue.thresholdText.isNotEmpty)
            TextSpan(
              text: '  ${issue.thresholdText}',
              style: const TextStyle(
                color: kWaterTextMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13),
    );
  }

  /// "No signal since 09:12 · last 2.4 m" (thieu lastSeenAt: "No signal").
  String _staleText() {
    final lastSeen = issue.lastSeenAt;
    if (lastSeen == null) return 'No signal';

    final last = formatWithUnit(
      issue.lastValue,
      issue.unit,
      decimals: decimals,
    );
    return 'No signal since ${formatHhmm(lastSeen)} · last $last';
  }

  String _rightText() {
    if (issue.status == WaterStatus.stale) {
      final lastSeen = issue.lastSeenAt;
      return lastSeen == null ? '' : '(${formatAge(lastSeen, now)})';
    }

    final since = issue.since;
    if (since != null) return formatSince(since, now);

    return formatTrend(issue.trend1h, issue.unit, decimals) ?? '';
  }
}

/// Chip trong hang "To check": vien + nen nhat theo [color], chu 12px.
class _Chip extends StatelessWidget {
  final Color color;
  final String text;
  final bool dot;
  final IconData? icon;
  final String? tooltip;
  final VoidCallback? onTap;

  const _Chip({
    required this.color,
    required this.text,
    this.dot = false,
    this.icon,
    this.tooltip,
    this.onTap,
  });

  static const double _padX = 9;
  static const double _dotSize = 7;
  static const double _dotGap = 6;

  static double textWidth(String text, double fontSize, FontWeight weight) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  /// Be rong tu nhien cua chip (khop voi [build]).
  static double widthOf(
    String text, {
    required bool dot,
    required double fontSize,
  }) {
    return _padX * 2 +
        2 +
        (dot ? _dotSize + _dotGap : 0) +
        textWidth(text, fontSize, FontWeight.w700) +
        1;
  }

  @override
  Widget build(BuildContext context) {
    final chip = Material(
      color: color.withValues(alpha: .12),
      shape: StadiumBorder(
        side: BorderSide(color: color.withValues(alpha: .5)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _padX, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot) ...[
                Container(
                  width: _dotSize,
                  height: _dotSize,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: _dotGap),
              ],
              if (icon != null) ...[
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dot
                        ? Theme.of(context).colorScheme.onSurface
                        : color,
                    fontSize: WaterIssueCard._chipFont,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}
