import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class FactorySummaryWidget extends StatelessWidget {
  final double totalPower;
  final double totalVolume;
  final double avgPressure;

  const FactorySummaryWidget(
    this.totalPower,
    this.totalVolume,
    this.avgPressure, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = [
      {
        "title": "Electric Power",
        "value": '${(totalPower / 1000).toStringAsFixed(0)}k kWh',
        "icon": Icons.flash_on,
        "color": Colors.orange,
        "data": <double>[500, 700, 650, 800, 600],
      },
      {
        "title": "Water Volume",
        "value": '${totalVolume.toStringAsFixed(0)} m³',
        "icon": Icons.water_drop,
        "color": Colors.blue,
        "data": <double>[200, 300, 250, 280, 320],
      },
      {
        "title": "Avg Pressure",
        "value": '${avgPressure.toStringAsFixed(1)} MPa',
        "icon": Icons.speed,
        "color": Colors.red,
        "data": <double>[0.8, 0.9, 1.0, 0.95, 0.85],
      },
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Factory Summary",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[400],
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ...metrics.map(
            (m) => SummaryMetricCard(
              title: m["title"] as String,
              value: m["value"] as String,
              icon: m["icon"] as IconData,
              color: m["color"] as Color,
              data: m["data"] as List<double>,
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final List<double> data;

  const SummaryMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withOpacity(0.3),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: SfCartesianChart(
              margin: EdgeInsets.zero,
              primaryXAxis: CategoryAxis(isVisible: false),
              primaryYAxis: NumericAxis(isVisible: false),
              series: <CartesianSeries>[
                ColumnSeries<double, int>(
                  dataSource: data,
                  xValueMapper: (value, index) => index,
                  yValueMapper: (value, _) => value,
                  color: color,
                  width: 0.6,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
