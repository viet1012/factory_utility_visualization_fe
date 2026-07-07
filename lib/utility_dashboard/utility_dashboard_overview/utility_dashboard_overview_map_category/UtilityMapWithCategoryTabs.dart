import 'dart:ui';

import 'package:flutter/material.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/voltage_card.dart';
import '../utility_dashboard_overview_monthly/utility_overview_monthly_box.dart';
import '../utility_dashboard_overview_widgets/factory_map_with_rain.dart';
import '../utility_dashboard_overview_widgets/monitoring_mascot.dart';

enum UtilityMapCate { electricity, water, air }

extension UtilityMapCateExt on UtilityMapCate {
  String get label {
    switch (this) {
      case UtilityMapCate.electricity:
        return 'ELECTRICAL';
      case UtilityMapCate.water:
        return 'WATER';
      case UtilityMapCate.air:
        return 'AIR';
    }
  }

  String get filterCate {
    switch (this) {
      case UtilityMapCate.electricity:
        return 'ELECTRICITY';
      case UtilityMapCate.water:
        return 'WATER';
      case UtilityMapCate.air:
        return 'AIR';
    }
  }

  ChartTheme get theme {
    switch (this) {
      case UtilityMapCate.electricity:
        return ChartThemes.power;
      case UtilityMapCate.water:
        return ChartThemes.water;
      case UtilityMapCate.air:
        return ChartThemes.air;
    }
  }
}

class UtilityMapWithCategoryTabs extends StatefulWidget {
  final String mainImageUrl;
  final String monthKey;
  final Map<String, VoltageStatus> alarms;
  final String targetFacId;
  final Map<String, Alignment> facPositions;
  final bool Function(String facId) shouldHighlight;
  final void Function(String facId, VoltageStatus? status)
  onVoltageAlarmChanged;

  const UtilityMapWithCategoryTabs({
    super.key,
    required this.mainImageUrl,
    required this.monthKey,
    required this.alarms,
    required this.targetFacId,
    required this.facPositions,
    required this.shouldHighlight,
    required this.onVoltageAlarmChanged,
  });

  @override
  State<UtilityMapWithCategoryTabs> createState() =>
      _UtilityMapWithCategoryTabsState();
}

class _UtilityMapWithCategoryTabsState
    extends State<UtilityMapWithCategoryTabs> {
  UtilityMapCate selected = UtilityMapCate.electricity;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FactoryMapWithRain(mainImageUrl: widget.mainImageUrl),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.10),
                  Colors.transparent,
                  Colors.black.withOpacity(0.15),
                ],
              ),
            ),
          ),

          MovingMascot(
            alarmCount: widget.alarms.length,
            size: 180,
            targetAlignment:
                widget.facPositions[widget.targetFacId] ??
                const Alignment(-0.60, 0.80),
            idleAlignment: widget.facPositions['idle']!,
          ),

          Align(
            alignment: const FractionalOffset(0.99, 0.9),
            child: _facBox('Fac_B', 'Fac B'),
          ),

          Align(
            alignment: const FractionalOffset(0.99, 0.02),
            child: _facBox('Fac_A', 'Fac A'),
          ),

          Align(
            alignment: const FractionalOffset(0.05, 0.02),
            child: _facBox('Fac_C', 'Fac C'),
          ),

          Align(alignment: Alignment.bottomCenter, child: _bottomTabs()),
        ],
      ),
    );
  }

  Widget _facBox(String facId, String title) {
    return UtilityOverviewMonthlyBox(
      facId: facId,
      month: widget.monthKey,
      headerTitle: title,
      filterCate: selected.filterCate,
      height: 145,
      isHighlighted: widget.shouldHighlight(facId),
      onVoltageAlarmChanged: widget.onVoltageAlarmChanged,
    );
  }

  Widget _bottomTabs() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(.12),
                  Colors.white.withOpacity(.04),
                ],
              ),
              border: Border.all(color: Colors.white.withOpacity(.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.28),
                  blurRadius: 22,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: UtilityMapCate.values.map((cate) {
                final active = selected == cate;
                final theme = cate.theme;
                final color = theme.iconColor;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => selected = cate),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? color.withOpacity(.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: active
                              ? color.withOpacity(.50)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            theme.icon,
                            size: 13,
                            color: active ? color : Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            cate.label,
                            style: TextStyle(
                              color: active ? Colors.white : Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
