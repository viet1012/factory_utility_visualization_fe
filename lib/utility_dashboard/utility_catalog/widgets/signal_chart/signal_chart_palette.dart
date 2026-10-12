import 'package:flutter/material.dart';

import '../../../utility_dashboard_common/chart_theme.dart';

/// Bang mau cua che do Chart, khai bao mot lan de cac widget con khong tu
/// dinh nghia lai. Gia tri lay dung tu cac mau dang dung trong panel chi tiet
/// va bang signal (catalog_signal_detail.dart), line chart dung ChartThemes.
abstract final class SignalChartColors {
  static const Color card = Color(0xFF0B1728);
  static const Color cardBorder = Color(0xFF20344D);
  static const Color chipIdle = Color(0xFF0C1A2A);
  static const Color chipSelected = Color(0xFF155E75);

  static const Color text = Colors.white;
  static const Color subText = Color(0xFF9AAEC5);
  static const Color mutedText = Color(0xFF6F859F);

  static const Color online = Color(0xFF4ADE80);
  static const Color stale = Colors.orangeAccent;
  static const Color alert = Colors.redAccent;

  static const Color status = Color(0xFF60A5FA);

  /// Progress bar manh khi doi range (cung tone accent cua tree / device list).
  static const Color progress = Color(0xFF22D3EE);

  static Color get gridLine => Colors.white.withValues(alpha: .07);
  static Color get axisLine => Colors.white.withValues(alpha: .14);

  /// Cham avg tren thanh noi min–max (24h / 7d).
  static const Color avgDot = Colors.white;

  /// Duong nguong net dut + nhan cua no.
  static const Color thresholdLine = Color(0xFFFCA5A5);

  /// Nen khoang mat du lieu.
  static Color get gapZone => const Color(0xFF94A3B8).withValues(alpha: .10);

  static Color get skeleton => Colors.white.withValues(alpha: .05);
  static Color get skeletonHighlight => Colors.white.withValues(alpha: .10);

  /// Mau badge PLC theo category, giong cot PLC cua bang.
  static Color category(String category) {
    final value = category.trim().toUpperCase();

    if (value.contains('ELECTRIC')) return const Color(0xFFFBBF24);
    if (value.contains('WATER')) return const Color(0xFF22D3EE);
    if (value.contains('AIR') || value.contains('COMPRESSED')) {
      return const Color(0xFFA78BFA);
    }

    return const Color(0xFF94A3B8);
  }

  /// Mau duong analog theo theme chart hien co cua app.
  static Color line(String rawCategory) {
    return ChartThemes.byCate(rawCategory).line;
  }
}
