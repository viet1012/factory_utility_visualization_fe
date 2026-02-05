import 'package:flutter/material.dart';

class GaugeCenterText extends StatelessWidget {
  final double value;
  final String unit;
  final double percent; // 0..1
  final Color color;

  const GaugeCenterText({
    super.key,
    required this.value,
    required this.unit,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value.toStringAsFixed(1),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(unit, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        Text(
          '${(percent * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
