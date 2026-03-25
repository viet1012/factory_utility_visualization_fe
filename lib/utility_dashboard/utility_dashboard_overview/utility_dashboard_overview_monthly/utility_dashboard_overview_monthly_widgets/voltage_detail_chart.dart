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
  void dispose() {
    _disposed = true;
    _reloadTimer?.cancel();
    super.dispose();
  }

  Future<void> prepareToClose() async {
    if (_closing || !mounted) return;
    _closing = true;

    _reloadTimer?.cancel();

    if (_showChart) {
      setState(() {
        _showChart = false;
      });

      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _load() async {
    if (_loadingNow || _disposed || _closing) return;
    _loadingNow = true;

    try {
      final d = await widget.api.getVoltageDetail(facId: widget.facId);
      if (!mounted || _disposed || _closing) return;

      final next = _VoltageCache.from(d);

      if (_dataChanged(next)) {
        setState(() {
          _cache = next;
          _error = null;
          _isLoading = false;
        });
      } else if (_isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
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
    return SfCartesianChart(
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
        minimum: 300,
        maximum: 460,
        interval: 20,
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
            start: 342,
            end: 360,
            color: Colors.orange.withOpacity(0.08),
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

// voltage_detail_chart.dart
//
// import 'dart:async';
// import 'dart:ui' as ui;
//
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
//
// import '../../utility_dashboard_api/utility_dashboard_overview_api.dart';
//
// // =============================================================================
// // MODEL
// // =============================================================================
// class AlarmPoint {
//   final DateTime time;
//   final double value;
//   final String tag; // 🔥 D108 / D110 / D112
//
//   AlarmPoint({required this.time, required this.value, required this.tag});
// }
//
// class VoltageDetail {
//   final DateTime time;
//   final double d108;
//   final double d110;
//   final double d112;
//   final String alarm;
//
//   VoltageDetail({
//     required this.time,
//     required this.d108,
//     required this.d110,
//     required this.d112,
//     required this.alarm,
//   });
//
//   factory VoltageDetail.fromJson(Map<String, dynamic> json) {
//     return VoltageDetail(
//       time: DateTime.parse(json["pickAt"]),
//       d108: (json["d108"] ?? 0).toDouble(),
//       d110: (json["d110"] ?? 0).toDouble(),
//       d112: (json["d112"] ?? 0).toDouble(),
//       alarm: json["alarm"] ?? "Normal",
//     );
//   }
// }
//
// // =============================================================================
// // CACHE
// // =============================================================================
//
// class _VoltageCache {
//   final List<VoltageDetail> data;
//   final List<VoltageDetail> alarmD12;
//   final List<VoltageDetail> alarmD14;
//   final List<VoltageDetail> alarmD16;
//   final bool hasAlarm;
//
//   const _VoltageCache({
//     required this.data,
//     required this.alarmD12,
//     required this.alarmD14,
//     required this.alarmD16,
//     required this.hasAlarm,
//   });
//
//   static bool isAlarm(double v) => v < 342 || v > 418;
//
//   static _VoltageCache from(List<VoltageDetail> d) {
//     final a12 = d.where((e) => isAlarm(e.d108)).toList();
//     final a14 = d.where((e) => isAlarm(e.d110)).toList();
//     final a16 = d.where((e) => isAlarm(e.d112)).toList();
//     return _VoltageCache(
//       data: d,
//       alarmD12: a12,
//       alarmD14: a14,
//       alarmD16: a16,
//       hasAlarm: a12.isNotEmpty || a14.isNotEmpty || a16.isNotEmpty,
//     );
//   }
// }
//
// class VoltageDetailScreen extends StatelessWidget {
//   final UtilityDashboardOverviewApi api;
//   final String facId;
//
//   const VoltageDetailScreen({
//     super.key,
//     required this.api,
//     required this.facId,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: const Text('Voltage Detail'),
//         backgroundColor: Colors.black,
//       ),
//       body: SafeArea(
//         child: _VoltageDetailChart(api: api, facId: facId),
//       ),
//     );
//   }
// }
// // =============================================================================
// // VoltageChartDialog — entry point public, dùng từ bên ngoài
// // =============================================================================

class VoltageChartDialog extends StatefulWidget {
  final UtilityDashboardOverviewApi api;
  final String facId;

  const VoltageChartDialog({super.key, required this.api, required this.facId});

  @override
  State<VoltageChartDialog> createState() => _VoltageChartDialogState();
}

//
class _VoltageChartDialogState extends State<VoltageChartDialog> {
  bool _showChart = true;
  bool _closing = false;

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;

    // 🔥 Bước 1: Remove chart khỏi tree ngay lập tức
    setState(() => _showChart = false);

    // 🔥 Bước 2: Đợi đủ để Syncfusion flush pending layout
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) Navigator.pop(context);
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
          // width: 1400,
          // height: 620,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              // 🔥 Khi _showChart = false → thay bằng SizedBox → Syncfusion bị unmount
              if (_showChart)
                KeyedSubtree(
                  key: const ValueKey('voltage_chart'),
                  child: VoltageDetailChart(
                    api: widget.api,
                    facId: widget.facId,
                  ),
                )
              else
                const SizedBox.expand(),

              // 🔥 Nút đóng chỉ hiện khi chưa closing
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

//
// // =============================================================================
// // _VoltageDetailChart — private, chỉ dùng trong file này
// // =============================================================================
//
// class _VoltageDetailChart extends StatefulWidget {
//   final UtilityDashboardOverviewApi api;
//   final String facId;
//
//   const _VoltageDetailChart({
//     super.key,
//     required this.api,
//     required this.facId,
//   });
//
//   @override
//   State<_VoltageDetailChart> createState() => _VoltageDetailChartState();
// }
//
// class _VoltageDetailChartState extends State<_VoltageDetailChart> {
//   _VoltageCache? _cache;
//   bool _isLoading = true;
//   Object? _error;
//
//   Timer? _timer;
//   bool _disposed = false;
//   bool _loadingNow = false;
//
//   late final TooltipBehavior _tooltip;
//   late final ZoomPanBehavior _zoomPan;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _tooltip = TooltipBehavior(enable: true);
//     _zoomPan = ZoomPanBehavior(
//       enablePinching: true,
//       enablePanning: true,
//       zoomMode: ZoomMode.x,
//     );
//
//     _load();
//   }
//
//   @override
//   void dispose() {
//     _disposed = true;
//     _timer?.cancel(); // 🔥 FIX QUAN TRỌNG
//     super.dispose();
//   }
//
//   Future<void> _load() async {
//     if (_loadingNow || _disposed) return;
//     _loadingNow = true;
//
//     try {
//       final data = await widget.api.getVoltageDetail(facId: widget.facId);
//
//       if (!mounted || _disposed) return;
//
//       final next = _VoltageCache.from(data);
//
//       if (_dataChanged(next)) {
//         setState(() {
//           _cache = next;
//           _error = null;
//           _isLoading = false;
//         });
//       } else {
//         if (_isLoading) setState(() => _isLoading = false);
//       }
//     } catch (e) {
//       if (!mounted || _disposed) return;
//
//       setState(() {
//         _error = e;
//         _isLoading = false;
//       });
//     } finally {
//       _loadingNow = false;
//     }
//
//     // 🔥 SAFE RELOAD LOOP
//     if (!_disposed) {
//       _timer?.cancel();
//       _timer = Timer(const Duration(seconds: 30), _load);
//     }
//   }
//
//   bool _dataChanged(_VoltageCache next) {
//     final cur = _cache;
//     if (cur == null) return true;
//     if (next.data.length != cur.data.length) return true;
//     if (next.data.isEmpty) return false;
//
//     final last = next.data.length - 1;
//
//     return next.data[0].d108 != cur.data[0].d108 ||
//         next.data[last].d108 != cur.data[last].d108;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         _VoltageHeader(hasAlarm: _cache?.hasAlarm ?? false),
//         Expanded(child: _buildBody()),
//       ],
//     );
//   }
//
//   Widget _buildBody() {
//     if (_isLoading) {
//       return const Center(child: CircularProgressIndicator());
//     }
//
//     if (_error != null) {
//       return Center(child: Text('Error: $_error'));
//     }
//
//     return RepaintBoundary(
//       child: _VoltageChart(
//         cache: _cache!,
//         tooltip: _tooltip,
//         zoomPan: _zoomPan,
//       ),
//     );
//   }
// }
//
// // =============================================================================
// // _VoltageHeader
// // =============================================================================
// class _VoltageHeader extends StatelessWidget {
//   final bool hasAlarm;
//
//   const _VoltageHeader({required this.hasAlarm});
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         const Text('VOLTAGE MONITOR', style: TextStyle(color: Colors.white)),
//         const Spacer(),
//         if (hasAlarm) _AlarmBadge(active: true),
//       ],
//     );
//   }
// }
//
// // =============================================================================
// // _AlarmBadge
// // =============================================================================
//
// class _AlarmBadge extends StatefulWidget {
//   final bool active;
//
//   const _AlarmBadge({required this.active});
//
//   @override
//   State<_AlarmBadge> createState() => _AlarmBadgeState();
// }
//
// class _AlarmBadgeState extends State<_AlarmBadge>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _ctrl;
//   late final Animation<double> _opacity;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _ctrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 800),
//     );
//
//     _opacity = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
//
//     _updateAnimation();
//   }
//
//   @override
//   void didUpdateWidget(covariant _AlarmBadge oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     _updateAnimation();
//   }
//
//   void _updateAnimation() {
//     if (widget.active) {
//       _ctrl.repeat(reverse: true);
//     } else {
//       _ctrl.stop();
//       _ctrl.value = 1.0; // đứng yên
//     }
//   }
//
//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return FadeTransition(
//       opacity: _opacity,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//         decoration: BoxDecoration(
//           color: Colors.red.withOpacity(0.15),
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(color: Colors.red),
//         ),
//         child: const Text(
//           'ALARM',
//           style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
//         ),
//       ),
//     );
//   }
// }
// // =============================================================================
// // _VoltageChart
// // =============================================================================
//
// class _VoltageChart extends StatelessWidget {
//   final _VoltageCache cache;
//   final TooltipBehavior tooltip;
//   final ZoomPanBehavior zoomPan;
//
//   _VoltageChart({
//     required this.cache,
//     required this.tooltip,
//     required this.zoomPan,
//   });
//
//   DateTime? visibleMin;
//   DateTime? visibleMax;
//
//   @override
//   Widget build(BuildContext context) {
//     final alarmPoints = buildAlarmPoints(cache.data);
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         return Stack(
//           children: [
//             SfCartesianChart(
//               enableAxisAnimation: false,
//               backgroundColor: Colors.transparent,
//               plotAreaBackgroundColor: Colors.transparent,
//               tooltipBehavior: tooltip,
//               zoomPanBehavior: zoomPan,
//               legend: Legend(
//                 isVisible: true,
//                 position: LegendPosition.top,
//                 overflowMode: LegendItemOverflowMode.wrap,
//                 textStyle: TextStyle(
//                   color: Colors.white.withOpacity(0.85),
//                   fontSize: 14,
//                 ),
//               ),
//               primaryXAxis: DateTimeAxis(
//                 dateFormat: DateFormat.Hm(),
//                 intervalType: DateTimeIntervalType.hours,
//                 majorGridLines: MajorGridLines(
//                   color: Colors.white.withOpacity(0.05),
//                 ),
//                 labelStyle: TextStyle(
//                   color: Colors.white.withOpacity(0.5),
//                   fontSize: 14,
//                 ),
//               ),
//               primaryYAxis: NumericAxis(
//                 minimum: 300,
//                 maximum: 460,
//                 interval: 20,
//                 axisLine: const AxisLine(color: Colors.transparent),
//                 majorTickLines: const MajorTickLines(size: 0),
//                 majorGridLines: MajorGridLines(
//                   color: Colors.white.withOpacity(0.08),
//                   width: 1,
//                   dashArray: const [4, 4],
//                 ),
//                 labelStyle: TextStyle(
//                   color: Colors.white.withOpacity(0.5),
//                   fontSize: 14,
//                 ),
//                 labelFormat: '{value}V',
//                 plotBands: [
//                   PlotBand(
//                     start: 360,
//                     end: 400,
//                     color: const Color(0xFF1197D1).withOpacity(0.08),
//                   ),
//                   PlotBand(
//                     start: 342,
//                     end: 360,
//                     color: Colors.orange.withOpacity(0.08),
//                   ),
//                   PlotBand(
//                     start: 400,
//                     end: 418,
//                     color: Colors.orange.withOpacity(0.08),
//                   ),
//                   PlotBand(
//                     start: 0,
//                     end: 323,
//                     color: Colors.red.withOpacity(0.05),
//                   ),
//                   PlotBand(
//                     start: 437,
//                     end: 500,
//                     color: Colors.red.withOpacity(0.05),
//                   ),
//                 ],
//               ),
//               series: <CartesianSeries>[
//                 SplineSeries<VoltageDetail, DateTime>(
//                   animationDuration: 0,
//                   dataSource: cache.data,
//                   xValueMapper: (e, _) => e.time,
//                   yValueMapper: (e, _) => e.d108 == 0 ? null : e.d108,
//                   emptyPointSettings: const EmptyPointSettings(
//                     mode: EmptyPointMode.gap,
//                   ),
//                   color: const Color(0xFF00B4FF),
//                   name: 'D108',
//                   markerSettings: const MarkerSettings(isVisible: false),
//                   splineType: SplineType.monotonic,
//                 ),
//                 SplineSeries<VoltageDetail, DateTime>(
//                   animationDuration: 0,
//                   dataSource: cache.data,
//                   xValueMapper: (e, _) => e.time,
//                   yValueMapper: (e, _) => e.d110 == 0 ? null : e.d110,
//                   emptyPointSettings: const EmptyPointSettings(
//                     mode: EmptyPointMode.gap,
//                   ),
//                   color: const Color(0xFFFF9500),
//                   width: 2,
//                   name: 'D110',
//                   markerSettings: const MarkerSettings(isVisible: false),
//                   splineType: SplineType.monotonic,
//                 ),
//                 SplineSeries<VoltageDetail, DateTime>(
//                   animationDuration: 0,
//                   dataSource: cache.data,
//                   xValueMapper: (e, _) => e.time,
//                   yValueMapper: (e, _) => e.d112 == 0 ? null : e.d112,
//                   emptyPointSettings: const EmptyPointSettings(
//                     mode: EmptyPointMode.gap,
//                   ),
//                   color: const Color(0xFF2ECC71),
//                   width: 2,
//                   name: 'D112',
//                   markerSettings: const MarkerSettings(isVisible: false),
//                   splineType: SplineType.monotonic,
//                 ),
//                 // if (cache.alarmD12.isNotEmpty)
//                 //   _alarmSeries('D108', cache.alarmD12, (e) => e.d108),
//                 // if (cache.alarmD14.isNotEmpty)
//                 //   _alarmSeries('D110', cache.alarmD14, (e) => e.d110),
//                 // if (cache.alarmD16.isNotEmpty)
//                 //   _alarmSeries('D112', cache.alarmD16, (e) => e.d112),
//               ],
//
//               /// 🔥 Overlay alarm
//             ),
//             IgnorePointer(
//               child: CustomPaint(
//                 size: Size.infinite,
//                 painter: AlarmPainter(alarms: alarmPoints),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   List<AlarmPoint> buildAlarmPoints(List<VoltageDetail> data) {
//     final List<AlarmPoint> result = [];
//
//     for (final e in data) {
//       if (e.d108 != 0 && (e.d108 < 342 || e.d108 > 396)) {
//         result.add(AlarmPoint(time: e.time, value: e.d108, tag: 'D108'));
//       }
//       if (e.d110 != 0 && (e.d110 < 342 || e.d110 > 396)) {
//         result.add(AlarmPoint(time: e.time, value: e.d110, tag: 'D110'));
//       }
//       if (e.d112 != 0 && (e.d112 < 342 || e.d112 > 396)) {
//         result.add(AlarmPoint(time: e.time, value: e.d112, tag: 'D112'));
//       }
//     }
//
//     return result;
//   }
//
//   static ScatterSeries<VoltageDetail, DateTime> _alarmSeries(
//     String name,
//     List<VoltageDetail> alarms,
//     double Function(VoltageDetail) valueGetter,
//   ) {
//     return ScatterSeries<VoltageDetail, DateTime>(
//       animationDuration: 0,
//       animationDelay: 0,
//       isVisibleInLegend: false,
//       name: name,
//       dataSource: List.of(alarms),
//       // 🔥 FIX
//       xValueMapper: (e, _) => e.time,
//       yValueMapper: (e, _) => valueGetter(e),
//       color: Colors.orange,
//       markerSettings: const MarkerSettings(
//         isVisible: true,
//         width: 18,
//         height: 18,
//         borderColor: Colors.red,
//         borderWidth: 2,
//       ),
//       dataLabelMapper: (e, _) =>
//           '$name\n${DateFormat('dd/MM HH:mm').format(e.time)}\n'
//           '${valueGetter(e).toStringAsFixed(1)}V',
//       dataLabelSettings: const DataLabelSettings(
//         isVisible: true,
//         labelAlignment: ChartDataLabelAlignment.top,
//         opacity: 1, // 🔥 FIX animation
//         textStyle: TextStyle(
//           color: Colors.redAccent,
//           fontWeight: FontWeight.bold,
//           fontSize: 13,
//         ),
//       ),
//     );
//   }
// }
//
// class AlarmPainter extends CustomPainter {
//   final List<AlarmPoint> alarms;
//
//   AlarmPainter({required this.alarms});
//
//   static const double minY = 300;
//   static const double maxY = 460;
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     if (alarms.isEmpty) return;
//
//     final pointPaint = Paint()
//       ..color = Colors.red
//       ..style = PaintingStyle.fill;
//
//     final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
//
//     final minX = alarms.first.time.millisecondsSinceEpoch.toDouble();
//     final maxX = alarms.last.time.millisecondsSinceEpoch.toDouble();
//
//     double mapX(DateTime t) {
//       final x = t.millisecondsSinceEpoch.toDouble();
//       return (x - minX) / (maxX - minX) * size.width;
//     }
//
//     double mapY(double v) {
//       return size.height - ((v - minY) / (maxY - minY) * size.height);
//     }
//
//     for (final a in alarms) {
//       final dx = mapX(a.time);
//       final dy = mapY(a.value);
//
//       // 🔥 DOT
//       canvas.drawCircle(Offset(dx, dy), 5, pointPaint);
//
//       // 🔥 GLOW
//       canvas.drawCircle(
//         Offset(dx, dy),
//         10,
//         pointPaint..color = Colors.red.withOpacity(0.2),
//       );
//
//       // 🔥 TEXT (PLC + value)
//       final textSpan = TextSpan(
//         text: '${a.tag}\n${a.value.toStringAsFixed(1)}V',
//         style: const TextStyle(
//           color: Colors.red,
//           fontSize: 10,
//           fontWeight: FontWeight.bold,
//         ),
//       );
//
//       textPainter.text = textSpan;
//       textPainter.layout();
//
//       textPainter.paint(canvas, Offset(dx + 4, dy - textPainter.height - 4));
//     }
//   }
//
//   @override
//   bool shouldRepaint(covariant AlarmPainter oldDelegate) {
//     return oldDelegate.alarms != alarms;
//   }
// }
