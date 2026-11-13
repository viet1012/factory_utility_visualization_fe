import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utility_dashboard/shared/formatters/period_basis_formatter.dart';
import '../day_night/solar_day_night.dart';
import '../weather/model/weather_data.dart';
import 'led_text.dart';

/// Badge gọn ở góc map: đồng hồ (giờ nhà máy) + vòng tiến trình ngày/đêm
/// + thời tiết. Thay cho badge thời tiết cũ nên không tốn thêm chỗ.
///
/// Hiệu suất:
/// - Không dùng BackdropFilter (map bên dưới có xe/mưa chạy 60fps, blur nền
///   sẽ phải tính lại mỗi frame).
/// - Chỉ phần đồng hồ rebuild mỗi giây, nằm trong RepaintBoundary riêng;
///   Timer canh đúng biên giây, dừng khi map không active.
class MapClockWeatherBadge extends StatelessWidget {
  final bool isActive;
  final DayNightController dayNight;
  final WeatherData? weather;
  final bool weatherUnavailable;
  final bool isRaining;
  final double rainIntensity;

  const MapClockWeatherBadge({
    super.key,
    required this.isActive,
    required this.dayNight,
    required this.weather,
    required this.weatherUnavailable,
    required this.isRaining,
    required this.rainIntensity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0B1220).withValues(alpha: .62),
            const Color(0xFF0B1220).withValues(alpha: .38),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .28),
            blurRadius: 14,
            spreadRadius: -6,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            child: _LiveClock(isActive: isActive, dayNight: dayNight),
          ),
          Container(
            width: 1,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.white.withValues(alpha: .14),
          ),
          _WeatherPart(
            isDay: dayNight.value,
            weather: weather,
            unavailable: weatherUnavailable,
            isRaining: isRaining,
            rainIntensity: rainIntensity,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Clock
// ---------------------------------------------------------------------------

class _LiveClock extends StatefulWidget {
  final bool isActive;
  final DayNightController dayNight;

  const _LiveClock({required this.isActive, required this.dayNight});

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  static final _hm = DateFormat('HH:mm');
  static final _ss = DateFormat('ss');
  static final _date = DateFormat('EEE dd MMM', 'en_US');
  static final _short = DateFormat('HH:mm');

  /// Màu LED của đồng hồ (cyan, cùng tông viền neon của map).
  static const _ledColor = Color(0xFF4DF2FF);

  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _scheduleTick();
  }

  @override
  void didUpdateWidget(covariant _LiveClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;
    if (widget.isActive) {
      setState(() => _now = DateTime.now());
      _scheduleTick();
    } else {
      _timer?.cancel();
    }
  }

  /// Hẹn tick ngay sau biên giây kế tiếp (không trôi như Timer.periodic).
  void _scheduleTick() {
    _timer?.cancel();
    final now = DateTime.now();
    final wait = 1000 - now.millisecond + 5;
    _timer = Timer(Duration(milliseconds: wait), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _scheduleTick();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Giờ nhà máy (UTC+7), không phụ thuộc múi giờ của máy hiển thị.
  static DateTime _plant(DateTime t) =>
      t.toUtc().add(PeriodBasisFormatter.plantUtcOffset);

  @override
  Widget build(BuildContext context) {
    final plant = _plant(_now);
    final ctl = widget.dayNight;
    final phase = ctl.phase;
    final isDay = ctl.value; // cảnh đang hiển thị (auto hoặc chọn tay)
    final manual = ctl.mode != DayNightMode.auto;
    final accent = isDay ? const Color(0xFFFFC14D) : const Color(0xFF9DB4FF);
    final modeLabel = switch (ctl.mode) {
      DayNightMode.auto => 'AUTO',
      DayNightMode.day => 'DAY',
      DayNightMode.night => 'NIGHT',
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message:
              'Scene: $modeLabel  (click: Auto → Day → Night)\n'
              'Sunrise ${_short.format(_plant(phase.today.sunrise))}'
              '  ·  Sunset ${_short.format(_plant(phase.today.sunset))}',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: ctl.cycleMode,
              child: SizedBox.square(
                dimension: 30,
                child: CustomPaint(
                  painter: _PhaseRingPainter(
                    // chọn tay: vòng đầy; auto: tiến trình ngày/đêm
                    progress: manual ? 1 : phase.progressAt(_now.toUtc()),
                    color: manual ? accent.withValues(alpha: .55) : accent,
                  ),
                  child: Icon(
                    isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                    size: 14,
                    color: accent,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                LedText(
                  _hm.format(plant),
                  height: 19,
                  color: _ledColor,
                  colonOn: plant.second.isEven,
                ),
                const SizedBox(width: 4),
                LedText(
                  _ss.format(plant),
                  height: 10,
                  color: _ledColor.withValues(alpha: .7),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text.rich(
              TextSpan(
                text: _date.format(plant).toUpperCase(),
                children: [
                  if (manual)
                    TextSpan(
                      text: '  ·  $modeLabel',
                      style: TextStyle(color: accent),
                    ),
                ],
              ),
              style: TextStyle(
                color: Colors.white.withValues(alpha: .62),
                fontSize: 9,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Vòng tiến trình của pha ngày (mọc → lặn) hoặc đêm (lặn → mọc).
class _PhaseRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _PhaseRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1.5);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = Colors.white.withValues(alpha: .12);
    canvas.drawOval(rect, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, arc);
  }

  // Vẽ lại khi tiến trình đổi >= 0.1% (≈ 40s), không phải mỗi giây.
  @override
  bool shouldRepaint(covariant _PhaseRingPainter old) =>
      old.color != color || (old.progress - progress).abs() >= 0.001;
}

// ---------------------------------------------------------------------------
// Weather
// ---------------------------------------------------------------------------

class _WeatherPart extends StatelessWidget {
  final bool isDay;
  final WeatherData? weather;
  final bool unavailable;
  final bool isRaining;
  final double rainIntensity;

  const _WeatherPart({
    required this.isDay,
    required this.weather,
    required this.unavailable,
    required this.isRaining,
    required this.rainIntensity,
  });

  @override
  Widget build(BuildContext context) {
    final w = weather;
    final dim = Colors.white.withValues(alpha: .62);

    if (w == null) {
      return Tooltip(
        message: unavailable
            ? 'Weather service unavailable'
            : 'Loading weather...',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              unavailable ? Icons.cloud_off_rounded : Icons.cloud_sync_rounded,
              size: 15,
              color: dim,
            ),
            const SizedBox(width: 5),
            Text(
              unavailable ? 'N/A' : '...',
              style: TextStyle(
                color: dim,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    const rainColor = Color(0xFF22D3EE);
    final subtitle = isRaining
        ? 'RAIN ${(rainIntensity * 100).round()}%'
        : w.condition.toUpperCase();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _weatherIcon(w.condition, isDay),
              size: 15,
              color: isRaining ? rainColor : Colors.white,
            ),
            const SizedBox(width: 5),
            LedText(
              '${w.temperature.toStringAsFixed(1)}°',
              height: 14,
              color: isRaining ? rainColor : const Color(0xFFFFB84D),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 1,
          style: TextStyle(
            color: isRaining ? rainColor : dim,
            fontSize: 9,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
      ],
    );
  }

  static IconData _weatherIcon(String condition, bool isDay) {
    switch (condition) {
      case 'rain':
      case 'drizzle':
        return Icons.water_drop;
      case 'storm':
      case 'thunderstorm':
        return Icons.flash_on;
      case 'clouds':
      case 'cloudy':
        return Icons.cloud;
      case 'clear':
        return isDay ? Icons.wb_sunny : Icons.nightlight_round;
      default:
        return Icons.wb_cloudy;
    }
  }
}
