// // voltage_card.dart
//
// import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/voltage_detail_chart.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import '../../utility_dashboard_api/utility_dashboard_overview_api.dart';
//
// // =============================================================================
// // MODEL
// // =============================================================================

class VoltageStatus {
  final String fac;
  final String boxDeviceId;
  final String name;
  final double minVol;
  final double maxVol;
  final String alarm;
  final DateTime timestamp;

  VoltageStatus({
    required this.fac,
    required this.boxDeviceId,
    required this.name,
    required this.minVol,
    required this.maxVol,
    required this.alarm,
    required this.timestamp,
  });

  factory VoltageStatus.fromJson(Map<String, dynamic> json) {
    return VoltageStatus(
      fac: json['fac']?.toString() ?? '',
      boxDeviceId: json['boxDeviceId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      minVol: (json['minVol'] as num?)?.toDouble() ?? 0,
      maxVol: (json['maxVol'] as num?)?.toDouble() ?? 0,
      alarm: json['alarm']?.toString() ?? 'Normal',
      timestamp: DateTime.parse(json['timestamp']).toLocal(),
    );
  }

  bool get isAlarm => alarm == "Alarm";
}

//
// // =============================================================================
// // VoltageCard
// // =============================================================================
//
// class VoltageCard extends StatefulWidget {
//   final VoltageStatus status;
//   final Animation<double> pulseAnimation;
//   final String facId;
//
//   const VoltageCard({
//     super.key,
//     required this.status,
//     required this.pulseAnimation,
//     required this.facId,
//   });
//
//   @override
//   State<VoltageCard> createState() => _VoltageCardState();
// }
//
// class _VoltageCardState extends State<VoltageCard> {
//   @override
//   void initState() {
//     super.initState();
//     if (widget.status.isAlarm) {
//       WidgetsBinding.instance.addPostFrameCallback((_) => _showAlarmDialog());
//     }
//   }
//
//   @override
//   void didUpdateWidget(covariant VoltageCard old) {
//     super.didUpdateWidget(old);
//     if (!old.status.isAlarm && widget.status.isAlarm) {
//       WidgetsBinding.instance.addPostFrameCallback((_) => _showAlarmDialog());
//     }
//   }
//
//   void _showAlarmDialog() {
//     if (!mounted) return;
//     final api = context.read<UtilityDashboardOverviewApi>();
//
//     showDialog(
//       context: context,
//       barrierColor: Colors.black54,
//       builder: (_) => _AlarmDialog(
//         status: widget.status,
//         facId: widget.facId,
//         api: api,
//         parentContext: context,
//       ),
//     );
//   }
//
//   void _showDetailChart() {
//     if (!mounted) return;
//     final api = context.read<UtilityDashboardOverviewApi>();
//     showDialog(
//       context: context,
//       builder: (_) => VoltageChartDialog(api: api, facId: widget.facId),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final alarm = widget.status.isAlarm;
//     final color = alarm ? const Color(0xFFEF5350) : const Color(0xFFFFB300);
//
//     return GestureDetector(
//       onTap: _showDetailChart,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 300),
//         padding: const EdgeInsets.symmetric(vertical: 6),
//         decoration: BoxDecoration(
//           color: color.withOpacity(0.08),
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: color.withOpacity(alarm ? 0.6 : 0.25)),
//         ),
//         child: Row(
//           children: [
//             AnimatedBuilder(
//               animation: widget.pulseAnimation,
//               builder: (_, child) => Transform.scale(
//                 scale: alarm ? widget.pulseAnimation.value : 1.0,
//                 child: child,
//               ),
//               child: Container(
//                 width: 28,
//                 height: 28,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: color.withOpacity(0.15),
//                 ),
//                 child: Icon(Icons.bolt_rounded, color: color, size: 22),
//               ),
//             ),
//             const SizedBox(width: 10),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       Text(
//                         'Voltage',
//                         style: TextStyle(
//                           color: color,
//                           fontSize: 15,
//                           fontWeight: FontWeight.w800,
//                           letterSpacing: 1.2,
//                         ),
//                       ),
//                       if (alarm) ...[
//                         const SizedBox(width: 6),
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 5,
//                             vertical: 1,
//                           ),
//                           decoration: BoxDecoration(
//                             color: const Color(0xFFEF5350).withOpacity(0.2),
//                             borderRadius: BorderRadius.circular(4),
//                             border: Border.all(
//                               color: const Color(0xFFEF5350),
//                               width: 0.5,
//                             ),
//                           ),
//                           child: const Text(
//                             'ALARM',
//                             style: TextStyle(
//                               color: Color(0xFFEF5350),
//                               fontSize: 11,
//                               fontWeight: FontWeight.bold,
//                               letterSpacing: 0.8,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ],
//                   ),
//                   const SizedBox(height: 3),
//                   Row(
//                     children: [
//                       _VoltageChip(
//                         label: 'MIN',
//                         value: widget.status.minVol,
//                         color: Colors.white60,
//                       ),
//                       const SizedBox(width: 12),
//                       AnimatedBuilder(
//                         animation: widget.pulseAnimation,
//                         builder: (_, child) => Transform.scale(
//                           scale: alarm ? widget.pulseAnimation.value : 1.0,
//                           child: child,
//                         ),
//                         child: _VoltageChip(
//                           label: 'MAX',
//                           value: widget.status.maxVol,
//                           color: color,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             Icon(
//               Icons.chevron_right_rounded,
//               color: color.withOpacity(0.5),
//               size: 22,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // =============================================================================
// // _AlarmDialog
// // =============================================================================
//
// class _AlarmDialog extends StatelessWidget {
//   final VoltageStatus status;
//   final String facId;
//   final UtilityDashboardOverviewApi api;
//   final BuildContext parentContext;
//
//   const _AlarmDialog({
//     required this.status,
//     required this.facId,
//     required this.api,
//     required this.parentContext,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final screen = MediaQuery.of(context).size;
//     final dialogWidth = screen.width < 700 ? screen.width * 0.92 : 760.0;
//     final isWide = dialogWidth >= 680;
//
//     return Dialog(
//       backgroundColor: Colors.transparent,
//       insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
//       child: Container(
//         width: dialogWidth,
//         constraints: const BoxConstraints(maxWidth: 760, minHeight: 420),
//         padding: const EdgeInsets.all(28),
//         decoration: BoxDecoration(
//           color: const Color(0xFF1A0A0A),
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(color: const Color(0xFFEF5350), width: 1.6),
//           boxShadow: [
//             BoxShadow(
//               color: const Color(0xFFEF5350).withOpacity(0.28),
//               blurRadius: 36,
//               spreadRadius: 6,
//             ),
//             BoxShadow(
//               color: Colors.black.withOpacity(0.35),
//               blurRadius: 18,
//               offset: const Offset(0, 10),
//             ),
//           ],
//           gradient: const LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [Color(0xFF2A0D10), Color(0xFF160708)],
//           ),
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Row(
//               children: [
//                 Container(
//                   width: 54,
//                   height: 54,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: const Color(0xFFEF5350).withOpacity(0.12),
//                     border: Border.all(
//                       color: const Color(0xFFEF5350).withOpacity(0.45),
//                     ),
//                   ),
//                   child: const Icon(
//                     Icons.warning_amber_rounded,
//                     color: Color(0xFFEF5350),
//                     size: 30,
//                   ),
//                 ),
//                 const SizedBox(width: 14),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         'VOLTAGE ALARM',
//                         style: TextStyle(
//                           color: Color(0xFFEF5350),
//                           fontSize: 22,
//                           fontWeight: FontWeight.w800,
//                           letterSpacing: 1.6,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         'Điện áp đang vượt ngoài ngưỡng vận hành an toàn.',
//                         style: TextStyle(
//                           color: Colors.white.withOpacity(0.68),
//                           fontSize: 13,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 IconButton(
//                   onPressed: () => Navigator.of(context).pop(),
//                   icon: const Icon(
//                     Icons.close,
//                     color: Colors.white60,
//                     size: 22,
//                   ),
//                   splashRadius: 22,
//                 ),
//               ],
//             ),
//             const SizedBox(height: 20),
//             Container(
//               height: 1,
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     Colors.transparent,
//                     Colors.white.withOpacity(0.16),
//                     Colors.transparent,
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(height: 24),
//
//             if (isWide)
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Expanded(flex: 6, child: _AlarmInfoPanel(status: status)),
//                   const SizedBox(width: 18),
//                   Expanded(
//                     flex: 5,
//                     child: Column(
//                       children: [
//                         _AlarmChip(
//                           label: 'MIN VOLTAGE',
//                           value: status.minVol,
//                           color: Colors.white70,
//                           height: 104,
//                           valueFontSize: 32,
//                         ),
//                         const SizedBox(height: 14),
//                         _AlarmChip(
//                           label: 'MAX VOLTAGE',
//                           value: status.maxVol,
//                           color: const Color(0xFFEF5350),
//                           height: 104,
//                           valueFontSize: 32,
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               )
//             else
//               Column(
//                 children: [
//                   _AlarmInfoPanel(status: status),
//                   const SizedBox(height: 16),
//                   _AlarmChip(
//                     label: 'MIN VOLTAGE',
//                     value: status.minVol,
//                     color: Colors.white70,
//                     height: 100,
//                     valueFontSize: 30,
//                   ),
//                   const SizedBox(height: 12),
//                   _AlarmChip(
//                     label: 'MAX VOLTAGE',
//                     value: status.maxVol,
//                     color: const Color(0xFFEF5350),
//                     height: 100,
//                     valueFontSize: 30,
//                   ),
//                 ],
//               ),
//
//             const SizedBox(height: 24),
//             Row(
//               children: [
//                 Expanded(
//                   child: OutlinedButton.icon(
//                     onPressed: () async {
//                       Navigator.of(context).pop();
//
//                       await Future.delayed(const Duration(milliseconds: 200));
//
//                       if (!parentContext.mounted) return;
//
//                       showDialog(
//                         context: parentContext,
//                         barrierDismissible: true,
//                         builder: (_) =>
//                             VoltageChartDialog(api: api, facId: facId),
//                       );
//                     },
//                     icon: const Icon(
//                       Icons.bar_chart_rounded,
//                       color: Color(0xFFEF5350),
//                       size: 22,
//                     ),
//                     label: const Text(
//                       'XEM CHI TIẾT',
//                       style: TextStyle(
//                         color: Color(0xFFEF5350),
//                         fontWeight: FontWeight.w800,
//                         fontSize: 15,
//                         letterSpacing: 1.2,
//                       ),
//                     ),
//                     style: OutlinedButton.styleFrom(
//                       minimumSize: const Size.fromHeight(52),
//                       side: const BorderSide(
//                         color: Color(0xFFEF5350),
//                         width: 0.8,
//                       ),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: TextButton(
//                     onPressed: () => Navigator.of(context).pop(),
//                     style: TextButton.styleFrom(
//                       minimumSize: const Size.fromHeight(52),
//                       backgroundColor: const Color(
//                         0xFFEF5350,
//                       ).withOpacity(0.14),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                         side: const BorderSide(
//                           color: Color(0xFFEF5350),
//                           width: 0.6,
//                         ),
//                       ),
//                     ),
//                     child: const Text(
//                       'ĐÃ HIỂU',
//                       style: TextStyle(
//                         color: Color(0xFFEF5350),
//                         fontWeight: FontWeight.w800,
//                         fontSize: 15,
//                         letterSpacing: 1.2,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class _AlarmInfoPanel extends StatelessWidget {
//   final VoltageStatus status;
//
//   const _AlarmInfoPanel({required this.status});
//
//   String _formatDateTime(DateTime dt) {
//     return '${dt.day.toString().padLeft(2, '0')}/'
//         '${dt.month.toString().padLeft(2, '0')}/'
//         '${dt.year} '
//         '${dt.hour.toString().padLeft(2, '0')}:'
//         '${dt.minute.toString().padLeft(2, '0')}';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(18),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.04),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: Colors.white.withOpacity(0.08)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'THÔNG TIN CẢNH BÁO',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 14,
//               fontWeight: FontWeight.w800,
//               letterSpacing: 1.1,
//             ),
//           ),
//           const SizedBox(height: 14),
//           _InfoRow(
//             label: 'Nhà máy',
//             value: status.fac.isEmpty ? '-' : status.fac,
//           ),
//           const SizedBox(height: 10),
//           _InfoRow(
//             label: 'Box Device',
//             value: status.boxDeviceId.isEmpty ? '-' : status.boxDeviceId,
//           ),
//           const SizedBox(height: 10),
//           _InfoRow(
//             label: 'Thiết bị',
//             value: status.name.isEmpty ? 'Voltage' : status.name,
//           ),
//           const SizedBox(height: 10),
//           _InfoRow(
//             label: 'Trạng thái',
//             value: status.alarm,
//             valueColor: const Color(0xFFEF5350),
//           ),
//           const SizedBox(height: 10),
//           _InfoRow(
//             label: 'Thời gian',
//             value: _formatDateTime(status.timestamp),
//           ),
//           const SizedBox(height: 14),
//           Text(
//             'Khuyến nghị: kiểm tra nguồn cấp, dao động pha và tải liên quan trước khi tiếp tục vận hành kéo dài.',
//             style: TextStyle(
//               color: Colors.white.withOpacity(0.68),
//               fontSize: 13,
//               height: 1.45,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _InfoRow extends StatelessWidget {
//   final String label;
//   final String value;
//   final Color? valueColor;
//
//   const _InfoRow({required this.label, required this.value, this.valueColor});
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         SizedBox(
//           width: 86,
//           child: Text(
//             label,
//             style: TextStyle(
//               color: Colors.white.withOpacity(0.55),
//               fontSize: 12,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ),
//         Expanded(
//           child: Text(
//             value,
//             style: TextStyle(
//               color: valueColor ?? Colors.white,
//               fontSize: 13,
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// // =============================================================================
// // _AlarmChip
// // =============================================================================
// class _AlarmChip extends StatelessWidget {
//   final String label;
//   final double value;
//   final Color color;
//   final double height;
//   final double valueFontSize;
//
//   const _AlarmChip({
//     required this.label,
//     required this.value,
//     required this.color,
//     this.height = 96,
//     this.valueFontSize = 32,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: height,
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.08),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: color.withOpacity(0.28)),
//       ),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Text(
//             label,
//             style: const TextStyle(
//               color: Colors.white60,
//               fontSize: 13,
//               fontWeight: FontWeight.w600,
//               letterSpacing: 1.0,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             '${value.toStringAsFixed(0)} V',
//             style: TextStyle(
//               color: color,
//               fontSize: valueFontSize,
//               fontWeight: FontWeight.w800,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // =============================================================================
// // _VoltageChip
// // =============================================================================
//
// class _VoltageChip extends StatelessWidget {
//   final String label;
//   final double value;
//   final Color color;
//
//   const _VoltageChip({
//     required this.label,
//     required this.value,
//     required this.color,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return RichText(
//       text: TextSpan(
//         children: [
//           TextSpan(
//             text: '$label  ',
//             style: const TextStyle(
//               color: Colors.white70,
//               fontSize: 10,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           TextSpan(
//             text: '${value.toStringAsFixed(0)} V',
//             style: TextStyle(
//               color: color,
//               fontSize: 14,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
