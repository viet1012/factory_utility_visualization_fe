import 'dart:math' as math;

import 'package:factory_utility_visualization/weather_widgets/weather/model/rain_splash.dart';

class RainDrop {
  double x;
  double y;
  final double length;
  final double speed;
  final double opacity;
  final double windOffset;

  // Dùng chung 1 Random instance thay vì tạo mới mỗi lần reset giọt mưa.
  // math.Random() cấp phát mới mỗi lần gọi khá tốn nếu lặp lại liên tục.
  static final math.Random _rng = math.Random();

  RainDrop({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
    required this.opacity,
    this.windOffset = 0,
  });

  /// [maxSplashes] chặn splash list phình to không kiểm soát khi
  /// nhiều giọt cùng chạm đáy trong 1 frame — trước đây add() không
  /// giới hạn, có thể vượt qua cap 40 đặt ở State bên ngoài.
  void update(
    double intensityMultiplier,
    List<RainSplash> splashes, {
    int maxSplashes = 60,
  }) {
    y += speed * intensityMultiplier;

    if (y > 1.0) {
      if (splashes.length < maxSplashes) {
        splashes.add(RainSplash(x: x, y: 1.0, age: 0));
      }

      // Reset hạt mưa lại trên cao
      y = -0.1;
      x = _rng.nextDouble();
    }
  }
}
