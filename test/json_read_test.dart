import 'package:flutter_test/flutter_test.dart';

import 'package:factory_utility_visualization/utility_dashboard/shared/json/json_read.dart';

void main() {
  group('jsonDouble', () {
    test('doc num va chuoi so', () {
      expect(jsonDouble(3), 3.0);
      expect(jsonDouble(2.5), 2.5);
      expect(jsonDouble('1.25'), 1.25);
      expect(jsonDouble(' 7 '), 7.0);
    });

    test('null / rong / sai / khong huu han -> null', () {
      expect(jsonDouble(null), isNull);
      expect(jsonDouble(''), isNull);
      expect(jsonDouble('abc'), isNull);
      expect(jsonDouble('NaN'), isNull);
      expect(jsonDouble('Infinity'), isNull);
      expect(jsonDouble(true), isNull);
    });
  });

  group('jsonInt', () {
    test('doc num (bo phan thap phan) va chuoi so nguyen', () {
      expect(jsonInt(4), 4);
      expect(jsonInt(4.9), 4);
      expect(jsonInt(12.0), 12);
      expect(jsonInt('42'), 42);
      expect(jsonInt(' 5 '), 5);
    });

    test('null / sai / chuoi thap phan -> null', () {
      expect(jsonInt(null), isNull);
      expect(jsonInt(''), isNull);
      expect(jsonInt('12.5'), isNull);
      expect(jsonInt('x'), isNull);
      expect(jsonInt(double.nan), isNull);
    });
  });

  test('jsonText trim, null -> rong', () {
    expect(jsonText('  a b  '), 'a b');
    expect(jsonText(12), '12');
    expect(jsonText(null), '');
  });

  group('jsonDateTime', () {
    test('chuoi khong offset giu nguyen gio local', () {
      final value = jsonDateTime('2026-10-12T08:00:00')!;
      expect(value.isUtc, isFalse);
      expect(value.hour, 8);
    });

    test('chuoi co offset doi sang local, cung thoi diem', () {
      final value = jsonDateTime('2026-10-12T08:00:00+07:00')!;
      expect(value.isUtc, isFalse);
      expect(
        value.toUtc(),
        DateTime.utc(2026, 10, 12, 1),
      );
    });

    test('DateTime UTC -> local', () {
      final utc = DateTime.utc(2026, 1, 1);
      final value = jsonDateTime(utc)!;
      expect(value.isUtc, isFalse);
      expect(value.toUtc(), utc);
    });

    test('null / rong / sai -> null', () {
      expect(jsonDateTime(null), isNull);
      expect(jsonDateTime('  '), isNull);
      expect(jsonDateTime('not-a-date'), isNull);
    });
  });
}
