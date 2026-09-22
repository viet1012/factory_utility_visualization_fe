import 'package:flutter/material.dart';

import '../signal_health_style.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool? isNg;

  const StatusBadge(this.status, {super.key, this.isNg});

  @override
  Widget build(BuildContext context) {
    final isOk = isNg == null ? status == 'OK' : !isNg!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOk
            ? kGreen.withValues(alpha: .14)
            : kRed.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOk
              ? kGreen.withValues(alpha: .55)
              : kRed.withValues(alpha: .55),
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isOk ? kGreen : kRed,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}
