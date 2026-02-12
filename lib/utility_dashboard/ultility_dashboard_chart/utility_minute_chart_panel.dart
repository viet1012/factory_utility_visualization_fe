import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_models/response/minute_point.dart';
import '../../utility_state/minute_series_provider.dart';
import '../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../utility_dashboard_common/info_box/utility_info_box_widgets.dart';
import '../utility_dashboard_common/utility_fac_style.dart';

class _ChartPoint {
  final DateTime ts;
  final double y;

  _ChartPoint(this.ts, this.y);
}

class UtilityMinuteChartPanel extends StatefulWidget {
  final double width;
  final double? height;

  final String facId;
  final String? scadaId;
  final String? cate;
  final String? boxDeviceId;
  final String? plcAddress;
  final List<String>? cateIds;

  const UtilityMinuteChartPanel({
    super.key,
    required this.facId,
    this.scadaId,
    this.cate,
    this.boxDeviceId,
    this.plcAddress,
    this.cateIds,
    this.width = 520,
    this.height,
  });

  @override
  State<UtilityMinuteChartPanel> createState() =>
      _UtilityMinuteChartPanelState();
}

class _UtilityMinuteChartPanelState extends State<UtilityMinuteChartPanel>
    with TickerProviderStateMixin {
  late final UtilityInfoBoxFx fx;
  late String _key;

  bool get _hasRequiredFilter {
    final dev = (widget.boxDeviceId ?? '').trim();
    final addr = (widget.plcAddress ?? '').trim();
    return dev.isNotEmpty && addr.isNotEmpty;
  }

  void _rebuildKey() {
    final p = context.read<MinuteSeriesProvider>();
    _key = p.buildKey(
      facId: widget.facId,
      scadaId: widget.scadaId,
      cate: widget.cate,
      boxDeviceId: widget.boxDeviceId,
      plcAddress: widget.plcAddress,
      cateIds: widget.cateIds,
    );
  }

  void _registerAndFetch() {
    final p = context.read<MinuteSeriesProvider>();

    p.upsertRequest(
      key: _key,
      facId: widget.facId,
      scadaId: widget.scadaId,
      cate: widget.cate,
      boxDeviceId: widget.boxDeviceId,
      plcAddress: widget.plcAddress,
      cateIds: widget.cateIds,
    );

    if (_hasRequiredFilter) {
      p.fetchKeyNow(_key);
    }
  }

  @override
  void initState() {
    super.initState();
    fx = UtilityInfoBoxFx(this)..init();

    _rebuildKey();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _registerAndFetch();
    });
  }

  @override
  void didUpdateWidget(covariant UtilityMinuteChartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final changed =
        oldWidget.boxDeviceId != widget.boxDeviceId ||
        oldWidget.plcAddress != widget.plcAddress ||
        oldWidget.facId != widget.facId ||
        oldWidget.scadaId != widget.scadaId ||
        oldWidget.cate != widget.cate ||
        (oldWidget.cateIds?.join(',') != widget.cateIds?.join(','));

    if (!changed) return;

    _rebuildKey();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _registerAndFetch();
    });
  }

  @override
  void dispose() {
    fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MinuteSeriesProvider>(
      builder: (context, p, _) {
        final rows = p.getRows(_key);
        final err = p.getError(_key);

        // ✅ loading logic giống InfoBox
        final hasError = err != null;
        final isLoading = !_hasRequiredFilter
            ? false
            : (!p.hasFetchedOnce(_key) && !hasError);

        // ✅ màu theo "facTitle" như InfoBox
        final facilityColor = UtilityFacStyle.colorFromFac(widget.facId);

        return SlideTransition(
          position: fx.slide,
          child: MouseRegion(
            onEnter: (_) => fx.onHover(true),
            onExit: (_) => fx.onHover(false),
            child: AnimatedBuilder(
              animation: fx.listenable,
              builder: (context, child) {
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(fx.rotate.value),
                  child: Transform.scale(
                    scale: fx.scale.value,
                    child: Container(
                      width: widget.width,
                      height: widget.height ?? 320,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1A237E).withOpacity(0.25),
                            const Color(0xFF0D47A1).withOpacity(0.20),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFF0D47A1).withOpacity(0.25),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: facilityColor.withOpacity(0.25),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ✅ header y chang InfoBox
                                UtilityInfoBoxWidgets.header(
                                  facilityColor: facilityColor,
                                  facTitle: widget.facId,
                                  boxDeviceId: widget.boxDeviceId,
                                  plcAddress: widget.plcAddress,
                                  isLoading: isLoading,
                                  hasError: hasError,
                                  err: err,
                                ),

                                // body
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: _body(
                                      rows: rows,
                                      hasError: hasError,
                                      err: err,
                                      fetchedOnce: p.hasFetchedOnce(_key),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _body({
    required List<MinutePointDto> rows,
    required bool hasError,
    required Object? err,
    required bool fetchedOnce,
  }) {
    if (!_hasRequiredFilter) {
      return Center(
        child: Text(
          'Missing boxDeviceId + plcAddress',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
      );
    }

    // ✅ giống info box: chưa có data và chưa error => loading
    if (!fetchedOnce && !hasError) {
      return const Center(child: CircularProgressIndicator());
    }

    // ✅ đã fetch mà lỗi
    if (hasError && rows.isEmpty) {
      return Center(
        child: Text(
          'API error:\n$err',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
      );
    }

    // ✅ đã fetch ok nhưng rỗng -> NO DATA (không xoay)
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'No data in selected window',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
      );
    }

    final last = rows.lastWhere(
      (p) => p.value != null,
      orElse: () => rows.last,
    );
    final lastVal = last.value?.toStringAsFixed(2) ?? '--';
    final lastTs = DateFormat('HH:mm:ss').format(last.ts.toLocal());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Latest: $lastVal  • $lastTs',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 4),
        Expanded(child: _chart(rows)),
      ],
    );
  }

  Widget _chart(List<MinutePointDto> rows) {
    final data = <_ChartPoint>[];
    for (final p in rows) {
      final v = p.value;
      if (v == null) continue;
      data.add(_ChartPoint(p.ts.toLocal(), v));
    }

    if (data.length < 2) {
      return Center(
        child: Text(
          'Not enough points',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
      );
    }

    final ys = data.map((e) => e.y).toList()..sort();
    final minY = ys.first;
    final maxY = ys.last;
    final pad = (maxY - minY).abs() * 0.10;
    final safeMinY = minY - pad;
    final safeMaxY = maxY + pad;

    final minX = data.first.ts;
    final maxX = data.last.ts;

    final totalMinutes = maxX.difference(minX).inMinutes;
    final intervalMin = totalMinutes <= 30 ? 5 : 10;

    final tooltip = TooltipBehavior(
      enable: true,
      canShowMarker: true,
      header: '',
      textStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
    );
    return SfCartesianChart(
      plotAreaBorderWidth: 1,
      plotAreaBorderColor: Colors.white.withOpacity(0.12),
      tooltipBehavior: tooltip,
      zoomPanBehavior: ZoomPanBehavior(
        enablePinching: true,
        enablePanning: true,
        zoomMode: ZoomMode.y,
      ),
      primaryXAxis: DateTimeAxis(
        minimum: minX,
        maximum: maxX,
        intervalType: DateTimeIntervalType.minutes,
        interval: intervalMin.toDouble(),
        dateFormat: DateFormat('HH:mm'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(0.08),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(0.15), width: 1),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.75),
          fontSize: 14,
        ),
      ),
      primaryYAxis: NumericAxis(
        minimum: safeMinY,
        maximum: safeMaxY,
        numberFormat: NumberFormat('0.00'),

        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(0.08),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(0.15), width: 1),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.75),
          fontSize: 14,
        ),
      ),
      series: <CartesianSeries<_ChartPoint, DateTime>>[
        SplineAreaSeries<_ChartPoint, DateTime>(
          dataSource: data,
          xValueMapper: (p, _) => p.ts,
          yValueMapper: (p, _) => p.y,
          splineType: SplineType.natural,
          markerSettings: const MarkerSettings(isVisible: false),
          opacity: 0.25,
        ),
      ],
    );
  }
}
