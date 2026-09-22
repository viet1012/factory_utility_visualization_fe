import 'package:flutter/material.dart';

class MonthLabelBadge extends StatelessWidget {
  final String monthLabel;

  const MonthLabelBadge({super.key, required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1623),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFF294052), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            size: 14,
            color: Color(0xFF8A9BA8),
          ),

          const SizedBox(width: 5),

          Text(
            monthLabel,
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFF22D3EE),
              fontSize: 14,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
