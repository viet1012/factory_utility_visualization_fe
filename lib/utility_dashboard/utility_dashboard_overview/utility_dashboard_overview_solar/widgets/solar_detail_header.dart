import 'package:flutter/material.dart';

import '../../utility_dashboard_overview_widgets/month_label_badge.dart';
import '../helpers/solar_detail_formatters.dart';

/// Header cua Solar Detail: back, tieu de, month badge, facility badge, refresh.
class SolarDetailHeader extends StatelessWidget {
  final String facId;

  /// Gia tri hien thi tren [MonthLabelBadge].
  final String monthLabel;

  final bool refreshing;

  final VoidCallback onBack;

  final VoidCallback onRefresh;

  const SolarDetailHeader({
    super.key,
    required this.facId,
    required this.monthLabel,
    required this.refreshing,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xff03111d).withValues(alpha: .95),
        border: Border(
          bottom: BorderSide(
            color: SolarDetailColors.cyan.withValues(alpha: .15),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),

          const SizedBox(width: 12),

          const Text(
            'SOLAR ENERGY ANALYTICS',
            style: TextStyle(
              color: SolarDetailColors.yellow,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: .6,
            ),
          ),

          const Spacer(),

          MonthLabelBadge(monthLabel: monthLabel),

          const SizedBox(width: 10),

          _facilityBadge(),

          const SizedBox(width: 10),

          IconButton(
            tooltip: 'Refresh',
            onPressed: refreshing ? null : onRefresh,
            icon: const Icon(
              Icons.refresh_rounded,
              color: SolarDetailColors.cyan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _facilityBadge() {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: SolarDetailColors.cyan.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SolarDetailColors.cyan.withValues(alpha: .35),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        facId.toUpperCase(),
        style: const TextStyle(
          color: SolarDetailColors.cyan,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
