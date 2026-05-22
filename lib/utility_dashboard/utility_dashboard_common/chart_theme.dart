import 'package:flutter/material.dart';

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
  });
}

class ChartThemes {
  // =========================
  // CATEGORY HELPERS
  // =========================

  static String cateKey(String? cate) {
    final raw = (cate ?? '').toLowerCase().trim();

    if (raw == 'electricity' || raw == 'power') return 'power';

    if (raw == 'compressed air' || raw == 'compressor_air' || raw == 'air') {
      return 'air';
    }

    if (raw == 'water') return 'water';
    if (raw == 'gas') return 'gas';
    if (raw == 'steam') return 'steam';

    return raw;
  }

  static IconData cateIcon(String? cate) {
    switch (cateKey(cate)) {
      case 'water':
        return Icons.water_drop_rounded;

      case 'air':
        return Icons.air_rounded;

      case 'gas':
        return Icons.local_fire_department_rounded;

      case 'steam':
        return Icons.cloud_rounded;

      case 'power':
        return Icons.bolt_rounded;

      default:
        return Icons.sensors_rounded;
    }
  }

  static Color cateIconColor(String? cate, ChartTheme theme) {
    switch (cateKey(cate)) {
      case 'water':
        return const Color(0xFF7DD3FC);

      case 'air':
        return const Color(0xFFBAE6FD);

      case 'gas':
        return const Color(0xFFFFB74D);

      case 'steam':
        return const Color(0xFFD1D5DB);

      default:
        return theme.line;
    }
  }

  // =========================
  // THEME RESOLVER
  // =========================

  static ChartTheme getThemeByCate(String? cate) {
    switch (cateKey(cate)) {
      case 'power':
        return power;

      case 'water':
        return water;

      case 'air':
        return air;

      case 'steam':
        return steam;

      default:
        return power;
    }
  }

  // =========================
  // THEMES
  // =========================

  // ⚡ ELECTRICITY
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
  );

  // 💧 WATER
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
  );

  // 🌬 AIR
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
  );

  // 🔥 STEAM
  static const ChartTheme steam = ChartTheme(
    title: 'STEAM',
    unit: 'kg/h',
    line: Color(0xFFF87171),
    fillTop: Color(0x4DF87171),
    fillBottom: Color(0x00F87171),
    accent: Color(0xFFFCA5A5),
    usdLine: Color(0xFF10B981),
    usdFillTop: Color(0x4D10B981),
    usdFillBottom: Color(0x0010B981),
  );

  // 🌡 TEMPERATURE
  static const ChartTheme temperature = ChartTheme(
    title: 'TEMPERATURE',
    unit: '°C',
    line: Color(0xFFFB923C),
    fillTop: Color(0x4DFB923C),
    fillBottom: Color(0x00FB923C),
    accent: Color(0xFFFED7AA),
    usdLine: Color(0xFF10B981),
    usdFillTop: Color(0x4D10B981),
    usdFillBottom: Color(0x0010B981),
  );
}
