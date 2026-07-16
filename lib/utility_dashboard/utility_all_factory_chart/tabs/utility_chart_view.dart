import 'package:flutter/material.dart';

enum UtilityChartView {
  minutes(label: 'Minutes', icon: Icons.timeline_rounded),
  daily(label: 'Daily', icon: Icons.calendar_today_rounded);

  final String label;
  final IconData icon;

  const UtilityChartView({required this.label, required this.icon});
}
