import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';

class VoltageDetail {
  final DateTime recordedMinute;
  final String cateId;
  final String boxDeviceId;
  final double minVol;
  final double maxVol;
  final double minVolStd;
  final double maxVolStd;
  final String alarm;
  final DateTime updatedAt;

  const VoltageDetail({
    required this.recordedMinute,
    required this.cateId,
    required this.boxDeviceId,
    required this.minVol,
    required this.maxVol,
    required this.minVolStd,
    required this.maxVolStd,
    required this.alarm,
    required this.updatedAt,
  });

  factory VoltageDetail.fromJson(Map<String, dynamic> json) {
    return VoltageDetail(
      recordedMinute: DateTime.parse(
        json['recordedMinute']?.toString() ?? DateTime.now().toIso8601String(),
      ).toLocal(),
      cateId: json['cateId']?.toString() ?? '',
      boxDeviceId: json['boxDeviceId']?.toString() ?? '',
      minVol: (json['minVol'] as num?)?.toDouble() ?? 0.0,
      maxVol: (json['maxVol'] as num?)?.toDouble() ?? 0.0,
      minVolStd: (json['minVolStd'] as num?)?.toDouble() ?? 0.0,
      maxVolStd: (json['maxVolStd'] as num?)?.toDouble() ?? 0.0,
      alarm: json['alarm']?.toString() ?? 'Normal',
      updatedAt: DateTime.parse(
        json['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
      ).toLocal(),
    );
  }

  bool get hasStdRange => minVolStd != 0 || maxVolStd != 0;

  bool get isAlarmByStd {
    if (!hasStdRange) return false;
    final lowAlarm = minVol != 0 && minVol < minVolStd;
    final highAlarm = maxVol != 0 && maxVol > maxVolStd;
    return lowAlarm || highAlarm;
  }

  bool get isAlarm =>
      alarm.toLowerCase() == 'alarm' ||
      alarm.toLowerCase() == 'critical' ||
      isAlarmByStd;
}

class _VoltageCache {
  final List<VoltageDetail> data;
  final List<VoltageDetail> alarmMin;
  final List<VoltageDetail> alarmMax;
  final bool hasAlarm;
  final double minStd;
  final double maxStd;

  const _VoltageCache({
    required this.data,
    required this.alarmMin,
    required this.alarmMax,
    required this.hasAlarm,
    required this.minStd,
    required this.maxStd,
  });

  static _VoltageCache from(List<VoltageDetail> d) {
    final data = List<VoltageDetail>.unmodifiable(d);

    final alarmMin = data
        .where((e) => e.minVol != 0 && e.minVol < e.minVolStd)
        .toList(growable: false);

    final alarmMax = data
        .where((e) => e.maxVol != 0 && e.maxVol > e.maxVolStd)
        .toList(growable: false);

    double minStd = 0;
    double maxStd = 0;

    if (data.isNotEmpty) {
      final minStdCandidates = data
          .map((e) => e.minVolStd)
          .where((v) => v != 0)
          .toList();
      final maxStdCandidates = data
          .map((e) => e.maxVolStd)
          .where((v) => v != 0)
          .toList();

      minStd = minStdCandidates.isNotEmpty ? minStdCandidates.first : 0;
      maxStd = maxStdCandidates.isNotEmpty ? maxStdCandidates.first : 0;
    }

    return _VoltageCache(
      data: data,
      alarmMin: alarmMin,
      alarmMax: alarmMax,
      hasAlarm: alarmMin.isNotEmpty || alarmMax.isNotEmpty,
      minStd: minStd,
      maxStd: maxStd,
    );
  }
}

class VoltageDetailChart extends StatefulWidget {
  final UtilityDashboardOverviewApi api;
  final String facId;

  const VoltageDetailChart({super.key, required this.api, required this.facId});

  @override
  State<VoltageDetailChart> createState() => VoltageDetailChartState();
}

class VoltageDetailChartState extends State<VoltageDetailChart> {
  _VoltageCache? _cache;
  bool _isLoading = true;
  Object? _error;

  bool _showChart = true;
  bool _loadingNow = false;
  bool _disposed = false;
  bool _closing = false;

  Timer? _reloadTimer;

  late final TooltipBehavior _tooltip;
  late final ZoomPanBehavior _zoomPan;

  Future<void> prepareToClose() async {
    if (_closing || !mounted) return;
    _closing = true;

    _reloadTimer?.cancel();

    if (_showChart) {
      setState(() {
        _showChart = false;
      });

      await Future.delayed(const Duration(milliseconds: 32));
    }
  }

  @override
  void initState() {
    super.initState();

    _tooltip = TooltipBehavior(
      enable: true,
      color: const Color(0xFF1A2E3D),
      textStyle: const TextStyle(color: Colors.white, fontSize: 13),
    );

    _zoomPan = ZoomPanBehavior(
      enablePinching: true,
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
      enablePanning: true,
      zoomMode: ZoomMode.x,
    );

    _load();
  }

