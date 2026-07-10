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
        return 'ELECTRICITY';
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
  final String nightImageUrl;

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
    required this.nightImageUrl,
  });

  @override
  State<UtilityMapWithCategoryTabs> createState() =>
      _UtilityMapWithCategoryTabsState();
}

class _UtilityMapWithCategoryTabsState extends State<UtilityMapWithCategoryTabs>
    with TickerProviderStateMixin {
  UtilityMapCate selected = UtilityMapCate.electricity;

  late final AnimationController _progressCtrl;
  late final AnimationController _hourglassCtrl;

  static const int _autoSeconds = 20;

  @override
  void initState() {
    super.initState();

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _autoSeconds),
    );

    _hourglassCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _progressCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _goNextTab();
      }
    });

    _startProgress();
  }

  void _startProgress() {
    _progressCtrl.forward(from: 0);
  }

  void _goNextTab() {
    final list = UtilityMapCate.values;
    final nextIndex = (list.indexOf(selected) + 1) % list.length;
    _changeTab(list[nextIndex], resetProgress: true);
  }

  void _changeTab(UtilityMapCate cate, {bool resetProgress = true}) {
    if (selected == cate) return;

    _hourglassCtrl.forward(from: 0);

    setState(() {
      selected = cate;
    });

    if (resetProgress) {
      _progressCtrl.forward(from: 0);
    }
  }

  int get _remainSeconds {
    final remain = _autoSeconds - (_progressCtrl.value * _autoSeconds).floor();
    return remain.clamp(0, _autoSeconds);
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _hourglassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FactoryMapWithRain(
            mainImageUrl: widget.mainImageUrl,
            nightImageUrl: widget.nightImageUrl,
          ),

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
                const Alignment(-0.4, 0.3),
            idleAlignment: widget.facPositions['idle']!,
          ),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 650),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final offset = Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(animation);

              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: offset,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: .96, end: 1).animate(animation),
                    child: child,
                  ),
                ),
              );
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Align(
                //   alignment: const FractionalOffset(0.99, 0.9),
                //   child: _facBox('Fac_B', 'Fac B'),
                // ),
                // Align(
                //   alignment: const FractionalOffset(0.99, 0.02),
                //   child: _facBox('Fac_A', 'Fac A'),
                // ),
                // Align(
                //   alignment: const FractionalOffset(0.05, 0.02),
                //   child: _facBox('Fac_C', 'Fac C'),
                // ),
                Align(
                  alignment: const FractionalOffset(0.03, 0.1),
                  child: _facBox('Fac_B', 'Fac B'),
                ),
                Align(
                  alignment: const FractionalOffset(0.03, 0.68),
                  child: _facBox('Fac_A', 'Fac A'),
                ),
                Align(
                  alignment: const FractionalOffset(0.99, 0.3),
                  child: _facBox('Fac_C', 'Fac C'),
                ),
              ],
            ),
          ),

          Center(child: _hourglassEffect()),

          Align(alignment: Alignment.bottomCenter, child: _bottomTabs()),
        ],
      ),
    );
  }

  Widget _hourglassEffect() {
    final color = selected.theme.iconColor;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _hourglassCtrl,
        builder: (_, __) {
          final v = _hourglassCtrl.value;
          final opacity = v < .5 ? v * 2 : (1 - v) * 2;

          return Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform.rotate(
              angle: v * 3.14159,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(.42),
                  border: Border.all(color: color.withOpacity(.7)),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(.38),
                      blurRadius: 32,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.hourglass_bottom_rounded,
                  color: color,
                  size: 31,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _facBox(String facId, String title) {
    return UtilityOverviewMonthlyBox(
      key: ValueKey('monthly_box_$facId'),
      facId: facId,
      month: widget.monthKey,
      headerTitle: title,
      filterCate: selected.filterCate,
      height: 130,
      isHighlighted: widget.shouldHighlight(facId),
      onVoltageAlarmChanged: widget.onVoltageAlarmChanged,
    );
  }

  Widget _bottomTabs() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(.13),
                  Colors.white.withOpacity(.045),
                ],
              ),
              border: Border.all(color: Colors.white.withOpacity(.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.30),
                  blurRadius: 24,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _progressCtrl,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: UtilityMapCate.values.map((cate) {
                    final active = selected == cate;
                    final theme = cate.theme;
                    final color = theme.iconColor;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _changeTab(cate),
                        child: Stack(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? color.withOpacity(.18)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: active
                                      ? color.withOpacity(.55)
                                      : Colors.transparent,
                                ),
                                boxShadow: active
                                    ? [
                                        BoxShadow(
                                          color: color.withOpacity(.30),
                                          blurRadius: 15,
                                          spreadRadius: -2,
                                        ),
                                      ]
                                    : null,
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
                                      color: active
                                          ? Colors.white
                                          : Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: .2,
                                    ),
                                  ),

                                  if (active) ...[
                                    const SizedBox(width: 7),
                                    RotationTransition(
                                      turns: _progressCtrl,
                                      child: Icon(
                                        Icons.hourglass_bottom_rounded,
                                        size: 13,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_remainSeconds}s',
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            if (active)
                              Positioned(
                                left: 8,
                                right: 8,
                                bottom: 3,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    height: 2,
                                    color: Colors.white.withOpacity(.12),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor: _progressCtrl.value,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: color,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: color.withOpacity(.65),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
