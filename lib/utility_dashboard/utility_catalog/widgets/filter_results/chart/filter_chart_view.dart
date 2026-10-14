import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/polling/dashboard_polling_intervals.dart';
import '../../../../shared/polling/polling_coordinator.dart';
import '../../../../shared/polling/polling_scope.dart';
import '../../../../shared/polling/polling_task_ids.dart';
import '../../../catalog_view_models.dart';
import '../../../providers/filter_chart_controller.dart';
import '../../../providers/filter_sparkline_controller.dart';
import '../../../../shared/widgets/debounced_layout_builder.dart';
import '../../signal_chart/signal_chart_palette.dart';
import '../../signal_chart/signal_compact_card.dart';
import '../../signal_chart/signal_group_card.dart';
import '../../signal_chart/signal_status_chips.dart' show StatusSignalChip;
import '../filter_result_cells.dart';
import 'filter_chart_cartesian.dart' show filterGroupSpecOf;
import 'filter_chart_groups.dart';

/// Che do Chart cua Filter results: moi nhom signal (code, unit) mot the,
/// cho MOI device khop filter (toi da FilterChartController.maxDevices).
class FilterChartView extends StatefulWidget {
  /// Moi dong khop filter (khong chi trang hien tai).
  final List<CatalogTableRow> rows;

  /// Mo panel device (cung cach bam device trong danh sach).
  final ValueChanged<String> onOpenDevice;

  const FilterChartView({
    super.key,
    required this.rows,
    required this.onOpenDevice,
  });

  @override
  State<FilterChartView> createState() => _FilterChartViewState();
}

class _FilterChartViewState extends State<FilterChartView> {
  late FilterChartController _controller;
  late final PollingCoordinator _coordinator;
  late final String _refreshTaskId = PollingTaskIds.filterChart(this);

  late Map<String, List<String>> _signalsByDevice;

  @override
  void initState() {
    super.initState();

    _controller = context.read<FilterChartController>();

    // Nhip lam moi 30s: task scope SCADA TABLE, tu dung khi tab an / bi che
    // va chay ngay khi hien lai.
    _coordinator = context.read<PollingCoordinator>()
      ..register(
        id: _refreshTaskId,
        scope: PollingScope.scadaTable,
        interval: DashboardPollingIntervals.filterHistoryCheck,
        action: _controller.refreshStale,
        runImmediately: true,
      )
      ..start(_refreshTaskId);

    _indexDevices();
    _sync();
  }

  @override
  void didUpdateWidget(covariant FilterChartView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (identical(oldWidget.rows, widget.rows)) return;

    final before = _signalsByDevice;
    _indexDevices();

    // Polling tao danh sach dong moi: chi sync khi tap device / signal doi.
    if (!_sameDevices(before, _signalsByDevice)) _sync();
  }

  void _indexDevices() {
    final map = <String, List<String>>{};

    for (final row in widget.rows) {
      map
          .putIfAbsent(row.deviceKey, () => <String>[])
          .add(filterSignalIdOf(row));
    }

    _signalsByDevice = map;
  }

  @override
  void dispose() {
    _coordinator.unregister(_refreshTaskId);

    // Roi Filter results / ve Table: huy request, dung lam moi. Cache giu lai
    // (60s) de quay lai nhanh.
    _controller.sync(const <SparklineDeviceRequest>[]);

    super.dispose();
  }

  bool get _tooMany =>
      _signalsByDevice.length > FilterChartController.maxDevices;

  void _sync() {
    _controller.sync(
      _tooMany
          ? const <SparklineDeviceRequest>[]
          : [
              for (final entry in _signalsByDevice.entries)
                SparklineDeviceRequest(
                  deviceKey: entry.key,
                  signalIds: List<String>.unmodifiable(entry.value),
                ),
            ],
    );
  }

  static bool _sameDevices(
    Map<String, List<String>> a,
    Map<String, List<String>> b,
  ) {
    if (a.length != b.length) return false;

    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || other.length != entry.value.length) return false;

