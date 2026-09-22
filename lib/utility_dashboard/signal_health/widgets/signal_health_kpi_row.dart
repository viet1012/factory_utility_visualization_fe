import 'package:flutter/material.dart';

import '../signal_health_style.dart';

class SignalHealthKpiRow extends StatelessWidget {
  final int totalFac;
  final int totalBoxDevice;
  final int totalRegister;
  final int totalNgRegister;

  const SignalHealthKpiRow({
    super.key,
    required this.totalFac,
    required this.totalBoxDevice,
    required this.totalRegister,
    required this.totalNgRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _KpiCard(
          title: 'FACILITY',
          value: totalFac,
          subtitle: 'Tổng số FAC',
          icon: Icons.factory,
          color: const Color(0xff2563eb),
        ),
        const SizedBox(width: 16),
        _KpiCard(
          title: 'BOX DEVICE',
          value: totalBoxDevice,
          subtitle: 'Tổng số BoxDevice',
          icon: Icons.memory,
          color: const Color(0xff7c3aed),
        ),
        const SizedBox(width: 16),
        _KpiCard(
          title: 'REGISTER',
          value: totalRegister,
          subtitle: 'Tổng số Register',
          icon: Icons.menu_book,
          color: const Color(0xfff97316),
        ),
        const SizedBox(width: 16),
        _KpiCard(
          title: 'NG REGISTER',
          value: totalNgRegister,
          subtitle: 'Tổng số Register lỗi',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xffdc2626),
          danger: true,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final int value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool danger;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          // Only the danger KPI (NG REGISTER) keeps an accent; the rest stay
          // neutral so they do not all shout at once.
          color: danger ? kRed.withValues(alpha: .10) : kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: danger
                ? kRed.withValues(alpha: .40)
                : kBorder.withValues(alpha: .5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: kText,
                    height: 1.1,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: kSubText,
                    fontSize: 11,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
