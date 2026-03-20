import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_dashboard_api/utility_dashboard_overview_api.dart';

class VoltageDetail {
  final DateTime time;
  final double d12;
  final double d14;
  final double d16;
  final String alarm;

  VoltageDetail({
    required this.time,
    required this.d12,
    required this.d14,
    required this.d16,
    required this.alarm,
  });

  factory VoltageDetail.fromJson(Map<String, dynamic> json) {
    return VoltageDetail(
      time: DateTime.parse(json["pickAt"]),
      d12: (json["d12"] ?? 0).toDouble(),
      d14: (json["d14"] ?? 0).toDouble(),
      d16: (json["d16"] ?? 0).toDouble(),
      alarm: json["alarm"] ?? "Normal",
    );
  }
}

// ──────────────────────────────────────────
// Immutable cache — tính một lần sau fetch, không tính trong build()
// ─────────────────────────────────────────────────────────────────────────────

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

  static _VoltageCache from(List<VoltageDetail> d) {
    final a12 = d.where((e) => e.d12 > 245).toList();
    final a14 = d.where((e) => e.d14 > 245).toList();
    final a16 = d.where((e) => e.d16 > 245).toList();
    return _VoltageCache(
      data: d,
      alarmD12: a12,
      alarmD14: a14,
      alarmD16: a16,
      hasAlarm: a12.isNotEmpty || a14.isNotEmpty || a16.isNotEmpty,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StatefulWidget
// ─────────────────────────────────────────────────────────────────────────────

class VoltageDetailChart extends StatefulWidget {
  final UtilityDashboardOverviewApi api;

  const VoltageDetailChart({super.key, required this.api});

  @override
  State<VoltageDetailChart> createState() => _VoltageDetailChartState();
}

class _VoltageDetailChartState extends State<VoltageDetailChart> {
  _VoltageCache? _cache;
  bool isLoading = true;
  Object? error;

  // Khởi tạo một lần, không recreate mỗi build()
  // late final đảm bảo Syncfusion không tạo lại object nặng
  late final TooltipBehavior _tooltip;
  late final ZoomPanBehavior _zoomPan;

  bool _loadingNow = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    // Tạo đúng một lần — Syncfusion reuse object này xuyên suốt lifecycle
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
    super.dispose();
  }

  Future<void> _load() async {
    if (_loadingNow || _disposed) return;
    _loadingNow = true;

    try {
      final d = await widget.api.getVoltageDetail();
      if (!mounted) return;

      final next = _VoltageCache.from(d);

      // Chỉ setState khi data thực sự thay đổi
      if (_dataChanged(next)) {
        setState(() {
          _cache = next;
          error = null;
          isLoading = false;
        });
      } else {
        if (isLoading) setState(() => isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e;
        isLoading = false;
      });
    } finally {
      _loadingNow = false;
    }

    if (!_disposed) {
      Future.delayed(const Duration(seconds: 30), _load);
    }
  }

  bool _dataChanged(_VoltageCache next) {
    final cur = _cache;
    if (cur == null) return true;
    if (next.data.length != cur.data.length) return true;
    // So sánh sample đầu + cuối để tránh loop toàn bộ list
    if (next.data.isEmpty) return false;
    final last = next.data.length - 1;
    return next.data[0].d12 != cur.data[0].d12 ||
        next.data[0].time != cur.data[0].time ||
        next.data[last].d12 != cur.data[last].d12 ||
        next.data[last].time != cur.data[last].time;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build — shell + header tách khỏi chart body
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
          // Header — StatelessWidget riêng, rebuild độc lập với chart
          _VoltageHeader(hasAlarm: _cache?.hasAlarm ?? false),

          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1197D1)),
                  )
                : error != null
                ? Center(
                    child: Text(
                      'Error: $error',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                    // RepaintBoundary: chart có GPU layer riêng
                    // header alarm badge blink KHÔNG kéo chart repaint
                    child: RepaintBoundary(
                      child: _VoltageChart(
                        cache: _cache!,
                        tooltip: _tooltip,
                        zoomPan: _zoomPan,
                      ),
                    ),
                  ),
          ),
        ],
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
        minimum: 190,
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
            start: 205,
            end: 245,
            color: const Color(0xFF1197D1).withOpacity(0.06),
            borderColor: Colors.transparent,
          ),
          PlotBand(
            start: 205,
            end: 205,
            borderWidth: 1.5,
            borderColor: Colors.grey.withOpacity(0.5),
            dashArray: const [6, 4],
            text: '  205V',
            textStyle: TextStyle(
              color: Colors.grey.withOpacity(0.7),
              fontSize: 18,
            ),
            verticalTextAlignment: TextAnchor.start,
          ),
          PlotBand(
            start: 245,
            end: 245,
            borderWidth: 1.5,
            borderColor: Colors.red.withOpacity(0.4),
            dashArray: const [6, 4],
            text: '  245V',
            textStyle: TextStyle(
              color: Colors.red.withOpacity(0.4),
              fontSize: 18,
            ),
            verticalTextAlignment: TextAnchor.start,
          ),
        ],
      ),
      series: <CartesianSeries>[
        SplineSeries<VoltageDetail, DateTime>(
          animationDuration: 0,
          dataSource: cache.data,
          xValueMapper: (e, _) => e.time,
          yValueMapper: (e, _) => e.d12 == 0 ? null : e.d12,
          emptyPointSettings: const EmptyPointSettings(
            mode: EmptyPointMode.gap,
          ),
          color: const Color(0xFF00B4FF),
          name: 'D12',
          markerSettings: const MarkerSettings(isVisible: false),
          splineType: SplineType.monotonic,
        ),
        SplineSeries<VoltageDetail, DateTime>(
          animationDuration: 0,
          dataSource: cache.data,
          xValueMapper: (e, _) => e.time,
          yValueMapper: (e, _) => e.d14 == 0 ? null : e.d14,
          emptyPointSettings: const EmptyPointSettings(
            mode: EmptyPointMode.gap,
          ),
          color: const Color(0xFFFF9500),
          width: 2,
          name: 'D14',
          markerSettings: const MarkerSettings(isVisible: false),
          splineType: SplineType.monotonic,
        ),
        SplineSeries<VoltageDetail, DateTime>(
          animationDuration: 0,
          dataSource: cache.data,
          xValueMapper: (e, _) => e.time,
          yValueMapper: (e, _) => e.d16 == 0 ? null : e.d16,
          emptyPointSettings: const EmptyPointSettings(
            mode: EmptyPointMode.gap,
          ),
          color: const Color(0xFF2ECC71),
          width: 2,
          name: 'D16',
          markerSettings: const MarkerSettings(isVisible: false),
          splineType: SplineType.monotonic,
        ),
        if (cache.alarmD12.isNotEmpty)
          _alarmSeries('D12', cache.alarmD12, (e) => e.d12),
        if (cache.alarmD14.isNotEmpty)
          _alarmSeries('D14', cache.alarmD14, (e) => e.d14),
        if (cache.alarmD16.isNotEmpty)
          _alarmSeries('D16', cache.alarmD16, (e) => e.d16),
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
      dataSource: alarms,
      xValueMapper: (e, _) => e.time,
      yValueMapper: (e, _) => valueGetter(e),
      color: Colors.red.withOpacity(0.8),
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
              'OVER VOLTAGE',
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

// import 'dart:async';
//
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
//
// import '../../utility_dashboard_api/utility_dashboard_overview_api.dart';
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Model
// // ─────────────────────────────────────────────────────────────────────────────
//
// class VoltageDetail {
//   final DateTime time;
//   final Map<String, double> values; // {"L1": 220.5, "L2": 218.3, "L3": 222.1}
//   final String alarm;
//
//   VoltageDetail({
//     required this.time,
//     required this.values,
//     required this.alarm,
//   });
//
//   factory VoltageDetail.fromJson(Map<String, dynamic> json) {
//     final rawValues = json["values"] as Map<String, dynamic>? ?? {};
//
//     return VoltageDetail(
//       time: DateTime.parse(json["time"] ?? DateTime.now().toIso8601String()),
//       values: rawValues.map(
//         (k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0.0),
//       ),
//       alarm: json["alarm"]?.toString() ?? "Normal",
//     );
//   }
//
//   /// Helper để lấy value an toàn
//   double getValue(String key) => values[key] ?? 0.0;
//
//   /// Kiểm tra có alarm không
//   bool get hasAlarm => alarm == "Alarm";
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Immutable cache
// // ─────────────────────────────────────────────────────────────────────────────
//
// class _VoltageCache {
//   final List<VoltageDetail> data;
//   final Map<String, List<VoltageDetail>>
//   alarmMap; // {"L1": [alarm points], "L2": [...]}
//   final bool hasAlarm;
//   final List<String> lineNames; // ["L1", "L2", "L3"]
//
//   const _VoltageCache({
//     required this.data,
//     required this.alarmMap,
//     required this.hasAlarm,
//     required this.lineNames,
//   });
//
//   static _VoltageCache from(List<VoltageDetail> data) {
//     final Map<String, List<VoltageDetail>> alarmMap = {};
//     final Set<String> allLineNames = {};
//
//     // Collect all line names and alarm points
//     for (var detail in data) {
//       allLineNames.addAll(detail.values.keys);
//
//       detail.values.forEach((lineName, value) {
//         // Check if value is out of range
//         if (value > 245 || value < 205) {
//           alarmMap.putIfAbsent(lineName, () => []);
//           alarmMap[lineName]!.add(detail);
//         }
//       });
//     }
//
//     return _VoltageCache(
//       data: data,
//       alarmMap: alarmMap,
//       hasAlarm: alarmMap.isNotEmpty,
//       lineNames: allLineNames.toList()..sort(),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Main Widget
// // ─────────────────────────────────────────────────────────────────────────────
//
// class VoltageDetailChart extends StatefulWidget {
//   final UtilityDashboardOverviewApi api;
//   final String facId;
//
//   const VoltageDetailChart({super.key, required this.api, required this.facId});
//
//   @override
//   State<VoltageDetailChart> createState() => _VoltageDetailChartState();
// }
//
// class _VoltageDetailChartState extends State<VoltageDetailChart> {
//   _VoltageCache? _cache;
//   bool isLoading = true;
//   Object? error;
//
//   late final TooltipBehavior _tooltip;
//   late final ZoomPanBehavior _zoomPan;
//
//   bool _loadingNow = false;
//   bool _disposed = false;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _tooltip = TooltipBehavior(
//       enable: true,
//       color: const Color(0xFF1A2E3D),
//       textStyle: const TextStyle(color: Colors.white, fontSize: 13),
//     );
//
//     _zoomPan = ZoomPanBehavior(
//       enablePinching: true,
//       enableDoubleTapZooming: true,
//       enableMouseWheelZooming: true,
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
//     super.dispose();
//   }
//
//   Future<void> _load() async {
//     if (_loadingNow || _disposed) return;
//     _loadingNow = true;
//
//     try {
//       final List<VoltageDetail> details = await widget.api.getVoltageDetail(
//         facId: widget.facId,
//       );
//
//       if (!mounted) return;
//
//       final nextCache = _VoltageCache.from(details);
//
//       if (_dataChanged(nextCache)) {
//         setState(() {
//           _cache = nextCache;
//           error = null;
//           isLoading = false;
//         });
//       } else {
//         if (isLoading) setState(() => isLoading = false);
//       }
//     } catch (e) {
//       if (!mounted) return;
//       setState(() {
//         error = e;
//         isLoading = false;
//       });
//     } finally {
//       _loadingNow = false;
//     }
//
//     if (!_disposed) {
//       Future.delayed(const Duration(seconds: 30), _load);
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
//     return next.data[0].time != cur.data[0].time ||
//         next.data[last].time != cur.data[last].time ||
//         next.hasAlarm != cur.hasAlarm;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 500,
//       decoration: BoxDecoration(
//         color: const Color(0xFF000000),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(
//           color: const Color(0xFF1197D1).withOpacity(0.4),
//           width: 1.5,
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: const Color(0xFF1197D1).withOpacity(0.15),
//             blurRadius: 20,
//             spreadRadius: 2,
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _VoltageHeader(hasAlarm: _cache?.hasAlarm ?? false),
//           Expanded(
//             child: isLoading
//                 ? const Center(
//                     child: CircularProgressIndicator(color: Color(0xFF1197D1)),
//                   )
//                 : error != null
//                 ? Center(
//                     child: Text(
//                       'Error: $error',
//                       style: const TextStyle(
//                         color: Colors.redAccent,
//                         fontSize: 13,
//                       ),
//                     ),
//                   )
//                 : _cache == null || _cache!.data.isEmpty
//                 ? const Center(
//                     child: Text(
//                       'No data available',
//                       style: TextStyle(color: Colors.white54),
//                     ),
//                   )
//                 : Padding(
//                     padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
//                     child: RepaintBoundary(
//                       child: _VoltageChart(
//                         cache: _cache!,
//                         tooltip: _tooltip,
//                         zoomPan: _zoomPan,
//                       ),
//                     ),
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Header
// // ─────────────────────────────────────────────────────────────────────────────
//
// class _VoltageHeader extends StatelessWidget {
//   final bool hasAlarm;
//
//   const _VoltageHeader({required this.hasAlarm});
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
//       child: Row(
//         children: [
//           Container(
//             width: 4,
//             height: 20,
//             decoration: BoxDecoration(
//               color: const Color(0xFF1197D1),
//               borderRadius: BorderRadius.circular(2),
//             ),
//           ),
//           const SizedBox(width: 10),
//           const Text(
//             'VOLTAGE MONITOR',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 14,
//               fontWeight: FontWeight.bold,
//               letterSpacing: 1.5,
//             ),
//           ),
//           const Spacer(),
//           if (hasAlarm) const _AlarmBadge(),
//         ],
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Chart
// // ─────────────────────────────────────────────────────────────────────────────
//
// class _VoltageChart extends StatelessWidget {
//   final _VoltageCache cache;
//   final TooltipBehavior tooltip;
//   final ZoomPanBehavior zoomPan;
//
//   const _VoltageChart({
//     required this.cache,
//     required this.tooltip,
//     required this.zoomPan,
//   });
//
//   // Color mapping for different lines
//   static const Map<String, Color> _lineColors = {
//     'L1': Color(0xFF00B4FF),
//     'L2': Color(0xFFFF9500),
//     'L3': Color(0xFF2ECC71),
//     'D12': Color(0xFF00B4FF),
//     'D14': Color(0xFFFF9500),
//     'D16': Color(0xFF2ECC71),
//   };
//
//   Color _getColorForLine(String lineName, int index) {
//     return _lineColors[lineName] ??
//         Color.lerp(Colors.blue, Colors.purple, index * 0.3)!;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return SfCartesianChart(
//       enableAxisAnimation: false,
//       backgroundColor: Colors.transparent,
//       plotAreaBackgroundColor: Colors.transparent,
//       tooltipBehavior: tooltip,
//       zoomPanBehavior: zoomPan,
//       legend: Legend(
//         isVisible: true,
//         position: LegendPosition.top,
//         overflowMode: LegendItemOverflowMode.wrap,
//         textStyle: TextStyle(
//           color: Colors.white.withOpacity(0.85),
//           fontSize: 14,
//         ),
//       ),
//       primaryXAxis: DateTimeAxis(
//         dateFormat: DateFormat.Hm(),
//         intervalType: DateTimeIntervalType.hours,
//         majorGridLines: MajorGridLines(color: Colors.white.withOpacity(0.05)),
//         labelStyle: TextStyle(
//           color: Colors.white.withOpacity(0.5),
//           fontSize: 14,
//         ),
//       ),
//       primaryYAxis: NumericAxis(
//         minimum: 190,
//         interval: 20,
//         axisLine: const AxisLine(color: Colors.transparent),
//         majorTickLines: const MajorTickLines(size: 0),
//         majorGridLines: MajorGridLines(
//           color: Colors.white.withOpacity(0.08),
//           width: 1,
//           dashArray: const [4, 4],
//         ),
//         labelStyle: TextStyle(
//           color: Colors.white.withOpacity(0.5),
//           fontSize: 14,
//         ),
//         labelFormat: '{value}V',
//         plotBands: [
//           PlotBand(
//             start: 205,
//             end: 245,
//             color: const Color(0xFF1197D1).withOpacity(0.06),
//             borderColor: Colors.transparent,
//           ),
//           PlotBand(
//             start: 205,
//             end: 205,
//             borderWidth: 1.5,
//             borderColor: Colors.grey.withOpacity(0.5),
//             dashArray: const [6, 4],
//             text: '  205V',
//             textStyle: TextStyle(
//               color: Colors.grey.withOpacity(0.7),
//               fontSize: 18,
//             ),
//             verticalTextAlignment: TextAnchor.start,
//           ),
//           PlotBand(
//             start: 245,
//             end: 245,
//             borderWidth: 1.5,
//             borderColor: Colors.red.withOpacity(0.4),
//             dashArray: const [6, 4],
//             text: '  245V',
//             textStyle: TextStyle(
//               color: Colors.red.withOpacity(0.4),
//               fontSize: 18,
//             ),
//             verticalTextAlignment: TextAnchor.start,
//           ),
//         ],
//       ),
//       series: _buildSeries(),
//     );
//   }
//
//   List<CartesianSeries> _buildSeries() {
//     final List<CartesianSeries> series = [];
//
//     // Create spline series for each line
//     for (int i = 0; i < cache.lineNames.length; i++) {
//       final lineName = cache.lineNames[i];
//       final color = _getColorForLine(lineName, i);
//
//       series.add(
//         SplineSeries<VoltageDetail, DateTime>(
//           animationDuration: 0,
//           dataSource: cache.data,
//           xValueMapper: (detail, _) => detail.time,
//           yValueMapper: (detail, _) {
//             final value = detail.getValue(lineName);
//             return value == 0 ? null : value;
//           },
//           emptyPointSettings: const EmptyPointSettings(
//             mode: EmptyPointMode.gap,
//           ),
//           color: color,
//           width: 2,
//           name: lineName,
//           markerSettings: const MarkerSettings(isVisible: false),
//           splineType: SplineType.monotonic,
//         ),
//       );
//
//       // Add alarm series if exists
//       final alarmPoints = cache.alarmMap[lineName];
//       if (alarmPoints != null && alarmPoints.isNotEmpty) {
//         series.add(_buildAlarmSeries(lineName, alarmPoints));
//       }
//     }
//
//     return series;
//   }
//
//   ScatterSeries<VoltageDetail, DateTime> _buildAlarmSeries(
//     String lineName,
//     List<VoltageDetail> alarmPoints,
//   ) {
//     return ScatterSeries<VoltageDetail, DateTime>(
//       animationDuration: 0,
//       animationDelay: 0,
//       isVisibleInLegend: false,
//       name: '$lineName Alarm',
//       dataSource: alarmPoints,
//       xValueMapper: (detail, _) => detail.time,
//       yValueMapper: (detail, _) => detail.getValue(lineName),
//       color: Colors.red.withOpacity(0.8),
//       markerSettings: const MarkerSettings(
//         isVisible: true,
//         width: 18,
//         height: 18,
//         borderColor: Colors.red,
//         borderWidth: 2,
//       ),
//       dataLabelMapper: (detail, _) =>
//           '$lineName\n${DateFormat('dd/MM HH:mm').format(detail.time)}\n'
//           '${detail.getValue(lineName).toStringAsFixed(1)}V',
//       dataLabelSettings: const DataLabelSettings(
//         isVisible: true,
//         labelAlignment: ChartDataLabelAlignment.top,
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
// // ─────────────────────────────────────────────────────────────────────────────
// // Alarm Badge
// // ─────────────────────────────────────────────────────────────────────────────
//
// class _AlarmBadge extends StatefulWidget {
//   const _AlarmBadge();
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
//     _ctrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 700),
//     )..repeat(reverse: true);
//     _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
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
//         child: const Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
//             SizedBox(width: 4),
//             Text(
//               'OVER VOLTAGE',
//               style: TextStyle(
//                 color: Colors.red,
//                 fontSize: 13,
//                 fontWeight: FontWeight.bold,
//                 letterSpacing: 0.5,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
