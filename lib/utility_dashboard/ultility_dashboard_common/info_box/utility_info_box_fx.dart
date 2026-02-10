import 'package:flutter/material.dart';

class UtilityInfoBoxFx {
  final TickerProvider vsync;

  late final AnimationController hoverCtrl;
  late final AnimationController slideCtrl;
  late final AnimationController pulseCtrl;

  late final Animation<double> scale;
  late final Animation<double> rotate;
  late final Animation<Offset> slide;
  late final Animation<double> pulse;

  UtilityInfoBoxFx(this.vsync);

  void init() {
    hoverCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: vsync,
    );

    slideCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: vsync,
    );

    pulseCtrl = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: vsync,
    )..repeat(reverse: true);

    scale = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: hoverCtrl, curve: Curves.easeOutCubic));

    rotate = Tween<double>(
      begin: 0,
      end: 0.02,
    ).animate(CurvedAnimation(parent: hoverCtrl, curve: Curves.easeInOut));

    slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: slideCtrl, curve: Curves.easeOutCubic));

    pulse = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: pulseCtrl, curve: Curves.easeInOut));

    slideCtrl.forward();
  }

  void onHover(bool isEnter) {
    if (isEnter) {
      hoverCtrl.forward();
    } else {
      hoverCtrl.reverse();
    }
  }

  Listenable get listenable => Listenable.merge([scale, rotate]);

  void dispose() {
    hoverCtrl.dispose();
    slideCtrl.dispose();
    pulseCtrl.dispose();
  }
}
