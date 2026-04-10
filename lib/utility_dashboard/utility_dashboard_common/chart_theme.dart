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
  // ⚡ ELECTRICITY - Vibrant Amber/Orange
  // Modern energy vibe: warm, energetic, attention-grabbing
  static const ChartTheme power = ChartTheme(
    title: 'ELECTRICITY',
    unit: 'kWh',

    // Primary colors: warm amber/orange gradient
    line: Color(0xFFFFB400),
    // bright amber - main line
    fillTop: Color(0x4DFFB400),
    // 30% opacity for gradient top
    fillBottom: Color(0x00FFB400),
    // transparent for gradient bottom
    accent: Color(0xFFFFA500),
    // vibrant orange highlight

    // Cost tracking: green (constant across all)
    usdLine: Color(0xFF10B981),
    usdFillTop: Color(0x4D10B981),
    usdFillBottom: Color(0x0010B981),
  );

  // 💧 WATER - Aqua Blue (calm, clean, professional)
  // Water vibe: cool, refreshing, trust-inducing
  static const ChartTheme water = ChartTheme(
    title: 'WATER',
    unit: 'm³',

    line: Color(0xFF0369A1),
    // Deep ocean blue
    fillTop: Color(0x4D0369A1),
    // 30% opacity
    fillBottom: Color(0x000369A1),
    // Transparent
    accent: Color(0xFF0EA5E9),
    // Bright sky blue

    // Cost tracking: green
    usdLine: Color(0xFF10B981),
    usdFillTop: Color(0x4D10B981),
    usdFillBottom: Color(0x0010B981),
  );

  // 🌬 COMPRESSED AIR - Industrial Purple/Violet
  // Air vibe: professional, technical, innovative
  static const ChartTheme air = ChartTheme(
    title: 'COMPRESSED AIR',
    unit: 'Nm³',

    // Primary colors: deep purple to violet gradient
    line: Color(0xFFA78BFA),
    // soft violet - main line
    fillTop: Color(0x4DA78BFA),
    // 30% opacity
    fillBottom: Color(0x00A78BFA),
    // transparent bottom
    accent: Color(0xFFDDD6FE),
    // light violet highlight

    // Cost tracking: green
    usdLine: Color(0xFF10B981),
    usdFillTop: Color(0x4D10B981),
    usdFillBottom: Color(0x0010B981),
  );

  // 🔥 STEAM - Deep Red/Rose (warm, powerful)
  // (Optional: if you add STEAM later)
  static const ChartTheme steam = ChartTheme(
    title: 'STEAM',
    unit: 'kg/h',

    line: Color(0xFFF87171),
    // coral red
    fillTop: Color(0x4DF87171),
    fillBottom: Color(0x00F87171),
    accent: Color(0xFFFCA5A5),

    // light red highlight
    usdLine: Color(0xFF10B981),
    usdFillTop: Color(0x4D10B981),
    usdFillBottom: Color(0x0010B981),
  );

  // 🌡 TEMPERATURE - Warm Orange/Peach
  // (Optional: if you add TEMPERATURE later)
  static const ChartTheme temperature = ChartTheme(
    title: 'TEMPERATURE',
    unit: '°C',

    line: Color(0xFFFB923C),
    // warm orange
    fillTop: Color(0x4DFB923C),
    fillBottom: Color(0x00FB923C),
    accent: Color(0xFFFED7AA),

    // peach highlight
    usdLine: Color(0xFF10B981),
    usdFillTop: Color(0x4D10B981),
    usdFillBottom: Color(0x0010B981),
  );

  // ⚙ GAS - Teal/Turquoise (modern, stable)
  // (Optional: if you add GAS later)
  static const ChartTheme gas = ChartTheme(
    title: 'NATURAL GAS',
    unit: 'm³',

    line: Color(0xFF14B8A6),
    // teal
    fillTop: Color(0x4D14B8A6),
    fillBottom: Color(0x0014B8A6),
    accent: Color(0xFF5EEAD4),

    // light teal highlight
    usdLine: Color(0xFF10B981),
    usdFillTop: Color(0x4D10B981),
    usdFillBottom: Color(0x0010B981),
  );
}
