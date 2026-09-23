import 'package:flutter/material.dart';

import '../../../shared/widgets/chart_state_widgets.dart';
import '../../controllers/signal_health_history_controller.dart';
import '../../models/signal_health_history_models.dart';
import '../../signal_health_style.dart';
import '../../utils/signal_health_history_utils.dart';
import 'signal_health_history_description_chart.dart';
import 'signal_health_history_detail.dart';
import 'signal_health_history_device_chart.dart';
import 'signal_health_history_filter.dart';
import 'signal_health_history_level_cards.dart';
import 'signal_health_history_trend_chart.dart';

/// Root widget for HISTORY mode.
///
/// Owns layout and wiring only: every number it renders comes from the
/// aggregation helpers in [signal_health_history_utils], and all fetching is
/// delegated to [SignalHealthHistoryController]. This keeps the aggregation out
/// of both this widget and `SignalHealthMatrixScreen`.
class SignalHealthHistoryPanel extends StatelessWidget {
  final SignalHealthHistoryController controller;

  /// Facet options sourced from the CURRENT-mode matrix, so History offers the
  /// same Facility/Category/SCADA/Device vocabulary the user already sees.
  final List<String> facOptions;
  final List<String> cateOptions;
  final List<String> scadaOptions;
  final List<String> boxDeviceOptions;

  const SignalHealthHistoryPanel({
    super.key,
    required this.controller,
    required this.facOptions,
    required this.cateOptions,
    required this.scadaOptions,
    required this.boxDeviceOptions,
  });