  @override
  void didUpdateWidget(covariant VoltageDetailChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.facId != widget.facId) {
      _reloadTimer?.cancel();

      setState(() {
        _cache = null;
        _error = null;
        _isLoading = true;
        _showChart = true;
      });

      _load();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _reloadTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loadingNow || _disposed || _closing) return;
    _loadingNow = true;

    try {
      final raw = await widget.api.getVoltageDetail(facId: widget.facId);

      if (!mounted || _disposed || _closing) return;

      final details = raw
          .map<VoltageDetail>(
            (e) => VoltageDetail.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();

      final next = _VoltageCache.from(details);

      setState(() {
        _cache = next;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || _disposed || _closing) return;

      setState(() {
        _error = e;
        _isLoading = false;
      });
    } finally {
      _loadingNow = false;
    }

    _scheduleReload();
  }

  void _scheduleReload() {
    _reloadTimer?.cancel();
    if (_disposed || _closing) return;
    _reloadTimer = Timer(const Duration(seconds: 30), _load);
  }

  @override
  Widget build(BuildContext context) {
    final hasAlarm = _cache?.hasAlarm ?? false;

    return Container(
      height: 500,
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1197D1).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1197D1).withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VoltageHeader(
            hasAlarm: hasAlarm,
            boxDeviceId: _cache?.data.isNotEmpty == true
                ? _cache!.data.first.boxDeviceId
                : null,
            cateId: _cache?.data.isNotEmpty == true
                ? _cache!.data.first.cateId
                : null,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1197D1)),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          'Error: $_error',
          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
        ),
      );
    }

    final cache = _cache;
    if (cache == null || cache.data.isEmpty) {
      return const Center(
        child: Text('No data', style: TextStyle(color: Colors.white70)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: RepaintBoundary(
        child: _showChart
            ? _VoltageChart(cache: cache, tooltip: _tooltip, zoomPan: _zoomPan)
            : const SizedBox.expand(),
      ),
    );
  }
}

class _VoltageHeader extends StatelessWidget {
  final bool hasAlarm;
  final String? boxDeviceId;
  final String? cateId;

