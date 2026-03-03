import 'package:flutter/material.dart';

class UtilityDashboardOverviewHourlyHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  final bool loading;

  final IconData icon;
  final Color backgroundColor;
  final bool showDivider;

  const UtilityDashboardOverviewHourlyHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.loading = false,
    this.icon = Icons.analytics_outlined,
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
            ? Border(bottom: BorderSide(color: Colors.white.withOpacity(0.10)))
            : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),

          // ✅ 1 Text duy nhất -> không bị chia 50/50
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  if (hasSub) ...[
                    const TextSpan(text: '   '),
                    TextSpan(
                      text: sub,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.60),
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
