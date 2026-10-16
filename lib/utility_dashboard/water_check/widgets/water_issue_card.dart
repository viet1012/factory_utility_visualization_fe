import 'package:flutter/material.dart';

import '../../shared/charts/value_format.dart';
import '../models/water_check_models.dart';
import 'water_check_format.dart';

/// Card "To check": toi da [maxRows] dong; nhieu hon thi dong cuoi la
/// "+N more" mo danh sach day du. Khong co issue: mot dong xanh gon.
/// Bam dong -> cuon toi diem do.
class WaterIssueCard extends StatelessWidget {
  final List<WaterIssue> issues;
  final String Function(WaterIssue issue) deviceNameOf;
  final int Function(WaterIssue issue) decimalsOf;
  final ValueChanged<WaterIssue> onFocus;
  final ValueChanged<WaterIssue> onOpenChart;

  const WaterIssueCard({
    super.key,
    required this.issues,
    required this.deviceNameOf,
    required this.decimalsOf,
    required this.onFocus,
    required this.onOpenChart,
  });

  static const double rowHeight = 26;
  static const int maxRows = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (issues.isEmpty) {
      return Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: kWaterOkColor.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kWaterOkColor.withValues(alpha: .35)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 15, color: kWaterOkColor),
            SizedBox(width: 8),
            Text(
              'All water points normal',
              style: TextStyle(
                color: kWaterOkColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final overflow = issues.length > maxRows;
    final shown = overflow ? issues.take(maxRows - 1).toList() : issues;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kWaterNearColor.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            height: rowHeight,
            child: Row(
              children: [
                Text(
                  'To check',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${issues.length}',
                  style: const TextStyle(
                    color: kWaterNearColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final issue in shown) _row(issue, now),
                if (overflow)
                  SizedBox(
                    height: rowHeight,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _showAll(context),
                        icon: const Icon(Icons.unfold_more_rounded, size: 15),
                        label: Text('+${issues.length - shown.length} more'),
                        style: TextButton.styleFrom(
                          foregroundColor: kWaterAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 22),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
