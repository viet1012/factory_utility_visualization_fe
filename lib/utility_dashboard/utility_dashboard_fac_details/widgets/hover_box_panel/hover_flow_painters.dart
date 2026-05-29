import 'dart:math' as math;

import 'package:flutter/material.dart';

class ElectricFlowPainter extends CustomPainter {
  final double progress;

  ElectricFlowPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    final paint = Paint()
      ..color = const Color(0xFFFFB400).withOpacity(0.6 * (1 - progress))
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Draw 2-3 lightning bolts
    for (int bolt = 0; bolt < 2; bolt++) {
      final offset = (bolt - 0.5) * 4.0;
      final path = Path();
      path.moveTo(0, size.height / 2 + offset);

      for (int i = 0; i < 6; i++) {
        final x = (size.width / 6) * (i + progress * 2);
        final y =
            size.height / 2 +
            offset +
            (random.nextDouble() - 0.5) * 3 +
            math.sin((i + progress * 2) * math.pi) * 2;

        path.lineTo(x.clamp(0, size.width), y);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(ElectricFlowPainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════════════════════
// 💧 WATER FLOW PAINTER
// ═══════════════════════════════════════════════════════════════════════════

class WaterFlowPainter extends CustomPainter {
  final double progress;

  WaterFlowPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF0369A1).withOpacity(0.5 * (1 - progress));

    // Draw expanding wave rings
    for (int i = 0; i < 3; i++) {
      final radius = (size.width / 2) * (progress + (i * 0.3)) % 1.0;
      final waveOpacity = (1 - (progress + (i * 0.3)) % 1.0);
      paint.color = const Color(0xFF0369A1).withOpacity(0.5 * waveOpacity);

      canvas.drawCircle(Offset(size.width / 2, size.height / 2), radius, paint);
    }
  }

  @override
  bool shouldRepaint(WaterFlowPainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════════════════════
// 🌬 AIR FLOW PAINTER
// ═══════════════════════════════════════════════════════════════════════════

class AirFlowPainter extends CustomPainter {
  final double progress;

  AirFlowPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFA78BFA).withOpacity(0.6);

    // Draw 2 sine wave streams
    for (int stream = 0; stream < 2; stream++) {
      final path = Path();
      final offset = (stream - 0.5) * 4.0;
      path.moveTo(0, size.height / 2 + offset);

      for (int i = 0; i < 8; i++) {
        final x = (size.width / 8) * (i + progress);
        final y =
            size.height / 2 + offset + math.sin((i + progress) * math.pi) * 2;

        path.lineTo(x.clamp(0, size.width), y);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(AirFlowPainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════════════════════
// ✨ PARTICLE FLOW PAINTER (Default)
// ═══════════════════════════════════════════════════════════════════════════

class ParticleFlowPainter extends CustomPainter {
  final double progress;

  ParticleFlowPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF38BDF8).withOpacity(0.7 * (1 - progress));

    // Draw 3 flowing particles
    for (int i = 0; i < 3; i++) {
      final particleProgress = (progress + (i * 0.3)) % 1.0;
      final x = size.width * particleProgress;
      final y = size.height / 2;

      canvas.drawCircle(Offset(x, y), 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(ParticleFlowPainter oldDelegate) => true;
}

class PremiumIconEffectPainter extends CustomPainter {
  final double progress;
  final Color color;
  final String? category;

  PremiumIconEffectPainter({
    required this.progress,
    required this.color,
    required this.category,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rect = Offset.zero & size;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = SweepGradient(
        transform: GradientRotation(progress * math.pi * 2),
        colors: [
          Colors.transparent,
          color.withOpacity(0.20),
          color.withOpacity(0.95),
          Colors.white.withOpacity(0.80),
          color.withOpacity(0.25),
          Colors.transparent,
        ],
      ).createShader(rect);

    canvas.drawCircle(center, 18, ringPaint);

    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withOpacity((1 - progress) * 0.30);

    canvas.drawCircle(center, 12 + progress * 8, pulsePaint);

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withOpacity(0.85);

    for (int i = 0; i < 3; i++) {
      final p = (progress + i * 0.33) % 1.0;
      final angle = p * math.pi * 2;

      final radius = switch ((category ?? '').toLowerCase()) {
        'water' => 13 + math.sin(p * math.pi * 2) * 2,
        'air' || 'compressor_air' => 15 + math.sin(p * math.pi * 4) * 1.8,
        'power' || 'electricity' || 'electric' => 16,
        _ => 15,
      };

      final offset = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );

      canvas.drawCircle(offset, 1.35, dotPaint);
    }

    final shinePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white.withOpacity(0.28), Colors.transparent],
      ).createShader(Rect.fromLTWH(7, 6, 16, 10));

    canvas.drawOval(Rect.fromLTWH(8, 6, 14, 8), shinePaint);
  }

  @override
  bool shouldRepaint(covariant PremiumIconEffectPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.category != category;
  }
}

class ScadaEnergyIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String cate;
  final Animation<double> animation;

  const ScadaEnergyIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.cate,
    required this.animation,
  });

  bool get _isAir {
    final c = cate.toLowerCase();
    return c.contains('air') || c.contains('compressor');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final progress = animation.value;
        final pulse = 1.0 + math.sin(progress * math.pi * 2) * 0.055;

        return SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.36),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),

              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.18),
                      color.withOpacity(0.18),
                      Colors.black.withOpacity(0.10),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.20),
                    width: 1,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: CustomPaint(painter: _getFlowPainter(progress)),
                      ),
                    ),
                    Icon(icon, color: color, size: 22),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  CustomPainter _getFlowPainter(double progress) {
    final c = cate.toLowerCase();

    if (c.contains('power') || c.contains('electric') || c.contains('energy')) {
      return ElectricFlowPainter(progress);
    }

    if (c.contains('water')) {
      return WaterFlowPainter(progress);
    }

    if (c.contains('air') || c.contains('compressor')) {
      return AirFlowPainter(progress);
    }

    return ParticleFlowPainter(progress);
  }
}
