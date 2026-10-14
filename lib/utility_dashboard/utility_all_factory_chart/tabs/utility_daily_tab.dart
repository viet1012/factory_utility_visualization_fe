import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/utility_chart_catalog_controller.dart';
import '../controllers/utility_daily_chart_controller.dart';
import '../../utility_dashboard_common/chart_theme.dart';
import '../../shared/widgets/chart_loading_widgets.dart';
import '../../shared/widgets/chart_state_widgets.dart';
import '../models/utility_chart_models.dart';
import '../widgets/utility_daily_chart_grid.dart';
import 'utility_chart_tab_plan.dart';

class UtilityDailyTab extends StatefulWidget {
  final bool isActive;
  final String facId;
  final String cate;
  final String? scadaId;

  /// Giong Minutes / Hourly: ALL hoac device that, khong phai BOX GROUP.
  final String selectedBox;

  final bool importantOnly;

  const UtilityDailyTab({
    super.key,
    required this.isActive,
    required this.facId,
    required this.cate,
    required this.scadaId,
    required this.selectedBox,
    required this.importantOnly,
  });

  @override
  State<UtilityDailyTab> createState() => _UtilityDailyTabState();
}

class _UtilityDailyTabState extends State<UtilityDailyTab> {
  String _lastLoadSignature = '';

  /// Grid da ve lan truoc (catalog khop). Doi filter: giu grid nay mo kem
  /// progress bar cho toi khi catalog moi ve, khong nhay ve skeleton.
  Widget? _lastGrid;

  Widget _pendingBody(Color color) {
    final last = _lastGrid;
    if (last == null) return ChartGridSkeleton(color: color);

    return ChartBusyOverlay(busy: true, color: color, child: last);
  }

  @override
  void didUpdateWidget(covariant UtilityDailyTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Roi tab: huy request dang chay. Quay lai: load lai (cache 5 phut).
    if (oldWidget.isActive && !widget.isActive) {
      _lastLoadSignature = '';
      context.read<UtilityDailyChartController>().cancel();
    } else if (!oldWidget.isActive && widget.isActive) {
      _lastLoadSignature = '';
    }
  }

  void _scheduleLoad(List<SignalChartConfig> charts, String desiredSignature) {
    if (!widget.isActive) return;

    final catalog = context.read<UtilityChartCatalogController>();

    if (catalog.loadedRequestSignature != desiredSignature) return;

    final plcsByBox = resolvePlcsByBox(charts, widget.selectedBox);

    if (plcsByBox.isEmpty) return;

    final signature = plcsByBoxSignature(plcsByBox);

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
        context.read<UtilityDailyChartController>().load(plcsByBox: plcsByBox),
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
    final color = ChartThemes.byCate(widget.cate).line;

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
            return ChartApiErrorState(color: color, onRetry: _retryCatalog);
          }

          return _pendingBody(color);
        }

        if (vm.error != null && vm.charts.isEmpty) {
          return ChartApiErrorState(color: color, onRetry: _retryCatalog);
        }

        if (vm.charts.isEmpty) {
          return EmptyChartState(
            icon: Icons.query_stats_rounded,
            title: 'No Daily Data',
            message:
                'No utility signals found in '
                '${widget.selectedBox} / '
                '${widget.scadaId ?? "-"}',
            color: Colors.white.withValues(alpha: .58),
          );
        }

        _scheduleLoad(vm.charts, desiredSignature);

        final grid = Stack(
          children: [
            UtilityDailyChartGrid(
              charts: vm.charts,
              facId: widget.facId,
              cate: widget.cate,
              selectedBox: widget.selectedBox,
            ),
            const Positioned(
              top: 10,
              right: 12,
              child: _DailyRefreshingBadge(),
            ),
          ],
        );

        _lastGrid = grid;

        return ChartBusyOverlay(busy: false, color: color, child: grid);
      },
    );
  }
}

/// Hien khi dang tai lai trong luc da co chart.
class _DailyRefreshingBadge extends StatelessWidget {
  const _DailyRefreshingBadge();

  @override
  Widget build(BuildContext context) {
    final refreshing = context.select<UtilityDailyChartController, bool>(
      (controller) => controller.fetching && controller.hasData,
    );

    if (!refreshing) return const SizedBox.shrink();

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E31),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 1.8),
          ),
          SizedBox(width: 7),
          Text(
            'Refreshing daily data',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
