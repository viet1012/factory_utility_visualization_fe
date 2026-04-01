// import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/voltage_card1.dart';
// import 'package:flutter/material.dart';
//
// import '../../utility_dashboard_api/utility_dashboard_overview_api.dart';
// import 'voltage_detail_chart.dart';
//
// class MultiVoltageAlarmDialog extends StatelessWidget {
//   final ValueNotifier<Map<String, VoltageStatus>> alarmsNotifier;
//   final UtilityDashboardOverviewApi api;
//   final BuildContext parentContext;
//
//   const MultiVoltageAlarmDialog({
//     super.key,
//     required this.alarmsNotifier,
//     required this.api,
//     required this.parentContext,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final screen = MediaQuery.of(context).size;
//     final width = screen.width < 720 ? screen.width * 0.92 : 820.0;
//
//     return Dialog(
//       backgroundColor: Colors.transparent,
//       insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
//       child: ValueListenableBuilder<Map<String, VoltageStatus>>(
//         valueListenable: alarmsNotifier,
//         builder: (context, alarmMap, _) {
//           final sorted = alarmMap.values.toList()
//             ..sort((a, b) {
//               int severity(String s) {
//                 switch (s) {
//                   case 'Critical':
//                     return 3;
//                   case 'Alarm':
//                     return 2;
//                   case 'Warning':
//                     return 1;
//                   default:
//                     return 0;
//                 }
//               }
//
//               return severity(b.alarm).compareTo(severity(a.alarm));
//             });
//
//           if (sorted.isEmpty) {
//             WidgetsBinding.instance.addPostFrameCallback((_) {
//               if (context.mounted) {
//                 Navigator.of(context).pop();
//               }
//             });
//             return const SizedBox.shrink();
//           }
//
//           return Container(
//             width: width,
//             constraints: const BoxConstraints(maxWidth: 820, minHeight: 420),
//             padding: const EdgeInsets.all(24),
//             decoration: BoxDecoration(
//               color: const Color(0xFF1A0A0A),
//               borderRadius: BorderRadius.circular(20),
//               border: Border.all(color: const Color(0xFFEF5350), width: 1.4),
//               gradient: const LinearGradient(
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//                 colors: [Color(0xFF2A0D10), Color(0xFF160708)],
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: const Color(0xFFEF5350).withOpacity(0.25),
//                   blurRadius: 32,
//                   spreadRadius: 4,
//                 ),
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.35),
//                   blurRadius: 16,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Row(
//                   children: [
//                     Container(
//                       width: 52,
//                       height: 52,
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         color: const Color(0xFFEF5350).withOpacity(0.12),
//                         border: Border.all(
//                           color: const Color(0xFFEF5350).withOpacity(0.45),
//                         ),
//                       ),
//                       child: const Icon(
//                         Icons.warning_amber_rounded,
//                         color: Color(0xFFEF5350),
//                         size: 30,
//                       ),
//                     ),
//                     const SizedBox(width: 14),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text(
//                             'VOLTAGE ALARMS',
//                             style: TextStyle(
//                               color: Color(0xFFEF5350),
//                               fontSize: 22,
//                               fontWeight: FontWeight.w800,
//                               letterSpacing: 1.5,
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                           Text(
//                             '${sorted.length} cảnh báo đang hoạt động',
//                             style: TextStyle(
//                               color: Colors.white.withOpacity(0.68),
//                               fontSize: 13,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     IconButton(
//                       onPressed: () => Navigator.of(context).pop(),
//                       icon: const Icon(Icons.close, color: Colors.white60),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 20),
//                 Container(
//                   height: 1,
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [
//                         Colors.transparent,
//                         Colors.white.withOpacity(0.16),
//                         Colors.transparent,
//                       ],
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 18),
//                 Flexible(
//                   child: ConstrainedBox(
//                     constraints: const BoxConstraints(maxHeight: 420),
//                     child: ListView.separated(
//                       shrinkWrap: true,
//                       itemCount: sorted.length,
//                       separatorBuilder: (_, __) => const SizedBox(height: 12),
//                       itemBuilder: (context, index) {
//                         final alarm = sorted[index];
//                         const color = Color(0xFFEF5350);
//                         final isTop = index == 0;
//
//                         return Container(
//                           padding: const EdgeInsets.all(16),
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(
//                               isTop ? 0.08 : 0.04,
//                             ),
//                             borderRadius: BorderRadius.circular(18),
//                             border: Border.all(
//                               color: color.withOpacity(isTop ? 0.80 : 0.38),
//                               width: isTop ? 1.3 : 1,
//                             ),
//                             boxShadow: isTop
//                                 ? [
//                                     BoxShadow(
//                                       color: color.withOpacity(0.16),
//                                       blurRadius: 20,
//                                       spreadRadius: 1,
//                                     ),
//                                   ]
//                                 : null,
//                           ),
//                           child: Row(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               // LEFT COLUMN
//                               Expanded(
//                                 flex: 6,
//                                 child: Row(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Expanded(
//                                       child: Column(
//                                         crossAxisAlignment:
//                                             CrossAxisAlignment.start,
//                                         children: [
//                                           Wrap(
//                                             spacing: 8,
//                                             runSpacing: 8,
//                                             crossAxisAlignment:
//                                                 WrapCrossAlignment.center,
//                                             children: [
//                                               Text(
//                                                 alarm.fac.isEmpty
//                                                     ? '-'
//                                                     : alarm.fac,
//                                                 style: const TextStyle(
//                                                   color: Colors.white,
//                                                   fontSize: 22,
//                                                   fontWeight: FontWeight.w900,
//                                                   height: 1.1,
//                                                 ),
//                                               ),
//                                               Container(
//                                                 padding:
//                                                     const EdgeInsets.symmetric(
//                                                       horizontal: 10,
//                                                       vertical: 4,
//                                                     ),
//                                                 decoration: BoxDecoration(
//                                                   color: color.withOpacity(
//                                                     0.18,
//                                                   ),
//                                                   borderRadius:
//                                                       BorderRadius.circular(
//                                                         999,
//                                                       ),
//                                                   border: Border.all(
//                                                     color: color.withOpacity(
//                                                       0.45,
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 child: const Text(
//                                                   'ALARM',
//                                                   style: TextStyle(
//                                                     color: color,
//                                                     fontSize: 10,
//                                                     fontWeight: FontWeight.w900,
//                                                     letterSpacing: 1,
//                                                   ),
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                           const SizedBox(height: 8),
//                                           if (alarm.boxDeviceId.isNotEmpty)
//                                             Container(
//                                               padding:
//                                                   const EdgeInsets.symmetric(
//                                                     horizontal: 10,
//                                                     vertical: 5,
//                                                   ),
//                                               decoration: BoxDecoration(
//                                                 color: Colors.white.withOpacity(
//                                                   0.05,
//                                                 ),
//                                                 borderRadius:
//                                                     BorderRadius.circular(999),
//                                                 border: Border.all(
//                                                   color: Colors.white
//                                                       .withOpacity(0.10),
//                                                 ),
//                                               ),
//                                               child: Text(
//                                                 'BOX ${alarm.boxDeviceId}',
//                                                 style: TextStyle(
//                                                   color: Colors.white
//                                                       .withOpacity(0.82),
//                                                   fontSize: 18,
//                                                   fontWeight: FontWeight.w700,
//                                                   letterSpacing: 0.6,
//                                                 ),
//                                               ),
//                                             ),
//                                         ],
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//
//                               const SizedBox(width: 16),
//
//                               // RIGHT COLUMN
//                               Expanded(
//                                 flex: 5,
//                                 child: Column(
//                                   crossAxisAlignment:
//                                       CrossAxisAlignment.stretch,
//                                   children: [
//                                     Row(
//                                       children: [
//                                         Expanded(
//                                           child: _CompactMetricCard(
//                                             label: 'MAX',
//                                             value:
//                                                 '${alarm.maxVol.toStringAsFixed(0)} V',
//                                             color: color,
//                                             emphasize: true,
//                                           ),
//                                         ),
//                                         const SizedBox(width: 10),
//                                         Expanded(
//                                           child: _CompactMetricCard(
//                                             label: 'MIN',
//                                             value:
//                                                 '${alarm.minVol.toStringAsFixed(0)} V',
//                                             color: Colors.white70,
//                                             emphasize: false,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                     const SizedBox(height: 10),
//                                     Align(
//                                       alignment: Alignment.centerRight,
//                                       child: FilledButton.icon(
//                                         onPressed: () async {
//                                           Navigator.of(context).pop();
//
//                                           await Future.delayed(
//                                             const Duration(milliseconds: 180),
//                                           );
//
//                                           if (!parentContext.mounted) return;
//
//                                           showDialog(
//                                             context: parentContext,
//                                             builder: (_) => VoltageChartDialog(
//                                               api: api,
//                                               facId: alarm.fac,
//                                             ),
//                                           );
//                                         },
//                                         icon: const Icon(
//                                           Icons.bar_chart_rounded,
//                                           size: 16,
//                                         ),
//                                         label: const Text('Chi tiết'),
//                                         style: FilledButton.styleFrom(
//                                           backgroundColor: color.withOpacity(
//                                             0.18,
//                                           ),
//                                           foregroundColor: color,
//                                           elevation: 0,
//                                           padding: const EdgeInsets.symmetric(
//                                             horizontal: 14,
//                                             vertical: 12,
//                                           ),
//                                           shape: RoundedRectangleBorder(
//                                             borderRadius: BorderRadius.circular(
//                                               12,
//                                             ),
//                                             side: BorderSide(
//                                               color: color.withOpacity(0.45),
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 18),
//                 SizedBox(
//                   width: double.infinity,
//                   child: TextButton(
//                     onPressed: () => Navigator.of(context).pop(),
//                     child: const Text('ĐÃ HIỂU TẤT CẢ'),
//                   ),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
//
// class _CompactMetricCard extends StatelessWidget {
//   final String label;
//   final String value;
//   final Color color;
//   final bool emphasize;
//
//   const _CompactMetricCard({
//     required this.label,
//     required this.value,
//     required this.color,
//     required this.emphasize,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//       decoration: BoxDecoration(
//         color: color.withOpacity(emphasize ? 0.12 : 0.06),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: color.withOpacity(emphasize ? 0.42 : 0.18)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               color: emphasize ? color.withOpacity(0.95) : Colors.white60,
//               fontSize: 10,
//               fontWeight: FontWeight.w800,
//               letterSpacing: 1.1,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             value,
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//             style: TextStyle(
//               color: color,
//               fontSize: 30,
//               fontWeight: FontWeight.w900,
//               height: 1,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
