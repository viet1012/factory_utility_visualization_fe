// import 'dart:async';
// import 'dart:math';
//
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
//
// import '../../utility_models/f2_utility_parameter_history.dart';
// import '../../utility_models/request/utility_series_request.dart';
// import '../../utility_models/utility_facade_service.dart';
// import '../../utility_models/utility_mock_repository.dart';
//
// /// ==============================
// /// MINI DASH (SCADA-style)
// /// - Bucket = hour/day/month: 1 điểm / bucket
// /// - Realtime tick: UPSERT điểm bucket hiện tại (không add theo giây)
// /// ==============================
// class UtilityMiniDashScreen extends StatefulWidget {
//   final List<FacTree> facs;
//   final UtilityMockRepository repo;
//
//   const UtilityMiniDashScreen({
//     super.key,
//     required this.facs,
//     required this.repo,
//   });
//
//   @override
//   State<UtilityMiniDashScreen> createState() => _UtilityMiniDashScreenState();
// }
//
// class _UtilityMiniDashScreenState extends State<UtilityMiniDashScreen> {
//   // ===== global filters =====
//   late String _facId;
//   TimeBucket _bucket = TimeBucket.hour;
//
//   // chọn 1 param cho từng utility
//   String? _powerKey;
//   String? _waterKey;
//   String? _airKey;
//
//   // realtime
//   bool _realtime = true;
//   int _rtIntervalSec = 2;
//   Timer? _rtTimer;
//
//   // ✅ buffer realtime theo key nhưng lưu dưới dạng bucketed points
//   final Map<String, List<_TsPoint>> _rtSeriesByKey = {};
//
//   List<String> get _facIds =>
//       widget.facs.map((e) => e.facId).toSet().toList()..sort();
//
//   @override
//   void initState() {
//     super.initState();
//     _facId = _facIds.isNotEmpty ? _facIds.first : 'A';
//     _ensureDefaultKeys();
//     _startRealtime();
//   }
//
//   @override
//   void didUpdateWidget(covariant UtilityMiniDashScreen oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     _ensureDefaultKeys();
//     if (_realtime) _startRealtime();
//   }
//
//   @override
//   void dispose() {
//     _rtTimer?.cancel();
//     super.dispose();
//   }
//
//   // =========================
//   // HELPERS
//   // =========================
//   double _toDouble(dynamic v) {
//     if (v == null) return 0.0;
//     if (v is num) return v.toDouble();
//     return double.tryParse('$v') ?? 0.0;
//   }
//
//   DateTime _bucketStart(DateTime t, TimeBucket b) {
//     switch (b) {
//       case TimeBucket.hour:
//         return DateTime(t.year, t.month, t.day, t.hour);
//       case TimeBucket.day:
//         return DateTime(t.year, t.month, t.day);
//       case TimeBucket.month:
//         return DateTime(t.year, t.month, 1);
//     }
//   }
//
//   DateTime _cutoffTime(DateTime now) {
//     switch (_bucket) {
//       case TimeBucket.hour:
//         return now.subtract(const Duration(hours: 23));
//       case TimeBucket.day:
//         return now.subtract(const Duration(days: 29));
//       case TimeBucket.month:
//         return DateTime(now.year, now.month - 11, 1);
//     }
//   }
//
//   (double, double) _stableRangePoints(
//     List<_TsPoint> pts, {
//     double padRatio = 0.12,
//   }) {
//     if (pts.isEmpty) return (0, 1);
//
//     final vs = pts.map((e) => e.v).toList();
//     var minY = vs.reduce(min);
//     var maxY = vs.reduce(max);
//
//     final span = (maxY - minY).abs();
//     final pad = span == 0 ? 1.0 : span * padRatio;
//
//     minY -= pad;
//     maxY += pad;
//
//     if ((maxY - minY) < 0.01) maxY = minY + 0.01;
//     return (minY, maxY);
//   }
//
//   FacTree? _fac() {
//     if (widget.facs.isEmpty) return null;
//     for (final f in widget.facs) {
//       if (f.facId == _facId) return f;
//     }
//     return widget.facs.first;
//   }
//
//   List<DeviceTree> _devicesForUtility(String utility) {
//     final fac = _fac();
//     if (fac == null) return [];
//     final allDevices = fac.boxes.expand((b) => b.devices).toList();
//     return allDevices.where((d) => d.channel.cate == utility).toList();
//   }
//
//   List<ParamNode> _paramsForUtility(String utility) {
//     final devs = _devicesForUtility(utility);
//     if (devs.isEmpty) return [];
//     return devs.expand((d) => d.params).toList();
//   }
//
//   String _pKey(ParamNode p) =>
//       '${p.master.boxDeviceId}::${p.master.plcAddress}';
//
//   ParamNode? _findParamByKey(String utility, String? key) {
//     if (key == null) return null;
//     final params = _paramsForUtility(utility);
//     for (final p in params) {
//       if (_pKey(p) == key) return p;
//     }
//     return null;
//   }
//
//   void _ensureDefaultKeys() {
//     final powerParams = _paramsForUtility('Electricity');
//     if (_powerKey == null && powerParams.isNotEmpty) {
//       _powerKey = _pKey(powerParams.first);
//     } else if (_powerKey != null &&
//         _findParamByKey('Electricity', _powerKey) == null &&
//         powerParams.isNotEmpty) {
//       _powerKey = _pKey(powerParams.first);
//     }
//
//     final waterParams = _paramsForUtility('Water');
//     if (_waterKey == null && waterParams.isNotEmpty) {
//       _waterKey = _pKey(waterParams.first);
//     } else if (_waterKey != null &&
//         _findParamByKey('Water', _waterKey) == null &&
//         waterParams.isNotEmpty) {
//       _waterKey = _pKey(waterParams.first);
//     }
//
//     final airParams = _paramsForUtility('Compressed Air');
//     if (_airKey == null && airParams.isNotEmpty) {
//       _airKey = _pKey(airParams.first);
//     } else if (_airKey != null &&
//         _findParamByKey('Compressed Air', _airKey) == null &&
//         airParams.isNotEmpty) {
//       _airKey = _pKey(airParams.first);
//     }
//
//     if (mounted) setState(() {});
//   }
//
//   UtilitySeriesRequest _buildReq({
//     required String utility,
//     required ParamNode p,
//   }) {
//     final now = DateTime.now();
//     DateTime from;
//     DateTime to = now;
//
//     switch (_bucket) {
//       case TimeBucket.hour:
//         from = now.subtract(const Duration(hours: 23));
//         break;
//       case TimeBucket.day:
//         from = now.subtract(const Duration(days: 29));
//         break;
//       case TimeBucket.month:
//         from = DateTime(now.year, now.month - 11, 1);
//         to = DateTime(now.year, now.month, 1);
//         break;
//     }
//
//     return UtilitySeriesRequest(
//       facId: _facId,
//       utility: utility,
//       deviceId: p.master.boxDeviceId,
//       plcAddress: p.master.plcAddress,
//       from: from,
//       to: to,
//       bucket: _bucket,
//       seed: 1,
//     );
//   }
//
//   // =========================
//   // REALTIME (UPSERT BY BUCKET)
//   // =========================
//   void _startRealtime() {
//     _rtTimer?.cancel();
//     if (!_realtime) return;
//
//     _rtTimer = Timer.periodic(
//       Duration(seconds: _rtIntervalSec),
//       (_) => _tickRealtime(),
//     );
//   }
//
//   Future<void> _tickRealtime() async {
//     if (!mounted) return;
//
//     await _tickOne('Electricity', _powerKey);
//     await _tickOne('Water', _waterKey);
//     await _tickOne('Compressed Air', _airKey);
//
//     if (mounted) setState(() {});
//   }
//
//   Future<void> _tickOne(String utility, String? key) async {
//     if (key == null) return;
//     final p = _findParamByKey(utility, key);
//     if (p == null) return;
//
//     final deviceId = p.master.boxDeviceId;
//     final plcAddress = p.master.plcAddress;
//
//     final now = DateTime.now();
//     final latestAll = await widget.repo.fetchLatestHistories(
//       at: now,
//       seed: now.millisecondsSinceEpoch,
//     );
//
//     final point = latestAll
//         .where((h) => h.boxDeviceId == deviceId && h.plcAddress == plcAddress)
//         .cast<UtilityParameterHistory?>()
//         .firstWhere((x) => x != null, orElse: () => null);
//
//     if (point == null) return;
//
//     final bt = _bucketStart(point.recordedAt, _bucket);
//     final v = _toDouble(point.value);
//
//     final buf = _rtSeriesByKey.putIfAbsent(key, () => []);
//
//     // ✅ UPSERT theo bucketTime
//     final idx = buf.indexWhere((e) => e.t == bt);
//     if (idx >= 0) {
//       buf[idx] = _TsPoint(bt, v);
//     } else {
//       buf.add(_TsPoint(bt, v));
//     }
//
//     // ✅ cắt window theo bucket
//     final cutoff = _bucketStart(_cutoffTime(now), _bucket);
//     buf.removeWhere((e) => e.t.isBefore(cutoff));
//     buf.sort((a, b) => a.t.compareTo(b.t));
//   }
//
//   void _clearBuffers() {
//     _rtSeriesByKey.clear();
//   }
//
//   // =========================
//   // PICK SIGNAL (BOTTOM SHEET)
//   // =========================
//   Future<void> _pickSignal(String utility) async {
//     final params = _paramsForUtility(utility);
//     if (params.isEmpty) return;
//
//     String? currentKey;
//     if (utility == 'Electricity') currentKey = _powerKey;
//     if (utility == 'Water') currentKey = _waterKey;
//     if (utility == 'Compressed Air') currentKey = _airKey;
//
//     String? temp = currentKey;
//
//     await showModalBottomSheet(
//       context: context,
//       backgroundColor: const Color(0xFF0E1729),
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (_) {
//         return StatefulBuilder(
//           builder: (context, setModalState) {
//             return SafeArea(
//               child: Padding(
//                 padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Choose signal • $utility',
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.w900,
//                         fontSize: 16,
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//
//                     // ===== LIST =====
//                     Expanded(
//                       child: ListView.builder(
//                         itemCount: params.length,
//                         itemBuilder: (_, i) {
//                           final p = params[i];
//                           final k = _pKey(p);
//                           final selected = (k == temp);
//
//                           return ListTile(
//                             dense: true,
//                             selected: selected,
//                             selectedTileColor: const Color(
//                               0xFF1B2A44,
//                             ).withOpacity(0.4),
//
//                             onTap: () {
//                               setModalState(() => temp = k); // ✅ ĐÚNG
//                             },
//
//                             leading: Icon(
//                               selected
//                                   ? Icons.radio_button_checked
//                                   : Icons.radio_button_off,
//                               color: selected
//                                   ? Colors.white
//                                   : const Color(0xFF9FB2D6),
//                             ),
//                             title: Text(
//                               p.master.nameEn,
//                               style: const TextStyle(color: Colors.white),
//                             ),
//                             subtitle: Text(
//                               '${p.master.boxDeviceId} • ${p.master.plcAddress} • ${p.master.unit}',
//                               style: const TextStyle(color: Color(0xFF9FB2D6)),
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//
//                     const SizedBox(height: 8),
//
//                     // ===== APPLY =====
//                     SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: const Color(0xFF1B2A44),
//                           foregroundColor: Colors.white,
//                           padding: const EdgeInsets.symmetric(vertical: 12),
//                         ),
//                         onPressed: () {
//                           setState(() {
//                             if (utility == 'Electricity') _powerKey = temp;
//                             if (utility == 'Water') _waterKey = temp;
//                             if (utility == 'Compressed Air') _airKey = temp;
//                             _clearBuffers();
//                           });
//                           Navigator.pop(context);
//                         },
//                         child: const Text('Apply'),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//   // =========================
//   // UI
//   // =========================
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         _topBar(),
//         Expanded(
//           child: ListView(
//             padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
//             children: [
//               _miniChartCard(
//                 title: 'POWER',
//                 utility: 'Electricity',
//                 keySelected: _powerKey,
//                 lineColor: const Color(0xFFEA5455),
//                 fillColor: const Color(0xFFEA5455),
//               ),
//               const SizedBox(height: 12),
//               _miniChartCard(
//                 title: 'WATER',
//                 utility: 'Water',
//                 keySelected: _waterKey,
//                 lineColor: const Color(0xFF4DB3FF),
//                 fillColor: const Color(0xFF4DB3FF),
//               ),
//               const SizedBox(height: 12),
//               _miniChartCard(
//                 title: 'AIR COMPRESSER',
//                 utility: 'Compressed Air',
//                 keySelected: _airKey,
//                 lineColor: const Color(0xFF28C76F),
//                 fillColor: const Color(0xFF28C76F),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _topBar() {
//     final bucketLabel = '[${_bucket.name.toUpperCase()}]';
//
//     return Container(
//       padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
//       decoration: BoxDecoration(
//         color: const Color(0xFF0E1729),
//         border: Border(
//           bottom: BorderSide(color: const Color(0xFF1B2A44).withOpacity(0.8)),
//         ),
//       ),
//       child: Row(
//         children: [
//           Text(
//             bucketLabel,
//             style: const TextStyle(
//               color: Color(0xFF28C76F),
//               fontWeight: FontWeight.w900,
//               fontSize: 14,
//               letterSpacing: 0.3,
//             ),
//           ),
//           const SizedBox(width: 12),
//
//           _miniDrop<String>(
//             value: _facId,
//             items: _facIds,
//             onChanged: (v) {
//               setState(() {
//                 _facId = v;
//                 _ensureDefaultKeys();
//                 _clearBuffers();
//               });
//             },
//             prefix: 'FAC',
//             labelOf: (x) => x,
//           ),
//           const SizedBox(width: 10),
//
//           _miniDrop<TimeBucket>(
//             value: _bucket,
//             items: TimeBucket.values,
//             onChanged: (v) {
//               setState(() {
//                 _bucket = v;
//                 _clearBuffers();
//
//                 // ✅ gợi ý “SCADA chuẩn”: bucket càng lớn refresh càng thưa
//                 _rtIntervalSec = (v == TimeBucket.hour)
//                     ? 2
//                     : (v == TimeBucket.day)
//                     ? 60
//                     : 30;
//               });
//               if (_realtime) _startRealtime();
//             },
//             prefix: 'BUCKET',
//             labelOf: (b) => b.name.toUpperCase(),
//           ),
//
//           const Spacer(),
//
//           Row(
//             children: [
//               const Text('RT', style: TextStyle(color: Color(0xFF9FB2D6))),
//               Switch(
//                 value: _realtime,
//                 onChanged: (v) {
//                   setState(() => _realtime = v);
//                   if (v) {
//                     _startRealtime();
//                   } else {
//                     _rtTimer?.cancel();
//                     _rtTimer = null;
//                   }
//                 },
//               ),
//               _miniDrop<int>(
//                 value: _rtIntervalSec,
//                 items: const [1, 2, 3, 5, 10, 30],
//                 onChanged: (v) {
//                   setState(() => _rtIntervalSec = v);
//                   if (_realtime) _startRealtime();
//                 },
//                 prefix: 's',
//                 labelOf: (x) => '${x}s',
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _miniDrop<T>({
//     required T value,
//     required List<T> items,
//     required void Function(T v) onChanged,
//     required String prefix,
//     String Function(T v)? labelOf,
//   }) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
//       decoration: BoxDecoration(
//         color: const Color(0xFF0B1220),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: const Color(0xFF1B2A44)),
//       ),
//       child: DropdownButton<T>(
//         value: value,
//         underline: const SizedBox.shrink(),
//         dropdownColor: const Color(0xFF0E1729),
//         iconEnabledColor: const Color(0xFF9FB2D6),
//         items: items
//             .map(
//               (e) => DropdownMenuItem(
//                 value: e,
//                 child: Text(
//                   '$prefix: ${labelOf?.call(e) ?? e.toString()}',
//                   style: const TextStyle(color: Colors.white),
//                 ),
//               ),
//             )
//             .toList(),
//         onChanged: (v) {
//           if (v == null) return;
//           onChanged(v);
//         },
//       ),
//     );
//   }
//
//   Widget _miniChartCard({
//     required String title,
//     required String utility,
//     required String? keySelected,
//     required Color lineColor,
//     required Color fillColor,
//   }) {
//     final p = _findParamByKey(utility, keySelected);
//     final unit = p?.master.unit ?? '--';
//     final name = p?.master.nameEn ?? 'No signal';
//
//     final buf = (keySelected == null) ? null : _rtSeriesByKey[keySelected];
//
//     Future<List<_TsPoint>> future() async {
//       if (keySelected == null || p == null) return const [];
//       if (buf != null && buf.isNotEmpty) return buf;
//
//       // seed history -> bucketed points
//       final req = _buildReq(utility: utility, p: p);
//       final seed = await widget.repo.fetchSeries(req);
//
//       // normalize time -> bucketStart, giữ last per bucket
//       final byBucket = <DateTime, _TsPoint>{};
//       for (final h in seed) {
//         final bt = _bucketStart(h.recordedAt, _bucket);
//         byBucket[bt] = _TsPoint(bt, _toDouble(h.value)); // last wins
//       }
//
//       final merged = byBucket.values.toList()
//         ..sort((a, b) => a.t.compareTo(b.t));
//
//       _rtSeriesByKey[keySelected] = merged;
//       return merged;
//     }
//
//     return Container(
//       height: 190,
//       decoration: BoxDecoration(
//         color: const Color(0xFF0E1729),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: const Color(0xFF1B2A44)),
//       ),
//       child: Stack(
//         children: [
//           Positioned.fill(
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(10, 38, 10, 10),
//               child: FutureBuilder<List<_TsPoint>>(
//                 future: future(),
//                 builder: (context, snap) {
//                   final pts = snap.data ?? const <_TsPoint>[];
//                   final sorted = [...pts]..sort((a, b) => a.t.compareTo(b.t));
//
//                   final lastV = sorted.isEmpty ? null : sorted.last.v;
//                   final yRange = _stableRangePoints(sorted, padRatio: 0.12);
//
//                   return Stack(
//                     children: [
//                       _MiniAreaChart(
//                         points: sorted,
//                         bucket: _bucket,
//                         lineColor: lineColor,
//                         fillColor: fillColor.withOpacity(0.22),
//                         yMin: yRange.$1,
//                         yMax: yRange.$2,
//                       ),
//                       Positioned(
//                         right: 8,
//                         bottom: 6,
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 8,
//                             vertical: 4,
//                           ),
//                           decoration: BoxDecoration(
//                             color: const Color(0xFF0B1220).withOpacity(0.85),
//                             borderRadius: BorderRadius.circular(8),
//                             border: Border.all(color: const Color(0xFF1B2A44)),
//                           ),
//                           child: Text(
//                             lastV == null ? '--' : lastV.toStringAsFixed(2),
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontWeight: FontWeight.w900,
//                               fontSize: 13,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   );
//                 },
//               ),
//             ),
//           ),
//
//           Positioned(
//             left: 10,
//             top: 10,
//             right: 10,
//             child: Row(
//               children: [
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.w900,
//                     fontSize: 13,
//                     letterSpacing: 0.3,
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 4,
//                   ),
//                   decoration: BoxDecoration(
//                     color: const Color(0xFF0B1220),
//                     borderRadius: BorderRadius.circular(8),
//                     border: Border.all(color: const Color(0xFF1B2A44)),
//                   ),
//                   child: Text(
//                     unit,
//                     style: const TextStyle(
//                       color: Color(0xFF9FB2D6),
//                       fontWeight: FontWeight.w800,
//                       fontSize: 11,
//                     ),
//                   ),
//                 ),
//                 const Spacer(),
//                 InkWell(
//                   onTap: () => _pickSignal(utility),
//                   borderRadius: BorderRadius.circular(8),
//                   child: Container(
//                     width: 34,
//                     height: 28,
//                     alignment: Alignment.center,
//                     decoration: BoxDecoration(
//                       color: const Color(0xFF0B1220),
//                       borderRadius: BorderRadius.circular(8),
//                       border: Border.all(color: const Color(0xFF1B2A44)),
//                     ),
//                     child: const Icon(
//                       Icons.tune,
//                       size: 18,
//                       color: Color(0xFF9FB2D6),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           Positioned(
//             left: 10,
//             top: 28,
//             right: 60,
//             child: Text(
//               name,
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: const TextStyle(
//                 color: Color(0xFF9FB2D6),
//                 fontWeight: FontWeight.w700,
//                 fontSize: 11,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// /// ==============================
// /// MINI AREA CHART (SCADA)
// /// - Tooltip + Crosshair
// /// - Y fixed range (no jitter)
// /// ==============================
// class _MiniAreaChart extends StatefulWidget {
//   final List<_TsPoint> points;
//   final TimeBucket bucket;
//   final Color lineColor;
//   final Color fillColor;
//   final double yMin;
//   final double yMax;
//
//   const _MiniAreaChart({
//     required this.points,
//     required this.bucket,
//     required this.lineColor,
//     required this.fillColor,
//     required this.yMin,
//     required this.yMax,
//   });
//
//   @override
//   State<_MiniAreaChart> createState() => _MiniAreaChartState();
// }
//
// class _MiniAreaChartState extends State<_MiniAreaChart> {
//   late TooltipBehavior _tooltip;
//   late CrosshairBehavior _crosshair;
//
//   DateTimeIntervalType _intervalType(TimeBucket b) {
//     switch (b) {
//       case TimeBucket.hour:
//         return DateTimeIntervalType.hours;
//       case TimeBucket.day:
//         return DateTimeIntervalType.days;
//       case TimeBucket.month:
//         return DateTimeIntervalType.months;
//     }
//   }
//
//   DateFormat _fmtX(TimeBucket b) {
//     switch (b) {
//       case TimeBucket.hour:
//         return DateFormat.Hm();
//       case TimeBucket.day:
//         return DateFormat('dd/MM');
//       case TimeBucket.month:
//         return DateFormat('MM/yyyy');
//     }
//   }
//
//   @override
//   void initState() {
//     super.initState();
//
//     _tooltip = TooltipBehavior(
//       enable: true,
//       activationMode: ActivationMode.singleTap,
//       canShowMarker: true,
//     );
//
//     _crosshair = CrosshairBehavior(
//       enable: true,
//       activationMode: ActivationMode.longPress,
//       lineType: CrosshairLineType.vertical,
//       lineWidth: 1,
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final pts = widget.points;
//     if (pts.isEmpty) {
//       return Container(
//         decoration: BoxDecoration(
//           color: const Color(0xFF0B1220),
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(color: const Color(0xFF1B2A44)),
//         ),
//         child: const Center(
//           child: Text('No data', style: TextStyle(color: Color(0xFF9FB2D6))),
//         ),
//       );
//     }
//
//     final df = _fmtX(widget.bucket);
//
//     return SfCartesianChart(
//       margin: EdgeInsets.zero,
//       plotAreaBorderWidth: 0,
//       tooltipBehavior: _tooltip,
//       crosshairBehavior: _crosshair,
//
//       primaryXAxis: DateTimeAxis(
//         intervalType: _intervalType(widget.bucket),
//         interval: 1,
//         majorGridLines: const MajorGridLines(width: 0),
//         axisLine: const AxisLine(width: 0),
//         labelStyle: const TextStyle(color: Color(0xFF9FB2D6), fontSize: 10),
//         dateFormat: df,
//         edgeLabelPlacement: EdgeLabelPlacement.shift,
//       ),
//
//       primaryYAxis: NumericAxis(
//         minimum: widget.yMin,
//         maximum: widget.yMax,
//         majorGridLines: MajorGridLines(
//           width: 0.6,
//           color: const Color(0xFF1B2A44).withOpacity(0.5),
//         ),
//         axisLine: const AxisLine(width: 0),
//         isVisible: false,
//       ),
//
//       series: <CartesianSeries<_TsPoint, DateTime>>[
//         AreaSeries<_TsPoint, DateTime>(
//           dataSource: pts,
//           xValueMapper: (p, _) => p.t,
//           yValueMapper: (p, _) => p.v,
//           borderColor: widget.lineColor,
//           borderWidth: 2,
//           color: widget.fillColor,
//           dataLabelSettings: const DataLabelSettings(isVisible: false),
//           markerSettings: const MarkerSettings(isVisible: false),
//         ),
//       ],
//     );
//   }
// }
//
// class _TsPoint {
//   final DateTime t;
//   final double v;
//
//   const _TsPoint(this.t, this.v);
// }
