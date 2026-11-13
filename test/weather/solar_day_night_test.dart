import 'package:factory_utility_visualization/weather_widgets/day_night/solar_day_night.dart';
import 'package:flutter_test/flutter_test.dart';

/// Giờ nhà máy (UTC+7) -> UTC.
DateTime plant(int y, int m, int d, int hh, int mm) =>
    DateTime.utc(y, m, d, hh, mm).subtract(const Duration(hours: 7));

void expectNear(DateTime actual, DateTime expected) {
  final diff = actual.difference(expected).inSeconds.abs();
  expect(diff, lessThanOrEqualTo(120), reason: '$actual vs $expected');
}

void main() {
  group('SunTimes', () {
    // Giá trị tham chiếu cho TP.HCM / Bình Dương (±2 phút).
    test('13/11: mọc ~05:48, lặn ~17:26', () {
      final t = SunTimes.forDate(2026, 11, 13);
      expectNear(t.sunrise, plant(2026, 11, 13, 5, 48));
      expectNear(t.sunset, plant(2026, 11, 13, 17, 26));
    });

    test('21/06: mọc ~05:31, lặn ~18:17', () {
      final t = SunTimes.forDate(2026, 6, 21);
      expectNear(t.sunrise, plant(2026, 6, 21, 5, 31));
      expectNear(t.sunset, plant(2026, 6, 21, 18, 17));
    });

    test('21/12: mọc ~06:06, lặn ~17:35', () {
      final t = SunTimes.forDate(2026, 12, 21);
      expectNear(t.sunrise, plant(2026, 12, 21, 6, 6));
      expectNear(t.sunset, plant(2026, 12, 21, 17, 35));
    });
  });

  group('SolarPhase', () {
    test('trưa là ban ngày, kết thúc lúc lặn', () {
      final p = SolarPhase.at(plant(2026, 11, 13, 12, 0));
      expect(p.isDay, isTrue);
      expectNear(p.end, plant(2026, 11, 13, 17, 26));
      expect(
        p.progressAt(plant(2026, 11, 13, 12, 0)),
        inInclusiveRange(.5, .6),
      );
    });

    test('rạng sáng là ban đêm, kết thúc lúc mọc cùng ngày', () {
      final p = SolarPhase.at(plant(2026, 11, 13, 3, 0));
      expect(p.isDay, isFalse);
      expectNear(p.start, plant(2026, 11, 12, 17, 26));
      expectNear(p.end, plant(2026, 11, 13, 5, 48));
    });

    test('tối là ban đêm, kết thúc lúc mọc ngày hôm sau', () {
      final p = SolarPhase.at(plant(2026, 11, 13, 21, 0));
      expect(p.isDay, isFalse);
      expectNear(p.end, plant(2026, 11, 14, 5, 48));
    });

    test('qua năm mới không lỗi', () {
      final p = SolarPhase.at(plant(2026, 12, 31, 23, 30));
      expect(p.isDay, isFalse);
      expect(p.end.isAfter(plant(2027, 1, 1, 5, 0)), isTrue);
    });
  });

  test('DayNightController dùng đồng hồ được cung cấp', () {
    final day = DayNightController(clock: () => plant(2026, 11, 13, 9, 0));
    final night = DayNightController(clock: () => plant(2026, 11, 13, 22, 0));
    addTearDown(day.dispose);
    addTearDown(night.dispose);

    expect(day.value, isTrue);
    expect(night.value, isFalse);
  });

  test('chọn tay: Auto -> Day -> Night -> Auto, có báo listener', () {
    final ctl = DayNightController(clock: () => plant(2026, 11, 13, 9, 0));
    addTearDown(ctl.dispose);
    var notified = 0;
    ctl.addListener(() => notified++);

    ctl.cycleMode(); // day (ban ngày sẵn -> value không đổi nhưng vẫn báo)
    expect(ctl.mode, DayNightMode.day);
    expect(ctl.value, isTrue);
    expect(notified, 1);

    ctl.cycleMode(); // night
    expect(ctl.value, isFalse);

    ctl.cycleMode(); // auto -> theo mặt trời (9h sáng = ngày)
    expect(ctl.mode, DayNightMode.auto);
    expect(ctl.value, isTrue);
    expect(notified, 3);
  });
}
