import 'package:intl/intl.dart';

/// Ky tinh cua so lieu, de nguoi xem biet moi con so thuoc ky nao:
///
/// - THANG DUONG LICH (ngay 1 → cuoi thang; thang hien tai = den hom nay):
///   GET /api/utility/monthly-summary (panel SUMMARY), /api/solar/monthly,
///   /api/solar/detail.
/// - KY HOA DON (ngay 21 thang truoc → ngay 20 thang nay):
///   GET /api/utility/electric-consumption (Monitoring › Bill period).
///
/// Chi dung cho hien thi; khong tinh so lieu hay tham so API.
abstract final class PeriodBasisFormatter {
  /// Tooltip canh nhan "Calendar month · …" (SUMMARY, Solar).
  static const String calendarMonthHint =
      'Calendar month. Elec. consumption uses the bill period '
      '(21st → 20th), so totals can differ.';

  /// Tooltip cua man Elec. consumption.
  static const String billPeriodHint =
      'Bill period (21st → 20th). SUMMARY and Solar use the calendar month, '
      'so totals can differ.';

  static const String _calendarMonth = 'Calendar month';

  /// Gio nha may: backend tra moc thoi gian kem `+07:00` (vd `dataUntil`
  /// cua electric-consumption). Viet Nam khong co gio mua he.
  static const Duration plantUtcOffset = Duration(hours: 7);

  static final DateFormat _dayFormat = DateFormat('MMM d', 'en_US');

  /// Ngay hom nay theo gio nha may (khong phu thuoc mui gio cua trinh duyet).
  static DateTime plantToday({DateTime? now}) {
    final plant = (now ?? DateTime.now()).toUtc().add(plantUtcOffset);
    return DateTime(plant.year, plant.month, plant.day);
  }

  /// yyyyMM -> khoang ngay cua thang duong lich:
  /// - thang hien tai (theo [today]): ngay 1 → [today] (MTD)
  /// - thang khac: ngay 1 → ngay cuoi thang
  ///
  /// null khi [yyyyMM] sai dinh dang.
  static ({DateTime from, DateTime to, bool isMtd})? calendarMonthRange(
    String yyyyMM, {
    required DateTime today,
  }) {
    final raw = yyyyMM.trim();
    if (raw.length != 6) return null;

    final year = int.tryParse(raw.substring(0, 4));
    final month = int.tryParse(raw.substring(4, 6));
    if (year == null || month == null || month < 1 || month > 12) {
      return null;
    }

    final from = DateTime(year, month);
    final isMtd = today.year == year && today.month == month;
    // Ngay 0 cua thang sau = ngay cuoi thang nay (tu xu ly nam nhuan,
    // thang 12 -> sang nam sau).
    final to = isMtd
        ? DateTime(today.year, today.month, today.day)
        : DateTime(year, month + 1, 0);

    return (from: from, to: to, isMtd: isMtd);
  }

  /// `Calendar month · Nov 1 – Nov 12` (thang hien tai) hoac
  /// `Calendar month · Nov 1 – Nov 30`. Ngay 1 cua thang hien tai:
  /// `Calendar month · Nov 1`. Sai dinh dang: `Calendar month`.
  ///
  /// [today] mac dinh la [plantToday].
  static String calendarMonthLabel(String yyyyMM, {DateTime? today}) {
    final range = calendarMonthRange(yyyyMM, today: today ?? plantToday());
    if (range == null) return _calendarMonth;

    final from = _dayFormat.format(range.from);
    final to = _dayFormat.format(range.to);
    return from == to
        ? '$_calendarMonth · $from'
        : '$_calendarMonth · $from – $to';
  }
}
