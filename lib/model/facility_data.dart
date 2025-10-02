import 'package:flutter/material.dart';

class FacilityData {
  final String name;
  final double electricPower; // kWh
  final double waterFlow; // m³
  final double compressedAirPressure; // MPa
  final double temperature; // °C

  FacilityData({
    required this.name,
    required this.electricPower,
    required this.waterFlow,
    required this.compressedAirPressure,
    required this.temperature,
  });
}
