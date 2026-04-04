// import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_widgets/utility_facility_info_box_tree.dart';
// import 'package:flutter/material.dart';
//
// import '../../widgets/overview/factory_map_with_rain.dart';
// import '../ultility_dashboard_chart/utility_hourly_bar_panel.dart';
// import '../utility_dashboard_widgets/utility_category_compare_view.dart';
//
// class UtilityDashboardOverview extends StatelessWidget {
//   final String mainImageUrl;
//
//   const UtilityDashboardOverview({super.key, required this.mainImageUrl});
//
//   @override
//   Widget build(BuildContext context) {
//     return LayoutBuilder(
//       builder: (context, c) {
//         return Container(
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.35),
//                 spreadRadius: 2,
//                 blurRadius: 10,
//                 offset: const Offset(0, 5),
//               ),
//             ],
//           ),
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Expanded(
//                 child: Align(
//                   alignment: Alignment.topCenter,
//                   child: UtilityHourlyBarChartPanel(
//                     facId: 'KVH',
//                     boxDeviceId: 'DPB-L2-PANNEL_CB-80A',
//                     plcAddress: 'D30',
//                   ),
//                 ),
//               ),
//               Expanded(
//                 flex: 3,
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(16),
//                   child: Stack(
//                     children: [
//                       FactoryMapWithRain(mainImageUrl: mainImageUrl),
//
//                       // overlay gradient
//                       Container(
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             begin: Alignment.topCenter,
//                             end: Alignment.bottomCenter,
//                             colors: [
//                               Colors.black.withOpacity(0.1),
//                               Colors.transparent,
//                               Colors.black.withOpacity(0.15),
//                             ],
//                           ),
//                         ),
//                       ),
//
//                       /// ===== FAC A =====
//                       Align(
//                         alignment: const FractionalOffset(0.95, 0.04),
//                         // child: const UtilityFacilityInfoBox(
//                         //   facId: 'Fac_A',
//                         //   cateIds: ['E_TTL_KW', 'E_Cur1'],
//                         // ),
//                       ),
//
//                       /// ===== FAC B =====
//                       Align(
//                         alignment: const FractionalOffset(0.95, 0.7),
//                         // child: const UtilityFacilityInfoBox(
//                         //   facId: 'Fac_B',
//                         //   // boxDeviceId: '',
//                         //   cateIds: ['E_EneCon'],
//                         // ),
//                         child: UtilityFacilityInfoBoxTree(
//                           headerTitle: 'Fac B',
//                           facIds: ['Fac_B'],
//                           plcAddresses: ['D30', 'D24'],
//                           boxDeviceId: 'DPB-L2-PANNEL_CB-80A',
//                         ),
//                       ),
//
//                       /// ===== FAC C =====
//                       Align(
//                         alignment: const FractionalOffset(0.1, 0.04),
//                         // child: const UtilityFacilityInfoBox(
//                         //   facId: 'Fac_C',
//                         //   cateIds: ['E_TTL_KW', 'E_Cur1'],
//                         // ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               Expanded(child: UtilityCategoryCompareView()),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_common/chart_theme.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_daily/utility_dashboard_overview_daily_chart.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_hourly/utility_dashboard_overview_hourly_widgets/utility_dashboard_overview_hourly_compare.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_hourly/utility_dashboard_overview_hourly_widgets/utility_dashboard_overview_hourly_header.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_minutely/utility_dashboard_overview_minutes_chart.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/voltage_card.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_overview_monthly_box.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_widgets/monitoring_mascot.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_widgets/utility_dashboard_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'utility_dashboard_overview_widgets/factory_map_with_rain.dart';

class UtilityDashboardOverview extends StatefulWidget {
  final String mainImageUrl;

  const UtilityDashboardOverview({super.key, required this.mainImageUrl});

  @override
  State<UtilityDashboardOverview> createState() =>
      _UtilityDashboardOverviewState();
}

// class _UtilityDashboardOverviewState extends State<UtilityDashboardOverview> {
//   String selectedFac = 'KVH'; // KVH / Fac_A / Fac_B / Fac_C
//   DateTime selectedMonth = DateTime.now();
//   late AnimationController _alarmController;
//   late Animation<double> _blinkAnimation;
//
//   String toYYYYMM(DateTime d) =>
//       '${d.year}${d.month.toString().padLeft(2, '0')}';
//
//   // Helper function để check xem có highlight không
//   bool shouldHighlight(String facId) {
//     if (selectedFac == 'KVH') {
//       return true; // KVH = sáng tất cả
//     }
//     return selectedFac == facId; // Chỉ sáng khi match
//   }
//
//   final ValueNotifier<Map<String, VoltageStatus>> _activeVoltageAlarms =
//       ValueNotifier({});
//   bool _isVoltageAlarmDialogOpen = false;
//
//   void _handleVoltageAlarmChanged(String facId, VoltageStatus? status) {
//     final next = Map<String, VoltageStatus>.from(_activeVoltageAlarms.value);
//
//     if (status == null || !status.isAlarm) {
//       next.remove(facId);
//     } else {
//       next[facId] = status;
//     }
//
//     _activeVoltageAlarms.value = next;
//
//     if (next.isEmpty) {
//       _alarmController.stop();
//       _alarmController.reset();
//     } else {
//       _alarmController.repeat(reverse: true); // nhấp nháy
//     }
//   }
//
//   void _handleVoltageAlarmChanged1(String facId, VoltageStatus? status) {
//     final next = Map<String, VoltageStatus>.from(_activeVoltageAlarms.value);
//
//     if (status == null || !status.isAlarm) {
//       next.remove(facId);
//     } else {
//       next[facId] = status;
//     }
//
//     _activeVoltageAlarms.value = next;
//
//     if (next.isEmpty) {
//       if (_isVoltageAlarmDialogOpen && mounted) {
//         Navigator.of(context, rootNavigator: true).pop();
//         _isVoltageAlarmDialogOpen = false;
//       }
//       return;
//     }
//
//     if (_isVoltageAlarmDialogOpen) return;
//
//     _isVoltageAlarmDialogOpen = true;
//     final api = context.read<UtilityDashboardOverviewApi>();
//
//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       if (!mounted) return;
//
//       await showDialog(
//         context: context,
//         barrierDismissible: true,
//         builder: (_) => MultiVoltageAlarmDialog(
//           alarmsNotifier: _activeVoltageAlarms,
//           api: api,
//           parentContext: context,
//         ),
//       );
//
//       if (!mounted) return;
//       _isVoltageAlarmDialogOpen = false;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final nowStr = DateFormat('d/M/yyyy').format(DateTime.now());
//     final yStr = DateFormat(
//       'd/M/yyyy',
//     ).format(DateTime.now().subtract(const Duration(days: 1)));
//
//     final monthKey = toYYYYMM(selectedMonth);
//     return Column(
//       children: [
//         UtilityDashboardTopBar(
//           selectedFac: selectedFac,
//           selectedMonth: selectedMonth,
//           onFacChanged: (v) => setState(() => selectedFac = v),
//           onMonthChanged: (m) =>
//               setState(() => selectedMonth = DateTime(m.year, m.month, 1)),
//         ),
//         Expanded(
//           child: LayoutBuilder(
//             builder: (context, c) {
//               return Container(
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(16),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.35),
//                       spreadRadius: 2,
//                       blurRadius: 10,
//                       offset: const Offset(0, 5),
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   children: [
//                     // ====== TOP: Map + Category Compare ======
//                     Expanded(
//                       flex: 2,
//                       child: Row(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Column(
//                             children: [
//                               Container(
//                                 padding: EdgeInsets.all(1),
//                                 // decoration: BoxDecoration(color: Colors.white),
//                                 child: Text(
//                                   '[MINUTELY]',
//                                   style: TextStyle(
//                                     color: const Color(
//                                       0xFF5CFF7A,
//                                     ).withOpacity(0.9),
//                                     fontSize: 13,
//                                     fontWeight: FontWeight.w900,
//                                     letterSpacing: 0.5,
//                                   ),
//                                 ),
//                               ),
//                               Expanded(
//                                 child: UtilityDashboardOverviewMinutesChart(
//                                   facId: selectedFac,
//                                   theme: ChartThemes.power,
//                                 ),
//                               ),
//                               Expanded(
//                                 child: UtilityDashboardOverviewMinutesChart(
//                                   facId: selectedFac,
//                                   theme: ChartThemes.water,
//                                   nameEng: 'Test',
//                                 ),
//                               ),
//                               Expanded(
//                                 child: UtilityDashboardOverviewMinutesChart(
//                                   facId: selectedFac,
//                                   theme: ChartThemes.air,
//                                   nameEng: 'Test',
//                                 ),
//                               ),
//                             ],
//                           ),
//
//                           // Map
//                           Expanded(
//                             flex: 2,
//                             child: ClipRRect(
//                               borderRadius: BorderRadius.circular(16),
//                               child: Stack(
//                                 children: [
//                                   FactoryMapWithRain(
//                                     mainImageUrl: widget.mainImageUrl,
//                                   ),
//
//                                   // overlay gradient
//                                   Container(
//                                     decoration: BoxDecoration(
//                                       gradient: LinearGradient(
//                                         begin: Alignment.topCenter,
//                                         end: Alignment.bottomCenter,
//                                         colors: [
//                                           Colors.black.withOpacity(0.1),
//                                           Colors.transparent,
//                                           Colors.black.withOpacity(0.15),
//                                         ],
//                                       ),
//                                     ),
//                                   ),
//
//                                   /// ===== FAC B =====
//                                   Align(
//                                     alignment: const FractionalOffset(
//                                       0.95,
//                                       0.9,
//                                     ),
//                                     child: UtilityOverviewMonthlyBox(
//                                       facId: 'Fac_B',
//                                       month: monthKey,
//                                       headerTitle: 'Fac B',
//                                       isHighlighted: shouldHighlight('Fac_B'),
//                                       onVoltageAlarmChanged:
//                                           _handleVoltageAlarmChanged,
//                                     ),
//                                   ),
//
//                                   /// ===== FAC A =====
//                                   Align(
//                                     alignment: const FractionalOffset(
//                                       0.95,
//                                       0.02,
//                                     ),
//                                     child: UtilityOverviewMonthlyBox(
//                                       facId: 'Fac_A',
//                                       month: monthKey,
//                                       headerTitle: 'Fac A',
//                                       isHighlighted: shouldHighlight('Fac_A'),
//                                       onVoltageAlarmChanged:
//                                           _handleVoltageAlarmChanged,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//
//                           // Category Compare (phải)
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.stretch,
//                               children: [
//                                 UtilityDashboardOverviewHourlyHeader(
//                                   title: '[HOURLY COMPARE]',
//                                   subtitle: 'Today: $nowStr  •  Prev: $yStr',
//                                 ),
//                                 Expanded(
//                                   child: UtilityDashboardOverviewHourlyCompare(
//                                     facId: selectedFac,
//                                     theme: ChartThemes.power,
//                                   ),
//                                 ),
//                                 Expanded(
//                                   child: UtilityDashboardOverviewHourlyCompare(
//                                     facId: selectedFac,
//                                     theme: ChartThemes.water,
//                                     nameEng: 'Test',
//                                   ),
//                                 ),
//                                 Expanded(
//                                   child: UtilityDashboardOverviewHourlyCompare(
//                                     facId: selectedFac,
//                                     theme: ChartThemes.air,
//                                     nameEng: 'Test',
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//
//                     // ====== BOTTOM: Bar Chart ======
//                     Expanded(
//                       child: Column(
//                         children: [
//                           Container(
//                             padding: EdgeInsets.all(1),
//                             // decoration: BoxDecoration(color: Colors.white),
//                             child: Text(
//                               '[DAILY]',
//                               style: TextStyle(
//                                 color: const Color(0xFF5CFF7A).withOpacity(0.9),
//                                 fontSize: 13,
//                                 fontWeight: FontWeight.w900,
//                                 letterSpacing: 0.5,
//                               ),
//                             ),
//                           ),
//                           Expanded(
//                             flex: 1,
//                             child: Row(
//                               children: [
//                                 Expanded(
//                                   child: UtilityDashboardOverviewDailyChart(
//                                     facId: selectedFac,
//                                     month: monthKey,
//                                     height: 320,
//                                     theme: ChartThemes.power,
//                                   ),
//                                 ),
//                                 Expanded(
//                                   child: UtilityDashboardOverviewDailyChart(
//                                     facId: selectedFac,
//                                     month: monthKey,
//                                     height: 320,
//                                     theme: ChartThemes.water,
//                                     nameEng: 'TEST',
//                                   ),
//                                 ),
//                                 Expanded(
//                                   child: UtilityDashboardOverviewDailyChart(
//                                     facId: selectedFac,
//                                     month: monthKey,
//                                     height: 320,
//                                     theme: ChartThemes.air,
//                                     nameEng: 'TEST',
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }
// }