      for (var i = 0; i < other.length; i++) {
        if (other[i] != entry.value[i]) return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FilterChartController>();
    final sparklines = context.watch<FilterSparklineController>();

    if (_tooMany) {
      return _NarrowFilterMessage(deviceCount: _signalsByDevice.length);
    }

    final result = buildFilterChartGroups(
      widget.rows,
      chartSeriesOf: (row, signalId) =>
          controller.seriesFor(row.deviceKey, signalId),
      fallbackSeriesOf: sparklines.seriesFor,
      stateOf: controller.stateOf,
    );

    final switching = controller.switching;
    final empty = result.groups.isEmpty && result.status.isEmpty;

    return Column(
      children: [
        SizedBox(
          height: 2,
          child: switching
              ? const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: SignalChartColors.progress,
                )
              : null,
        ),
        Expanded(
          child: AnimatedOpacity(
            // Doi range: giu chart cu, lam mo cho toi khi range moi xong.
            opacity: switching ? .45 : 1,
            duration: const Duration(milliseconds: 150),
            child: empty
                ? const Center(
                    child: Text(
                      'No signals to chart',
                      style: TextStyle(color: SignalChartColors.mutedText),
                    ),
                  )
                : DebouncedLayoutBuilder(
                    builder: (context, constraints) => CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.all(12),
                          sliver: SliverMainAxisGroup(
                            slivers: _buildSlivers(
                              result.groups,
                              result.status,
                              controller,
                              constraints.maxWidth,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// Theo thu tu nhom (vuot -> gan nguong -> con lai): nhom >= 2 signal la
  /// mot the full width; cac nhom 1 signal lien tiep xep thanh luoi the gon.
  /// STATUS o cuoi: mot hang chip.
  List<Widget> _buildSlivers(
    List<FilterChartGroup> groups,
    List<FilterStatusItem> status,
    FilterChartController controller,
    double width,
  ) {
    final columns = width < 700
        ? 1
        : width < 1200
        ? 2
        : 3;

    final range = controller.displayRange;
    final slivers = <Widget>[];
    var singles = <FilterChartGroup>[];

    void flushSingles() {
      if (singles.isEmpty) return;

      final block = singles;
      singles = <FilterChartGroup>[];

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.only(bottom: _gap),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: _compactExtent,
              mainAxisSpacing: _gap,
              crossAxisSpacing: _gap,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final member = block[index].members.single;

              return RepaintBoundary(
                key: ValueKey(block[index].key),
                child: SignalCompactCard(
                  row: member.row,
                  series: member.series,
                  subtitle: member.row.boxDeviceId,
                  subtitleTooltip: member.fullLabel,
                  range: range,
                  loading: _isLoading(member),
                ),
              );
            }, childCount: block.length),
          ),
        ),
      );
    }

    for (final group in groups) {
      if (group.members.length == 1) {
        singles.add(group);
        continue;
      }

      flushSingles();

      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: _gap),
            child: RepaintBoundary(
              key: ValueKey(group.key),
              child: SignalGroupCard(
                group: group,
                subtitle: _groupSubtitle(group),
                range: range,
                chartHeight: _groupChartHeight,
                loading: group.members.any(_isLoading),
                chipWithSubject: true,
                singleLineColor: SignalChartColors.line(
                  group.members.first.row.rawCategory,
                ),
              ),
            ),
          ),
        ),
      );
    }

    flushSingles();

    if (status.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in status)
                StatusSignalChip(
                  row: item.row,
                  series: item.series,
                  showDevice: true,
                ),
            ],
          ),
        ),
      );
    }

    return slivers;
  }

  static const double _gap = 10;

  /// The gon: ten + gia tri + sparkline ~60px.
  static const double _compactExtent = 128;

  static const double _groupChartHeight = 170;

  /// "°C · 3 signals · 2 devices".
  static String _groupSubtitle(FilterChartGroup group) {
    final unit = filterGroupSpecOf(group).resolveUnit(group.unit);

    return [
      if (unit.isNotEmpty) unit,
      pluralize(group.members.length, 'signal'),
      pluralize(group.deviceCount, 'device'),
    ].join(' · ');
  }

  static bool _isLoading(FilterChartMember member) {
    return member.series == null &&
        (member.state == null || member.state == FilterChartLoadState.loading);
  }
}

class _NarrowFilterMessage extends StatelessWidget {
  final int deviceCount;

  const _NarrowFilterMessage({required this.deviceCount});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.filter_alt_rounded,
            size: 36,
            color: SignalChartColors.mutedText,
          ),
          const SizedBox(height: 10),
          Text(
            'Narrow the filter to view charts ($deviceCount devices)',
            style: const TextStyle(
              color: SignalChartColors.subText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Charts are available for up to '
            '${FilterChartController.maxDevices} devices.',
            style: TextStyle(color: SignalChartColors.mutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
