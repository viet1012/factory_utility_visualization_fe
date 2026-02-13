// overlay_layouts.dart
import 'dart:ui';

/// 0..1 theo chi?u r?ng/chi?u cao c?a ?nh
final Map<String, Offset> facAAddressPos = {
  'D1': const Offset(0.5, 0.18),
  'D18': const Offset(0.4, 0.22),
  'D20': const Offset(0.1, 0.7),
  'D22': const Offset(0.82, 0.22),
  'D24': const Offset(0.86, 0.22),
};
final Map<String, Map<String, Offset>> facLayoutsSeed = {
  'Fac_A': Map<String, Offset>.from(facAAddressPos),
  'Fac_B': Map<String, Offset>.from(facAAddressPos),
};
