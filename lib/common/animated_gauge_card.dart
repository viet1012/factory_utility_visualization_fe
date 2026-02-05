import 'package:flutter/material.dart';

import 'gauge_status.dart';
class AnimatedGaugeCard extends StatelessWidget {
  final Widget gauge;
  final Color statusColor;
  final String statusText;

  const AnimatedGaugeCard({
    super.key,
    required this.gauge,
    required this.statusColor,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1A237E),
            Colors.black,
            Color(0xFF0D47A1),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(child: gauge),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GaugeStatus(
              color: statusColor,
              text: statusText,
            ),
          ),
        ],
      ),
    );
  }
}
