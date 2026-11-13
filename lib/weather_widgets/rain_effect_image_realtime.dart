import 'dart:async';
import 'dart:math' as math;

import 'package:factory_utility_visualization/weather_widgets/clock/map_clock_weather_badge.dart';
import 'package:factory_utility_visualization/weather_widgets/day_night/solar_day_night.dart';
import 'package:factory_utility_visualization/weather_widgets/weather/api/weather_api_service.dart';
import 'package:factory_utility_visualization/weather_widgets/weather/api_rain_painter.dart';
import 'package:factory_utility_visualization/weather_widgets/weather/model/rain_drop.dart';
import 'package:factory_utility_visualization/weather_widgets/weather/model/rain_splash.dart';
import 'package:factory_utility_visualization/weather_widgets/weather/model/weather_data.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:factory_utility_visualization/utility_dashboard/shared/polling/dashboard_polling_intervals.dart';
import 'package:factory_utility_visualization/utility_dashboard/shared/polling/polling_coordinator.dart';
import 'package:factory_utility_visualization/utility_dashboard/shared/polling/polling_scope.dart';
import 'package:factory_utility_visualization/utility_dashboard/shared/polling/polling_task_ids.dart';

class ApiControlledRainImage extends StatefulWidget {
  final bool isActive;
  final String imageUrl;
  final String? nightImageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final WeatherApiService weatherService;
  final bool showWeatherInfo;

  /// Lớp cảnh động (vd: xe chạy) vẽ ngay trên ảnh nền, dưới lớp tối + mưa.
  final Widget Function(BuildContext context, bool isDay)? sceneLayerBuilder;

  const ApiControlledRainImage({
    super.key,
    required this.isActive,
    required this.imageUrl,
    required this.weatherService,
    this.nightImageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.showWeatherInfo = true,
    this.sceneLayerBuilder,
  });

  @override
  State<ApiControlledRainImage> createState() => _ApiControlledRainImageState();
}

