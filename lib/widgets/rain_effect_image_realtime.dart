import 'dart:async';
import 'dart:math' as math;
import 'package:factory_utility_visualization/widgets/rain_effect_image.dart';
import 'package:factory_utility_visualization/widgets/weather/api/weather_api_service.dart';
import 'package:factory_utility_visualization/widgets/weather/api_rain_painter.dart';
import 'package:factory_utility_visualization/widgets/weather/model/rain_drop.dart';
import 'package:factory_utility_visualization/widgets/weather/model/rain_splash.dart';
import 'package:factory_utility_visualization/widgets/weather/model/weather_data.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// API-Controlled Rain Effect Widget
class ApiControlledRainImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final WeatherApiService weatherService;

  const ApiControlledRainImage({
    Key? key,
    required this.imageUrl,
    required this.weatherService,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<ApiControlledRainImage> createState() => _ApiControlledRainImageState();
}

class _ApiControlledRainImageState extends State<ApiControlledRainImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<RainDrop> rainDrops = [];
  List<RainSplash> splashes = [];

  WeatherData? currentWeather;
  bool isRaining = false;
  double rainIntensity = 0.0;
  int rainDropCount = 0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(milliseconds: 50),
      vsync: this,
    )..repeat();

    _startWeatherMonitoring();
  }

  // Test
  void _startWeatherMonitoring() {
    // Nếu service là MockWeatherService (stream)
    if (widget.weatherService is MockWeatherService) {
      final mockService = widget.weatherService as MockWeatherService;
      mockService.weatherStream().listen((weather) {
        if (!mounted) return;
        setState(() {
          currentWeather = weather;
          _updateRainEffect(weather);
        });
      });
    } else {
      // Service thật: fetch 1 lần + update định kỳ
      _updateWeather();
      Timer.periodic(Duration(minutes: 45), (timer) {
        _updateWeather();
      });
    }
  }

  Future<void> _updateWeather() async {
    final weather = await widget.weatherService.fetchWeatherData();

    if (weather != null && mounted) {
      setState(() {
        currentWeather = weather;
        _updateRainEffect(weather);
      });
    }
  }

  void _updateRainEffect(WeatherData weather) {
    // Determine if it should rain
    isRaining =
        weather.condition.contains('rain') ||
        weather.condition.contains('storm') ||
        weather.rainIntensity > 0.05;

    if (isRaining) {
      rainIntensity = weather.rainIntensity;

      // Calculate rain drop count based on intensity
      rainDropCount = (50 + (weather.rainIntensity * 150)).toInt();

      // Reinitialize rain drops with new count
      _initializeRainDrops();
    } else {
      rainDropCount = 0;
      rainDrops.clear();
    }
  }

  void _updateSplashes() {
    final random = math.Random();

    // Xoá splash cũ
    splashes.removeWhere((s) => s.age > 1.0);

    // Ngẫu nhiên thêm splash mới khi có mưa
    if (isRaining && random.nextDouble() < 0.3) {
      // splashes.add(
      //   RainSplash(
      //     x: random.nextDouble(),
      //     y: 0.9 + random.nextDouble() * 0.1,
      //     age: 0,
      //   ),
      // );
      splashes.add(
        RainSplash(
          x: random.nextDouble(),
          y: random.nextDouble(), // từ 0 → 1, loang khắp màn hình
          age: 0,
        ),
      );
    }

    // Update splash hiện tại
    for (var splash in splashes) {
      splash.age += 0.05;
    }
  }

  void _initializeRainDrops() {
    final random = math.Random();
    rainDrops = List.generate(
      rainDropCount,
      (index) => RainDrop(
        x: random.nextDouble(),
        y: random.nextDouble(),
        length: 3 + random.nextDouble() * (3 * rainIntensity),
        speed: 0.01 + random.nextDouble() * (0.02 * rainIntensity),
        opacity: 0.3 + random.nextDouble() * (0.7 * rainIntensity),
        windOffset: currentWeather?.windSpeed ?? 0,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  // Trong build() của _ApiControlledRainImageState
  Widget build(BuildContext context) {
    final isDay = currentWeather?.isDaytime ?? true;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        // Background image
        AnimatedCrossFade(
          duration: const Duration(seconds: 1),
          firstChild: Image.asset(
            widget.imageUrl,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
          ),
          secondChild: Image.asset(
            'assets/images/SPC2_night.png',
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            color: Colors.blueGrey.withOpacity(0.3),
            colorBlendMode: BlendMode.darken,
          ),
          crossFadeState: isDay
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
        ),

        // Weather overlay (darker for night or rain)
        Positioned.fill(
          child: Container(
            color: isRaining
                ? (isDay
                      ? Colors.black.withOpacity(0.1 + rainIntensity * 0.2)
                      : Colors.black.withOpacity(0.3 + rainIntensity * 0.3))
                : (isDay
                      ? Colors.transparent
                      : Colors.black.withOpacity(0.25)), // night dark overlay
          ),
        ),

        // Rain effect
        if (isRaining)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                for (var drop in rainDrops) {
                  drop.update(rainIntensity, splashes);
                }
                _updateSplashes();

                return CustomPaint(
                  painter: ApiRainPainter(
                    splashes: splashes,
                    rainDrops: rainDrops,
                    intensity: rainIntensity,
                    windSpeed: currentWeather?.windSpeed ?? 0,
                    isDay: isDay,
                  ),
                );
              },
            ),
          ),

        // Weather info overlay
        Positioned(bottom: 10, left: 10, child: _buildWeatherInfo()),
      ],
    );
  }

  Widget _buildWeatherInfo() {
    if (currentWeather == null) {
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Loading weather...',
          style: TextStyle(color: Colors.white, fontSize: 10),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF1A237E), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getWeatherIcon(), color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text(
                currentWeather!.condition.toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (isRaining) ...[
            SizedBox(height: 4),
            Text(
              'Intensity: ${(rainIntensity * 100).toInt()}%',
              style: TextStyle(color: Colors.cyanAccent, fontSize: 14),
            ),
          ],
          SizedBox(height: 4),
          Text(
            '${currentWeather!.temperature.toStringAsFixed(1)}°C',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  IconData _getWeatherIcon() {
    switch (currentWeather?.condition) {
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
  // Stream mô phỏng thay đổi thời tiết + ngày/đêm
  Stream<WeatherData> weatherStream() async* {
    final now = DateTime.now();

    // 1. Ban ngày mưa nặng
    yield WeatherData(
      condition: 'rain',
      rainIntensity: 0.9,
      temperature: 24,
      humidity: 220,
      windSpeed: 4,
      isDaytime: true,
    );
    await Future.delayed(Duration(seconds: 10));

    // 2. Ban ngày mưa nhẹ
    yield WeatherData(
      condition: 'rain',
      rainIntensity: 0.3,
      temperature: 24,
      humidity: 200,
      windSpeed: 4,
      isDaytime: true,
    );
    await Future.delayed(Duration(seconds: 15));

    // 3. Ban đêm mưa nhẹ
    yield WeatherData(
      condition: 'rain',
      rainIntensity: 0.3,
      temperature: 22,
      humidity: 190,
      windSpeed: 3,
      isDaytime: false,
    );
    await Future.delayed(Duration(seconds: 45));

    // 4. Ban đêm trời quang
    yield WeatherData(
      condition: 'clear',
      rainIntensity: 0.0,
      temperature: 22,
      humidity: 180,
      windSpeed: 2,
      isDaytime: false,
    );
    await Future.delayed(Duration(seconds: 15));

    // Lặp lại chu kỳ
    await for (final data in weatherStream()) {
      yield data;
    }
  }
}
