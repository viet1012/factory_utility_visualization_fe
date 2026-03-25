// voltage_card.dart

import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_monthly/utility_dashboard_overview_monthly_widgets/voltage_detail_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_dashboard_api/utility_dashboard_overview_api.dart';

class VoltageStatus {
  final String fac;
  final String boxDeviceId;
  final String name;
  final double minVol;
  final double maxVol;
  final String alarm;
  final DateTime timestamp;

  VoltageStatus({
    required this.fac,
    required this.boxDeviceId,
    required this.name,
    required this.minVol,
    required this.maxVol,
    required this.alarm,
    required this.timestamp,
  });

  factory VoltageStatus.fromJson(Map<String, dynamic> json) {
    return VoltageStatus(
      fac: json['fac']?.toString() ?? '',
      boxDeviceId: json['boxDeviceId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      minVol: (json['minVol'] as num?)?.toDouble() ?? 0,
      maxVol: (json['maxVol'] as num?)?.toDouble() ?? 0,
      alarm: json['alarm']?.toString() ?? 'Normal',
      timestamp: DateTime.parse(json['timestamp']).toLocal(),
    );
  }

  bool get isAlarm => alarm == 'Alarm' || alarm == 'Critical';
}

class VoltageCard extends StatelessWidget {
  final VoltageStatus status;
  final Animation<double> pulseAnimation;
  final String facId;

  const VoltageCard({
    super.key,
    required this.status,
    required this.pulseAnimation,
    required this.facId,
  });

  void _showDetailChart(BuildContext context) {
    final api = context.read<UtilityDashboardOverviewApi>();
    showDialog(
      context: context,
      builder: (_) => VoltageChartDialog(api: api, facId: facId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alarm = status.isAlarm;
    final color = alarm ? const Color(0xFFEF5350) : const Color(0xFFFFB300);

    return GestureDetector(
      onTap: () => _showDetailChart(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(alarm ? 0.6 : 0.25)),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: pulseAnimation,
              builder: (_, child) => Transform.scale(
                scale: alarm ? pulseAnimation.value : 1.0,
                child: child,
              ),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15),
                ),
                child: Icon(Icons.bolt_rounded, color: color, size: 22),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Voltage',
                        style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (alarm) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF5350).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFEF5350),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            status.alarm.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFFEF5350),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _VoltageChip(
                        label: 'MIN',
                        value: status.minVol,
                        color: Colors.white60,
                      ),
                      const SizedBox(width: 12),
                      AnimatedBuilder(
                        animation: pulseAnimation,
                        builder: (_, child) => Transform.scale(
                          scale: alarm ? pulseAnimation.value : 1.0,
                          child: child,
                        ),
                        child: _VoltageChip(
                          label: 'MAX',
                          value: status.maxVol,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: color.withOpacity(0.5),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _VoltageChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _VoltageChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: '${value.toStringAsFixed(0)} V',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
