import 'package:flutter/material.dart';

class MonthLabelBadge extends StatelessWidget {
  final String monthLabel;

  final double height;
  final double fontSize;
  final double iconSize;

  const MonthLabelBadge({
    super.key,
    required this.monthLabel,
    this.height = 26,
    this.fontSize = 14,
    this.iconSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_month_rounded,
            color: Colors.white70,
            size: iconSize,
          ),

          const SizedBox(width: 4),

          Text(
            monthLabel,
            style: TextStyle(
              color: const Color(0xff22d3ee),
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
