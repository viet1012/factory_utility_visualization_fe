import 'package:flutter/material.dart';

class UtilityDailyHeader extends StatelessWidget {
  final String title;

  const UtilityDailyHeader({super.key, this.title = 'DAILY'});

  static const _accent = Color(0xFF5CFF7A);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, _accent.withValues(alpha: .35)],
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _accent.withValues(alpha: .25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 13,
                  color: _accent,
                ),
                const SizedBox(width: 7),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_accent.withValues(alpha: .35), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
