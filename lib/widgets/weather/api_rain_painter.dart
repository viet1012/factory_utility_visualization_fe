import 'package:flutter/material.dart';

import '../rain_effect_image.dart';
import 'model/rain_drop.dart';
import 'model/rain_splash.dart';

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
