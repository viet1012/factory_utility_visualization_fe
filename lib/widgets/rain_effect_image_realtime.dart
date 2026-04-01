import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:factory_utility_visualization/widgets/weather/api_rain_painter.dart';
import 'package:factory_utility_visualization/widgets/weather/api/weather_api_service.dart';
import 'package:factory_utility_visualization/widgets/weather/model/rain_drop.dart';
import 'package:factory_utility_visualization/widgets/weather/model/rain_splash.dart';
import 'package:factory_utility_visualization/widgets/weather/model/weather_data.dart';

class ApiControlledRainImage extends StatefulWidget {
  final String imageUrl;
  final String? nightImageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final WeatherApiService weatherService;
  final bool showWeatherInfo;

  const ApiControlledRainImage({
    super.key,
    required this.imageUrl,
    required this.weatherService,
    this.nightImageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.showWeatherInfo = true,
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

  Timer? _weatherTimer;
  StreamSubscription<WeatherData>? _mockWeatherSub;

  WeatherData? _currentWeather;
  bool _isRaining = false;
  double _rainIntensity = 0.0;
  int _rainDropCount = 0;

  bool get _isDay => _currentWeather?.isDaytime ?? true;

  @override
  void initState() {
    super.initState();

    _rainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..repeat();

    _startWeatherMonitoring();
  }

  void _startWeatherMonitoring() {
    if (widget.weatherService is MockWeatherService) {
      final mockService = widget.weatherService as MockWeatherService;
      _mockWeatherSub = mockService.weatherStream().listen((weather) {
        if (!mounted) return;
        setState(() {
          _applyWeather(weather);
        });
      });
      return;
    }

    _fetchWeather();
    _weatherTimer = Timer.periodic(const Duration(minutes: 45), (_) {
      _fetchWeather();
    });
  }

  Future<void> _fetchWeather() async {
    final weather = await widget.weatherService.fetchWeatherData();
    if (!mounted || weather == null) return;

    setState(() {
      _applyWeather(weather);
    });
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
    _rainDropCount = (50 + (_rainIntensity * 150)).toInt();
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

  void _updateSplashes() {
    _splashes.removeWhere((s) => s.age > 1.0);

    if (_isRaining && _random.nextDouble() < 0.3) {
      _splashes.add(
        RainSplash(x: _random.nextDouble(), y: _random.nextDouble(), age: 0),
      );
    }

    for (final splash in _splashes) {
      splash.age += 0.05;
    }
  }

  @override
  void dispose() {
    _weatherTimer?.cancel();
    _mockWeatherSub?.cancel();
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
          _buildWeatherOverlay(),
          if (_isRaining) _buildRainLayer(),
          if (widget.showWeatherInfo)
            Positioned(
              left: 10,
              bottom: 10,
              child: _WeatherInfoBadge(
                weather: _currentWeather,
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
      color: Colors.blueGrey.withOpacity(0.3),
      colorBlendMode: BlendMode.darken,
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
              ? Colors.black.withOpacity(0.1 + _rainIntensity * 0.2)
              : Colors.black.withOpacity(0.3 + _rainIntensity * 0.3))
        : (_isDay ? Colors.transparent : Colors.black.withOpacity(0.25));

    return Positioned.fill(child: ColoredBox(color: overlayColor));
  }

  Widget _buildRainLayer() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _rainController,
        builder: (context, child) {
          for (final drop in _rainDrops) {
            drop.update(_rainIntensity, _splashes);
          }
          _updateSplashes();

          return CustomPaint(
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
    );
  }
}

class _WeatherInfoBadge extends StatelessWidget {
  final WeatherData? weather;
  final bool isRaining;
  final double rainIntensity;

  const _WeatherInfoBadge({
    required this.weather,
    required this.isRaining,
    required this.rainIntensity,
  });

  @override
  Widget build(BuildContext context) {
    if (weather == null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Loading weather...',
          style: TextStyle(color: Colors.white, fontSize: 10),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A237E), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getWeatherIcon(weather!.condition),
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                weather!.condition.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (isRaining) ...[
            const SizedBox(height: 4),
            Text(
              'Intensity: ${(rainIntensity * 100).toInt()}%',
              style: const TextStyle(color: Colors.cyanAccent, fontSize: 14),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${weather!.temperature.toStringAsFixed(1)}°C',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  static IconData _getWeatherIcon(String condition) {
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
        return Icons.wb_sunny;
      default:
        return Icons.wb_cloudy;
    }
  }
}

class MockWeatherService extends WeatherApiService {
  Stream<WeatherData> weatherStream() async* {
    while (true) {
      yield WeatherData(
        condition: 'rain',
        rainIntensity: 0.9,
        temperature: 24,
        humidity: 220,
        windSpeed: 4,
        isDaytime: true,
      );
      await Future.delayed(const Duration(seconds: 10));

      yield WeatherData(
        condition: 'rain',
        rainIntensity: 0.3,
        temperature: 24,
        humidity: 200,
        windSpeed: 4,
        isDaytime: true,
      );
      await Future.delayed(const Duration(seconds: 15));

      yield WeatherData(
        condition: 'rain',
        rainIntensity: 0.3,
        temperature: 22,
        humidity: 190,
        windSpeed: 3,
        isDaytime: false,
      );
      await Future.delayed(const Duration(seconds: 45));

      yield WeatherData(
        condition: 'clear',
        rainIntensity: 0.0,
        temperature: 22,
        humidity: 180,
        windSpeed: 2,
        isDaytime: false,
      );
      await Future.delayed(const Duration(seconds: 15));
    }
  }
}