class _ApiControlledRainImageState extends State<ApiControlledRainImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rainController;
  final math.Random _random = math.Random();

  final List<RainDrop> _rainDrops = [];
  final List<RainSplash> _splashes = [];

  bool _weatherRequestRunning = false;
  late final PollingCoordinator _pollingCoordinator;

  WeatherData? _currentWeather;
  bool _weatherUnavailable = false;
  Timer? _weatherRetryTimer;
  bool _isRaining = false;
  double _rainIntensity = 0.0;
  int _rainDropCount = 0;

  /// Ngày/đêm tính offline theo giờ mặt trời mọc/lặn tại nhà máy,
  /// không phụ thuộc API thời tiết (API lỗi vẫn đổi nền đúng giờ).
  final DayNightController _dayNight = DayNightController();

  bool get _isDay => _dayNight.value;

  static const _weatherRetryDelay = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();

    _dayNight.addListener(_onDayNightChanged);

    _rainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    );

    _pollingCoordinator = context.read<PollingCoordinator>();
    _pollingCoordinator.register(
      id: PollingTaskIds.mapWeather,
      scope: PollingScope.map,
      interval: DashboardPollingIntervals.mapWeather,
      action: _fetchWeather,
    );
    _pollingCoordinator.start(PollingTaskIds.mapWeather);

    if (widget.isActive) {
      _fetchWeather();
    }
  }

  void _onDayNightChanged() {
    if (mounted) setState(() {});
  }

  /// Chỉ chạy animation mưa khi đang active VÀ đang mưa — AnimationController
  /// chạy không sẽ ép Flutter vẽ frame liên tục dù không có gì thay đổi.
  void _syncRainAnimation() {
    final shouldRun = widget.isActive && _isRaining;
    if (shouldRun && !_rainController.isAnimating) {
      _rainController.repeat();
    } else if (!shouldRun && _rainController.isAnimating) {
      _rainController.stop();
    }
  }

  @override
  void didUpdateWidget(covariant ApiControlledRainImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isActive == widget.isActive) return;

    _syncRainAnimation();
    if (widget.isActive && _currentWeather == null) {
      _fetchWeather();
    }
  }

  Future<void> _fetchWeather() async {
    if (_weatherRequestRunning || !widget.isActive) return;

    _weatherRequestRunning = true;
    _weatherRetryTimer?.cancel();

    try {
      final weather = await widget.weatherService.fetchWeatherData();
      if (!mounted || !widget.isActive) return;

      if (weather == null) {
        // API lỗi: giữ số liệu cũ (nếu có), báo N/A và thử lại sớm
        // thay vì đợi chu kỳ polling 45 phút.
        setState(() => _weatherUnavailable = true);
        _weatherRetryTimer = Timer(_weatherRetryDelay, _fetchWeather);
        return;
      }

      setState(() {
        _weatherUnavailable = false;
        _applyWeather(weather);
      });
      _syncRainAnimation();
    } finally {
      _weatherRequestRunning = false;
    }
  }

  void _applyWeather(WeatherData weather) {
    _currentWeather = weather;

    final rainingNow =
        weather.condition.contains('rain') ||
        weather.condition.contains('storm') ||
        weather.rainIntensity > 0.05;

    _isRaining = rainingNow;

    if (!_isRaining) {
      _rainIntensity = 0.0;
      _rainDropCount = 0;
      _rainDrops.clear();
      _splashes.clear();
      return;
    }

    _rainIntensity = weather.rainIntensity;
    _rainDropCount = (30 + (_rainIntensity * 70)).toInt().clamp(0, 100);
    _initializeRainDrops();
  }

  void _initializeRainDrops() {
    _rainDrops
      ..clear()
      ..addAll(
        List.generate(
          _rainDropCount,
          (_) => RainDrop(
            x: _random.nextDouble(),
            y: _random.nextDouble(),
            length: 3 + _random.nextDouble() * (3 * _rainIntensity),
            speed: 0.01 + _random.nextDouble() * (0.02 * _rainIntensity),
            opacity: 0.3 + _random.nextDouble() * (0.7 * _rainIntensity),
            windOffset: _currentWeather?.windSpeed ?? 0,
          ),
        ),
      );
  }

  DateTime? _lastSplashSpawn;

  void _updateSplashes() {
    // Duyệt ngược, remove tại chỗ — không tạo list mới mỗi lần
    for (int i = _splashes.length - 1; i >= 0; i--) {
      _splashes[i].age += 0.05;
      if (_splashes[i].age > 1.0) {
        _splashes.removeAt(i);
      }
    }

    // Giới hạn tốc độ sinh splash theo thời gian thực, không phải theo % mỗi frame
    final now = DateTime.now();
    final canSpawn =
        _lastSplashSpawn == null ||
        now.difference(_lastSplashSpawn!) > const Duration(milliseconds: 120);

    // Giới hạn tổng số splash cùng lúc để tránh phình list
    if (_isRaining && canSpawn && _splashes.length < 40) {
      _splashes.add(
        RainSplash(x: _random.nextDouble(), y: _random.nextDouble(), age: 0),
      );
      _lastSplashSpawn = now;
    }
  }

  @override
  void dispose() {
    _pollingCoordinator.stop(PollingTaskIds.mapWeather);
    _pollingCoordinator.unregister(PollingTaskIds.mapWeather);
    _weatherRetryTimer?.cancel();
    _dayNight
      ..removeListener(_onDayNightChanged)
      ..dispose();
    _rainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackgroundImage(),
          if (widget.sceneLayerBuilder != null)
            Positioned.fill(child: widget.sceneLayerBuilder!(context, _isDay)),
          _buildWeatherOverlay(),
          if (_isRaining) _buildRainLayer(),
          if (widget.showWeatherInfo)
            Positioned(
              right: 10,
              top: 10,
              child: MapClockWeatherBadge(
                isActive: widget.isActive,
                dayNight: _dayNight,
                weather: _currentWeather,
                weatherUnavailable: _weatherUnavailable,
                isRaining: _isRaining,
                rainIntensity: _rainIntensity,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBackgroundImage() {
    final dayImage = Image.asset(
      widget.imageUrl,
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
    );

    final nightImage = Image.asset(
      widget.nightImageUrl ?? widget.imageUrl,
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
    );

    return Positioned.fill(
      child: AnimatedSwitcher(
        duration: const Duration(seconds: 1),
        child: _isDay
            ? SizedBox.expand(key: const ValueKey('day'), child: dayImage)
            : SizedBox.expand(key: const ValueKey('night'), child: nightImage),
      ),
    );
  }

  Widget _buildWeatherOverlay() {
    final overlayColor = _isRaining
        ? (_isDay
              ? Colors.black.withValues(alpha: 0.1 + _rainIntensity * 0.2)
              : Colors.black.withValues(alpha: 0.3 + _rainIntensity * 0.3))
        : (_isDay ? Colors.transparent : Colors.black.withValues(alpha: 0.25));

    return Positioned.fill(child: ColoredBox(color: overlayColor));
  }

  int _frameSkip = 0;

  Widget _buildRainLayer() {
    return Positioned.fill(
      child: RepaintBoundary(
        // cô lập layer mưa khỏi phần còn lại của Stack
        child: AnimatedBuilder(
          animation: _rainController,
          builder: (context, child) {
            _frameSkip++;
            if (_frameSkip % 2 == 0) {
              // chỉ update vật lý mỗi 2 frame ≈ 30fps
              for (final drop in _rainDrops) {
                drop.update(_rainIntensity, _splashes);
              }
              _updateSplashes();
            }

            return CustomPaint(
              isComplex: true, // gợi ý engine cache layer tốt hơn
              willChange: true, // báo layer này thay đổi liên tục
              painter: ApiRainPainter(
                splashes: _splashes,
                rainDrops: _rainDrops,
                intensity: _rainIntensity,
                windSpeed: _currentWeather?.windSpeed ?? 0,
                isDay: _isDay,
              ),
            );
          },
        ),
      ),
    );
  }
}
