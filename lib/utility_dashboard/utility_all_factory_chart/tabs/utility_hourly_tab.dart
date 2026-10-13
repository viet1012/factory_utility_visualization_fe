import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/utility_chart_catalog_controller.dart';
import '../controllers/utility_hourly_chart_controller.dart';
import '../../utility_dashboard_common/chart_theme.dart';
import '../../shared/widgets/chart_loading_widgets.dart';
import '../../shared/widgets/chart_state_widgets.dart';
import '../models/utility_chart_models.dart';
import '../models/utility_hourly_models.dart';
import '../widgets/utility_glass_tab_row.dart';
import '../widgets/utility_hourly_chart_grid.dart';

class UtilityHourlyTab extends StatefulWidget {
  final bool isActive;
  final String facId;
  final String cate;
  final String? scadaId;

  /// Giong Minutes: ALL, DB-03_ES35-SW, DB-03_MFM384...
  final String selectedBox;

  final bool importantOnly;

  const UtilityHourlyTab({
    super.key,
    required this.isActive,
    required this.facId,
    required this.cate,
    required this.scadaId,
    required this.selectedBox,
    required this.importantOnly,
  });

  @override
  State<UtilityHourlyTab> createState() => _UtilityHourlyTabState();
}

class _UtilityHourlyTabState extends State<UtilityHourlyTab> {
  String _lastLoadSignature = '';

  /// Grid da ve lan truoc (catalog khop). Doi filter: giu grid nay mo kem
  /// progress bar cho toi khi catalog moi ve, khong nhay ve skeleton.
  Widget? _lastGrid;

  /// Catalog chua khop request hien tai.
  Widget _pendingBody(Color color) {
    final last = _lastGrid;
    if (last == null) return ChartGridSkeleton(color: color);

    return ChartBusyOverlay(busy: true, color: color, child: last);
  }

  Widget _showGrid(Widget grid, Color color) {
    _lastGrid = grid;
    return ChartBusyOverlay(busy: false, color: color, child: grid);
  }

  @override
  void didUpdateWidget(covariant UtilityHourlyTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    /*
     * Roi tab (hoac roi screen): huy request dang chay.
     * Quay lai tab: reset signature de load lai; controller dung cache 60s
     * nen quay lai nhanh se khong goi API.
     */
    if (oldWidget.isActive && !widget.isActive) {
      _lastLoadSignature = '';
      context.read<UtilityHourlyChartController>().cancel();
    } else if (!oldWidget.isActive && widget.isActive) {
      _lastLoadSignature = '';
    }
  }

  /// Device -> PLC da sort cua cac signal dang hien thi (cung bo loc voi
  /// UtilityHourlyChartGrid; catalog da loc Important / slave). Device khong
  /// con signal nao thi khong co trong map nen khong goi request.
  Map<String, List<String>> _resolvePlcsByBox(List<SignalChartConfig> charts) {
    final selected = widget.selectedBox.trim().toUpperCase();
    final showAll = selected.isEmpty || selected == 'ALL';

    final result = <String, Set<String>>{};

    for (final chart in charts) {
      final deviceId = chart.boxDeviceId.trim();
      final plc = chart.plcAddress.trim();

      if (deviceId.isEmpty || plc.isEmpty) continue;
      if (!showAll && deviceId.toUpperCase() != selected) continue;

      result.putIfAbsent(deviceId, () => <String>{}).add(plc);
    }

    final devices = result.keys.toList()..sort();

    return {
      for (final device in devices) device: result[device]!.toList()..sort(),
    };
  }

  void _scheduleLoad(
    List<SignalChartConfig> charts,
    String desiredSignature,
    UtilityHourlyRange range,
  ) {
    if (!widget.isActive) return;

    final catalog = context.read<UtilityChartCatalogController>();

    if (catalog.loadedRequestSignature != desiredSignature) return;

    final plcsByBox = _resolvePlcsByBox(charts);

    if (plcsByBox.isEmpty) return;

    // Request identity: range + PLC dang hien thi cua tung device. Doi switch
    // Important doi tap PLC nen load lai (controller chi tai phan con thieu).
    final signature = [
      range.name,
      for (final MapEntry(key: device, value: plcs) in plcsByBox.entries)
        '$device:${plcs.join(',')}',
    ].join('|');

    if (_lastLoadSignature == signature) return;

    _lastLoadSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive) return;

