import 'package:flutter/material.dart';

class ChartTheme {
  final String title;
  final String unit;

  final Color line;
  final Color fillTop;
  final Color fillBottom;
  final Color accent;

  const ChartTheme({
    required this.title,
    required this.unit,
    required this.line,
    required this.fillTop,
    required this.fillBottom,
    required this.accent,
  });
}

class ChartThemes {
  static const power = ChartTheme(
    title: 'ELECTRICITY',
    unit: 'kWh',
    // 👈 thêm
    line: Color(0xFFFFB300),
    fillTop: Color(0x66FFB300),
    fillBottom: Color(0x00FFB300),
    accent: Color(0xFFFFA000),
  );

  static const water = ChartTheme(
    title: 'WATER',
    unit: 'm³',
    line: Color(0xFF9E9E9E),
    // xám chính
    fillTop: Color(0x669E9E9E),
    // xám nhạt (opacity)
    fillBottom: Color(0x009E9E9E),
    // fade xuống
    accent: Color(0xFFBDBDBD), // xám sáng highlight
  );

  static const air = ChartTheme(
    title: 'AIR COMPRESSER',
    unit: 'Nm³',
    // 👈 thêm (chuẩn công nghiệp)
    line: Color(0xFF9E9E9E),
    // xám chính
    fillTop: Color(0x669E9E9E),
    // xám nhạt (opacity)
    fillBottom: Color(0x009E9E9E),
    // fade xuống
    accent: Color(0xFFBDBDBD), // xám sáng highlight
  );

  // static const water = ChartTheme(
  //   title: 'WATER',
  //   unit: 'm³',
  //   // 👈 thêm
  //   line: Color(0xFF52D6FF),
  //   fillTop: Color(0x6652D6FF),
  //   fillBottom: Color(0x0052D6FF),
  //   accent: Color(0xFF52D6FF),
  // );
  //
  // static const air = ChartTheme(
  //   title: 'AIR COMPRESSER',
  //   unit: 'Nm³',
  //   // 👈 thêm (chuẩn công nghiệp)
  //   line: Color(0xFF6CFF6C),
  //   fillTop: Color(0x666CFF6C),
  //   fillBottom: Color(0x006CFF6C),
  //   accent: Color(0xFF6CFF6C),
  // );
}
