import 'package:flutter/material.dart';

class PanelStyle {
  static const panelBg = Color(0xF20B1324);
  static const headerBg = Color(0xFF13223A);
  static const accent = Color(0xFF38BDF8);

  static const double scadaW = 72;
  static const double plcW = 78;
  static const double valueW = 112;
  static const double timeW = 92;
  static const double gap = 12;

  static final radius = BorderRadius.circular(18);

  static final panelDecoration = BoxDecoration(
    color: panelBg,
    borderRadius: radius,
    border: Border.all(color: accent.withOpacity(0.36)),
    boxShadow: [
      const BoxShadow(
        color: Colors.black54,
        blurRadius: 24,
        offset: Offset(0, 12),
      ),
      BoxShadow(
        color: accent.withOpacity(0.16),
        blurRadius: 18,
        spreadRadius: 1,
      ),
    ],
  );
}

class TextStyles {
  static final header = TextStyle(
    color: Colors.white.withOpacity(0.74),
    fontWeight: FontWeight.w800,
    fontSize: 14.5,
    letterSpacing: 0.2,
  );

  static final cell = TextStyle(
    color: Colors.white.withOpacity(0.90),
    fontWeight: FontWeight.w800,
    fontSize: 15.5,
    height: 1.0,
  );

  static const value = TextStyle(
    color: PanelStyle.accent,
    fontWeight: FontWeight.w900,
    fontSize: 16,
    letterSpacing: 0.3,
  );
}