      if (context
              .read<UtilityChartCatalogController>()
              .loadedRequestSignature !=
          desiredSignature) {
        return;
      }

      unawaited(
        context.read<UtilityHourlyChartController>().load(plcsByBox: plcsByBox),
      );
    });
  }

  void _retryCatalog() {
    context.read<UtilityChartCatalogController>().loadCatalog(
      facId: widget.facId,
      cate: widget.cate,
      importantOnly: widget.importantOnly ? 1 : 0,
      forceRefresh: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChartThemes.byCate(widget.cate);

    final range = context
        .select<UtilityHourlyChartController, UtilityHourlyRange>(
          (controller) => controller.range,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HourlyRangeBar(
          range: range,
          theme: theme,
          onChanged: (next) {
            context.read<UtilityHourlyChartController>().changeRange(next);
          },
        ),
        const SizedBox(height: 6),
        Expanded(child: _buildBody(theme, range)),
      ],
    );
  }

  Widget _buildBody(ChartTheme theme, UtilityHourlyRange range) {
    final desiredSignature =
        UtilityChartCatalogController.buildRequestSignature(
          facId: widget.facId,
          cate: widget.cate,
          importantOnly: widget.importantOnly ? 1 : 0,
        );

    return Selector<UtilityChartCatalogController, CatalogBodyVm>(
      selector: (_, provider) {
        return CatalogBodyVm(
          loading: provider.loading,
          error: provider.error,
          charts: provider.charts,
          loadedRequestSignature: provider.loadedRequestSignature,
          loadingRequestSignature: provider.loadingRequestSignature,
        );
      },
      shouldRebuild: (previous, next) {
        return previous.loading != next.loading ||
            previous.error != next.error ||
            previous.loadedRequestSignature != next.loadedRequestSignature ||
            previous.loadingRequestSignature != next.loadingRequestSignature ||
            !identical(previous.charts, next.charts);
      },
      builder: (context, vm, _) {
        // Charts dang luu co the thuoc category truoc: khong dung khi lech.
        if (!vm.matches(desiredSignature)) {
          if (vm.error != null && !vm.loading) {
            return ChartApiErrorState(
              color: theme.line,
              onRetry: _retryCatalog,
            );
          }

          return _pendingBody(theme.line);
        }

        if (vm.error != null && vm.charts.isEmpty) {
          return ChartApiErrorState(color: theme.line, onRetry: _retryCatalog);
        }

        if (vm.charts.isEmpty) {
          return EmptyChartState(
            icon: Icons.sensors_off_rounded,
            title: 'No Signals Available',
            message:
                'No utility signals found in '
                '${widget.selectedBox} / '
                '${widget.scadaId ?? "-"}',
            color: Colors.white.withValues(alpha: .58),
          );
        }

        _scheduleLoad(vm.charts, desiredSignature, range);

        return _showGrid(
          UtilityHourlyChartGrid(
            charts: vm.charts,
            facId: widget.facId,
            cate: widget.cate,
            scadaId: widget.scadaId,
            selectedBox: widget.selectedBox,
          ),
          theme.line,
        );
      },
    );
  }
}

// ============================================================
// RANGE BAR
// ============================================================

class _HourlyRangeBar extends StatelessWidget {
  final UtilityHourlyRange range;
  final ChartTheme theme;
  final ValueChanged<UtilityHourlyRange> onChanged;

  const _HourlyRangeBar({
    required this.range,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fetching = context.select<UtilityHourlyChartController, bool>(
      (controller) => controller.fetching,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'RANGE',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .52),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 10),
            UtilityGlassTabRow(
              labels: UtilityHourlyRange.values
                  .map((item) => item.label)
                  .toList(growable: false),
              selectedIndex: range.index,
              onSelect: (index) => onChanged(UtilityHourlyRange.values[index]),
              theme: theme,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                range.isMultiDay
                    ? 'Hourly snapshot · last 7 days'
                    : 'Hourly min / avg / max',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .48),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Giu chieu cao co dinh de grid khong nhay khi progress bat / tat.
        SizedBox(
          height: 2,
          child: fetching
              ? LinearProgressIndicator(
                  minHeight: 2,
                  color: theme.line,
                  backgroundColor: theme.line.withValues(alpha: .12),
                )
              : null,
        ),
      ],
    );
  }
}
