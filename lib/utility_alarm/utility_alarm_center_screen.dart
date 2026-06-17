// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
//
// class AbnormalJumpScreen extends StatefulWidget {
//   const AbnormalJumpScreen({super.key});
//
//   @override
//   State<AbnormalJumpScreen> createState() => _AbnormalJumpScreenState();
// }
//
// class _AbnormalJumpScreenState extends State<AbnormalJumpScreen> {
//   bool loading = true;
//   String? error;
//   List<dynamic> data = [];
//
//   static const String apiUrl =
//       'http://localhost:9999/api/utility/abnormal-signals';
//
//   @override
//   void initState() {
//     super.initState();
//     fetchData();
//   }
//
//   Future<void> fetchData() async {
//     setState(() {
//       loading = true;
//       error = null;
//     });
//
//     try {
//       final res = await http.get(Uri.parse(apiUrl));
//
//       if (res.statusCode == 200) {
//         final decoded = jsonDecode(res.body);
//         data = decoded is List ? decoded : [];
//       } else {
//         error = 'API Error: ${res.statusCode}';
//       }
//     } catch (e) {
//       error = e.toString();
//     }
//
//     setState(() => loading = false);
//   }
//
//   int get totalSignals {
//     int total = 0;
//
//     for (final fac in data) {
//       for (final cate in fac['categories'] ?? []) {
//         for (final scada in cate['scadas'] ?? []) {
//           for (final device in scada['devices'] ?? []) {
//             total += ((device['signals'] as List?)?.length ?? 0);
//           }
//         }
//       }
//     }
//
//     return total;
//   }
//
//   int get totalDevices {
//     int total = 0;
//
//     for (final fac in data) {
//       for (final cate in fac['categories'] ?? []) {
//         for (final scada in cate['scadas'] ?? []) {
//           total += ((scada['devices'] as List?)?.length ?? 0);
//         }
//       }
//     }
//
//     return total;
//   }
//
//   String get lastUpdated {
//     String latest = '-';
//
//     for (final fac in data) {
//       for (final cate in fac['categories'] ?? []) {
//         for (final scada in cate['scadas'] ?? []) {
//           for (final device in scada['devices'] ?? []) {
//             for (final signal in device['signals'] ?? []) {
//               final time = signal['recordedAt']?.toString() ?? '';
//               if (latest == '-' || time.compareTo(latest) > 0) {
//                 latest = time;
//               }
//             }
//           }
//         }
//       }
//     }
//
//     return latest;
//   }
//
//   List<Map<String, dynamic>> flattenSignals(List data) {
//     final List<Map<String, dynamic>> result = [];
//
//     for (final fac in data) {
//       for (final cate in fac['categories'] ?? []) {
//         for (final scada in cate['scadas'] ?? []) {
//           for (final device in scada['devices'] ?? []) {
//             for (final signal in device['signals'] ?? []) {
//               result.add({
//                 'fac': fac['fac'],
//                 'category': cate['cate'],
//                 'scadaId': scada['scadaId'],
//                 'boxDeviceId': device['boxDeviceId'],
//                 ...signal,
//               });
//             }
//           }
//         }
//       }
//     }
//
//     return result;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xfff8fafc),
//       body: loading
//           ? const Center(child: CircularProgressIndicator())
//           : error != null
//           ? Center(child: Text(error!))
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(20),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // _Header(lastUpdated: lastUpdated, onRefresh: fetchData),
//                   // const SizedBox(height: 16),
//                   _SummaryCard(
//                     facilityCount: data.length,
//                     deviceCount: totalDevices,
//                     signalCount: totalSignals,
//                   ),
//                   const SizedBox(height: 16),
//                   _GroupedErrorPanel(data: data),
//                 ],
//               ),
//             ),
//     );
//   }
// }
//
// class _SummaryCard extends StatelessWidget {
//   final int facilityCount;
//   final int deviceCount;
//   final int signalCount;
//
//   const _SummaryCard({
//     required this.facilityCount,
//     required this.deviceCount,
//     required this.signalCount,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Expanded(
//           child: _BigMetricCard(
//             title: 'FAC lỗi',
//             value: '$facilityCount',
//             icon: Icons.factory,
//             color: const Color(0xff2563eb),
//           ),
//         ),
//         const SizedBox(width: 14),
//         Expanded(
//           child: _BigMetricCard(
//             title: 'BoxDevice lỗi',
//             value: '$deviceCount',
//             icon: Icons.memory,
//             color: const Color(0xfff97316),
//           ),
//         ),
//         const SizedBox(width: 14),
//         Expanded(
//           child: _BigMetricCard(
//             title: 'Thanh ghi lỗi',
//             value: '$signalCount',
//             icon: Icons.warning_amber_rounded,
//             color: const Color(0xffdc2626),
//             danger: true,
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// class _BigMetricCard extends StatelessWidget {
//   final String title;
//   final String value;
//   final IconData icon;
//   final Color color;
//   final bool danger;
//
//   const _BigMetricCard({
//     required this.title,
//     required this.value,
//     required this.icon,
//     required this.color,
//     this.danger = false,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 92,
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//       decoration: BoxDecoration(
//         color: danger ? const Color(0xfffff1f2) : Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(
//           color: danger ? const Color(0xfffecaca) : const Color(0xffe2e8f0),
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(.04),
//             blurRadius: 18,
//             offset: const Offset(0, 8),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 54,
//             height: 54,
//             decoration: BoxDecoration(
//               color: color.withOpacity(.12),
//               borderRadius: BorderRadius.circular(16),
//             ),
//             child: Icon(icon, color: color, size: 30),
//           ),
//           const SizedBox(width: 18),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text(
//                 value,
//                 style: TextStyle(
//                   fontSize: 32,
//                   height: 1,
//                   fontWeight: FontWeight.w900,
//                   color: color,
//                 ),
//               ),
//               const SizedBox(height: 10),
//               Text(
//                 title,
//                 style: const TextStyle(
//                   color: Color(0xff64748b),
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _GroupedErrorPanel extends StatelessWidget {
//   final List<dynamic> data;
//
//   const _GroupedErrorPanel({required this.data});
//
//   int _countScadas(Map<String, dynamic> fac) {
//     int total = 0;
//     for (final cate in fac['categories'] ?? []) {
//       total += ((cate['scadas'] as List?)?.length ?? 0);
//     }
//     return total;
//   }
//
//   int _countSignalsInFac(Map<String, dynamic> fac) {
//     int total = 0;
//     for (final cate in fac['categories'] ?? []) {
//       for (final scada in cate['scadas'] ?? []) {
//         for (final device in scada['devices'] ?? []) {
//           total += ((device['signals'] as List?)?.length ?? 0);
//         }
//       }
//     }
//     return total;
//   }
//
//   int _countDevicesInScada(Map<String, dynamic> scada) {
//     return ((scada['devices'] as List?)?.length ?? 0);
//   }
//
//   int _countSignalsInScada(Map<String, dynamic> scada) {
//     int total = 0;
//     for (final device in scada['devices'] ?? []) {
//       total += ((device['signals'] as List?)?.length ?? 0);
//     }
//     return total;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'Danh sách lỗi theo Facility',
//           style: TextStyle(
//             fontSize: 22,
//             fontWeight: FontWeight.w900,
//             color: Color(0xff0f172a),
//           ),
//         ),
//         const SizedBox(height: 6),
//
//         ...data.map<Widget>((fac) {
//           final categories = fac['categories'] as List? ?? [];
//
//           return Container(
//             margin: const EdgeInsets.only(bottom: 18),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(22),
//               border: Border.all(color: const Color(0xffe2e8f0)),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(.04),
//                   blurRadius: 18,
//                   offset: const Offset(0, 8),
//                 ),
//               ],
//             ),
//             child: ExpansionTile(
//               initiallyExpanded: true,
//               tilePadding: const EdgeInsets.symmetric(
//                 horizontal: 24,
//                 vertical: 12,
//               ),
//               childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
//               leading: Container(
//                 width: 52,
//                 height: 52,
//                 decoration: BoxDecoration(
//                   color: const Color(0xffdbeafe),
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: const Icon(Icons.factory, color: Color(0xff2563eb)),
//               ),
//               title: Text(
//                 'FAC ${fac['fac']}',
//                 style: const TextStyle(
//                   fontSize: 24,
//                   fontWeight: FontWeight.w900,
//                 ),
//               ),
//               subtitle: Padding(
//                 padding: const EdgeInsets.only(top: 6),
//                 child: Text(
//                   '${_countScadas(fac)} SCADA lỗi • ${_countSignalsInFac(fac)} thanh ghi lỗi',
//                   style: const TextStyle(
//                     color: Color(0xff64748b),
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//               children: [
//                 for (final cate in categories)
//                   for (final scada in cate['scadas'] ?? [])
//                     _ScadaErrorCard(
//                       category: cate['cate'],
//                       scada: scada,
//                       deviceCount: _countDevicesInScada(scada),
//                       signalCount: _countSignalsInScada(scada),
//                     ),
//               ],
//             ),
//           );
//         }),
//       ],
//     );
//   }
// }
//
// class _ScadaErrorCard extends StatelessWidget {
//   final String category;
//   final Map<String, dynamic> scada;
//   final int deviceCount;
//   final int signalCount;
//
//   const _ScadaErrorCard({
//     required this.category,
//     required this.scada,
//     required this.deviceCount,
//     required this.signalCount,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final devices = scada['devices'] as List? ?? [];
//
//     return Container(
//       margin: const EdgeInsets.only(bottom: 14),
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//       decoration: BoxDecoration(
//         color: const Color(0xfff8fafc),
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(color: const Color(0xffe2e8f0)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const Icon(Icons.dns, color: Color(0xff16a34a)),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: Text(
//                   'SCADA ${scada['scadaId']}',
//                   style: const TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.w900,
//                   ),
//                 ),
//               ),
//               _CountPill('$deviceCount BoxDevice'),
//               const SizedBox(width: 8),
//               _CountPill('$signalCount thanh ghi lỗi', danger: true),
//             ],
//           ),
//           const SizedBox(height: 6),
//           Text(
//             'Category: $category',
//             style: const TextStyle(
//               color: Color(0xff64748b),
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//           const SizedBox(height: 16),
//           ...devices.map<Widget>((device) => _DeviceErrorCard(device: device)),
//         ],
//       ),
//     );
//   }
// }
//
// class _DeviceErrorCard extends StatelessWidget {
//   final Map<String, dynamic> device;
//
//   const _DeviceErrorCard({required this.device});
//
//   @override
//   Widget build(BuildContext context) {
//     final signals = device['signals'] as List? ?? [];
//
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xffe5e7eb)),
//       ),
//       child: Column(
//         children: [
//           Row(
//             children: [
//               const Icon(Icons.memory, color: Color(0xfff97316)),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: Text(
//                   '${device['boxDeviceId']}',
//                   style: const TextStyle(
//                     fontSize: 17,
//                     fontWeight: FontWeight.w900,
//                   ),
//                 ),
//               ),
//               _CountPill('${signals.length} thanh ghi lỗi', danger: true),
//             ],
//           ),
//           const SizedBox(height: 6),
//           ...signals.map<Widget>((signal) => _SignalErrorItem(signal: signal)),
//         ],
//       ),
//     );
//   }
// }
//
// class _SignalErrorItem extends StatelessWidget {
//   final Map<String, dynamic> signal;
//
//   const _SignalErrorItem({required this.signal});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 6),
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//       decoration: BoxDecoration(
//         color: const Color(0xffFFF8F8),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: const Color(0xffFECACA)),
//       ),
//       child: Column(
//         children: [
//           Row(
//             children: [
//               const Icon(
//                 Icons.warning_amber_rounded,
//                 color: Colors.red,
//                 size: 20,
//               ),
//               const SizedBox(width: 6),
//
//               Expanded(
//                 child: Text(
//                   signal["signalName"],
//                   style: const TextStyle(
//                     fontSize: 17,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//
//               _StatusBadge(signal["status"]),
//             ],
//           ),
//
//           const SizedBox(height: 10),
//
//           Row(
//             children: [
//               Expanded(
//                 child: _MetricValue(
//                   title: "PREV",
//                   value: "${signal["prevValue"]}",
//                   color: Colors.grey.shade700,
//                 ),
//               ),
//
//               Expanded(
//                 child: _MetricValue(
//                   title: "CURRENT",
//                   value: "${signal["currentValue"]}",
//                   color: Colors.red,
//                 ),
//               ),
//
//               Expanded(
//                 child: _MetricValue(
//                   title: "JUMP",
//                   value: "${signal["jumpSize"]}",
//                   color: Colors.orange,
//                 ),
//               ),
//             ],
//           ),
//
//           const SizedBox(height: 8),
//
//           Row(
//             children: [
//               Text(
//                 "PLC ${signal["plcAddress"]}",
//                 style: const TextStyle(
//                   fontWeight: FontWeight.w600,
//                   color: Colors.blueGrey,
//                 ),
//               ),
//
//               const Spacer(),
//
//               Text(
//                 signal["recordedAt"],
//                 style: const TextStyle(fontSize: 12, color: Colors.grey),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _MetricValue extends StatelessWidget {
//   final String title;
//   final String value;
//   final Color color;
//
//   const _MetricValue({
//     required this.title,
//     required this.value,
//     required this.color,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Text(
//           title,
//           style: const TextStyle(
//             fontSize: 11,
//             color: Colors.grey,
//             letterSpacing: 0.5,
//           ),
//         ),
//
//         const SizedBox(height: 2),
//
//         Text(
//           value,
//           maxLines: 1,
//           overflow: TextOverflow.ellipsis,
//           style: TextStyle(
//             fontSize: 30,
//             fontWeight: FontWeight.w900,
//             color: color,
//             height: 1,
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// class _CountPill extends StatelessWidget {
//   final String text;
//   final bool danger;
//
//   const _CountPill(this.text, {this.danger = false});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
//       decoration: BoxDecoration(
//         color: danger ? const Color(0xffffe4e6) : Colors.white,
//         borderRadius: BorderRadius.circular(99),
//         border: Border.all(
//           color: danger ? const Color(0xfffca5a5) : const Color(0xffe2e8f0),
//         ),
//       ),
//       child: Text(
//         text,
//         style: TextStyle(
//           color: danger ? const Color(0xffdc2626) : const Color(0xff334155),
//           fontWeight: FontWeight.w800,
//           fontSize: 13,
//         ),
//       ),
//     );
//   }
// }
//
// class _StatusBadge extends StatelessWidget {
//   final String status;
//
//   const _StatusBadge(this.status);
//
//   @override
//   Widget build(BuildContext context) {
//     return Chip(
//       label: Text(status),
//       backgroundColor: const Color(0xffffe4e6),
//       labelStyle: const TextStyle(
//         color: Colors.red,
//         fontWeight: FontWeight.bold,
//         fontSize: 12,
//       ),
//     );
//   }
// }
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_widgets/chart_state_widgets.dart';

const kBg = Color(0xff0f172a);
const kCard = Color(0xff111827);
const kCard2 = Color(0xff1e293b);
const kBorder = Color(0xff334155);
const kText = Color(0xfff8fafc);
const kSubText = Color(0xffcbd5e1);
const kBlue = Color(0xff38bdf8);
const kGreen = Color(0xff22c55e);
const kOrange = Color(0xfff97316);
const kRed = Color(0xffef4444);

class SignalHealthMatrixScreen extends StatefulWidget {
  const SignalHealthMatrixScreen({super.key});

  @override
  State<SignalHealthMatrixScreen> createState() =>
      _SignalHealthMatrixScreenState();
}

class _SignalHealthMatrixScreenState extends State<SignalHealthMatrixScreen> {
  String facFilter = 'ALL';
  String cateFilter = 'ALL';
  String scadaFilter = 'ALL';
  String keyword = '';

  static const Duration _pollInterval = Duration(minutes: 1);
  static const Duration _requestTimeout = Duration(seconds: 12);

  bool loading = true;
  bool refreshing = false;
  bool _isFetching = false;
  String? error;
  Timer? _refreshTimer;

  List<dynamic> data = [];
  Map<String, dynamic>? selected;

  static const String apiUrl =
      'http://localhost:9999/api/utility/signal-health-matrix';

  @override
  void initState() {
    super.initState();
    _load();
    _startPolling();
  }

  void _startPolling() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(_pollInterval, (_) {
      if (!_isFetching && mounted) {
        _load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_isFetching || !mounted) return;

    _isFetching = true;

    if (!silent && data.isEmpty) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    if (silent && mounted) {
      setState(() => refreshing = true);
    }

    final oldBoxDeviceId = selected?['boxDeviceId'];

    try {
      final res = await http.get(Uri.parse(apiUrl)).timeout(_requestTimeout);

      if (res.statusCode != 200) {
        throw Exception('API Error: ${res.statusCode}');
      }

      final decoded = jsonDecode(res.body);
      final newData = decoded is List ? decoded : [];

      final newSelected = _findSelectedDevice(newData, oldBoxDeviceId);

      if (!mounted) return;

      setState(() {
        data = newData;
        selected = newSelected;
        loading = false;
        refreshing = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        refreshing = false;

        if (data.isEmpty) {
          error = e.toString();
        }
      });
    } finally {
      _isFetching = false;
    }
  }

  Map<String, dynamic>? _findSelectedDevice(
    List<dynamic> newData,
    String? oldBoxDeviceId,
  ) {
    if (newData.isEmpty) return null;

    if (oldBoxDeviceId != null) {
      for (final item in newData) {
        final row = item as Map<String, dynamic>;
        if ('${row['boxDeviceId']}' == oldBoxDeviceId) {
          return row;
        }
      }
    }

    return newData.first as Map<String, dynamic>;
  }

  List<dynamic> get filteredData {
    return data.where((e) {
      final facOk = facFilter == 'ALL' || e['fac'] == facFilter;
      final cateOk = cateFilter == 'ALL' || e['cate'] == cateFilter;
      final scadaOk = scadaFilter == 'ALL' || e['scadaId'] == scadaFilter;

      final text = keyword.toLowerCase();
      final searchOk =
          text.isEmpty ||
          '${e['fac']}'.toLowerCase().contains(text) ||
          '${e['cate']}'.toLowerCase().contains(text) ||
          '${e['scadaId']}'.toLowerCase().contains(text) ||
          '${e['boxDeviceId']}'.toLowerCase().contains(text);

      return facOk && cateOk && scadaOk && searchOk;
    }).toList();
  }

  List<String> get facOptions => [
    'ALL',
    ...data.map((e) => '${e['fac']}').toSet(),
  ];

  List<String> get cateOptions => [
    'ALL',
    ...data.map((e) => '${e['cate']}').toSet(),
  ];

  List<String> get scadaOptions => [
    'ALL',
    ...data.map((e) => '${e['scadaId']}').toSet(),
  ];

  int get totalFac => data.map((e) => e['fac']).toSet().length;

  int get totalBoxDevice => data.length;

  int get totalRegister => data.fold(
    0,
    (sum, e) => sum + ((e['totalRegisters'] ?? 0) as num).toInt(),
  );

  int get totalNgRegister =>
      data.fold(0, (sum, e) => sum + ((e['ngRegisters'] ?? 0) as num).toInt());

  String get lastUpdated {
    String latest = '-';

    for (final device in data) {
      for (final signal in device['signals'] ?? []) {
        final time = '${signal['recordedAt'] ?? ''}';
        if (time.isNotEmpty && (latest == '-' || time.compareTo(latest) > 0)) {
          latest = time;
        }
      }
    }

    return latest;
  }

  Widget _body() {
    // Loading lần đầu
    if (loading && data.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // API lỗi và chưa có dữ liệu
    if (error != null && data.isEmpty) {
      return ChartApiErrorState(color: Colors.redAccent, onRetry: _load);
    }

    // Không có dữ liệu
    if (data.isEmpty) {
      return const EmptyChartState(
        title: 'No Signal Health Data',
        message: 'No signal health matrix data found.',
      );
    }

    // Có dữ liệu -> render dashboard
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          _Header(
            lastUpdated: refreshing ? 'Refreshing...' : lastUpdated,
            onRefresh: () => _load(silent: true),
          ),

          const SizedBox(height: 16),

          _KpiRow(
            totalFac: totalFac,
            totalBoxDevice: totalBoxDevice,
            totalRegister: totalRegister,
            totalNgRegister: totalNgRegister,
          ),

          const SizedBox(height: 16),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    children: [
                      _FilterRow(
                        facOptions: facOptions,
                        cateOptions: cateOptions,
                        scadaOptions: scadaOptions,
                        facValue: facFilter,
                        cateValue: cateFilter,
                        scadaValue: scadaFilter,
                        onFacChanged: (v) => setState(() => facFilter = v!),
                        onCateChanged: (v) => setState(() => cateFilter = v!),
                        onScadaChanged: (v) => setState(() => scadaFilter = v!),
                        onSearchChanged: (v) => setState(() => keyword = v),
                      ),

                      const SizedBox(height: 12),

                      Expanded(
                        child: _MatrixTable(
                          data: filteredData,
                          selected: selected,
                          onSelect: (item) {
                            setState(() => selected = item);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  flex: 4,
                  child: selected == null
                      ? const SizedBox()
                      : _DetailPanel(device: selected!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: kBg, body: _body());
  }
}

class _Header extends StatelessWidget {
  final String lastUpdated;
  final VoidCallback onRefresh;

  const _Header({required this.lastUpdated, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: kBlue.withOpacity(.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBlue.withOpacity(.35)),
          ),
          child: const Icon(Icons.monitor_heart, color: kBlue),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Signal Health Matrix',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: kText,
                ),
              ),
              Text(
                'Tổng hợp tình trạng Device và Register',
                style: TextStyle(color: kSubText),
              ),
            ],
          ),
        ),
        Text(
          'Last updated: $lastUpdated',
          style: const TextStyle(color: kSubText),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: kBlue,
            side: BorderSide(color: kBlue.withOpacity(.45)),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.download),
          label: const Text('Export Excel'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kBlue,
            foregroundColor: kBg,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  final int totalFac;
  final int totalBoxDevice;
  final int totalRegister;
  final int totalNgRegister;

  const _KpiRow({
    required this.totalFac,
    required this.totalBoxDevice,
    required this.totalRegister,
    required this.totalNgRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _KpiCard(
          title: 'FACILITY',
          value: totalFac,
          subtitle: 'Tổng số FAC',
          icon: Icons.factory,
          color: const Color(0xff2563eb),
        ),
        const SizedBox(width: 16),
        _KpiCard(
          title: 'BOX DEVICE',
          value: totalBoxDevice,
          subtitle: 'Tổng số BoxDevice',
          icon: Icons.memory,
          color: const Color(0xff7c3aed),
        ),
        const SizedBox(width: 16),
        _KpiCard(
          title: 'REGISTER',
          value: totalRegister,
          subtitle: 'Tổng số Register',
          icon: Icons.menu_book,
          color: const Color(0xfff97316),
        ),
        const SizedBox(width: 16),
        _KpiCard(
          title: 'NG REGISTER',
          value: totalNgRegister,
          subtitle: 'Tổng số Register lỗi',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xffdc2626),
          danger: true,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final int value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool danger;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 108,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: danger ? kRed.withOpacity(.10) : kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: danger ? kRed.withOpacity(.45) : kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: kText,
                    height: 1.1,
                  ),
                ),
                Text(subtitle, style: const TextStyle(color: kSubText)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final List<String> facOptions;
  final List<String> cateOptions;
  final List<String> scadaOptions;

  final String facValue;
  final String cateValue;
  final String scadaValue;

  final ValueChanged<String?> onFacChanged;
  final ValueChanged<String?> onCateChanged;
  final ValueChanged<String?> onScadaChanged;
  final ValueChanged<String> onSearchChanged;

  const _FilterRow({
    required this.facOptions,
    required this.cateOptions,
    required this.scadaOptions,
    required this.facValue,
    required this.cateValue,
    required this.scadaValue,
    required this.onFacChanged,
    required this.onCateChanged,
    required this.onScadaChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterDropdown(
          value: facValue,
          items: facOptions,
          onChanged: onFacChanged,
        ),
        const SizedBox(width: 12),
        _FilterDropdown(
          value: cateValue,
          items: cateOptions,
          onChanged: onCateChanged,
        ),
        const SizedBox(width: 12),
        _FilterDropdown(
          value: scadaValue,
          items: scadaOptions,
          onChanged: onScadaChanged,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            onChanged: onSearchChanged,
            style: const TextStyle(color: kText),
            decoration: InputDecoration(
              hintText: 'Search device...',
              hintStyle: const TextStyle(color: kSubText),
              prefixIcon: const Icon(Icons.search, color: kSubText),
              filled: true,
              fillColor: kCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBlue),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 205,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,

          // 👇 Màu nền menu xổ xuống
          dropdownColor: kCard,

          // 👇 Màu chữ của item đang chọn
          style: const TextStyle(
            color: kText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),

          // 👇 Màu icon mũi tên
          iconEnabledColor: kText,

          items: items.map((e) {
            return DropdownMenuItem<String>(
              value: e,
              child: Text(
                e,
                style: const TextStyle(
                  color: kText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),

          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _MatrixTable extends StatelessWidget {
  final List<dynamic> data;
  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _MatrixTable({
    required this.data,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: kCard2,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Row(
              children: [
                _HeaderCell('Facility', flex: 1),
                _HeaderCell('Category', flex: 1),
                _HeaderCell('SCADA', flex: 1),
                _HeaderCell('Box Device ID', flex: 3),
                _HeaderCell('Total', flex: 1, center: true),
                _HeaderCell('NG', flex: 1, center: true),
                _HeaderCell('Status', flex: 1, center: true),
                SizedBox(width: 44),
              ],
            ),
          ),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(10),
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = data[index] as Map<String, dynamic>;
                final isSelected = identical(row, selected);
                final isNg = row['status'] == 'NG';

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelect(row),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? kBlue.withOpacity(.14)
                          : isNg
                          ? kOrange.withOpacity(.10)
                          : kCard,
                      border: Border.all(
                        color: isSelected
                            ? kBlue
                            : isNg
                            ? kOrange.withOpacity(.45)
                            : kBorder,
                        width: isSelected ? 1.6 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _BodyCell('${row['fac']}', flex: 1, bold: true),
                        _BodyCell(
                          '${row['cate']}',
                          flex: 1,
                          child: _CategoryBadge('${row['cate']}'),
                        ),
                        _BodyCell(
                          '${row['scadaId']}',
                          flex: 1,
                          child: _SoftBadge('${row['scadaId']}'),
                        ),
                        _BodyCell('${row['boxDeviceId']}', flex: 3, bold: true),
                        _BodyCell(
                          '${row['totalRegisters']}',
                          flex: 1,
                          center: true,
                          child: _RegisterNumber(
                            '${row['totalRegisters']}',
                            color: kText,
                          ),
                        ),
                        _BodyCell(
                          '${row['ngRegisters']}',
                          flex: 1,
                          center: true,
                          child: _RegisterNumber(
                            '${row['ngRegisters']}',
                            color: isNg
                                ? const Color(0xffdc2626)
                                : const Color(0xff16a34a),
                          ),
                        ),
                        _BodyCell(
                          '${row['status']}',
                          flex: 1,
                          center: true,
                          child: _StatusBadge('${row['status']}'),
                        ),
                        SizedBox(
                          width: 44,
                          child: Icon(
                            Icons.chevron_right,
                            color: isSelected
                                ? const Color(0xff2563eb)
                                : const Color(0xff94a3b8),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: kBorder)),
            ),
            child: Row(
              children: [
                Text(
                  'Hiển thị ${data.length} bản ghi',
                  style: const TextStyle(
                    color: Color(0xff64748b),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Click vào dòng để xem chi tiết',
                  style: TextStyle(color: Color(0xff94a3b8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool center;

  const _HeaderCell(this.text, {required this.flex, this.center = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: center ? Alignment.center : Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: kSubText,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: .3,
          ),
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool center;
  final bool bold;
  final Widget? child;

  const _BodyCell(
    this.text, {
    required this.flex,
    this.center = false,
    this.bold = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: center ? Alignment.center : Alignment.centerLeft,
        child:
            child ??
            Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: kText,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
      ),
    );
  }
}

class _RegisterNumber extends StatelessWidget {
  final String value;
  final Color color;

  const _RegisterNumber(this.value, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String text;

  const _CategoryBadge(this.text);

  @override
  Widget build(BuildContext context) {
    final isElectric = text.toLowerCase().contains('electric');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isElectric ? const Color(0xfffff7ed) : const Color(0xffeff6ff),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isElectric ? const Color(0xffea580c) : const Color(0xff2563eb),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  final String text;

  const _SoftBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xfff1f5f9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xff334155),
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  final Map<String, dynamic> device;

  const _DetailPanel({required this.device});

  @override
  Widget build(BuildContext context) {
    final signals = device['signals'] as List? ?? [];

    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Register Details',
                style: TextStyle(
                  color: kText,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${signals.length} signals',
                style: const TextStyle(
                  color: kSubText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: signals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _SignalMetricCard(signal: signals[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalMetricCard extends StatelessWidget {
  final dynamic signal;

  const _SignalMetricCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final status = '${signal['status']}';
    final isOk = status == 'OK';
    final borderColor = isOk
        ? kGreen.withOpacity(.25)
        : kOrange.withOpacity(.55);
    final bgColor = isOk ? kCard2 : kOrange.withOpacity(.10);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOk ? Icons.check_circle : Icons.warning_amber_rounded,
                color: isOk ? kGreen : kOrange,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${signal['signalName']}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kText,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusBadge(status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MetaChip('PLC', '${signal['plcAddress']}'),
              const Spacer(),
              Text(
                _formatTime('${signal['recordedAt']}'),
                style: const TextStyle(
                  color: kSubText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ValueBox(
                  label: 'PREV',
                  value: '${signal['prevValue']}',
                  color: kText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ValueBox(
                  label: 'CURRENT',
                  value: '${signal['currentValue']}',
                  color: isOk ? kGreen : kRed,
                  highlight: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ValueBox(
                  label: 'JUMP',
                  value: '${signal['jumpSize']}',
                  color: _jumpColor(signal['jumpSize']),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: Text(
              '${signal['description']}',
              style: TextStyle(
                color: isOk ? kSubText : const Color(0xffffd28a),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _jumpColor(dynamic value) {
    final number = num.tryParse('$value') ?? 0;
    if (number == 0) return kSubText;
    if (number > 1000) return kRed;
    return kOrange;
  }

  static String _formatTime(String value) {
    if (value.length >= 19) {
      return value.substring(0, 19).replaceFirst('T', ' ');
    }
    return value;
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetaChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: kSubText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ValueBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool highlight;

  const _ValueBox({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(highlight ? .16 : .09),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withOpacity(.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(.85),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: highlight ? 22 : 20,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final isOk = status == 'OK';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOk ? kGreen.withOpacity(.14) : kRed.withOpacity(.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOk ? kGreen.withOpacity(.55) : kRed.withOpacity(.55),
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isOk ? kGreen : kRed,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: kCard,
    border: Border.all(color: kBorder),
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.25),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
