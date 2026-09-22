import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/formatters/month_formatter.dart';

/// Bang mau dung chung cho cac panel cua Solar Detail.
///
/// Giu nguyen gia tri mau cu cua SolarDetailScreen.
abstract final class SolarDetailColors {
  static const Color bg = Color(0xff020b15);

  static const Color panel = Color(0xff071d30);

  static const Color cyan = Color(0xff22d3ee);

  static const Color yellow = Color(0xffffb800);

  static const Color green = Color(0xff63f06d);

  static const Color border = Color(0xff17415d);
}

/// Cac ham format dung chung cho nhieu panel cua Solar Detail.
///
/// Chi la ham thuan tuy, khong giu state.
abstract final class SolarDetailFormatters {
  /// yyyyMM -> 'Aug 2026'. Uy quyen cho [MonthFormatter] dung chung.
  static String monthLabel(String value) {
    return MonthFormatter.label(value);
  }

  static String number(double value) {
    return NumberFormat('#,##0.0').format(value);
  }

  static String energy(double kwh) {
    if (kwh >= 1000) {
      return '${(kwh / 1000).toStringAsFixed(1)} MWh';
    }

    return '${kwh.toStringAsFixed(1)} kWh';
  }

  static String money(double value) {
    return NumberFormat('#,##0.00').format(value);
  }

  static String compact(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    return value.toStringAsFixed(0);
  }
}
