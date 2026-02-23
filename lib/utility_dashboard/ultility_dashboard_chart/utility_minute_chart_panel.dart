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

class _SeriesStatus {
  final bool stale; // không có điểm mới
  final bool noChange; // giá trị gần như không đổi
  final Duration? staleFor; // cũ bao lâu
  final double minY;
  final double maxY;
  final double delta;

  const _SeriesStatus({
    required this.stale,
    required this.noChange,
    required this.staleFor,
    required this.minY,
    required this.maxY,
    required this.delta,
  });
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

  bool get _canFetchBox {
    final dev = (widget.boxDeviceId ?? '').trim();
    return dev.isNotEmpty;
  }

  bool get _canRenderSignal {
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
      // plcAddress: widget.plcAddress,
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
      // plcAddress: widget.plcAddress,
      cateIds: widget.cateIds,
    );

    if (_canFetchBox) {
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
        // final rows = p.getRows(_key);
        final rows = p.getRowsForPlc(_key, widget.plcAddress ?? '');
        final err = p.getError(_key);

        // ✅ loading logic giống InfoBox
        final hasError = err != null;
        final isLoading = !_canFetchBox
            ? false
            : (!p.hasFetchedOnce(_key) && !hasError);

        // ✅ màu theo "facTitle" như InfoBox
        final facilityColor = UtilityFacStyle.colorFromFac(widget.facId);
        final signalName = rows.isNotEmpty
            ? (rows.last.nameEn ?? rows.last.cateId)
            : null;
        final unit = rows.isNotEmpty ? rows.last.unit : null;
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
                                  boxDeviceId: signalName,
                                  plcAddress: widget.plcAddress,
                                  unit: unit,
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

  // ====================== STATUS HELPERS ======================

  String _fmtDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inHours}h${(d.inMinutes % 60).toString().padLeft(2, '0')}m';
  }

  _SeriesStatus _analyze(List<_ChartPoint> data) {
    if (data.isEmpty) {
      return const _SeriesStatus(
        stale: false,
        noChange: false,
        staleFor: null,
        minY: 0,
        maxY: 0,
        delta: 0,
      );
    }

    // ---- stale: last point too old ----
    final now = DateTime.now();
    final lastTs = data.last.ts;
    final staleFor = now.difference(lastTs);

    // Threshold tuỳ bạn: 2 phút / 5 phút...
    const staleThreshold = Duration(minutes: 2);
    final stale = staleFor > staleThreshold;

    // ---- noChange: range too small ----
    double minY = data.first.y;
    double maxY = data.first.y;
    for (final p in data) {
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    final delta = (maxY - minY).abs();

    // deadband: nhỏ hơn 0.01 hoặc nhỏ hơn 0.05% mức trung bình
    final avg = (minY + maxY) / 2.0;
    final epsPct = avg.abs() * 0.0005; // 0.05%
    final eps = epsPct < 0.01 ? 0.01 : epsPct;

    final noChange = delta <= eps;

    return _SeriesStatus(
      stale: stale,
      noChange: noChange,
      staleFor: staleFor,
      minY: minY,
      maxY: maxY,
      delta: delta,
    );
  }

  Widget _statusBanner({required IconData icon, required String title}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ====================== BODY ======================

  Widget _body({
    required List<MinutePointDto> rows,
    required bool hasError,
    required Object? err,
    required bool fetchedOnce,
  }) {
    if (!_canRenderSignal) {
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

    // build chart data once here (để analyze + show banner)
    final chartData = <_ChartPoint>[];
    for (final p in rows) {
      final v = p.value;
      if (v == null) continue;
      chartData.add(_ChartPoint(p.ts.toLocal(), v));
    }

    Widget? banner;
    if (chartData.isNotEmpty) {
      final st = _analyze(chartData);

      if (st.stale) {
        banner = _statusBanner(
          icon: Icons.timer_off_rounded,
          title: 'No new data - Last update ${_fmtDuration(st.staleFor!)} ago',
        );
      } else if (st.noChange && chartData.length >= 2) {
        banner = _statusBanner(
          icon: Icons.horizontal_rule_rounded,
          title: 'No change detected',
        );
      }
    }

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
          child: Row(
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
        ),
        const SizedBox(height: 6),

        if (banner != null) ...[banner, const SizedBox(height: 6)],

        Expanded(child: _chart(rows)),
      ],
    );
  }

  // ====================== CHART ======================

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

    // analyze for optional plotBand (noChange)
    final st = _analyze(data);

    final ys = data.map((e) => e.y).toList()..sort();
    final minY = ys.first;
    final maxY = ys.last;

    // ✅ IMPORTANT: pad tối thiểu để tránh y-range = 0
    final range = (maxY - minY).abs();
    final pad10 = range * 0.10;

    // 1% của magnitude (nếu maxY gần 0 thì fallback 0.01)
    final mag = maxY.abs() > minY.abs() ? maxY.abs() : minY.abs();
    final minPad = mag * 0.01;

    final safePad = pad10 > 0 ? pad10 : (minPad > 0.01 ? minPad : 0.01);

    final safeMinY = minY - safePad;
    final safeMaxY = maxY + safePad;

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

        // ✅ VẼ “biểu đồ tương ứng” khi noChange: highlight dải giá trị
        plotBands: <PlotBand>[
          if (st.noChange)
            PlotBand(
              isVisible: true,
              start: minY,
              end: maxY,
              color: Colors.white.withOpacity(0.06),
              text: 'No change',
              textStyle: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontWeight: FontWeight.w800,
              ),
              verticalTextPadding: '6%',
            ),
        ],
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
