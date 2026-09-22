import 'package:flutter/material.dart';

class UtilityHourlyHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  final Color backgroundColor;
  final bool showDivider;

  const UtilityHourlyHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.backgroundColor = const Color(0xFF0B1324),
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final sub = subtitle?.trim();
    final hasSub = sub != null && sub.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: showDivider
            ? Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
              )
            : null,
      ),
      child: Row(
        children: [
          // ✅ 1 Text duy nhất -> không bị chia 50/50
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: title,
                    style: TextStyle(
                      color: const Color(0xFF5CFF7A).withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (hasSub) ...[
                    const TextSpan(text: '   '),
                    TextSpan(
                      text: sub,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
