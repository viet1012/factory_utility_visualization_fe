import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_dashboard_api/utility_dashboard_overview_api.dart';

class VoltageDetail {
  final DateTime time;
  final double d108;
  final double d110;
  final double d112;
  final String alarm;

  VoltageDetail({
    required this.time,
    required this.d108,
    required this.d110,
    required this.d112,
    required this.alarm,
  });

  factory VoltageDetail.fromJson(Map<String, dynamic> json) {
    return VoltageDetail(
      time: DateTime.parse(json["pickAt"]),
      d108: (json["d108"] ?? 0).toDouble(),
      d110: (json["d110"] ?? 0).toDouble(),
      d112: (json["d112"] ?? 0).toDouble(),
      alarm: json["alarm"] ?? "Normal",
    );
  }
}

class _VoltageCache {
  final List<VoltageDetail> data;
  final List<VoltageDetail> alarmD12;
  final List<VoltageDetail> alarmD14;
  final List<VoltageDetail> alarmD16;
  final bool hasAlarm;

  const _VoltageCache({
    required this.data,
    required this.alarmD12,
    required this.alarmD14,
    required this.alarmD16,
    required this.hasAlarm,
  });

  static bool _hasValue(double v) => v != 0;

  static bool isCritical(double v) => _hasValue(v) && (v < 323 || v > 437);

  static bool isAlarm(double v) => _hasValue(v) && (v < 342 || v > 418);

  static bool isWarning(double v) => _hasValue(v) && (v < 360 || v > 400);

