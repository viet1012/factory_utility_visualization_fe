import 'package:flutter/material.dart';

import '../signal_health_style.dart';

class SignalHealthHeader extends StatelessWidget {
  final String lastUpdated;
  final VoidCallback onRefresh;

  const SignalHealthHeader({
    super.key,
    required this.lastUpdated,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: kBlue.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: kBlue.withValues(alpha: .35)),
          ),
          child: const Icon(Icons.monitor_heart, color: kBlue, size: 20),
        ),

        const SizedBox(width: 10),

        const Text(
          'Signal Health Matrix',
          style: TextStyle(
            fontSize: 20,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: kText,
          ),
        ),

        // Đẩy phần bên dưới sang góc phải
        const Spacer(),

        Text(
          'Last updated: $lastUpdated',
          style: const TextStyle(fontSize: 11, color: kSubText),
        ),

        const SizedBox(width: 10),

        SizedBox(
          height: 34,
          child: OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 17),
            label: const Text(
              'Refresh',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: kBlue,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: BorderSide(color: kBlue.withValues(alpha: .45)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
