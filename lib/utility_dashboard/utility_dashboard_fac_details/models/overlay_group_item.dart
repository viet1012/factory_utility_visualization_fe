import 'dart:ui';

class OverlayGroupItem {
  final Offset pos01;
  final String direction;
  final String? color;

  const OverlayGroupItem({
    required this.pos01,
    required this.direction,
    this.color,
  });
}