  static _VoltageCache from(List<VoltageDetail> d) {
    final a12 = d.where((e) => isAlarm(e.d108)).toList(growable: false);
    final a14 = d.where((e) => isAlarm(e.d110)).toList(growable: false);
    final a16 = d.where((e) => isAlarm(e.d112)).toList(growable: false);

    return _VoltageCache(
      data: List.unmodifiable(d),
      alarmD12: a12,
      alarmD14: a14,
      alarmD16: a16,
      hasAlarm: a12.isNotEmpty || a14.isNotEmpty || a16.isNotEmpty,
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

      // đợi 1-2 frame để chart unmount hẳn
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
      final d = await widget.api.getVoltageDetail(facId: widget.facId);
      if (!mounted || _disposed || _closing) return;

      final next = _VoltageCache.from(d);

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

  bool _dataChanged(_VoltageCache next) {
    final cur = _cache;
    if (cur == null) return true;
    if (next.data.length != cur.data.length) return true;
    if (next.hasAlarm != cur.hasAlarm) return true;
    if (next.alarmD12.length != cur.alarmD12.length) return true;
    if (next.alarmD14.length != cur.alarmD14.length) return true;
    if (next.alarmD16.length != cur.alarmD16.length) return true;
    if (next.data.isEmpty) return false;

    final firstNew = next.data.first;
    final firstCur = cur.data.first;
    final lastNew = next.data.last;
    final lastCur = cur.data.last;

    return firstNew.time != firstCur.time ||
        lastNew.time != lastCur.time ||
        firstNew.d108 != firstCur.d108 ||
        firstNew.d110 != firstCur.d110 ||
        firstNew.d112 != firstCur.d112 ||
        lastNew.d108 != lastCur.d108 ||
        lastNew.d110 != lastCur.d110 ||
        lastNew.d112 != lastCur.d112;
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
          _VoltageHeader(hasAlarm: hasAlarm),
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

// ─────────────────────────────────────────────────────────────────────────────
// _VoltageHeader — StatelessWidget, tách hoàn toàn khỏi chart
// Khi _AlarmBadge blink → chỉ header repaint, chart KHÔNG bị kéo theo
// ─────────────────────────────────────────────────────────────────────────────

class _VoltageHeader extends StatelessWidget {
  final bool hasAlarm;

  const _VoltageHeader({required this.hasAlarm});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _VoltageChart — StatelessWidget thuần
// Chỉ rebuild khi cache reference thay đổi (data mới từ API)
// _tooltip và _zoomPan được pass vào, không recreate
// ─────────────────────────────────────────────────────────────────────────────

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
        .expand((e) => [e.d108, e.d110, e.d112])
        .where((v) => v != 0)
        .toList();

    double minY = values.isEmpty ? 0 : values.reduce((a, b) => a < b ? a : b);

    double maxY = values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);

    print('filtered values count: ${values.length}');
    print('minY: $minY');
    print('maxY: $maxY');

    minY -= 2;
    maxY += 2;
    // thêm padding
    minY = minY - 2;
    maxY = maxY + 2;
    return SfCartesianChart(
      key: ValueKey(
        '${cache.data.first.time}_${cache.data.last.time}_${minY}_${maxY}',
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
          PlotBand(
            start: 360,
            end: 400,
            color: const Color(0xFF1197D1).withOpacity(0.08),
          ),

          PlotBand(
            start: 400,
            end: 418,
            color: Colors.orange.withOpacity(0.08),
          ),
          PlotBand(start: 0, end: 323, color: Colors.red.withOpacity(0.05)),
          PlotBand(start: 437, end: 500, color: Colors.red.withOpacity(0.05)),
        ],
      ),
      series: <CartesianSeries>[
        SplineSeries<VoltageDetail, DateTime>(
          animationDuration: 0,
          dataSource: cache.data,
          xValueMapper: (e, _) => e.time,
          yValueMapper: (e, _) => e.d108 == 0 ? null : e.d108,
          emptyPointSettings: const EmptyPointSettings(
            mode: EmptyPointMode.gap,
          ),
          color: const Color(0xFF00B4FF),
          name: 'D108',
          markerSettings: const MarkerSettings(isVisible: false),
          splineType: SplineType.monotonic,
        ),
        SplineSeries<VoltageDetail, DateTime>(
          animationDuration: 0,
          dataSource: cache.data,
          xValueMapper: (e, _) => e.time,
          yValueMapper: (e, _) => e.d110 == 0 ? null : e.d110,
          emptyPointSettings: const EmptyPointSettings(
            mode: EmptyPointMode.gap,
          ),
          color: const Color(0xFFFF9500),
          width: 2,
          name: 'D110',
          markerSettings: const MarkerSettings(isVisible: false),
          splineType: SplineType.monotonic,
        ),
        SplineSeries<VoltageDetail, DateTime>(
          animationDuration: 0,
          dataSource: cache.data,
          xValueMapper: (e, _) => e.time,
          yValueMapper: (e, _) => e.d112 == 0 ? null : e.d112,
          emptyPointSettings: const EmptyPointSettings(
            mode: EmptyPointMode.gap,
          ),
          color: const Color(0xFF2ECC71),
          width: 2,
          name: 'D112',
          markerSettings: const MarkerSettings(isVisible: false),
          splineType: SplineType.monotonic,
        ),
        if (cache.alarmD12.isNotEmpty)
          _alarmSeries('D108', cache.alarmD12, (e) => e.d108),
        if (cache.alarmD14.isNotEmpty)
          _alarmSeries('D110', cache.alarmD14, (e) => e.d110),
        if (cache.alarmD16.isNotEmpty)
          _alarmSeries('D112', cache.alarmD16, (e) => e.d112),
      ],
    );
  }

  static ScatterSeries<VoltageDetail, DateTime> _alarmSeries(
    String name,
    List<VoltageDetail> alarms,
    double Function(VoltageDetail) valueGetter,
  ) {
    return ScatterSeries<VoltageDetail, DateTime>(
      animationDuration: 0,
      animationDelay: 0,
      isVisibleInLegend: false,
      name: name,
      dataSource: List<VoltageDetail>.unmodifiable(alarms),
      xValueMapper: (e, _) => e.time,
      yValueMapper: (e, _) {
        final v = valueGetter(e);
        return v == 0 ? null : v;
      },
      color: Colors.orange,
      markerSettings: const MarkerSettings(
        isVisible: true,
        width: 18,
        height: 18,
        borderColor: Colors.red,
        borderWidth: 2,
      ),
      dataLabelMapper: (e, _) =>
          '$name\n${DateFormat('dd/MM HH:mm').format(e.time)}\n'
          '${valueGetter(e).toStringAsFixed(1)}V',
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

// ─────────────────────────────────────────────────────────────────────────────
// _AlarmBadge — animation hoàn toàn isolated
// FadeTransition dùng Tween trực tiếp → không setState, không rebuild parent
// ─────────────────────────────────────────────────────────────────────────────

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

    // 1) báo child chuẩn bị đóng
    await _chartKey.currentState?.prepareToClose();

    if (!mounted) return;

    // 2) remove chart khỏi tree
    setState(() {
      _showChart = false;
    });

    // 3) đợi thêm 1-2 frame cho Dialog settle
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
