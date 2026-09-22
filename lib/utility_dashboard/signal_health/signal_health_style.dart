import 'package:flutter/material.dart';

/// Feature-local palette for the Signal Health Matrix.
///
/// Declared once here so the widget files never redefine these values.
const kBg = Color(0xff0f172a);
const kCard = Color(0xff111827);
const kCard2 = Color(0xff1e293b);
const kBorder = Color(0xff334155);
const kText = Color(0xfff8fafc);
const kSubText = Color(0xffcbd5e1);
const kBlue = Color(0xff38bdf8);
const kGreen = Color(0xff22c55e);
const kOrange = Color(0xfff97316);
const kRed = Color(0xffef4444);

/// Shared card shell used by the Device Table and the Register Details panel.
BoxDecoration cardDecoration() {
  return BoxDecoration(
    color: kCard,
    border: Border.all(color: kBorder),
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: .25),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
