import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_models/response/hour_point.dart';
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

  final String facId;
  final String? scadaId;
  final String? cate;
  final String? boxDeviceId;

  /// ✅ required
  final String plcAddress;

  /// ✅ bạn muốn truyền cateId + plcAddress
  final String? cateId;

  /// optional
  final List<String>? cateIds;

  /// time window
  final DateTime fromTs;
  final DateTime toTs;

  const UtilityHourlyBarChartPanel({
    super.key,
    required this.facId,
    required this.plcAddress,
    required this.fromTs,
    required this.toTs,

    this.scadaId,
    this.cate,
    this.boxDeviceId,
    this.cateId,
    this.cateIds,

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
    final addr = widget.plcAddress.trim();
    final hasCateId = (widget.cateId ?? '').trim().isNotEmpty;
    final hasCateIds = (widget.cateIds?.isNotEmpty == true);
    return addr.isNotEmpty && (hasCateId || hasCateIds);
  }

  void _rebuildKey() {
    final p = context.read<HourlySeriesProvider>();
    _key = p.buildKey(
      fromTs: widget.fromTs,
      toTs: widget.toTs,
      fac: widget.facId,
      scadaId: widget.scadaId,
      cate: widget.cate,
      boxDeviceId: widget.boxDeviceId,
      plcAddress: widget.plcAddress,
      cateId: widget.cateId,
      cateIds: widget.cateIds,
    );
  }

  void _registerAndFetch() {
    final p = context.read<HourlySeriesProvider>();

    p.upsertRequest(
      key: _key,
      fromTs: widget.fromTs,
      toTs: widget.toTs,
      fac: widget.facId,
      scadaId: widget.scadaId,
      cate: widget.cate,
      boxDeviceId: widget.boxDeviceId,
      plcAddress: widget.plcAddress,
      cateId: widget.cateId,
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
  void didUpdateWidget(covariant UtilityHourlyBarChartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final changed =
        oldWidget.facId != widget.facId ||
        oldWidget.scadaId != widget.scadaId ||
        oldWidget.cate != widget.cate ||
        oldWidget.boxDeviceId != widget.boxDeviceId ||
        oldWidget.plcAddress != widget.plcAddress ||
        oldWidget.cateId != widget.cateId ||
        (oldWidget.cateIds?.join(',') != widget.cateIds?.join(',')) ||
        oldWidget.fromTs != widget.fromTs ||
        oldWidget.toTs != widget.toTs;

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
    return Consumer<HourlySeriesProvider>(
      builder: (context, p, _) {
        final rows = p.getRows(_key);
        final err = p.getError(_key);

        final hasError = err != null;
        final isLoading = !_hasRequiredFilter
            ? false
            : (!p.hasFetchedOnce(_key) && !hasError);

        final facilityColor = UtilityFacStyle.colorFromFac(widget.facId);

        final signalName = rows.isNotEmpty
            ? (rows.last.nameEn ?? rows.last.cateId ?? widget.cateId)
            : (widget.cateId ?? 'Hourly');

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
                              boxDeviceId: signalName,
                              plcAddress: widget.plcAddress,
                              isLoading: isLoading,
                              hasError: hasError,
                              err: err,
                            ),
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
    required List<HourPointDto> rows,
    required bool hasError,
    required Object? err,
    required bool fetchedOnce,
  }) {
    if (!_hasRequiredFilter) {
      return Center(
        child: Text(
          'Missing plcAddress + (cateId or cateIds)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
      );
    }

    if (!fetchedOnce && !hasError) {
      return const Center(child: CircularProgressIndicator());
    }

    if (hasError && rows.isEmpty) {
      return Center(
        child: Text(
          'API error:\n$err',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
      );
    }

    if (rows.isEmpty) {
      return Center(
        child: Text(
          'No data in selected day',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
      );
    }

    final last = rows.last;
    final lastVal = last.value.toStringAsFixed(2);
    final lastTs = DateFormat('HH:mm').format(last.ts.toLocal());

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
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(child: _chart(rows)),
      ],
    );
  }

  Widget _chart(List<HourPointDto> rows) {
    final data = rows.map((e) => _BarPoint(e.ts.toLocal(), e.value)).toList()
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

    return SfCartesianChart(
      plotAreaBorderWidth: 1,
      plotAreaBorderColor: Colors.white.withOpacity(0.12),
      tooltipBehavior: tooltip,
      primaryXAxis: DateTimeAxis(
        minimum: minX,
        maximum: maxX,
        intervalType: DateTimeIntervalType.hours,
        interval: 2,
        dateFormat: DateFormat('HH:mm'),
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
          // nếu muốn bo tròn / spacing:
          // width: 0.8,
          // spacing: 0.2,
        ),
      ],
    );
  }
}
