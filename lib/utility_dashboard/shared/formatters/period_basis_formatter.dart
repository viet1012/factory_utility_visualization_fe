import 'package:intl/intl.dart';

import '../../monitoring/electricity/widgets/electricity_style.dart'
    show PlantTime;

/// Ky tinh cua so lieu, de nguoi xem biet moi con so thuoc ky nao:
///
/// - THANG DUONG LICH (ngay 1 → cuoi thang; thang hien tai = den hom nay):
///   GET /api/utility/monthly-summary (panel SUMMARY), /api/solar/monthly,
///   /api/solar/detail.
/// - KY HOA DON (ngay [billCutoffDay] thang truoc → ngay [billCutoffDay] - 1
///   thang nay): GET /api/utility/electric-consumption (Monitoring › Bill
///   period).
///
/// Chi dung cho hien thi; khong tinh so lieu hay tham so API.
abstract final class PeriodBasisFormatter {
  /// Ngay bat dau ky hoa don: ky cua thang M = ngay 21 thang M-1 → ngay 20
  /// thang M. Ngay >= cutoff thuoc ky cua thang sau.
  static const int billCutoffDay = 21;

  /// `day 21 → day 20` (dung trong chuoi const, vd hint tab Monitoring).
  static const String billPeriodSpanText =
      'day $billCutoffDay → day ${billCutoffDay - 1}';

  /// Tooltip canh nhan "Calendar month · …" cua Solar.
  static const String calendarMonthHint =
      'Calendar month. Elec. consumption uses the bill period '
      '($billPeriodSpanText), so totals can differ.';

  static const String _calendarMonth = 'Calendar month';
  static const String _calendarShort = 'Calendar';

  /// Gio nha may: backend tra moc thoi gian kem `+07:00` (vd `dataUntil`
  /// cua electric-consumption). Viet Nam khong co gio mua he.
  static const Duration plantUtcOffset = Duration(hours: 7);

  static final DateFormat _dayFormat = DateFormat('MMM d', 'en_US');
  static final DateFormat _monthYearFormat = DateFormat('MMM yyyy', 'en_US');

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
  /// [today] mac dinh la [plantToday]. Dung cho Solar (khong co pickAt).
  static String calendarMonthLabel(String yyyyMM, {DateTime? today}) {
    final range = calendarMonthRange(yyyyMM, today: today ?? plantToday());
    if (range == null) return _calendarMonth;

    final from = _dayFormat.format(range.from);
    final to = _dayFormat.format(range.to);
    return from == to
        ? '$_calendarMonth · $from'
        : '$_calendarMonth · $from – $to';
  }

  // ============================================================
  // SUMMARY (MONTHLY): khoang ngay theo pickAt
  // ============================================================

  /// pickAt moi nhat trong cac dong monthly-summary (null neu khong dong
  /// nao co pickAt doc duoc).
  static PlantTime? latestPickAt(Iterable<String?> values) {
    PlantTime? latest;
    DateTime? latestKey;

    for (final value in values) {
      final time = PlantTime.tryParse(value);
      if (time == null) continue;

      final key = DateTime(
        time.year,
        time.month,
        time.day,
        time.hour,
        time.minute,
      );
      if (latestKey == null || key.isAfter(latestKey)) {
        latest = time;
        latestKey = key;
      }
    }

    return latest;
  }

  /// Dong phu cua panel SUMMARY:
  /// - thang dang chay: `Calendar month · Nov 1 – Nov 12, 15:00`
  ///   (pickAt 00:00 = het ngay truoc: `Nov 1 – Nov 11`)
  /// - thang da qua: `Calendar month · Nov 1 – Nov 30`
  /// - chua co du lieu: `Calendar month · Nov 2026 · no data yet`
  ///
  /// [compact]: bo chu "month" (`Calendar · …`) khi thieu cho.
  static String calendarMonthDataLabel(
    String yyyyMM, {
    required PlantTime? pickAt,
    DateTime? today,
    bool compact = false,
  }) {
    final prefix = compact ? _calendarShort : _calendarMonth;
    final body = _calendarDataRange(yyyyMM, pickAt: pickAt, today: today);
    return body == null ? prefix : '$prefix · $body';
  }

  /// Tooltip ⓘ cua panel SUMMARY (nhieu dong):
  /// ```
  /// Calendar month: Nov 1 – Nov 12, 15:00
  /// Elec. consumption uses the bill period: Oct 21 → Nov 20
  /// so totals can differ.
  /// ```
  static String billPeriodHint(
    String yyyyMM, {
    required PlantTime? pickAt,
    DateTime? today,
  }) {
    final calendar =
        _calendarDataRange(yyyyMM, pickAt: pickAt, today: today) ?? yyyyMM;
    final billMonth = _parseMonth(yyyyMM);

    return [
      '$_calendarMonth: $calendar',
      billMonth == null
          ? 'Elec. consumption uses the bill period ($billPeriodSpanText)'
          : 'Elec. consumption uses the bill period: '
                '${billPeriodRangeText(billMonth)}',
      'so totals can differ.',
    ].join('\n');
  }

  /// Tooltip ⓘ cua man Elec. consumption (Monitoring › Bill period),
  /// [billMonth] = thang cua ky hoa don dang xem.
  static String billPeriodScreenHint(DateTime billMonth) {
    return 'Bill period: ${billPeriodRangeText(billMonth)}.\n'
        'SUMMARY and Solar use the calendar month, so totals can differ.';
  }

  /// Ky hoa don cua thang [billMonth]: `Oct 21 → Nov 20`.
  static String billPeriodRangeText(DateTime billMonth) {
    final from = DateTime(billMonth.year, billMonth.month - 1, billCutoffDay);
    final to = DateTime(billMonth.year, billMonth.month, billCutoffDay - 1);
    return '${PlantTime.formatDate(from)} → ${PlantTime.formatDate(to)}';
  }

  /// Phan sau `Calendar month · ` / `Calendar month: `. null khi [yyyyMM]
  /// sai dinh dang.
  static String? _calendarDataRange(
    String yyyyMM, {
    required PlantTime? pickAt,
    DateTime? today,
  }) {
    final plantDay = today ?? plantToday();
    final range = calendarMonthRange(yyyyMM, today: plantDay);
    if (range == null) return null;

    final noData = '${_monthYearFormat.format(range.from)} · no data yet';
    if (pickAt == null || range.from.isAfter(plantDay)) return noData;

    final fromText = PlantTime.formatDate(range.from);

    if (!range.isMtd) {
      return '$fromText – ${PlantTime.formatDate(range.to)}';
    }

    // Thang dang chay: moc cuoi = pickAt (00:00 = het ngay truoc).
    if (pickAt.isMidnight) {
      final last = pickAt.date.subtract(const Duration(days: 1));
      if (last.isBefore(range.from)) return noData;
      return '$fromText – ${PlantTime.formatDate(last)}';
    }

    if (pickAt.date.isBefore(range.from)) return noData;
    return '$fromText – ${PlantTime.formatDate(pickAt.date)}, '
        '${PlantTime.formatHour(pickAt.hour)}';
  }

  /// yyyyMM -> DateTime(year, month); null khi sai dinh dang.
  static DateTime? _parseMonth(String yyyyMM) {
    final raw = yyyyMM.trim();
    if (raw.length != 6) return null;
    final year = int.tryParse(raw.substring(0, 4));
    final month = int.tryParse(raw.substring(4, 6));
    if (year == null || month == null || month < 1 || month > 12) return null;
    return DateTime(year, month);
  }
}
