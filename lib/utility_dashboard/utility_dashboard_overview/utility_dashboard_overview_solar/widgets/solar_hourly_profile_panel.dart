import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../helpers/solar_detail_formatters.dart';
import '../models/solar_detail_data.dart';
import 'solar_detail_panel.dart';

/// Panel HOURLY SOLAR PROFILE: metric ben trai + column chart theo gio.
class SolarHourlyProfilePanel extends StatelessWidget {
  final SolarDetailData data;

  const SolarHourlyProfilePanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final hourly = data.hourlyProfile;

    return SolarDetailPanel(
      title:
          'HOURLY SOLAR PROFILE • '
          '${DateFormat('dd MMM yyyy').format(hourly.date)}',
      titleColor: SolarDetailColors.yellow,
      child: Expanded(
        child: Row(
          children: [
            SizedBox(
              width: 135,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _smallMetric(
                    'ENERGY',
                    SolarDetailFormatters.energy(hourly.totalEnergyKwh),
                  ),

                  _smallMetric(
                    'PEAK',
                    '${SolarDetailFormatters.number(hourly.peakEnergyKwh)} kWh',
                  ),

                  _smallMetric(
                    'PEAK HOUR',
                    hourly.peakHour == null
                        ? '-'
                        : '${hourly.peakHour!.toString().padLeft(2, '0')}:00',
                  ),
                ],
              ),
            ),

            Expanded(
              child: SfCartesianChart(
                margin: EdgeInsets.zero,
                plotAreaBorderWidth: 0,

                primaryXAxis: NumericAxis(
                  minimum: 0,
                  maximum: 23,
                  interval: 3,
                  labelFormat: '{value}:00',
                  majorGridLines: MajorGridLines(
                    color: Colors.white.withOpacity(.03),
                  ),
                  labelStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                ),

                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.compact(),
                  majorGridLines: MajorGridLines(
                    color: Colors.white.withOpacity(.05),
                  ),
                  labelStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                ),

                tooltipBehavior: TooltipBehavior(enable: true),

                series: <CartesianSeries<SolarHourlyPoint, int>>[
                  ColumnSeries<SolarHourlyPoint, int>(
                    name: 'Solar',
                    dataSource: hourly.points,

                    xValueMapper: (e, _) => e.hour,

                    yValueMapper: (e, _) => e.energyKwh,

                    color: SolarDetailColors.yellow,

                    width: 0.65,

                    spacing: 0.15,

                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
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

  Widget _smallMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),

          const SizedBox(height: 2),

          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
