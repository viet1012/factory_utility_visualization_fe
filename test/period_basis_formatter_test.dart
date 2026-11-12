import 'package:factory_utility_visualization/utility_dashboard/shared/formatters/period_basis_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 12);

  group('calendarMonthRange', () {
    test('current month runs from the 1st to today (MTD)', () {
      final range = PeriodBasisFormatter.calendarMonthRange(
        '202611',
        today: today,
      )!;
      expect(range.from, DateTime(2026, 11, 1));
      expect(range.to, DateTime(2026, 11, 12));
      expect(range.isMtd, isTrue);
    });

    test('past month runs to its last day', () {
      final range = PeriodBasisFormatter.calendarMonthRange(
        '202609',
        today: today,
      )!;
      expect(range.from, DateTime(2026, 9, 1));
      expect(range.to, DateTime(2026, 9, 30));
      expect(range.isMtd, isFalse);
    });

    test('February in a leap year ends on the 29th', () {
      final leap = PeriodBasisFormatter.calendarMonthRange(
        '202802',
        today: today,
      )!;
      expect(leap.to, DateTime(2028, 2, 29));

      final common = PeriodBasisFormatter.calendarMonthRange(
        '202602',
        today: today,
      )!;
      expect(common.to, DateTime(2026, 2, 28));
    });

    test('December ends on the 31st (no roll into next year)', () {
      final range = PeriodBasisFormatter.calendarMonthRange(
        '202512',
        today: today,
      )!;
      expect(range.from, DateTime(2025, 12, 1));
      expect(range.to, DateTime(2025, 12, 31));
    });

    test('December as the current month is MTD', () {
      final range = PeriodBasisFormatter.calendarMonthRange(
        '202612',
        today: DateTime(2026, 12, 5),
      )!;
      expect(range.to, DateTime(2026, 12, 5));
      expect(range.isMtd, isTrue);
    });

    test('invalid input returns null', () {
      for (final value in ['', '2026-11', '202613', '202600', 'abcdef']) {
        expect(
          PeriodBasisFormatter.calendarMonthRange(value, today: today),
          isNull,
          reason: value,
        );
      }
    });
  });

  group('calendarMonthLabel', () {
    test('current month', () {
      expect(
        PeriodBasisFormatter.calendarMonthLabel('202611', today: today),
        'Calendar month · Nov 1 – Nov 12',
      );
    });

    test('past month', () {
      expect(
        PeriodBasisFormatter.calendarMonthLabel('202609', today: today),
        'Calendar month · Sep 1 – Sep 30',
      );
    });

    test('leap February and December', () {
      expect(
        PeriodBasisFormatter.calendarMonthLabel('202802', today: today),
        'Calendar month · Feb 1 – Feb 29',
      );
      expect(
        PeriodBasisFormatter.calendarMonthLabel('202512', today: today),
        'Calendar month · Dec 1 – Dec 31',
      );
    });

    test('first day of the current month shows a single day', () {
      expect(
        PeriodBasisFormatter.calendarMonthLabel(
          '202611',
          today: DateTime(2026, 11, 1),
        ),
        'Calendar month · Nov 1',
      );
    });

    test('invalid month falls back to the basis name', () {
      expect(
        PeriodBasisFormatter.calendarMonthLabel('bad', today: today),
        'Calendar month',
      );
    });
  });

  group('plantToday (UTC+7)', () {
    test('uses plant time, not the viewer time zone', () {
      // 2026-11-30 18:30 UTC = 2026-12-01 01:30 tai nha may.
      expect(
        PeriodBasisFormatter.plantToday(
          now: DateTime.utc(2026, 11, 30, 18, 30),
        ),
        DateTime(2026, 12, 1),
      );
      // 2026-11-30 16:59 UTC = 2026-11-30 23:59 tai nha may.
      expect(
        PeriodBasisFormatter.plantToday(
          now: DateTime.utc(2026, 11, 30, 16, 59),
        ),
        DateTime(2026, 11, 30),
      );
    });
  });
}
