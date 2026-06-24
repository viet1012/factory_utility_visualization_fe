import 'dart:math' as math;

import 'package:factory_utility_visualization/weather_widgets/weather/model/rain_splash.dart';

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
