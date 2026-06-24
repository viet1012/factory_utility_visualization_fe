import 'package:flutter/material.dart';

import '../utility_dashboard_fac_details/models/group_frame_types.dart';

enum UtilityType { power, water, air }

class ChartTheme {
  final String title;
  final String unit;

  final Color line;
  final Color fillTop;
  final Color fillBottom;
  final Color accent;

  final Color usdLine;
  final Color usdFillTop;
  final Color usdFillBottom;

  final IconData icon;
  final Color iconColor;
  final GroupFrameEffect effect;

  const ChartTheme({
    required this.title,
    required this.unit,
    required this.line,
    required this.fillTop,
    required this.fillBottom,
    required this.accent,
    required this.usdLine,
    required this.usdFillTop,
    required this.usdFillBottom,
    required this.icon,
    required this.iconColor,
    required this.effect,
  });
}

class ChartThemes {
  static UtilityType typeOf(String? value) {
    final raw = (value ?? '').toLowerCase().trim();

    if (raw.contains('electric')) {
      return UtilityType.power;
    }

    if (raw.contains('water')) {
      return UtilityType.water;
    }

    if (raw.contains('air')) {
      return UtilityType.air;
    }

    return UtilityType.power;
  }

  static ChartTheme byType(UtilityType type) {
    switch (type) {
      case UtilityType.power:
        return power;
      case UtilityType.water:
        return water;
      case UtilityType.air:
        return air;
    }
  }

  static ChartTheme byCate(String? cate) {
    return byType(typeOf(cate));
  }

  static Color colorFromFac(String? facName) {
    switch ((facName ?? '').trim()) {
      case 'Fac_A':
        return const Color(0xFF4FC3F7);
      case 'Fac_B':
        return const Color(0xFF42A5F5);
      case 'Fac_C':
        return const Color(0xFF4FC3F7);
      default:
        return const Color(0xFF4FC3F7);
    }
  }

  static const ChartTheme power = ChartTheme(
    title: 'ELECTRICITY',
    unit: 'kWh',
    line: Color(0xFFFFB400),
    fillTop: Color(0x4DFFB400),
    fillBottom: Color(0x00FFB400),
    accent: Color(0xFFFFA500),
    usdLine: Color(0xFF10B981),
    usdFillTop: Color(0x4D10B981),
    usdFillBottom: Color(0x0010B981),
    icon: Icons.bolt_rounded,
    iconColor: Color(0xFFFFC107),
    effect: GroupFrameEffect.electric,
  );

  static const ChartTheme water = ChartTheme(
    title: 'WATER',
    unit: 'm³',
    line: Color(0xFF0369A1),
    fillTop: Color(0x4D0369A1),
    fillBottom: Color(0x000369A1),
    accent: Color(0xFF0EA5E9),
    usdLine: Color(0xFF10B981),
    usdFillTop: Color(0x4D10B981),
    usdFillBottom: Color(0x0010B981),
    icon: Icons.water_drop_rounded,
    iconColor: Color(0xFF38BDF8),
    effect: GroupFrameEffect.water,
  );

  static const ChartTheme air = ChartTheme(
    title: 'COMPRESSED AIR',
    unit: 'Nm³',
    line: Color(0xFFA78BFA),
    fillTop: Color(0x4DA78BFA),
    fillBottom: Color(0x00A78BFA),
    accent: Color(0xFFDDD6FE),
    usdLine: Color(0xFF10B981),
    usdFillTop: Color(0x4D10B981),
    usdFillBottom: Color(0x0010B981),
    icon: Icons.air_rounded,
    iconColor: Color(0xFFC084FC),
    effect: GroupFrameEffect.air,
  );
}

class ChartThemeResolver {
  static ChartTheme theme(String? cate) {
    return ChartThemes.byCate(cate);
  }

  static IconData icon(String? cate) {
    return theme(cate).icon;
  }

  static Color iconColor(String? cate) {
    return theme(cate).iconColor;
  }

  static GroupFrameEffect effect(String? cate) {
    return theme(cate).effect;
  }
}
