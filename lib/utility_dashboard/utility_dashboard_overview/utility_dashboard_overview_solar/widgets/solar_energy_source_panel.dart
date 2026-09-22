import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../helpers/solar_detail_formatters.dart';
import '../models/solar_detail_data.dart';
import 'solar_detail_panel.dart';

/// Panel ENERGY SOURCE: doughnut Solar/Grid + danh sach gia tri.
class SolarEnergySourcePanel extends StatelessWidget {
  final SolarDetailData data;

  const SolarEnergySourcePanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final s = data.summary;

    final pie = [
      _PieData('Solar', s.solarKwh, SolarDetailColors.yellow),
      _PieData('Grid', s.gridKwh, SolarDetailColors.cyan),
    ];

    return SolarDetailPanel(
      title: 'ENERGY SOURCE',
      titleColor: SolarDetailColors.yellow,
      child: Expanded(
        child: Row(
          children: [
            Expanded(
              child: SfCircularChart(
                margin: EdgeInsets.zero,

                series: <CircularSeries<_PieData, String>>[
                  DoughnutSeries<_PieData, String>(
                    dataSource: pie,
                    xValueMapper: (e, _) => e.name,
                    yValueMapper: (e, _) => e.value,
                    pointColorMapper: (e, _) => e.color,
                    innerRadius: '68%',
                    radius: '88%',
                  ),
                ],

                annotations: [
                  CircularChartAnnotation(
                    widget: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${s.solarSharePercent.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: SolarDetailColors.yellow,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const Text(
                          'SOLAR',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _miniSourceRow(
                    'Solar',
                    SolarDetailFormatters.energy(s.solarKwh),
                    SolarDetailColors.yellow,
                  ),

                  const SizedBox(height: 8),

                  _miniSourceRow(
                    'Main',
                    SolarDetailFormatters.energy(s.gridKwh),
                    SolarDetailColors.cyan,
                  ),

                  const SizedBox(height: 8),

                  _miniSourceRow(
                    'Total',
                    SolarDetailFormatters.energy(s.totalKwh),
                    Colors.white70,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniSourceRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),

        const SizedBox(width: 6),

        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ),

        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// PIE
// ============================================================================

class _PieData {
  final String name;

  final double value;

  final Color color;

  const _PieData(this.name, this.value, this.color);
}
