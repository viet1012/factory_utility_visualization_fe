import 'package:intl/intl.dart';

/// Format nhan thang dung chung cho toan bo dashboard.
///
/// Chi dung cho hien thi. Khong dung de parse input cua user hay
/// de tao tham so goi API.
///
/// Locale duoc ghim 'en_US' de moi man hinh luon ra cung mot ten thang.
abstract final class MonthFormatter {
  static final DateFormat _labelFormat = DateFormat('MMM yyyy', 'en_US');

  /// yyyyMM -> 'Aug 2026'.
  ///
  /// Tra ve chuoi goc (da trim) neu khong hop le. Khong bao gio throw.
  static String label(String yyyyMM) {
    final raw = yyyyMM.trim();

    if (raw.length != 6) {
      return raw;
    }

    final year = int.tryParse(raw.substring(0, 4));

    final month = int.tryParse(raw.substring(4, 6));

    if (year == null || month == null || month < 1 || month > 12) {
      return raw;
    }

    return _labelFormat.format(DateTime(year, month));
  }

  /// yyyyMM -> 'AUG 2026'.
  ///
  /// Dau vao khong hop le se tra ve chuoi goc da viet hoa.
  static String uppercaseLabel(String yyyyMM) {
    return label(yyyyMM).toUpperCase();
  }

  /// DateTime -> 'Aug 2026'.
  static String fromDateTime(DateTime value) {
    return _labelFormat.format(value);
  }
}
