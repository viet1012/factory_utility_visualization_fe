import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_models/response/tree_series_response.dart'; // chứa TreeSeriesResponse, TreePoint
import '../../utility_state/hourly_series_provider.dart';
import '../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../utility_dashboard_common/info_box/utility_info_box_widgets.dart';
import '../utility_dashboard_common/utility_fac_style.dart';

class _BarPoint {
  final DateTime ts;
  final double y;

  _BarPoint(this.ts, this.y);
}

class UtilityHourlyBarChartPanel extends StatefulWidget {
  final double width;
  final double? height;

  /// required by API
  final String facId;
  final String boxDeviceId;
  final String plcAddress;

  /// API preset
  final String? range; // TODAY/YESTERDAY/LAST_7_DAYS/THIS_MONTH (optional)
  final int? year; // optional when THIS_MONTH
  final int? month; // optional when THIS_MONTH

  /// optional UI
  final String? cate; // chỉ để show label nếu muốn
  final String? scadaId; // optional

  const UtilityHourlyBarChartPanel({
    super.key,
    required this.facId,
    required this.boxDeviceId,
    required this.plcAddress,
    this.range,
    this.year,
    this.month,
    this.cate,
    this.scadaId,
    this.width = 520,
    this.height,
  });

  @override
  State<UtilityHourlyBarChartPanel> createState() =>
      _UtilityHourlyBarChartPanelState();
}