  @override
  Widget build(BuildContext context) {
    final buckets = controller.buckets;

    final busy = controller.loading || controller.refreshing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SignalHealthHistoryFilterBar(
          filter: controller.filter,
          facOptions: facOptions,
          cateOptions: cateOptions,
          scadaOptions: scadaOptions,
          boxDeviceOptions: boxDeviceOptions,
          busy: busy,
          onChanged: controller.applyFilter,
          onRefresh: controller.refresh,
        ),
        const SizedBox(height: 8),
        if (controller.error != null && controller.hasData) _errorRibbon(),
        Expanded(child: _content(buckets)),
      ],
    );
  }

  /// Non-blocking failure notice shown when a refresh failed but the previous
  /// range is still on screen.
  Widget _errorRibbon() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kOrange.withValues(alpha: .10),
        border: Border.all(color: kOrange.withValues(alpha: .38)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: kOrange, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'History refresh failed. Showing the last loaded range.',
              style: TextStyle(color: kOrange, fontSize: 11.5),
            ),
          ),
          TextButton(
            onPressed: controller.retry,
            style: TextButton.styleFrom(
              foregroundColor: kOrange,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(List<SignalHealthHistoryBucket> buckets) {
    if (controller.loading && !controller.hasData) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (controller.error != null && !controller.hasData) {
      return ChartApiErrorState(
        color: Colors.redAccent,
        onRetry: controller.retry,
      );
    }

    if (buckets.isEmpty) {
      return const EmptyChartState(
        title: 'No History Data',
        message: 'No alerts were recorded for the selected range and filters.',
      );
    }

    /*
     * Toan bo aggregation chay o day, mot lan moi build, qua lop utils.
     * Selection level/description duoc truyen xuong de chart va drill-down
     * cung nhin mot tap du lieu.
     */
    final level = controller.selectedLevel;
    final descriptionKey = controller.selectedDescriptionKey;

    final trend = buildTrendSeries(buckets);

    final descriptions = buildTopDescriptions(buckets, levelFilter: level);

    final devices = buildTopDevices(
      buckets,
      levelFilter: level,
      descriptionKey: descriptionKey,
    );

    final selectedDevice = controller.selectedBoxDeviceId;

    final detailSignals = selectedDevice == null
        ? const <SignalHealthHistorySignal>[]
        : collectSignalsForDevice(
            buckets,
            selectedDevice,
            levelFilter: level,
            descriptionKey: descriptionKey,
          );

    final rangeLabel = formatRangeLabel(
      controller.filter.from,
      controller.filter.to,
    );

    final inconsistent = findInconsistentBuckets(buckets);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (inconsistent.isNotEmpty) _consistencyNotice(inconsistent.length),
          if (level != null || descriptionKey != null)
            _selectionBar(level: level, descriptionKey: descriptionKey),

          // Row 1 - level cards: severity + range total.
          SignalHealthHistoryLevelCards(
            level1Trend: buildLevelTrend(
              buckets,
              SignalHealthAlertLevel.level1,
            ),
            level2Trend: buildLevelTrend(
              buckets,
              SignalHealthAlertLevel.level2,
            ),
            level3Trend: buildLevelTrend(
              buckets,
              SignalHealthAlertLevel.level3,
            ),
            selectedLevel: level,
            onLevelTapped: controller.toggleLevel,
          ),
          const SizedBox(height: 12),

          /*
           * Row 2 - hourly trend by level.
           *
           * 300 thay vi 260: sau khi tru padding cua card, khoi tieu de va
           * legend, 260 chi con ~168px vung ve - khong du cho tooltip khi con
           * tro o gan day, gay overflow. 300 cho tooltip du cho lat len/xuong.
           */
          SizedBox(
            height: 300,
            child: SignalHealthHistoryTrendChart(points: trend),
          ),
          const SizedBox(height: 12),

          // Row 3 - top descriptions and top devices.
          SizedBox(
            height: 300,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SignalHealthHistoryDescriptionChart(
                    items: descriptions,
                    selectedKey: descriptionKey,
                    onDescriptionSelected: controller.toggleDescription,
                    rangeLabel: rangeLabel,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SignalHealthHistoryDeviceChart(
                    items: devices,
                    selectedBoxDeviceId: selectedDevice,
                    onDeviceSelected: controller.selectDevice,
                    rangeLabel: rangeLabel,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Row 4 - drill-down for the selected device.
          SizedBox(
            height: 320,
            child: SignalHealthHistoryDetail(
              boxDeviceId: selectedDevice,
              signals: detailSignals,
              onClear: () => controller.selectDevice(null),
            ),
          ),
        ],
      ),
    );
  }

  /// Non-blocking notice when a bucket's errorCount disagrees with the sum of
  /// its level counts. Charts still render from the level data.
  Widget _consistencyNotice(int bucketCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kOrange.withValues(alpha: .08),
        border: Border.all(color: kOrange.withValues(alpha: .30)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: kOrange, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$bucketCount hourly bucket(s) report an errorCount that does '
              'not match the sum of their alert levels.',
              style: const TextStyle(color: kOrange, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  /// Breadcrumb for the active level/description narrowing, with a clear-all.
  Widget _selectionBar({
    required SignalHealthAlertLevel? level,
    required String? descriptionKey,
  }) {
    final chips = <String>[
      if (level != null) level.label,
      if (descriptionKey != null) 'Selected description',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded, color: kBlue, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filtered by ${chips.join('  •  ')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: kSubText, fontSize: 11.5),
            ),
          ),
          TextButton(
            onPressed: controller.clearSelection,
            style: TextButton.styleFrom(
              foregroundColor: kBlue,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(
              'Clear',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared titled card shell for the three History charts.
///
/// Lives here rather than in its own file so the History widget set matches the
/// agreed file layout; it reuses [cardDecoration] from `signal_health_style`.
class SignalHealthHistoryChartShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  /// Optional longer explanation, surfaced behind an info icon beside the
  /// title so the subtitle can stay short.
  final String? helpText;

  const SignalHealthHistoryChartShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.helpText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                height: 28,
                width: 28,
                decoration: BoxDecoration(
                  color: kBlue.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: kBlue, size: 16),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: kText,
                              fontSize: 13.5,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (helpText != null) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: helpText!,
                            triggerMode: TooltipTriggerMode.tap,
                            showDuration: const Duration(seconds: 8),
                            textStyle: const TextStyle(
                              color: kText,
                              fontSize: 11.5,
                            ),
                            decoration: BoxDecoration(
                              color: kCard2,
                              border: Border.all(color: kBorder),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              color: kSubText,
                              size: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kSubText, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}