class _UtilityDashboardOverviewState extends State<UtilityDashboardOverview>
    with SingleTickerProviderStateMixin {
  String selectedFac = 'KVH';
  DateTime selectedMonth = DateTime.now();

  late AnimationController _alarmController;
  late Animation<double> _blinkAnimation;

  final ValueNotifier<Map<String, VoltageStatus>> _activeVoltageAlarms =
      ValueNotifier({});

  @override
  void initState() {
    super.initState();

    _alarmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250), // nhanh hơn
    );

    _blinkAnimation =
        Tween<double>(
          begin: 0.15,
          end: 0.9, // đậm hơn nhiều
        ).animate(
          CurvedAnimation(parent: _alarmController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _alarmController.dispose();
    super.dispose();
  }

  String toYYYYMM(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}';

  bool shouldHighlight(String facId) {
    if (selectedFac == 'KVH') return true;
    return selectedFac == facId;
  }

  // 🔥 HANDLE ALARM (NO POPUP)
  void _handleVoltageAlarmChanged(String facId, VoltageStatus? status) {
    final next = Map<String, VoltageStatus>.from(_activeVoltageAlarms.value);

    if (status == null || !status.isAlarm) {
      next.remove(facId);
    } else {
      next[facId] = status;
    }

    _activeVoltageAlarms.value = next;

    if (next.isEmpty) {
      _alarmController.stop();
      _alarmController.reset();
    } else {
      _alarmController.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nowStr = DateFormat('d/M/yyyy').format(DateTime.now());
    final yStr = DateFormat(
      'd/M/yyyy',
    ).format(DateTime.now().subtract(const Duration(days: 1)));

    final monthKey = toYYYYMM(selectedMonth);

    const Map<String, Alignment> facPositions = {
      'Fac_A': Alignment(0.3, -0.70),
      'Fac_B': Alignment(0.3, 0.72),
      'idle': Alignment(-0.60, 0.9),
    };

    return ValueListenableBuilder<Map<String, VoltageStatus>>(
      valueListenable: _activeVoltageAlarms,
      builder: (context, alarms, _) {
        String targetFacId;

        if (alarms.containsKey(selectedFac)) {
          targetFacId = selectedFac;
        } else if (alarms.isNotEmpty) {
          targetFacId = alarms.keys.first;
        } else {
          targetFacId = 'idle';
        }
        final hasAlarm = alarms.isNotEmpty;
        return AnimatedBuilder(
          animation: _blinkAnimation,
          builder: (context, child) {
            // final hasAlarm =
            //     _activeVoltageAlarms.value.isNotEmpty; // ✅ thêm dòng này

            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: hasAlarm
                        ? Colors.red.withOpacity(_blinkAnimation.value)
                        : Colors.transparent,
                  ),
                  child: child,
                ),
              ],
            );
          },

          child: Column(
            children: [
              UtilityDashboardTopBar(
                selectedFac: selectedFac,
                selectedMonth: selectedMonth,
                onFacChanged: (v) => setState(() => selectedFac = v),
                onMonthChanged: (m) => setState(
                  () => selectedMonth = DateTime(m.year, m.month, 1),
                ),
                hasAlarm: hasAlarm,
                blinkAnimation: _blinkAnimation, // 🔥 thêm luôn animation
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),

                      child: Column(
                        children: [
                          /// ===== TOP =====
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                /// LEFT CHART
                                Column(
                                  children: [
                                    _title('[MINUTELY]'),

                                    Expanded(
                                      child:
                                          UtilityDashboardOverviewMinutesChart(
                                            facId: selectedFac,
                                            theme: ChartThemes.power,
                                          ),
                                    ),
                                    Expanded(
                                      child:
                                          UtilityDashboardOverviewMinutesChart(
                                            facId: selectedFac,
                                            theme: ChartThemes.water,
                                            nameEng: 'test',
                                          ),
                                    ),
                                    Expanded(
                                      child:
                                          UtilityDashboardOverviewMinutesChart(
                                            facId: selectedFac,
                                            theme: ChartThemes.air,
                                            nameEng: 'test',
                                          ),
                                    ),
                                  ],
                                ),

                                /// MAP
                                Expanded(
                                  flex: 2,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        FactoryMapWithRain(
                                          mainImageUrl: widget.mainImageUrl,
                                        ),

                                        /// overlay
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.black.withOpacity(0.1),
                                                Colors.transparent,
                                                Colors.black.withOpacity(0.15),
                                              ],
                                            ),
                                          ),
                                        ),

                                        MovingMascot(
                                          alarmCount: alarms.length,
                                          size: 180,
                                          targetAlignment:
                                              facPositions[targetFacId] ??
                                              const Alignment(-0.60, 0.80),
                                          idleAlignment: facPositions['idle']!,
                                        ),

                                        /// FAC B
                                        Align(
                                          alignment: const FractionalOffset(
                                            0.99,
                                            0.9,
                                          ),
                                          child: UtilityOverviewMonthlyBox(
                                            facId: 'Fac_B',
                                            month: monthKey,
                                            headerTitle: 'Fac B',
                                            isHighlighted: shouldHighlight(
                                              'Fac_B',
                                            ),
                                            onVoltageAlarmChanged:
                                                _handleVoltageAlarmChanged,
                                          ),
                                        ),

                                        /// FAC A
                                        Align(
                                          alignment: const FractionalOffset(
                                            0.99,
                                            0.02,
                                          ),
                                          child: UtilityOverviewMonthlyBox(
                                            facId: 'Fac_A',
                                            month: monthKey,
                                            headerTitle: 'Fac A',
                                            isHighlighted: shouldHighlight(
                                              'Fac_A',
                                            ),
                                            onVoltageAlarmChanged:
                                                _handleVoltageAlarmChanged,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                /// RIGHT PANEL
                                Expanded(
                                  child: Column(
                                    children: [
                                      UtilityDashboardOverviewHourlyHeader(
                                        title: '[HOURLY COMPARE]',
                                        subtitle:
                                            'Today: $nowStr  •  Prev: $yStr',
                                      ),

                                      Expanded(
                                        child:
                                            UtilityDashboardOverviewHourlyCompare(
                                              facId: selectedFac,
                                              theme: ChartThemes.power,
                                            ),
                                      ),
                                      Expanded(
                                        child:
                                            UtilityDashboardOverviewHourlyCompare(
                                              facId: selectedFac,
                                              theme: ChartThemes.water,
                                              nameEng: 'test',
                                            ),
                                      ),
                                      Expanded(
                                        child:
                                            UtilityDashboardOverviewHourlyCompare(
                                              facId: selectedFac,
                                              theme: ChartThemes.air,
                                              nameEng: 'test',
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          /// ===== BOTTOM =====
                          Expanded(
                            child: Column(
                              children: [
                                _title('[DAILY]'),

                                Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child:
                                            UtilityDashboardOverviewDailyChart(
                                              facId: selectedFac,
                                              month: monthKey,
                                              theme: ChartThemes.power,
                                            ),
                                      ),
                                      Expanded(
                                        child:
                                            UtilityDashboardOverviewDailyChart(
                                              facId: selectedFac,
                                              month: monthKey,
                                              theme: ChartThemes.water,
                                              nameEng: 'test',
                                            ),
                                      ),
                                      Expanded(
                                        child:
                                            UtilityDashboardOverviewDailyChart(
                                              facId: selectedFac,
                                              month: monthKey,
                                              theme: ChartThemes.air,
                                              nameEng: 'test',
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _title(String text) {
    return Container(
      padding: const EdgeInsets.all(1),
      child: Text(
        text,
        style: TextStyle(
          color: const Color(0xFF5CFF7A).withOpacity(0.9),
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
