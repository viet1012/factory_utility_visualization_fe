import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_dashboard_api/utility_dashboard_overview_api.dart';

//
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

// class VoltageDetailChart extends StatefulWidget {
//   final UtilityDashboardOverviewApi api;
//
//   const VoltageDetailChart({super.key, required this.api});
//
//   @override
//   State<VoltageDetailChart> createState() => _VoltageDetailChartState();
// }
//
// class _VoltageDetailChartState extends State<VoltageDetailChart>
//     with TickerProviderStateMixin {
//   List<VoltageDetail> data = [];
//   bool isLoading = true;
//   late TooltipBehavior _tooltip;
//   late ZoomPanBehavior _zoomPan;
//
//   late AnimationController _blinkController;
//   late Animation<double> _blink;
//   late VoidCallback _blinkListener;
//
//   Timer? _timer;
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
//     // Thêm listener vào initState để rebuild đúng cách
//     _blinkController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 700),
//     )..repeat(reverse: true);
//
//     _blink = Tween<double>(begin: 0.4, end: 1.0).animate(_blinkController);
//
//     _blinkListener = () {
//       if (mounted) {
//         setState(() {});
//       }
//     };
//
//     _blink.addListener(_blinkListener);
//
//     load();
//     _timer = Timer.periodic(const Duration(seconds: 30), (_) => load());
//   }
//
//   @override
//   void dispose() {
//     _timer?.cancel();
//     _blink.removeListener(_blinkListener);
//     if (_blinkController.isAnimating) {
//       _blinkController.stop();
//     }
//
//     _blinkController.dispose();
//     super.dispose();
//   }
//
//   Future<List<VoltageDetail>> fetchVoltageDetail() async {
//     return widget.api.getVoltageDetail();
//   }
//
//   List<VoltageDetail> get alarms {
//     return data
//         .where((e) => e.d12 > 245 || e.d14 > 245 || e.d16 > 245)
//         .toList();
//   }
//
//   Future<void> load() async {
//     try {
//       final d = await fetchVoltageDetail();
//
//       if (!mounted) return;
//
//       setState(() {
//         data = d;
//
//         isLoading = false;
//       });
//     } catch (e) {
//       debugPrint("Voltage API error: $e");
//
//       if (!mounted) return;
//
//       setState(() {
//         isLoading = false;
//       });
//     }
//     for (var e in data) {
//       if (e.d12 > 245 || e.d14 > 245 || e.d16 > 245) {
//         debugPrint("${e.time}  ${e.d12} ${e.d14} ${e.d16}");
//       }
//     }
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
//           // ── HEADER ──
//           Padding(
//             padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
//             child: Row(
//               children: [
//                 Container(
//                   width: 4,
//                   height: 20,
//                   decoration: BoxDecoration(
//                     color: const Color(0xFF090909),
//                     borderRadius: BorderRadius.circular(2),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 const Text(
//                   "VOLTAGE MONITOR",
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 14,
//                     fontWeight: FontWeight.bold,
//                     letterSpacing: 1.5,
//                   ),
//                 ),
//                 const Spacer(),
//                 // Legend
//                 // _legend("D12", const Color(0xFF00B4FF)),
//                 // const SizedBox(width: 12),
//                 // _legend("D14", const Color(0xFFFF9500)),
//                 // const SizedBox(width: 12),
//                 // _legend("D16", const Color(0xFF2ECC71)),
//               ],
//             ),
//           ),
//
//           // ── CHART ──
//           Expanded(
//             child: isLoading
//                 ? const Center(
//                     child: CircularProgressIndicator(color: Color(0xFF1197D1)),
//                   )
//                 : Padding(
//                     padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
//                     child: SfCartesianChart(
//                       enableAxisAnimation: false,
//                       backgroundColor: Colors.transparent,
//                       plotAreaBackgroundColor: Colors.transparent,
//                       tooltipBehavior: _tooltip,
//                       zoomPanBehavior: _zoomPan,
//                       legend: Legend(
//                         isVisible: true,
//                         position: LegendPosition.top,
//                         overflowMode: LegendItemOverflowMode.wrap,
//                         textStyle: TextStyle(
//                           color: Colors.white.withOpacity(0.85),
//                           fontSize: 11,
//                         ),
//                       ),
//                       primaryXAxis: DateTimeAxis(
//                         dateFormat: DateFormat.Hm(), // 14:30
//                         intervalType: DateTimeIntervalType.hours,
//                         majorGridLines: MajorGridLines(
//                           color: Colors.white.withOpacity(0.05),
//                         ),
//                         labelStyle: TextStyle(
//                           color: Colors.white.withOpacity(0.5),
//                           fontSize: 14,
//                         ),
//                       ),
//                       primaryYAxis: NumericAxis(
//                         minimum: 180,
//                         // maximum: 320,
//                         interval: 20,
//                         axisLine: const AxisLine(color: Colors.transparent),
//                         majorTickLines: const MajorTickLines(size: 0),
//                         majorGridLines: MajorGridLines(
//                           color: Colors.white.withOpacity(0.08),
//                           width: 1,
//                           dashArray: const [4, 4],
//                         ),
//                         labelStyle: TextStyle(
//                           color: Colors.white.withOpacity(0.5),
//                           fontSize: 14,
//                         ),
//                         labelFormat: '{value}V',
//                         plotBands: [
//                           // Safe zone band giữa 205–245
//                           PlotBand(
//                             start: 205,
//                             end: 245,
//                             color: const Color(0xFF1197D1).withOpacity(0.06),
//                             borderColor: Colors.transparent,
//                           ),
//                           // Lower limit line
//                           PlotBand(
//                             start: 205,
//                             end: 205,
//                             borderWidth: 1.5,
//                             borderColor: Colors.grey.withOpacity(0.5),
//                             dashArray: const [6, 4],
//                             text: '  205V',
//                             textStyle: TextStyle(
//                               color: Colors.grey.withOpacity(0.7),
//                               fontSize: 18,
//                             ),
//                             verticalTextAlignment: TextAnchor.start,
//                           ),
//                           // Upper limit line
//                           PlotBand(
//                             start: 245,
//                             end: 245,
//                             borderWidth: 1.5,
//                             borderColor: Colors.red.withOpacity(0.8),
//                             dashArray: const [6, 4],
//                             text: '  245V',
//                             textStyle: TextStyle(
//                               color: Colors.red.withOpacity(0.8),
//                               fontSize: 18,
//                             ),
//                             verticalTextAlignment: TextAnchor.start,
//                           ),
//                         ],
//                       ),
//                       series: <CartesianSeries>[
//                         // D12
//                         SplineSeries<VoltageDetail, DateTime>(
//                           animationDuration: 0,
//                           dataSource: data,
//                           xValueMapper: (e, _) => e.time,
//                           yValueMapper: (e, _) => e.d12 == 0 ? null : e.d12,
//                           emptyPointSettings: const EmptyPointSettings(
//                             mode: EmptyPointMode.gap,
//                           ),
//
//                           color: const Color(0xFF00B4FF),
//                           name: 'D12',
//                           markerSettings: const MarkerSettings(
//                             isVisible: false,
//                           ),
//                           splineType: SplineType.monotonic,
//                         ),
//                         // D14
//                         SplineSeries<VoltageDetail, DateTime>(
//                           animationDuration: 0,
//
//                           dataSource: data,
//                           xValueMapper: (e, i) => e.time,
//                           yValueMapper: (e, _) => e.d14 == 0 ? null : e.d14,
//                           emptyPointSettings: const EmptyPointSettings(
//                             mode: EmptyPointMode.gap,
//                           ),
//                           color: const Color(0xFFFF9500),
//                           width: 2,
//                           name: 'D14',
//                           markerSettings: const MarkerSettings(
//                             isVisible: false,
//                           ),
//                           splineType: SplineType.monotonic,
//                         ),
//                         // D16
//                         SplineSeries<VoltageDetail, DateTime>(
//                           animationDuration: 0,
//
//                           dataSource: data,
//                           xValueMapper: (e, i) => e.time,
//                           yValueMapper: (e, _) => e.d16 == 0 ? null : e.d16,
//                           emptyPointSettings: const EmptyPointSettings(
//                             mode: EmptyPointMode.gap,
//                           ),
//                           color: const Color(0xFF2ECC71),
//                           width: 2,
//                           name: 'D16',
//                           markerSettings: const MarkerSettings(
//                             isVisible: false,
//                           ),
//                           splineType: SplineType.monotonic,
//                         ),
//
//                         /// ALARM POINTS
//                         buildAlarmSeries(
//                           name: 'D12',
//                           valueGetter: (e) => e.d12,
//                         ),
//                         buildAlarmSeries(
//                           name: 'D14',
//                           valueGetter: (e) => e.d14,
//                         ),
//                         buildAlarmSeries(
//                           name: 'D16',
//                           valueGetter: (e) => e.d16,
//                         ),
//                       ],
//                     ),
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   ScatterSeries<VoltageDetail, DateTime> buildAlarmSeries({
//     required String name,
//     required double Function(VoltageDetail) valueGetter,
//   }) {
//     return ScatterSeries<VoltageDetail, DateTime>(
//       name: name,
//
//       // tên series (D12 / D14 / D16)
//       dataSource: data.where((e) => valueGetter(e) > 245).toList(),
//
//       xValueMapper: (e, _) => e.time,
//       yValueMapper: (e, _) => valueGetter(e),
//
//       /// TEXT HIỂN THỊ
//       dataLabelMapper: (e, _) =>
//           "$name\n${DateFormat('dd/MM HH:mm').format(e.time)}\n${valueGetter(e).toStringAsFixed(1)}V",
//
//       color: Colors.red.withOpacity(_blink.value),
//
//       markerSettings: MarkerSettings(
//         isVisible: true,
//         width: 16 + (_blink.value * 10),
//         height: 16 + (_blink.value * 10),
//         borderColor: Colors.red,
//         borderWidth: 2,
//       ),
//
//       dataLabelSettings: const DataLabelSettings(
//         isVisible: true,
//         labelAlignment: ChartDataLabelAlignment.top,
//         textStyle: TextStyle(
//           color: Colors.red,
//           fontWeight: FontWeight.bold,
//           fontSize: 12,
//         ),
//       ),
//     );
//   }
//
//   Widget _legend(String label, Color color) {
//     return Row(
//       children: [
//         Container(
//           width: 24,
//           height: 3,
//           decoration: BoxDecoration(
//             color: color,
//             borderRadius: BorderRadius.circular(2),
//           ),
//         ),
//         const SizedBox(width: 5),
//         Text(
//           label,
//           style: TextStyle(
//             color: color.withOpacity(0.9),
//             fontSize: 14,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ],
//     );
//   }
// }

class VoltageDetailChart extends StatefulWidget {
  final UtilityDashboardOverviewApi api;

  const VoltageDetailChart({super.key, required this.api});

  @override
  State<VoltageDetailChart> createState() => _VoltageDetailChartState();
}

class _VoltageDetailChartState extends State<VoltageDetailChart> {
  List<VoltageDetail> data = [];
  bool isLoading = true;
  late TooltipBehavior _tooltip;
  late ZoomPanBehavior _zoomPan;
  Timer? _timer;
  Object? error;

  // Alarm lists tính sẵn
  List<VoltageDetail> alarmD12 = [];
  List<VoltageDetail> alarmD14 = [];
  List<VoltageDetail> alarmD16 = [];

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

    load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  Future<void> load() async {
    if (!mounted) return;
    try {
      final d = await widget.api.getVoltageDetail();
      if (!mounted) return;

      setState(() {
        data = d;
        alarmD12 = d.where((e) => e.d12 > 245).toList();
        alarmD14 = d.where((e) => e.d14 > 245).toList();
        alarmD16 = d.where((e) => e.d16 > 245).toList();
        error = null;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Voltage API error: $e");
      if (!mounted) return;
      setState(() {
        error = e;
        isLoading = false;
      });
    }
  }

  bool get hasAlarm =>
      alarmD12.isNotEmpty || alarmD14.isNotEmpty || alarmD16.isNotEmpty;

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
          // ── HEADER ──
          Padding(
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
                  "VOLTAGE MONITOR",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                // Blink badge — widget RIÊNG, không làm chart rebuild
                if (hasAlarm) const _AlarmBadge(),
              ],
            ),
          ),

          // ── CHART — chỉ rebuild khi data thay đổi ──
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1197D1)),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                    child: RepaintBoundary(
                      child: SfCartesianChart(
                        enableAxisAnimation: false,
                        backgroundColor: Colors.transparent,
                        plotAreaBackgroundColor: Colors.transparent,
                        tooltipBehavior: _tooltip,
                        zoomPanBehavior: _zoomPan,
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
                          majorGridLines: MajorGridLines(
                            color: Colors.white.withOpacity(0.05),
                          ),
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
                            dataSource: data,
                            xValueMapper: (e, _) => e.time,
                            yValueMapper: (e, _) => e.d12 == 0 ? null : e.d12,
                            emptyPointSettings: const EmptyPointSettings(
                              mode: EmptyPointMode.gap,
                            ),
                            color: const Color(0xFF00B4FF),
                            name: 'D12',
                            markerSettings: const MarkerSettings(
                              isVisible: false,
                            ),
                            splineType: SplineType.monotonic,
                          ),
                          SplineSeries<VoltageDetail, DateTime>(
                            animationDuration: 0,
                            dataSource: data,
                            xValueMapper: (e, _) => e.time,
                            yValueMapper: (e, _) => e.d14 == 0 ? null : e.d14,
                            emptyPointSettings: const EmptyPointSettings(
                              mode: EmptyPointMode.gap,
                            ),
                            color: const Color(0xFFFF9500),
                            width: 2,
                            name: 'D14',
                            markerSettings: const MarkerSettings(
                              isVisible: false,
                            ),
                            splineType: SplineType.monotonic,
                          ),
                          SplineSeries<VoltageDetail, DateTime>(
                            animationDuration: 0,
                            dataSource: data,
                            xValueMapper: (e, _) => e.time,
                            yValueMapper: (e, _) => e.d16 == 0 ? null : e.d16,
                            emptyPointSettings: const EmptyPointSettings(
                              mode: EmptyPointMode.gap,
                            ),
                            color: const Color(0xFF2ECC71),
                            width: 2,
                            name: 'D16',
                            markerSettings: const MarkerSettings(
                              isVisible: false,
                            ),
                            splineType: SplineType.monotonic,
                          ),
                          // Static alarm markers — KHÔNG dùng _blink
                          if (alarmD12.isNotEmpty)
                            _buildAlarmSeries('D12', alarmD12, (e) => e.d12),
                          if (alarmD14.isNotEmpty)
                            _buildAlarmSeries('D14', alarmD14, (e) => e.d14),
                          if (alarmD16.isNotEmpty)
                            _buildAlarmSeries('D16', alarmD16, (e) => e.d16),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  ScatterSeries<VoltageDetail, DateTime> _buildAlarmSeries(
    String name,
    List<VoltageDetail> alarms,
    double Function(VoltageDetail) valueGetter,
  ) {
    return ScatterSeries<VoltageDetail, DateTime>(
      animationDuration: 0,
      // ← bắt buộc
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
          "$name\n${DateFormat('dd/MM HH:mm').format(e.time)}\n${valueGetter(e).toStringAsFixed(1)}V",
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

// ── Widget blink RIÊNG — tự quản lý animation, không ảnh hưởng chart ──
class _AlarmBadge extends StatefulWidget {
  const _AlarmBadge();

  @override
  State<_AlarmBadge> createState() => _AlarmBadgeState();
}

class _AlarmBadgeState extends State<_AlarmBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

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
          border: Border.all(color: Colors.red, width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
            SizedBox(width: 4),
            Text(
              "OVER VOLTAGE",
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
