import 'dart:async';

import 'package:factory_utility_visualization/utility_dashboard/'
    'utility_all_factory_chart/widgets/utility_chart_loading_state.dart';
import 'package:factory_utility_visualization/utility_dashboard/'
    'utility_all_factory_chart/widgets/utility_minute_chart_grid.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/utility_chart_catalog_controller.dart';
import '../controllers/utility_minute_chart_controller.dart';
import '../../utility_dashboard_common/chart_theme.dart';
import '../../shared/widgets/chart_state_widgets.dart';
import '../models/utility_chart_models.dart';

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

  @override
  void didUpdateWidget(covariant UtilityMinutesTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    final sourceChanged =
        oldWidget.facId.trim() != widget.facId.trim() ||
        oldWidget.cate.trim() != widget.cate.trim() ||
        (oldWidget.scadaId ?? '').trim() != (widget.scadaId ?? '').trim() ||
        oldWidget.selectedBox.trim().toUpperCase() !=
            widget.selectedBox.trim().toUpperCase() ||
        oldWidget.importantOnly != widget.importantOnly;

    /*
     * Chỉ reset khi request thật sự đổi.
     *
     * Trước đây tab này còn reset khi isActive chuyển false -> true,
     * nên mỗi lần quay lại Minutes đều fetch lại dù request không đổi.
     * Signature đã bao gồm đầy đủ tham số request nên không cần reset
     * theo trạng thái active nữa.
     */
    if (sourceChanged) {
      _lastLoadSignature = '';
    }
  }

  List<String> _resolveDeviceIds(List<SignalChartConfig> charts) {
    final allDeviceIds =
        charts
            .map((chart) => chart.boxDeviceId.trim())
            .where((deviceId) => deviceId.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();

    final selected = widget.selectedBox.trim().toUpperCase();

    if (selected.isEmpty || selected == 'ALL') {
      return allDeviceIds;
    }

    return allDeviceIds
        .where((deviceId) => deviceId.toUpperCase() == selected)
        .toList(growable: false);
  }

  void _scheduleLoad(List<SignalChartConfig> charts, String desiredSignature) {
    if (!widget.isActive) {
      return;
    }

    /*
     * Chốt chặn cuối: chỉ nhận charts thuộc đúng request hiện tại.
     *
     * Tránh trường hợp trộn cate mới với deviceIds của catalog cũ.
     */
    final catalog = context.read<UtilityChartCatalogController>();

    if (catalog.loadedRequestSignature != desiredSignature) {
      return;
    }

    final deviceIds = _resolveDeviceIds(charts);

    if (deviceIds.isEmpty) {
      return;
    }

    // Request identity: mọi tham số ảnh hưởng tới dữ liệu Minutes.
    final signature = [
      widget.facId.trim(),
      widget.cate.trim(),
      (widget.scadaId ?? '').trim(),
      widget.selectedBox.trim().toUpperCase(),
      widget.importantOnly ? '1' : '0',
      ...deviceIds,
    ].join('|');

    if (_lastLoadSignature == signature) {
      return;
    }

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

      unawaited(_loadDevices(deviceIds));
    });
  }

  Future<void> _loadDevices(
    List<String> deviceIds, {
    bool forceRefresh = false,
  }) async {
    if (!widget.isActive || deviceIds.isEmpty) return;

    final provider = context.read<UtilityMinuteChartController>();

    final futures = <Future<void>>[];

    for (final boxDeviceId in deviceIds) {
      final requestKey = provider.buildKey(
        facId: widget.facId,
        scadaId: widget.scadaId,
        boxDeviceId: boxDeviceId,
      );

      provider.upsertRequest(
        key: requestKey,
        facId: widget.facId,
        scadaId: widget.scadaId,
        boxDeviceId: boxDeviceId,
      );

      if (!forceRefresh && provider.hasFetchedOnce(requestKey)) {
        continue;
      }

      futures.add(provider.fetchKeyNow(requestKey));
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        final chartsMatchRequest = vm.matches(desiredSignature);

        if (!chartsMatchRequest) {
          if (vm.error != null && !vm.loading) {
            return ChartApiErrorState(
              color: ChartThemes.byCate(widget.cate).line,
              onRetry: () {
                context.read<UtilityChartCatalogController>().loadCatalog(
                  facId: widget.facId,
                  cate: widget.cate,
                  importantOnly: widget.importantOnly ? 1 : 0,
                  forceRefresh: true,
                );
              },
            );
          }

          return UtilityChartLoadingState(
            cate: widget.cate,
            message: 'Loading ${widget.cate} data...',
          );
        }

        if (vm.loading && vm.charts.isEmpty) {
          return UtilityChartLoadingState(
            cate: widget.cate,
            message: 'Loading minute data...',
          );
        }

        if (vm.error != null && vm.charts.isEmpty) {
          return ChartApiErrorState(
            color: ChartThemes.byCate(widget.cate).line,
            onRetry: () {
              context.read<UtilityChartCatalogController>().loadCatalog(
                facId: widget.facId,
                cate: widget.cate,
                importantOnly: widget.importantOnly ? 1 : 0,
                forceRefresh: true,
              );
            },
          );
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
         *
         * ALL:
         *   DB-03_ES35-SW
         *   DB-03_MFM384
         *
         * => đúng 2 request.
         */
        _scheduleLoad(vm.charts, desiredSignature);

        return UtilityMinuteChartGrid(
          charts: vm.charts,
          facId: widget.facId,
          cate: widget.cate,
          scadaId: widget.scadaId,
          selectedBox: widget.selectedBox,
        );
      },
    );
  }
}
