import 'package:flutter/material.dart';

import '../helpers/solar_detail_formatters.dart';
import '../models/solar_detail_data.dart';
import 'solar_detail_panel.dart';

/// Hang KPI tren cung cua Solar Detail.
class SolarDetailKpiSection extends StatelessWidget {
  final SolarDetailData data;

  const SolarDetailKpiSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final s = data.summary;
    final cost = data.costImpact;
    final env = data.environmentalImpact;

    return Row(
      children: [
        Expanded(
          child: _SolarKpiTile(
            title: 'CURRENT POWER',
            value: '${SolarDetailFormatters.number(s.currentPowerKw)} kW',
            icon: Icons.wb_sunny_rounded,
            color: SolarDetailColors.yellow,
            note: 'LIVE',
          ),
        ),

        const SizedBox(width: 5),

        Expanded(
          child: _SolarKpiTile(
            title: 'SOLAR ENERGY',
            value: SolarDetailFormatters.energy(s.solarKwh),
            icon: Icons.solar_power_rounded,
            color: SolarDetailColors.yellow,
            note: 'MONTH',
          ),
        ),

        const SizedBox(width: 5),

        Expanded(
          child: _SolarKpiTile(
            title: 'GRID ENERGY',
            value: SolarDetailFormatters.energy(s.gridKwh),
            icon: Icons.electric_bolt_rounded,
            color: SolarDetailColors.cyan,
            note: 'MONTH',
          ),
        ),

        const SizedBox(width: 5),

        // =========================================================
        // NEW
        // =========================================================
        Expanded(
          child: _SolarKpiTile(
            title: 'TOTAL ENERGY',
            value: SolarDetailFormatters.energy(s.totalKwh),
            icon: Icons.energy_savings_leaf_rounded,
            color: Colors.white70,
            note: 'SOLAR + GRID',
          ),
        ),

        const SizedBox(width: 5),

        Expanded(
          child: _SolarKpiTile(
            title: 'SOLAR SHARE',
            value: '${s.solarSharePercent.toStringAsFixed(1)}%',
            icon: Icons.pie_chart_rounded,
            color: SolarDetailColors.yellow,
            note: 'SOLAR / TOTAL',
          ),
        ),

        const SizedBox(width: 5),

        Expanded(
          child: _SolarKpiTile(
            title: 'SOLAR COST',
            value: '\$${SolarDetailFormatters.money(cost.solarCostUsd)}',
            icon: Icons.attach_money_rounded,
            color: SolarDetailColors.green,
            note: 'RATE × 83%',
          ),
        ),

        const SizedBox(width: 5),

        Expanded(
          child: _SolarKpiTile(
            title: 'SAVING',
            value: '\$${SolarDetailFormatters.money(cost.savingUsd)}',
            icon: Icons.savings_rounded,
            color: SolarDetailColors.green,
            note: '${cost.savingPercent.toStringAsFixed(0)}%',
          ),
        ),

        const SizedBox(width: 5),

        Expanded(
          child: _SolarKpiTile(
            title: 'CO₂ AVOIDED',
            value: '${env.co2Ton.toStringAsFixed(1)} ton',
            icon: Icons.eco_rounded,
            color: SolarDetailColors.green,
            note: '${SolarDetailFormatters.compact(env.equivalentTrees)} trees',
          ),
        ),
      ],
    );
  }
}

class _SolarKpiTile extends StatelessWidget {
  final String title;

  final String value;

  final IconData icon;

  final Color color;

  final String? note;

  const _SolarKpiTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: solarPanelDecoration(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(.08),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(.25)),
            ),
            child: Icon(icon, color: color, size: 21),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 4),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),

                if (note != null) ...[
                  const SizedBox(height: 2),

                  Text(
                    note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
