import 'dart:math' as math;
import 'package:flutter/material.dart';

class RainEffectImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int rainDropCount;
  final double rainSpeed;
  final double rainIntensity;

  const RainEffectImage({
    Key? key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.rainDropCount = 100,
    this.rainSpeed = 1.0,
    this.rainIntensity = 1.0,
  }) : super(key: key);

  @override
  State<RainEffectImage> createState() => _RainEffectImageState();
}

class _RainEffectImageState extends State<RainEffectImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<RainDrop> rainDrops = [];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(milliseconds: 50),
      vsync: this,
    )..repeat();

    _initializeRainDrops();
  }

  void _initializeRainDrops() {
    final random = math.Random();
    rainDrops = List.generate(
      widget.rainDropCount,
      (index) => RainDrop(
        x: random.nextDouble(),
        y: random.nextDouble(),
        length: 10 + random.nextDouble() * 20,
        speed: 0.01 + random.nextDouble() * 0.02,
        opacity: 0.3 + random.nextDouble() * 0.7,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background image
        Image.asset(
          widget.imageUrl,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
        ),

        // Rain effect overlay
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Update rain positions
              for (var drop in rainDrops) {
                drop.update(widget.rainSpeed);
              }

              return CustomPaint(
                painter: RainPainter(
                  rainDrops: rainDrops,
                  intensity: widget.rainIntensity,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class RainDrop {
  double x;
  double y;
  final double length;
  final double speed;
  final double opacity;

  RainDrop({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
    required this.opacity,
  });

  void update(double speedMultiplier) {
    y += speed * speedMultiplier;

    // Reset when drop goes off screen
    if (y > 1.0) {
      y = -0.1;
      x = math.Random().nextDouble();
    }
  }
}

class RainPainter extends CustomPainter {
  final List<RainDrop> rainDrops;
  final double intensity;

  RainPainter({required this.rainDrops, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    for (var drop in rainDrops) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(drop.opacity * intensity)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      final startX = drop.x * size.width;
      final startY = drop.y * size.height;
      final endY = startY + drop.length;

      // Main rain line
      canvas.drawLine(Offset(startX, startY), Offset(startX, endY), paint);

      // Glow effect
      paint.strokeWidth = 3;
      paint.color = Colors.white.withOpacity(drop.opacity * 0.2 * intensity);
      canvas.drawLine(Offset(startX, startY), Offset(startX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(RainPainter oldDelegate) => true;
}

// Advanced Rain Effect với ripples và splashes
class AdvancedRainEffect extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;

  const AdvancedRainEffect({
    Key? key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<AdvancedRainEffect> createState() => _AdvancedRainEffectState();
}

class _AdvancedRainEffectState extends State<AdvancedRainEffect>
    with TickerProviderStateMixin {
  late AnimationController _rainController;
  late AnimationController _splashController;

  List<RainDrop> rainDrops = [];
  List<RainSplash> splashes = [];

  @override
  void initState() {
    super.initState();

    _rainController = AnimationController(
      duration: Duration(milliseconds: 50),
      vsync: this,
    )..repeat();

    _splashController = AnimationController(
      duration: Duration(milliseconds: 100),
      vsync: this,
    )..repeat();

    _initializeRain();
  }

  void _initializeRain() {
    final random = math.Random();
    rainDrops = List.generate(150, (index) {
      return RainDrop(
        x: random.nextDouble(),
        y: random.nextDouble(),
        length: 15 + random.nextDouble() * 25,
        speed: 0.015 + random.nextDouble() * 0.025,
        opacity: 0.4 + random.nextDouble() * 0.6,
      );
    });
  }

  void _updateSplashes() {
    final random = math.Random();

    // Remove old splashes
    splashes.removeWhere((splash) => splash.age > 1.0);

    // Add new splashes randomly
    if (random.nextDouble() < 0.3) {
      splashes.add(
        RainSplash(
          x: random.nextDouble(),
          y: 0.9 + random.nextDouble() * 0.1,
          age: 0,
        ),
      );
    }

    // Update existing splashes
    for (var splash in splashes) {
      splash.age += 0.05;
    }
  }

  @override
  void dispose() {
    _rainController.dispose();
    _splashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background image
        Image.asset(
          widget.imageUrl,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
        ),

        // Dark overlay for better rain visibility
        Positioned.fill(
          child: Container(color: Colors.black.withOpacity(0.15)),
        ),

        // Rain and splash effects
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge([_rainController, _splashController]),
            builder: (context, child) {
              for (var drop in rainDrops) {
                drop.update(1.0);
              }
              _updateSplashes();

              return CustomPaint(
                painter: AdvancedRainPainter(
                  rainDrops: rainDrops,
                  splashes: splashes,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class RainSplash {
  final double x;
  final double y;
  double age;

  RainSplash({required this.x, required this.y, required this.age});
}

class AdvancedRainPainter extends CustomPainter {
  final List<RainDrop> rainDrops;
  final List<RainSplash> splashes;

  AdvancedRainPainter({required this.rainDrops, required this.splashes});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw rain drops
    for (var drop in rainDrops) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(drop.opacity)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      final startX = drop.x * size.width;
      final startY = drop.y * size.height;
      final endY = startY + drop.length;

      // Main drop
      canvas.drawLine(Offset(startX, startY), Offset(startX, endY), paint);

      // Glow
      paint.strokeWidth = 4;
      paint.color = Colors.cyanAccent.withOpacity(drop.opacity * 0.3);
      canvas.drawLine(Offset(startX, startY), Offset(startX, endY), paint);
    }

    // Draw splashes
    for (var splash in splashes) {
      final opacity = (1.0 - splash.age).clamp(0.0, 1.0);
      final radius = splash.age * 15;

      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final center = Offset(splash.x * size.width, splash.y * size.height);

      canvas.drawCircle(center, radius, paint);

      // Inner circle
      paint.strokeWidth = 1;
      canvas.drawCircle(center, radius * 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(AdvancedRainPainter oldDelegate) => true;
}

// Cách sử dụng trong code của bạn:

// Option 1: Rain đơn giản
Widget _buildFactoryMapWithRain() {
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
          // Image với rain effect
          RainEffectImage(
            imageUrl: 'images/factory.jpg',
            fit: BoxFit.fill,
            rainDropCount: 100,
            rainSpeed: 1.5,
            rainIntensity: 0.8,
          ),

          // Các facility boxes và overlays khác
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

          // ... facility info boxes ...
        ],
      ),
    ),
  );
}

// Option 2: Rain với splashes (advanced)
Widget _buildFactoryMapWithAdvancedRain() {
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
          AdvancedRainEffect(imageUrl: 'images/factory.jpg', fit: BoxFit.fill),

          // ... overlay và facility boxes ...
        ],
      ),
    ),
  );
}
