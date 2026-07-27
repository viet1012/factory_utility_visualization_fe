import 'package:flutter/material.dart';

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
    if (rainDrops.isEmpty && splashes.isEmpty) return;

    final width = size.width;
    final height = size.height;
    final windEffect = (windSpeed / 50).clamp(-5.0, 5.0);

    // =====================================================
    // RAIN DROPS
    // Gộp toàn bộ giọt mưa thành 1 Path duy nhất và vẽ bằng
    // 1-2 lệnh drawPath, thay vì tạo Paint() mới + gọi drawLine()
    // riêng cho từng giọt (trước đây: ~100 giọt × 2 draw = ~200
    // drawLine + ~200 Paint alloc MỖI FRAME → đây là nguyên nhân
    // chính gây lag/giật).
    // Paint color/width giống nhau cho mọi giọt trong cùng 1 frame
    // (chỉ phụ thuộc intensity/isDay, không phụ thuộc từng giọt),
    // nên gộp path không làm sai lệch hình ảnh.
    // =====================================================
    if (rainDrops.isNotEmpty) {
      final mainPath = Path();

      for (final drop in rainDrops) {
        final startX = drop.x * width;
        final startY = drop.y * height;
        final dropSize = drop.length * (0.2 + intensity);
        final endX = startX + windEffect * drop.length;
        final endY = startY + dropSize;

        mainPath.moveTo(startX, startY);
        mainPath.lineTo(endX, endY);
      }

      final mainPaint = Paint()
        ..color = isDay ? Colors.white : Colors.cyanAccent
        ..strokeWidth = 1.3 + (intensity * 0.3)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawPath(mainPath, mainPaint);

      // Glow — tái dùng path đã gộp, không lặp lại vòng for lần 2.
      if (!isDay || intensity > 0.5) {
        final glowPaint = Paint()
          ..color = (isDay ? Colors.cyanAccent : Colors.blueAccent).withOpacity(
            (0.3 * intensity).clamp(0.0, 1.0),
          )
          ..strokeWidth = (0.5 + intensity * 0.5)
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        canvas.drawPath(mainPath, glowPaint);
      }
    }

    // =====================================================
    // SPLASHES
    // Mỗi splash có age/opacity/radius riêng nên không gộp path
    // được, nhưng TÁI DÙNG 1 Paint object cho toàn bộ vòng lặp
    // thay vì new Paint() mỗi splash mỗi frame.
    // =====================================================
    if (splashes.isNotEmpty) {
      final baseColor = isDay ? Colors.white : Colors.cyanAccent;
      final splashPaint = Paint()..style = PaintingStyle.stroke;

      for (final splash in splashes) {
        final opacity = (1.0 - splash.age).clamp(0.0, 1.0);
        final radius = splash.age * 15;
        final center = Offset(splash.x * width, splash.y * height);

        splashPaint
          ..color = baseColor.withOpacity(opacity * 0.5)
          ..strokeWidth = 2;
        canvas.drawCircle(center, radius, splashPaint);

        splashPaint.strokeWidth = 1;
        canvas.drawCircle(center, radius * 0.5, splashPaint);
      }
    }
  }

  // rainDrops/splashes bị mutate in-place (cùng reference mỗi frame),
  // nên so sánh reference sẽ luôn "bằng nhau" dù dữ liệu đã đổi giá trị
  // bên trong — giữ true là bắt buộc ở đây. Tần suất repaint thực tế
  // đã được throttle ở phía State (frame-skip ~30fps), nên vẫn hiệu quả.
  @override
  bool shouldRepaint(ApiRainPainter oldDelegate) => true;
}
