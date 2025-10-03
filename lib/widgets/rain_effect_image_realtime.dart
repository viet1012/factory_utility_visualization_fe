import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Weather API Service
class WeatherApiService {
  final String apiKey = 'f0481fa18fbc9c353fa3b3530208e8f1';

  Future<WeatherData?> fetchWeatherData() async {
    try {
      final url =
          'https://api.openweathermap.org/data/2.5/weather?lat=10.889414655521932&lon=106.72094061256969&appid=$apiKey&units=metric';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherData.fromJson(data);
      } else {
        print('Error response: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error fetching weather: $e');
    }
    return null;
  }

  // Stream realtime weather (update mỗi 60 phút)
  Stream<WeatherData> weatherStream() async* {
    while (true) {
      final data = await fetchWeatherData();
      if (data != null) yield data;
      await Future.delayed(const Duration(minutes: 15));
    }
  }
}

// Weather Data Model
class WeatherData {
  final String condition; // "rain", "clear", "cloudy", "storm"
  final double rainIntensity; // 0.0 - 1.0
  final double temperature;
  final double humidity;
  final double windSpeed;
  final bool isDaytime; // true = ban ngày, false = ban đêm

  WeatherData({
    required this.condition,
    required this.rainIntensity,
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    this.isDaytime = true, // default là ban ngày
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final weatherMain = json['weather'][0]['main'].toString().toLowerCase();

    // lấy lượng mưa (mm/h)
    final rain = (json['rain'] != null)
        ? (json['rain']['1h'] ?? json['rain']['3h'] ?? 0.0)
        : 0.0;

    // intensity = tỷ lệ 0.0 - 1.0
    double intensity;
    if (rain > 0) {
      intensity = (rain / 10.0).clamp(0.0, 1.0);
    } else if (weatherMain.contains('rain') ||
        weatherMain.contains('drizzle') ||
        weatherMain.contains('thunderstorm')) {
      intensity = 0.5; // mặc định có mưa vừa
    } else {
      intensity = 0.0;
    }

    final sunrise = json['sys']['sunrise']; // timestamp UTC
    final sunset = json['sys']['sunset']; // timestamp UTC
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    bool isDay = now >= sunrise && now <= sunset;

    print("DEBUG: condition=$weatherMain, rain=$rain, intensity=$intensity");

    return WeatherData(
      condition: weatherMain,
      rainIntensity: intensity,
      temperature: (json['main']['temp'] ?? 0.0).toDouble(),
      humidity: (json['main']['humidity'] ?? 0.0).toDouble(),
      windSpeed: (json['wind']['speed'] ?? 0.0).toDouble(),
      isDaytime: isDay,
    );
  }

  // Custom API format
  factory WeatherData.fromCustomJson(Map<String, dynamic> json) {
    return WeatherData(
      condition: json['condition'] ?? 'clear',
      rainIntensity: (json['rain_intensity'] ?? 0.0).toDouble(),
      temperature: (json['temperature'] ?? 25.0).toDouble(),
      humidity: (json['humidity'] ?? 60.0).toDouble(),
      windSpeed: (json['wind_speed'] ?? 0.0).toDouble(),
    );
  }
}

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