  const _VoltageHeader({required this.hasAlarm, this.boxDeviceId, this.cateId});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (cateId != null && cateId!.trim().isNotEmpty) cateId!.trim(),
      if (boxDeviceId != null && boxDeviceId!.trim().isNotEmpty)
        boxDeviceId!.trim(),
    ].join('  •  ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFF1197D1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'VOLTAGE MONITOR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (hasAlarm) const _AlarmBadge(),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VoltageChart extends StatelessWidget {
  final _VoltageCache cache;
  final TooltipBehavior tooltip;
  final ZoomPanBehavior zoomPan;

  const _VoltageChart({
    required this.cache,
    required this.tooltip,
    required this.zoomPan,
  });

  @override
  Widget build(BuildContext context) {
    final values = cache.data
        .expand((e) => [e.minVol, e.maxVol, e.minVolStd, e.maxVolStd])
        .where((v) => v != 0)
        .toList();

    double minY = values.isEmpty ? 0 : values.reduce((a, b) => a < b ? a : b);
    double maxY = values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);

    minY -= 4;
    maxY += 4;

    return SfCartesianChart(
      key: ValueKey(
        '${cache.data.first.recordedMinute}_${cache.data.last.recordedMinute}_${minY}_${maxY}_${cache.hasAlarm}',
      ),
      enableAxisAnimation: false,
      backgroundColor: Colors.transparent,
      plotAreaBackgroundColor: Colors.transparent,
      tooltipBehavior: tooltip,
      zoomPanBehavior: zoomPan,
      legend: Legend(
        isVisible: true,
        position: LegendPosition.top,
        overflowMode: LegendItemOverflowMode.wrap,
        textStyle: TextStyle(
          color: Colors.white.withOpacity(0.85),
          fontSize: 14,
        ),
      ),
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat.Hm(),
        intervalType: DateTimeIntervalType.hours,
        majorGridLines: MajorGridLines(color: Colors.white.withOpacity(0.05)),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 14,
        ),
      ),
      primaryYAxis: NumericAxis(
        minimum: minY,
        maximum: maxY,
        interval: 5,
        edgeLabelPlacement: EdgeLabelPlacement.shift,
        axisLine: const AxisLine(color: Colors.transparent),
        majorTickLines: const MajorTickLines(size: 0),
        majorGridLines: MajorGridLines(
          color: Colors.white.withOpacity(0.08),
          width: 1,
          dashArray: const [4, 4],
        ),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 14,
        ),
        labelFormat: '{value}V',
        plotBands: [
          if (cache.minStd != 0 && cache.maxStd != 0)
            PlotBand(
              start: cache.minStd,
              end: cache.maxStd,
              color: const Color(0xFF1197D1).withOpacity(0.08),
            ),
          if (cache.minStd != 0)
            PlotBand(
              start: 0,
              end: cache.minStd,
              color: Colors.red.withOpacity(0.05),
            ),
          if (cache.maxStd != 0)
            PlotBand(
              start: cache.maxStd,
              end: maxY,
              color: Colors.red.withOpacity(0.05),
            ),
        ],
      ),
      series: <CartesianSeries>[
        SplineSeries<VoltageDetail, DateTime>(
          animationDuration: 0,
          dataSource: cache.data,
          xValueMapper: (e, _) => e.recordedMinute,
          yValueMapper: (e, _) => e.minVol == 0 ? null : e.minVol,
          emptyPointSettings: const EmptyPointSettings(
            mode: EmptyPointMode.gap,
          ),
          color: const Color(0xFF00B4FF),
          name: 'Min Voltage',
          markerSettings: const MarkerSettings(isVisible: false),
          splineType: SplineType.monotonic,
        ),
        SplineSeries<VoltageDetail, DateTime>(
          animationDuration: 0,
          dataSource: cache.data,
          xValueMapper: (e, _) => e.recordedMinute,
          yValueMapper: (e, _) => e.maxVol == 0 ? null : e.maxVol,
          emptyPointSettings: const EmptyPointSettings(
            mode: EmptyPointMode.gap,
          ),
          color: const Color(0xFFFF9500),
          width: 2,
          name: 'Max Voltage',
          markerSettings: const MarkerSettings(isVisible: false),
          splineType: SplineType.monotonic,
        ),
        if (cache.alarmMin.isNotEmpty)
          _alarmSeries(
            'MIN',
            cache.alarmMin,
            (e) => e.minVol,
            Colors.redAccent,
          ),
        if (cache.alarmMax.isNotEmpty)
          _alarmSeries(
            'MAX',
            cache.alarmMax,
            (e) => e.maxVol,
            Colors.orangeAccent,
          ),
      ],
    );
  }

  static ScatterSeries<VoltageDetail, DateTime> _alarmSeries(
    String name,
    List<VoltageDetail> alarms,
    double Function(VoltageDetail) valueGetter,
    Color color,
  ) {
    return ScatterSeries<VoltageDetail, DateTime>(
      animationDuration: 0,
      animationDelay: 0,
      isVisibleInLegend: false,
      name: name,
      dataSource: List<VoltageDetail>.unmodifiable(alarms),
      xValueMapper: (e, _) => e.recordedMinute,
      yValueMapper: (e, _) {
        final v = valueGetter(e);
        return v == 0 ? null : v;
      },
      color: color,
      markerSettings: MarkerSettings(
        isVisible: true,
        width: 18,
        height: 18,
        borderColor: Colors.red,
        borderWidth: 2,
      ),
      dataLabelMapper: (e, _) =>
          '$name\n${DateFormat('dd/MM HH:mm').format(e.recordedMinute)}\n'
          '${valueGetter(e).toStringAsFixed(1)}V\n'
          'STD ${e.minVolStd.toStringAsFixed(0)}-${e.maxVolStd.toStringAsFixed(0)}V',
      dataLabelSettings: const DataLabelSettings(
        isVisible: true,
        opacity: 1,
        labelAlignment: ChartDataLabelAlignment.top,
        textStyle: TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _AlarmBadge extends StatefulWidget {
  const _AlarmBadge();

  @override
  State<_AlarmBadge> createState() => _AlarmBadgeState();
}

class _AlarmBadgeState extends State<_AlarmBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
            SizedBox(width: 4),
            Text(
              'VOLTAGE ALARM',
              style: TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VoltageChartDialog extends StatefulWidget {
  final UtilityDashboardOverviewApi api;
  final String facId;

  const VoltageChartDialog({super.key, required this.api, required this.facId});

  @override
  State<VoltageChartDialog> createState() => _VoltageChartDialogState();
}

class _VoltageChartDialogState extends State<VoltageChartDialog> {
  final GlobalKey<VoltageDetailChartState> _chartKey =
      GlobalKey<VoltageDetailChartState>();

  bool _showChart = true;
  bool _closing = false;

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;

    await _chartKey.currentState?.prepareToClose();

    if (!mounted) return;

    setState(() {
      _showChart = false;
    });

    await Future.delayed(const Duration(milliseconds: 80));

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (_) => _close(),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              if (_showChart)
                VoltageDetailChart(
                  key: _chartKey,
                  api: widget.api,
                  facId: widget.facId,
                )
              else
                const SizedBox.expand(),
              if (!_closing)
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    onPressed: _close,
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
