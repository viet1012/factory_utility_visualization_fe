import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Toạ độ nhà máy (trùng toạ độ gọi OpenWeather).
const double kFactoryLatitude = 10.889414655521932;
const double kFactoryLongitude = 106.72094061256969;

/// Giờ mặt trời mọc / lặn (UTC) của 1 ngày, tính offline bằng
/// "sunrise equation" (sai số ~1 phút) — không cần gọi API.
@immutable
class SunTimes {
  final DateTime sunrise;
  final DateTime sunset;

  const SunTimes(this.sunrise, this.sunset);

  /// [year]/[month]/[day] là ngày theo giờ địa phương của toạ độ.
  factory SunTimes.forDate(
    int year,
    int month,
    int day, {
    double latitude = kFactoryLatitude,
    double longitude = kFactoryLongitude,
  }) {
    double rad(double deg) => deg * math.pi / 180;
    double deg(double rad) => rad * 180 / math.pi;

    // Thời điểm (UTC) xấp xỉ giữa trưa mặt trời của ngày đó.
    final noonUtc = DateTime.utc(year, month, day, 12).subtract(
      Duration(
        microseconds: (longitude / 15 * Duration.microsecondsPerHour).round(),
      ),
    );
    final julian = noonUtc.millisecondsSinceEpoch / 86400000 + 2440587.5;
    final n = (julian - 2451545.0 + 0.0008).roundToDouble();
    final jStar = n - longitude / 360;

    final m = (357.5291 + 0.98560028 * jStar) % 360;
    final c =
        1.9148 * math.sin(rad(m)) +
        0.0200 * math.sin(rad(2 * m)) +
        0.0003 * math.sin(rad(3 * m));
    final lambda = (m + c + 180 + 102.9372) % 360;
    final jTransit =
        2451545.0 +
        jStar +
        0.0053 * math.sin(rad(m)) -
        0.0069 * math.sin(rad(2 * lambda));

    final declination = math.asin(
      math.sin(rad(lambda)) * math.sin(rad(23.4397)),
    );
    final cosOmega =
        (math.sin(rad(-0.833)) -
            math.sin(rad(latitude)) * math.sin(declination)) /
        (math.cos(rad(latitude)) * math.cos(declination));
    final omega = deg(math.acos(cosOmega.clamp(-1.0, 1.0)));

    DateTime toUtc(double j) => DateTime.fromMillisecondsSinceEpoch(
      ((j - 2440587.5) * 86400000).round(),
      isUtc: true,
    );

    return SunTimes(
      toUtc(jTransit - omega / 360),
      toUtc(jTransit + omega / 360),
    );
  }
}

/// Trạng thái ngày/đêm tại 1 thời điểm.
@immutable
class SolarPhase {
  final bool isDay;

  /// Mốc bắt đầu / kết thúc của pha hiện tại (UTC).
  final DateTime start;
  final DateTime end;

  /// Mặt trời mọc / lặn của ngày hiện tại (UTC) — để hiển thị.
  final SunTimes today;

  const SolarPhase({
    required this.isDay,
    required this.start,
    required this.end,
    required this.today,
  });

  /// 0..1 — đã đi được bao nhiêu phần của pha ngày (hoặc đêm).
  double progressAt(DateTime now) {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    return (now.difference(start).inSeconds / total).clamp(0.0, 1.0);
  }

  factory SolarPhase.at(
    DateTime now, {
    double latitude = kFactoryLatitude,
    double longitude = kFactoryLongitude,
  }) {
    // Ngày địa phương theo giờ mặt trời của toạ độ.
    final local = now.toUtc().add(
      Duration(minutes: (longitude / 15 * 60).round()),
    );
    SunTimes on(int dayOffset) => SunTimes.forDate(
      local.year,
      local.month,
      local.day + dayOffset,
      latitude: latitude,
      longitude: longitude,
    );

    final today = on(0);
    if (now.isBefore(today.sunrise)) {
      return SolarPhase(
        isDay: false,
        start: on(-1).sunset,
        end: today.sunrise,
        today: today,
      );
    }
    if (now.isBefore(today.sunset)) {
      return SolarPhase(
        isDay: true,
        start: today.sunrise,
        end: today.sunset,
        today: today,
      );
    }
    return SolarPhase(
      isDay: false,
      start: today.sunset,
      end: on(1).sunrise,
      today: today,
    );
  }
}

/// Chế độ cảnh: tự động theo mặt trời, hoặc ép ngày / đêm bằng tay.
enum DayNightMode { auto, day, night }

/// `true` = ban ngày. Chạy hoàn toàn offline (mạng nội bộ không có internet
/// vẫn đổi cảnh đúng giờ). Tự đổi đúng lúc mặt trời mọc/lặn bằng 1 Timer
/// hẹn giờ (không polling), kiểm tra lại tối đa mỗi 10 phút để bắt trường hợp
/// đổi giờ hệ thống / máy sleep.
class DayNightController extends ValueNotifier<bool> {
  final double latitude;
  final double longitude;
  final DateTime Function() _clock;

  Timer? _timer;
  late SolarPhase _phase;
  DayNightMode _mode;

  DayNightController({
    this.latitude = kFactoryLatitude,
    this.longitude = kFactoryLongitude,
    DayNightMode mode = DayNightMode.auto,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _mode = mode,
       super(true) {
    _evaluate();
  }

  SolarPhase get phase => _phase;

  DayNightMode get mode => _mode;

  set mode(DayNightMode m) {
    if (_mode == m) return;
    _mode = m;
    final before = value;
    value = _resolve();
    // value không đổi (vd auto -> day lúc đang ngày) vẫn phải báo để UI
    // cập nhật biểu tượng chế độ.
    if (before == value) notifyListeners();
  }

  /// Auto -> Ngày -> Đêm -> Auto.
  void cycleMode() => mode =
      DayNightMode.values[(_mode.index + 1) % DayNightMode.values.length];

  bool _resolve() => switch (_mode) {
    DayNightMode.auto => _phase.isDay,
    DayNightMode.day => true,
    DayNightMode.night => false,
  };

  static const _maxRecheck = Duration(minutes: 10);

  void _evaluate() {
    final now = _clock().toUtc();
    _phase = SolarPhase.at(now, latitude: latitude, longitude: longitude);
    value = _resolve();

    var delay = _phase.end.difference(now) + const Duration(seconds: 1);
    if (delay > _maxRecheck) delay = _maxRecheck;
    if (delay < const Duration(seconds: 1)) delay = const Duration(seconds: 1);

    _timer?.cancel();
    _timer = Timer(delay, _evaluate);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
