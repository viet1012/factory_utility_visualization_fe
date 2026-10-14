import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/charts/signal_thresholds.dart';
import '../../models/signal_history_models.dart';
import '../../providers/signal_history_controller.dart';
import '../filter_results/chart/filter_chart_cartesian.dart';
import '../filter_results/chart/filter_chart_groups.dart';
import 'signal_chart_groups.dart';
import 'signal_chart_palette.dart';
import 'signal_group_card.dart';

/// The Merge cua panel device: lay series cua cac signal trong nhom tu
/// [SignalHistoryController] roi ve bang [SignalGroupCard] (dung chung voi
/// Filter results).
class SignalChartGroupCard extends StatelessWidget {
  final SignalCardGroup group;

  /// Range cua du lieu dang hien: 24h / 7d ve cot.
  final HistoryRange? range;
  final VoidCallback onRetry;

  const SignalChartGroupCard({
    super.key,
    required this.group,
    required this.range,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final ids = group.signalIds;

    // Chi build lai khi series cua chinh cac signal trong nhom doi.
    return Selector<SignalHistoryController, List<SignalHistorySeries?>>(
      selector: (_, controller) => [
        for (final id in ids) controller.seriesById(id),
      ],
      shouldRebuild: (previous, next) {
        if (previous.length != next.length) return true;
        for (var i = 0; i < next.length; i++) {
          if (!identical(previous[i], next[i])) return true;
        }
        return false;
      },
      builder: (context, seriesList, _) {
        final chartGroup = FilterChartGroup(
          key: group.key,
          title: group.title,
          code: group.code,
          unit: group.unit,
          kind: group.kind,
          members: [
            for (var i = 0; i < group.members.length; i++)
              FilterChartMember(
                row: group.members[i].row,
                signalId: group.members[i].signalId,
                label: group.members[i].label,
                styleIndex: i,
                series: seriesList[i],
                state: null,
                thresholds:
                    seriesList[i]?.chartThresholds ?? const <SignalThreshold>[],
              ),
          ],
        );

        final unit = filterGroupSpecOf(chartGroup).resolveUnit(group.unit);

        return SignalGroupCard(
          group: chartGroup,
          subtitle: [
            if (unit.isNotEmpty) unit,
            if (group.members.length > 1)
              pluralize(group.members.length, 'signal'),
          ].join(' · '),
          range: range,
          onRetry: onRetry,
          singleLineColor: SignalChartColors.line(
            group.members.first.row.rawCategory,
          ),
        );
      },
    );
  }
}
