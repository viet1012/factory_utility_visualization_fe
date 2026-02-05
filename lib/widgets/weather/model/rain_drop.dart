import 'dart:math' as math;

import 'package:factory_utility_visualization/widgets/weather/model/rain_splash.dart';

import '../../rain_effect_image.dart';

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
