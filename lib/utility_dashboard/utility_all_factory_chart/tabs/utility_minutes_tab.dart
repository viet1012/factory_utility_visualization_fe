import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/utility_chart_catalog_controller.dart';
import '../controllers/utility_minute_chart_controller.dart';
import '../../utility_dashboard_common/chart_theme.dart';
import '../../shared/widgets/chart_loading_widgets.dart';
import '../../shared/widgets/chart_state_widgets.dart';
import '../models/utility_chart_models.dart';
import '../widgets/utility_minute_chart_grid.dart';
import 'utility_chart_tab_plan.dart';

class UtilityMinutesTab extends StatefulWidget {
  final bool isActive;
  final String facId;
  final String cate;
  final String? scadaId;

  /// Giá trị DEVICE đang chọn:
  /// ALL, DB-03_ES35-SW, DB-03_MFM384...
  final String selectedBox;

  final bool importantOnly;

  const UtilityMinutesTab({
    super.key,
    required this.isActive,
    required this.facId,
    required this.cate,
    required this.scadaId,
    required this.selectedBox,
    required this.importantOnly,
  });

  @override
  State<UtilityMinutesTab> createState() => _UtilityMinutesTabState();
}

class _UtilityMinutesTabState extends State<UtilityMinutesTab> {
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
  void didUpdateWidget(covariant UtilityMinutesTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    /*
     * Roi tab (hoac roi screen): huy request dang chay.
     * Quay lai tab: reset signature de load lai; controller dung cache 60s
     * va polling chay ngay khi scope bat lai.
     */
    if (oldWidget.isActive && !widget.isActive) {
      _lastLoadSignature = '';
      context.read<UtilityMinuteChartController>().cancel();
    } else if (!oldWidget.isActive && widget.isActive) {
      _lastLoadSignature = '';
    }
  }

  void _scheduleLoad(List<SignalChartConfig> charts, String desiredSignature) {
    if (!widget.isActive) return;

    final catalog = context.read<UtilityChartCatalogController>();

    if (catalog.loadedRequestSignature != desiredSignature) return;

    final plcsByBox = resolvePlcsByBox(charts, widget.selectedBox);

    // Request identity: PLC dang hien thi cua tung device.
    final signature = plcsByBoxSignature(plcsByBox);

    if (_lastLoadSignature == signature) return;

    _lastLoadSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive) return;

      // Category có thể đã đổi giữa lúc schedule và lúc callback chạy.
      if (context
              .read<UtilityChartCatalogController>()
              .loadedRequestSignature !=
          desiredSignature) {
        return;
      }

      // Map rong: dung poll cac device cu.
      unawaited(
        context.read<UtilityMinuteChartController>().load(plcsByBox: plcsByBox),
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

    // Catalog identity this tab currently wants to render.
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
        /*
         * Charts đang lưu có thể thuộc category trước đó.
         *
         * Ví dụ Water -> Electricity: widget.cate đã là Electricity nhưng
         * vm.charts vẫn là Water cho tới khi response mới được áp dụng.
         * Khi signature không khớp thì tuyệt đối không dùng vm.charts.
         */
        if (!vm.matches(desiredSignature)) {
          if (vm.error != null && !vm.loading) {
            return ChartApiErrorState(color: color, onRetry: _retryCatalog);
          }

          return _pendingBody(color);
        }

        if (vm.loading && vm.charts.isEmpty) {
          return _pendingBody(color);
        }

        if (vm.error != null && vm.charts.isEmpty) {
          return ChartApiErrorState(color: color, onRetry: _retryCatalog);
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

        /*
         * Chỉ gọi sau khi catalog đã có danh sách chart.
         * ALL device: mọi box trong cùng một request (chia lô khi > 30 box
         * hoặc > 300 signal).
         */
        _scheduleLoad(vm.charts, desiredSignature);

        return _showGrid(
          UtilityMinuteChartGrid(
            charts: vm.charts,
            facId: widget.facId,
            cate: widget.cate,
            scadaId: widget.scadaId,
            selectedBox: widget.selectedBox,
          ),
          color,
        );
      },
    );
  }
}