  void _startWeatherMonitoring1() {
    // Fetch initial weather
    _updateWeather();

    // Update every 10 minutes
    Timer.periodic(Duration(minutes: 10), (timer) {
      _updateWeather();
    });
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

class RainDrop {
  double x;
  double y;
  final double length;
  final double speed;
  final double opacity;
  final double windOffset;

  RainDrop({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
    required this.opacity,
    this.windOffset = 0,
  });

  // void update(double intensityMultiplier) {
  //   y += speed * intensityMultiplier;
  //   // x += (windOffset / 100); // Wind effect
  //
  //   // Reset when drop goes off screen
  //   if (y > 1.0) {
  //     y = -0.1;
  //     x = math.Random().nextDouble();
  //   }
  // }

  void update(double intensityMultiplier, List<RainSplash> splashes) {
    y += speed * intensityMultiplier;

    // Nếu rơi xuống hết màn hình thì reset + tạo splash
    if (y > 1.0) {
      // Tạo splash tại vị trí rơi
      splashes.add(
        RainSplash(
          x: x,
          y: 1.0, // mép dưới màn hình
          age: 0,
        ),
      );

      // Reset hạt mưa lại trên cao
      y = -0.1;
      x = math.Random().nextDouble();
    }
  }
}

class RainSplash {
  final double x;
  final double y;
  double age;

  RainSplash({required this.x, required this.y, required this.age});
}

class ApiRainPainter extends CustomPainter {
  final List<RainDrop> rainDrops;
  final List<RainSplash> splashes;

  final double intensity;
  final double windSpeed;
  final bool isDay;

  ApiRainPainter({
    required this.splashes,
    required this.rainDrops,
    required this.intensity,
    required this.windSpeed,
    this.isDay = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var drop in rainDrops) {
      final paint = Paint()
        ..color = (isDay ? Colors.white : Colors.cyanAccent)
        ..strokeWidth = 1.3 + (intensity * 0.3)
        ..strokeCap = StrokeCap.round;

      final startX = drop.x * size.width;
      final startY = drop.y * size.height;
      final windEffect = (windSpeed / 50).clamp(-5.0, 5.0);
      final endX = startX + windEffect * drop.length; // Wind angle
      final dropSize = drop.length * (0.2 + intensity); // giảm base size
      // final endY = startY + drop.length;

      // mưa càng nhẹ → hạt càng nhỏ:
      final endY = startY + dropSize;
      // Main rain line with wind angle
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);

      // Glow effect
      if (!isDay || intensity > 0.5) {
        // paint.strokeWidth = 3;

        paint.strokeWidth = (0.5 + intensity * 0.5); // mỏng hơn
        paint.color = (isDay ? Colors.cyanAccent : Colors.blueAccent)
            .withOpacity(drop.opacity * 0.3 * intensity);
        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
      }
    }

    // Draw splashes
    for (var splash in splashes) {
      final opacity = (1.0 - splash.age).clamp(0.0, 1.0);
      final radius = splash.age * 15;

      final paint = Paint()
        ..color = (isDay ? Colors.white : Colors.cyanAccent).withOpacity(
          opacity * 0.5,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final center = Offset(splash.x * size.width, splash.y * size.height);

      canvas.drawCircle(center, radius, paint);

      // Vẽ thêm nhiều splash nhỏ lệch tâm (tung toé ra xung quanh)
      // for (int i = 0; i < 3; i++) {
      //   final dx = (math.Random().nextDouble() - 0.5) * 30; // lệch trái phải
      //   final dy = (math.Random().nextDouble() - 0.5) * 20; // lệch lên xuống
      //   final offset = center.translate(dx, dy);
      //
      //   final randomRadius = radius * (0.3 + math.Random().nextDouble() * 0.7);
      //
      //   canvas.drawCircle(offset, randomRadius, paint);
      // }
      // Inner circle
      paint.strokeWidth = 1;
      canvas.drawCircle(center, radius * 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(ApiRainPainter oldDelegate) => true;
}

// Sử dụng trong Factory Dashboard
class FactoryDashboardWithWeather extends StatelessWidget {
  // final WeatherApiService weatherService = WeatherApiService();
  final WeatherApiService weatherService = MockWeatherService(); // Dùng mock
  final String mainImageUrl = 'images/factory.jpg';

  FactoryDashboardWithWeather({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.35),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Image with API-controlled rain
            ApiControlledRainImage(
              imageUrl: mainImageUrl,
              weatherService: weatherService,
              fit: BoxFit.fill,
            ),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.transparent,
                    Colors.black.withOpacity(0.15),
                  ],
                ),
              ),
            ),

            // Facility boxes và các elements khác...
          ],
        ),
      ),
    );
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