class _UtilityHourlyBarChartPanelState extends State<UtilityHourlyBarChartPanel>
    with TickerProviderStateMixin {
  late final UtilityInfoBoxFx fx;
  late String _key;

  bool get _hasRequiredFilter {
    return widget.facId.trim().isNotEmpty &&
        widget.boxDeviceId.trim().isNotEmpty &&
        widget.plcAddress.trim().isNotEmpty;
  }

  void _rebuildKey() {
    final p = context.read<TreeSeriesProvider>();
    _key = p.buildKey(
      fac: widget.facId,
      boxDeviceId: widget.boxDeviceId,
      plcAddress: widget.plcAddress,
      range: widget.range,
      year: widget.year,
      month: widget.month,
    );
  }

  void _fetch({bool force = false}) {
    final p = context.read<TreeSeriesProvider>();

    debugPrint(
      '[TreeSeriesPanel] key=$_key fac=${widget.facId} box=${widget.boxDeviceId} '
      'plc=${widget.plcAddress} range=${widget.range} y=${widget.year} m=${widget.month} force=$force',
    );

    if (_hasRequiredFilter) {
      p.load(
        fac: widget.facId,
        boxDeviceId: widget.boxDeviceId,
        plcAddress: widget.plcAddress,
        range: widget.range,
        year: widget.year,
        month: widget.month,
        force: force,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fx = UtilityInfoBoxFx(this)..init();

    _rebuildKey();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetch(force: false);
    });
  }

  @override
  void didUpdateWidget(covariant UtilityHourlyBarChartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final changed =
        oldWidget.facId != widget.facId ||
        oldWidget.boxDeviceId != widget.boxDeviceId ||
        oldWidget.plcAddress != widget.plcAddress ||
        oldWidget.range != widget.range ||
        oldWidget.year != widget.year ||
        oldWidget.month != widget.month ||
        oldWidget.cate != widget.cate ||
        oldWidget.scadaId != widget.scadaId;

    if (!changed) return;

    _rebuildKey();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetch(force: true); // ✅ đổi filter thì force reload
    });
  }

  @override
  void dispose() {
    fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TreeSeriesProvider>(
      builder: (context, p, _) {
        final data = p.dataOf(_key); // TreeSeriesResponse?
        final points = p.pointsOf(_key); // List<TreePoint>
        final err = p.errorOf(_key);

        final hasError = err != null;
        final isLoading = !_hasRequiredFilter
            ? false
            : (p.isLoading(_key) && points.isEmpty && !hasError);

        final facilityColor = UtilityFacStyle.colorFromFac(widget.facId);

        final bucket = data?.bucket; // "DAY" / "HOUR"
        final sig = data?.findSignal(
          boxDeviceId: widget.boxDeviceId,
          plcAddress: widget.plcAddress,
        );

        final signalName = (sig?.nameEn?.trim().isNotEmpty == true)
            ? sig!.nameEn!
            : (sig?.nameVi?.trim().isNotEmpty == true)
            ? sig!.nameVi!
            : 'Series';

        final unit = sig?.unit;
        // final headerSubtitle =
        //     '${widget.range ?? "CUSTOM"}${bucket != null ? " • $bucket" : ""}${unit != null ? " • $unit" : ""}';

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
                            const Color(0xFF2E1A47).withOpacity(0.25),
                            const Color(0xFF1A2A6C).withOpacity(0.18),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: facilityColor.withOpacity(0.22),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            UtilityInfoBoxWidgets.header(
                              facilityColor: facilityColor,
                              facTitle: widget.facId,
                              boxDeviceId: '$signalName',
                              // plcAddress:
                              //     '${widget.boxDeviceId} • ${widget.plcAddress}',
                              isLoading: isLoading,
                              hasError: hasError,
                              err: err,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: _body(
                                  points: points,
                                  hasError: hasError,
                                  err: err,
                                  bucket: bucket,
                                  loading: p.isLoading(_key),
                                  hasData: data != null,
                                ),
                              ),
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
    required List<TreePoint> points,
    required bool hasError,
    required Object? err,
    required String? bucket,
    required bool loading,
    required bool hasData,
  }) {
    if (!_hasRequiredFilter) {
      return Center(
        child: Text(
          'Missing facId/boxDeviceId/plcAddress',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
      );
    }

    // lần đầu chưa có data
    if (!hasData && loading && !hasError) {
      return const Center(child: CircularProgressIndicator());
    }

    if (hasError && points.isEmpty) {
      return Center(
        child: Text(
          'API error:\n$err',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
      );
    }

    if (points.isEmpty) {
      return Center(
        child: Text(
          'No data',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
      );
    }

    final last = points.last;
    final lastVal = last.value.toStringAsFixed(2);

    final lastTs = (bucket == 'DAY')
        ? DateFormat('MM-dd').format(last.ts.toLocal())
        : DateFormat('HH:mm').format(last.ts.toLocal());

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
              const Icon(Icons.bar_chart, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Last: $lastVal  • $lastTs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () {
                  // ✅ force reload
                  _fetch(force: true);
                },
                icon: Icon(
                  Icons.refresh_rounded,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(child: _chart(points, bucket)),
      ],
    );
  }

  Widget _chart(List<TreePoint> points, String? bucket) {
    final data = points.map((e) => _BarPoint(e.ts.toLocal(), e.value)).toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));

    if (data.length < 2) {
      return Center(
        child: Text(
          'Not enough points',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
      );
    }

    final minX = data.first.ts;
    final maxX = data.last.ts;

    final tooltip = TooltipBehavior(
      enable: true,
      canShowMarker: true,
      header: '',
      textStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
    );

    final isDay = bucket == 'DAY';

    return SfCartesianChart(
      plotAreaBorderWidth: 1,
      plotAreaBorderColor: Colors.white.withOpacity(0.12),
      tooltipBehavior: tooltip,
      primaryXAxis: DateTimeAxis(
        minimum: minX,
        maximum: maxX,
        intervalType: isDay
            ? DateTimeIntervalType.days
            : DateTimeIntervalType.hours,
        interval: isDay ? 1 : 2,
        dateFormat: isDay ? DateFormat('MM-dd') : DateFormat('HH:mm'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(0.08),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(0.15), width: 1),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.75),
          fontSize: 12,
        ),
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat('0.##'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(0.08),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(0.15), width: 1),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.75),
          fontSize: 12,
        ),
      ),
      series: <CartesianSeries<_BarPoint, DateTime>>[
        ColumnSeries<_BarPoint, DateTime>(
          dataSource: data,
          xValueMapper: (p, _) => p.ts,
          yValueMapper: (p, _) => p.y,
          width: 0.8,
          spacing: 0.2,
        ),
      ],
    );
  }
}
