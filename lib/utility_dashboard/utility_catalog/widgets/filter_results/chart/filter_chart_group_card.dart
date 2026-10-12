import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../models/signal_history_models.dart';
import '../../../providers/filter_chart_controller.dart';
import '../../signal_chart/signal_chart_palette.dart';
import 'filter_chart_cartesian.dart';
import 'filter_chart_groups.dart';
import 'filter_chart_legend.dart';
import 'filter_status_timeline.dart';

/// The cua mot nhom signal: header, chart theo kind, legend.
class FilterChartGroupCard extends StatefulWidget {
  final FilterChartGroup group;
  final ValueChanged<String> onOpenDevice;

  const FilterChartGroupCard({
    super.key,
    required this.group,
    required this.onOpenDevice,
  });

  @override
  State<FilterChartGroupCard> createState() => _FilterChartGroupCardState();
}

class _FilterChartGroupCardState extends State<FilterChartGroupCard> {
  static const double _chartHeight = 200;

  /// deviceKey bi an qua legend.
  final Set<String> _hidden = <String>{};

  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;

    final shown = _showAll ? group.members : group.priorityMembers;
    final drawn = [
      for (final member in shown)
        if (!_hidden.contains(member.deviceKey)) member,
    ];

    final hasData = shown.any((member) => member.series != null);
    final loading = shown.any(
      (member) => member.state == FilterChartLoadState.loading,
    );

    final isStatus = group.kind == SignalKind.status;

    final chartHeight = isStatus
        ? FilterStatusTimeline.heightFor(drawn.length.clamp(1, 999))
        : _chartHeight;

    Widget chart;

    if (!hasData && loading) {
      // Skeleton chi o lan tai dau cua nhom.
      chart = Shimmer.fromColors(
        baseColor: SignalChartColors.skeleton,
        highlightColor: SignalChartColors.skeletonHighlight,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } else if (!hasData) {
      chart = const Center(
        child: Text(
          'No history for this group',
          style: TextStyle(color: SignalChartColors.mutedText, fontSize: 12),
        ),
      );
    } else if (isStatus) {
      chart = FilterStatusTimeline(members: drawn);
    } else {
      chart = FilterChartCartesian(group: group, members: drawn);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GroupHeader(group: group),
          const SizedBox(height: 10),
          SizedBox(height: chartHeight, child: chart),
          const SizedBox(height: 10),
          FilterChartLegend(
            group: group,
            members: shown,
            hidden: _hidden,
            onToggle: (key) => setState(() {
              if (!_hidden.remove(key)) _hidden.add(key);
            }),
            onOpenDevice: widget.onOpenDevice,
          ),
          if (group.members.length > kFilterChartVisibleMembers)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(
                  _showAll
                      ? 'Show fewer'
                      : 'Show all (${group.members.length})',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final FilterChartGroup group;

  const _GroupHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    final kindLabel = switch (group.kind) {
      SignalKind.analog => 'ANALOG',
      SignalKind.counter => 'COUNTER',
      SignalKind.status => 'STATUS',
    };

    return Row(
      children: [
        Flexible(
          child: Text(
            group.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: SignalChartColors.text,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (group.subtitle != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              group.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SignalChartColors.mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (group.unit.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            group.unit,
            style: const TextStyle(
              color: SignalChartColors.subText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(width: 10),
        Text(
          kindLabel,
          style: const TextStyle(
            color: SignalChartColors.mutedText,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
          ),
        ),
        const Spacer(),
        if (group.thresholdsDiffer)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Tooltip(
              message:
                  'Devices in this group have different thresholds; '
                  'over-threshold values are marked in the legend.',
              child: Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: SignalChartColors.mutedText,
              ),
            ),
          ),
        if (group.overCount > 0)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: SignalChartColors.alert.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: SignalChartColors.alert.withValues(alpha: .35),
              ),
            ),
            child: Text(
              '${group.overCount} over threshold',
              style: const TextStyle(
                color: SignalChartColors.alert,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        Text(
          '${group.members.length} devices',
          style: const TextStyle(
            color: SignalChartColors.mutedText,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
