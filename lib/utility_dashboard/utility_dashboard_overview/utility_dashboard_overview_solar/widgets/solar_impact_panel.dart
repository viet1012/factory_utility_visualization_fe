import 'package:flutter/material.dart';

import '../helpers/solar_detail_formatters.dart';
import '../models/solar_detail_data.dart';
import 'solar_detail_panel.dart';

/// Panel COST & ENVIRONMENT: chi phi, tiet kiem va tac dong moi truong.
class SolarImpactPanel extends StatelessWidget {
  final SolarDetailData data;

  /// yyyyMM, dung cho tieu de panel.
  final String month;

  const SolarImpactPanel({super.key, required this.data, required this.month});

  @override
  Widget build(BuildContext context) {
    final cost = data.costImpact;
    final env = data.environmentalImpact;

    return SolarDetailPanel(
      title:
          'COST & ENVIRONMENT • '
          '${SolarDetailFormatters.monthLabel(month).toUpperCase()}',
      titleColor: SolarDetailColors.green,
      child: Expanded(
        child: Column(
          children: [
            // =====================================================
            // COST
            // =====================================================
            Expanded(
              flex: 6,
              child: Row(
                children: [
                  Expanded(
                    child: _miniImpactValue(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'NORMAL COST',
                      value:
                          '\$${SolarDetailFormatters.money(cost.normalCostUsd)}',
                      color: SolarDetailColors.cyan,
                      note: 'EVN × 100%',
                    ),
                  ),

                  const SizedBox(width: 6),

                  Expanded(
                    child: _miniImpactValue(
                      icon: Icons.solar_power_rounded,
                      title: 'SOLAR COST',
                      value:
                          '\$${SolarDetailFormatters.money(cost.solarCostUsd)}',
                      color: SolarDetailColors.yellow,
                      note: 'EVN × 83%',
                    ),
                  ),

                  const SizedBox(width: 6),

                  Expanded(
                    child: _miniImpactValue(
                      icon: Icons.savings_rounded,
                      title: 'SAVING',
                      value: '\$${SolarDetailFormatters.money(cost.savingUsd)}',
                      color: SolarDetailColors.green,
                      note: '${cost.savingPercent.toStringAsFixed(0)}%',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            Divider(height: 1, color: Colors.white.withValues(alpha: .08)),

            const SizedBox(height: 5),

            // =====================================================
            // ENVIRONMENT
            // =====================================================
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Expanded(
                    child: _impactEnvironment(
                      icon: Icons.eco_rounded,
                      title: 'CO₂ AVOIDED',
                      value: '${env.co2Ton.toStringAsFixed(2)} ton',
                    ),
                  ),

                  _verticalDivider(),

                  Expanded(
                    child: _impactEnvironment(
                      icon: Icons.park_rounded,
                      title: 'TREES',
                      value: SolarDetailFormatters.compact(env.equivalentTrees),
                    ),
                  ),

                  _verticalDivider(),

                  Expanded(
                    child: _impactEnvironment(
                      icon: Icons.science_outlined,
                      title: 'CO₂ FACTOR',
                      value: '${env.co2Factor}',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            Container(
              height: 25,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: SolarDetailColors.green.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: SolarDetailColors.green.withValues(alpha: .13),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 22,
                    color: Colors.white38,
                  ),

                  const SizedBox(width: 5),

                  const Expanded(
                    child: Text(
                      'Solar electricity rate = EVN tariff × 83%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),

                  Text(
                    'SAVE ${cost.savingPercent.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: SolarDetailColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniImpactValue({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? note,
  }) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: .15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),

          const SizedBox(height: 3),

          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 3),

          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          if (note != null)
            Text(
              note,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _impactEnvironment({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: SolarDetailColors.green, size: 22),

        const SizedBox(height: 2),

        Text(
          title,
          style: const TextStyle(
            color: SolarDetailColors.green,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 2),

        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: Colors.white.withValues(alpha: .08),
    );
  }
}
