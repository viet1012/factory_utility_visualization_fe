import 'package:flutter/material.dart';

class ChartTheme {
  final String title;
  final Color line;
  final Color fillTop;
  final Color fillBottom;
  final Color accent;

  const ChartTheme({
    required this.title,
    required this.line,
    required this.fillTop,
    required this.fillBottom,
    required this.accent,
  });
}

class ChartThemes {
  static const power = ChartTheme(
    title: 'ELECTRICITY',
    line: Color(0xFFFFB300),
    fillTop: Color(0x66FFB300),
    fillBottom: Color(0x00FFB300),
    accent: Color(0xFFFFA000),
  );
  static const water = ChartTheme(
    title: 'WATER',
    line: Color(0xFF52D6FF),
    // xanh nước
    fillTop: Color(0x6652D6FF),
    fillBottom: Color(0x0052D6FF),
    accent: Color(0xFF52D6FF),
  );

  static const air = ChartTheme(
    title: 'AIR COMPRESSER',
    line: Color(0xFF6CFF6C),
    // xanh lá
    fillTop: Color(0x666CFF6C),
    fillBottom: Color(0x006CFF6C),
    accent: Color(0xFF6CFF6C),
  );
}
