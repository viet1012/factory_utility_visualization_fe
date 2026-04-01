import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_models/response/minute_point.dart';
import '../../utility_state/minute_series_provider.dart';
import '../utility_dashboard_common/info_box/utility_info_box_widgets.dart';
import '../utility_dashboard_common/utility_fac_style.dart';

class _ChartPoint {
  final DateTime time;
  final double value;

  const _ChartPoint(this.time, this.value);
}

class _SeriesAnalysis {
  final bool isStale;
  final bool isFlat;
  final Duration? staleFor;
  final double minValue;
  final double maxValue;
  final double delta;

  const _SeriesAnalysis({
    required this.isStale,
    required this.isFlat,
    required this.staleFor,
    required this.minValue,
    required this.maxValue,
    required this.delta,
  });
}

class _PanelVm {
  final List<MinutePointDto> rows;
  final Object? error;
  final bool hasFetchedOnce;

  const _PanelVm({
    required this.rows,
    required this.error,
    required this.hasFetchedOnce,
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
    with AutomaticKeepAliveClientMixin {
  late String _requestKey;

  bool get _canFetchBox {
    final boxId = (widget.boxDeviceId ?? '').trim();
    return boxId.isNotEmpty;
  }

  bool get _canRenderSignal {
    final boxId = (widget.boxDeviceId ?? '').trim();
    final plc = (widget.plcAddress ?? '').trim();
    return boxId.isNotEmpty && plc.isNotEmpty;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _rebuildRequestKey();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _registerAndFetch();
    });
  }

  @override
  void didUpdateWidget(covariant UtilityMinuteChartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final hasChanged =
        oldWidget.facId != widget.facId ||
        oldWidget.scadaId != widget.scadaId ||
        oldWidget.cate != widget.cate ||
        oldWidget.boxDeviceId != widget.boxDeviceId ||
        oldWidget.plcAddress != widget.plcAddress ||
        oldWidget.cateIds?.join(',') != widget.cateIds?.join(',');

    if (!hasChanged) return;

    _rebuildRequestKey();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _registerAndFetch();
    });
  }

  void _rebuildRequestKey() {
    final provider = context.read<MinuteSeriesProvider>();

    _requestKey = provider.buildKey(
      facId: widget.facId,
      scadaId: widget.scadaId,
      cate: widget.cate,
      boxDeviceId: widget.boxDeviceId,
      cateIds: widget.cateIds,
    );
  }

  void _registerAndFetch() {
    final provider = context.read<MinuteSeriesProvider>();

    provider.upsertRequest(
      key: _requestKey,
      facId: widget.facId,
      scadaId: widget.scadaId,
      cate: widget.cate,
      boxDeviceId: widget.boxDeviceId,
      cateIds: widget.cateIds,
    );

    if (_canFetchBox) {
      provider.fetchKeyNow(_requestKey);
    }
  }

  // @override
  // Widget build(BuildContext context) {
  //   super.build(context);
  //
  //   return Selector<MinuteSeriesProvider, _PanelVm>(
  //     selector: (_, provider) => _PanelVm(
  //       rows: provider.getRowsForPlc(_requestKey, widget.plcAddress ?? ''),
  //       error: provider.getError(_requestKey),
  //       hasFetchedOnce: provider.hasFetchedOnce(_requestKey),
  //     ),
  //     shouldRebuild: (prev, next) =>
  //         !identical(prev.rows, next.rows) ||
  //         prev.error != next.error ||
  //         prev.hasFetchedOnce != next.hasFetchedOnce,
  //     builder: (context, vm, _) {
  //       final rows = vm.rows;
  //       final error = vm.error;
  //       final hasError = error != null;
  //       final hasFetchedOnce = vm.hasFetchedOnce;
  //
  //       final isLoading = !_canFetchBox
  //           ? false
  //           : (!hasFetchedOnce && !hasError);
  //
  //       final facilityColor = UtilityFacStyle.colorFromFac(widget.facId);
  //       final signalDisplayName = rows.isNotEmpty
  //           ? (rows.last.nameEn ?? rows.last.cateId)
  //           : null;
  //       final unit = rows.isNotEmpty ? rows.last.unit : null;
  //
  //       return RepaintBoundary(
  //         child: _buildPanelContainer(
  //           facilityColor: facilityColor,
  //           isLoading: isLoading,
  //           hasError: hasError,
  //           error: error,
  //           signalDisplayName: signalDisplayName,
  //           unit: unit,
  //           rows: rows,
  //           fetchedOnce: hasFetchedOnce,
  //         ),
  //       );
  //     },
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Selector<MinuteSeriesProvider, _PanelVm>(
      selector: (_, provider) => _PanelVm(
        rows: provider.getRowsForPlc(_requestKey, widget.plcAddress ?? ''),
        error: provider.getError(_requestKey),
        hasFetchedOnce: provider.hasFetchedOnce(_requestKey),
      ),
      shouldRebuild: (prev, next) =>
          !identical(prev.rows, next.rows) ||
          prev.error != next.error ||
          prev.hasFetchedOnce != next.hasFetchedOnce,
      builder: (context, vm, _) {
        final rows = vm.rows;
        final error = vm.error;
        final hasError = error != null;
        final hasFetchedOnce = vm.hasFetchedOnce;

        final isLoading = !_canFetchBox
            ? false
            : (!hasFetchedOnce && !hasError);

        final facilityColor = UtilityFacStyle.colorFromFac(widget.facId);
        final signalDisplayName = rows.isNotEmpty
            ? (rows.last.nameEn ?? rows.last.cateId)
            : null;
        final unit = rows.isNotEmpty ? rows.last.unit : null;

        return RepaintBoundary(
          child: _buildPanelContainer(
            facilityColor: facilityColor,
            isLoading: isLoading,
            hasError: hasError,
            error: error,
            signalDisplayName: signalDisplayName,
            unit: unit,
            rows: rows,
            fetchedOnce: hasFetchedOnce,
          ),
        );
      },
    );
  }

  Widget _buildPanelContainer({
    required Color facilityColor,
    required bool isLoading,
    required bool hasError,
    required Object? error,
    required String? signalDisplayName,
    required String? unit,
    required List<MinutePointDto> rows,
    required bool fetchedOnce,
  }) {
    return Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UtilityInfoBoxWidgets.header(
              facilityColor: facilityColor,
              facTitle: widget.facId,
              boxDeviceId: signalDisplayName,
              plcAddress: widget.plcAddress,
              unit: unit,
              isLoading: isLoading,
              hasError: hasError,
              err: error,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _buildBody(
                  rows: rows,
                  hasError: hasError,
                  error: error,
                  fetchedOnce: fetchedOnce,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody({
    required List<MinutePointDto> rows,
    required bool hasError,
    required Object? error,
    required bool fetchedOnce,
  }) {
    if (!_canRenderSignal) {
      return _buildCenteredMessage('Missing boxDeviceId + plcAddress');
    }

    if (!fetchedOnce && !hasError) {
      return const Center(child: CircularProgressIndicator());
    }

    if (hasError && rows.isEmpty) {
      return _buildCenteredMessage('API error:\n$error');
    }

    if (rows.isEmpty) {
      return _buildCenteredMessage('No data in selected window');
    }

    final chartPoints = _toChartPoints(rows);
    final latestPoint = _findLatestPoint(rows);
    final analysis = chartPoints.isEmpty ? null : _analyzeSeries(chartPoints);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLatestInfoBar(latestPoint),
        const SizedBox(height: 6),
        if (analysis != null) ...[
          if (analysis.isStale)
            _buildStatusBanner(
              icon: Icons.timer_off_rounded,
              title:
                  'No new data - Last update ${_formatDuration(analysis.staleFor!)} ago',
            )
          else if (analysis.isFlat && chartPoints.length >= 2)
            _buildStatusBanner(
              icon: Icons.horizontal_rule_rounded,
              title: 'No change detected',
            ),
          if (analysis.isStale || analysis.isFlat) const SizedBox(height: 6),
        ],
        Expanded(child: _buildChart(chartPoints)),
      ],
    );
  }

  Widget _buildLatestInfoBar(MinutePointDto latestPoint) {
    final latestUnit =
        (latestPoint.unit != null && latestPoint.unit!.isNotEmpty)
        ? latestPoint.unit!
        : '';

    final latestValue = '${latestPoint.value?.toStringAsFixed(2)}$latestUnit';
    final latestTime = DateFormat('HH:mm:ss').format(latestPoint.ts.toLocal());

    return Container(
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
              'Latest: $latestValue  • $latestTime',
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
    );
  }

  Widget _buildStatusBanner({required IconData icon, required String title}) {
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
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List<_ChartPoint> data) {
    if (data.length < 2) {
      return _buildCenteredMessage('Not enough points');
    }

    final analysis = _analyzeSeries(data);
    final axisBounds = _computeYAxisBounds(data);
    final timeBounds = _computeXAxisBounds(data);

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
      key: ValueKey(
        '${widget.facId}_${widget.cate}_${widget.boxDeviceId}_${widget.plcAddress}_${data.length}_${data.last.time.millisecondsSinceEpoch}',
      ),
      plotAreaBorderWidth: 1,
      plotAreaBorderColor: Colors.white.withOpacity(0.12),
      tooltipBehavior: tooltip,
      zoomPanBehavior: ZoomPanBehavior(
        enablePinching: true,
        enablePanning: true,
        zoomMode: ZoomMode.y,
      ),
      primaryXAxis: DateTimeAxis(
        minimum: timeBounds.minX,
        maximum: timeBounds.maxX,
        intervalType: DateTimeIntervalType.minutes,
        interval: timeBounds.intervalMinutes.toDouble(),
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
        minimum: axisBounds.minY,
        maximum: axisBounds.maxY,
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
        plotBands: [
          if (analysis.isFlat)
            PlotBand(
              isVisible: true,
              start: analysis.minValue,
              end: analysis.maxValue,
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
          animationDuration: 0,
          dataSource: data,
          xValueMapper: (point, _) => point.time,
          yValueMapper: (point, _) => point.value,
          splineType: SplineType.natural,
          markerSettings: const MarkerSettings(isVisible: false),
          opacity: 0.25,
        ),
      ],
    );
  }

  List<_ChartPoint> _toChartPoints(List<MinutePointDto> rows) {
    final points = <_ChartPoint>[];

    for (final row in rows) {
      final value = row.value;
      if (value == null) continue;
      points.add(_ChartPoint(row.ts.toLocal(), value));
    }

    return points;
  }

  MinutePointDto _findLatestPoint(List<MinutePointDto> rows) {
    return rows.lastWhere((row) => row.value != null, orElse: () => rows.last);
  }

  _SeriesAnalysis _analyzeSeries(List<_ChartPoint> points) {
    if (points.isEmpty) {
      return const _SeriesAnalysis(
        isStale: false,
        isFlat: false,
        staleFor: null,
        minValue: 0,
        maxValue: 0,
        delta: 0,
      );
    }

    final now = DateTime.now();
    final latestTimestamp = points.last.time;
    final staleFor = now.difference(latestTimestamp);

    const staleThreshold = Duration(minutes: 2);
    final isStale = staleFor > staleThreshold;

    double minValue = points.first.value;
    double maxValue = points.first.value;

    for (final point in points) {
      if (point.value < minValue) minValue = point.value;
      if (point.value > maxValue) maxValue = point.value;
    }

    final delta = (maxValue - minValue).abs();
    final avg = (minValue + maxValue) / 2.0;
    final epsPct = avg.abs() * 0.0005;
    final eps = epsPct < 0.01 ? 0.01 : epsPct;
    final isFlat = delta <= eps;

    return _SeriesAnalysis(
      isStale: isStale,
      isFlat: isFlat,
      staleFor: staleFor,
      minValue: minValue,
      maxValue: maxValue,
      delta: delta,
    );
  }

  ({double minY, double maxY}) _computeYAxisBounds(List<_ChartPoint> data) {
    final values = data.map((e) => e.value).toList()..sort();
    final minValue = values.first;
    final maxValue = values.last;

    final range = (maxValue - minValue).abs();
    final rangePadding = range * 0.2;

    final magnitude = maxValue.abs() > minValue.abs()
        ? maxValue.abs()
        : minValue.abs();
    final minimumPadding = magnitude * 0.01;

    final safePadding = rangePadding > 0
        ? rangePadding
        : (minimumPadding > 0.01 ? minimumPadding : 0.01);

    return (minY: minValue - safePadding, maxY: maxValue + safePadding);
  }

  ({DateTime minX, DateTime maxX, int intervalMinutes}) _computeXAxisBounds(
    List<_ChartPoint> data,
  ) {
    final minX = data.first.time;
    final maxX = data.last.time;
    final totalMinutes = maxX.difference(minX).inMinutes;
    final intervalMinutes = totalMinutes <= 30 ? 5 : 10;

    return (minX: minX, maxX: maxX, intervalMinutes: intervalMinutes);
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) return '${duration.inSeconds}s';
    if (duration.inMinutes < 60) return '${duration.inMinutes}m';
    return '${duration.inHours}h${(duration.inMinutes % 60).toString().padLeft(2, '0')}m';
  }

  Widget _buildCenteredMessage(String message) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withOpacity(0.8)),
      ),
    );
  }
}
