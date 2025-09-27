import 'package:flutter/material.dart';

class FacilityData {
  final String name;
  final double power; // kWh
  final double volume; // m³
  final double pressure; // MPa
  final Alignment position;

  FacilityData({
    required this.name,
    required this.power,
    required this.volume,
    required this.pressure,
    required this.position,
  });
}
