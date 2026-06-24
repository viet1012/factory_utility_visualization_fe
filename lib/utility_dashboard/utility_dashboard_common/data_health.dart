import 'package:flutter/material.dart';

enum DataHealth { loading, ok, inactive }

class DataHealthResult {
  final DataHealth health;

  const DataHealthResult(this.health);
}

class DataHealthAnalyzer {
  const DataHealthAnalyzer._();

  /// =========================
  /// CHECK HEALTH
  /// =========================
  static final Map<String, DataHealth> _lastHealth = {};

  static DataHealthResult analyze({
    required String key,
    required bool loading,
    required Object? error,
    required List<double> values,
  }) {
    DataHealth health;

    if (loading) {
      health = DataHealth.loading;
    } else if (error != null || values.isEmpty) {
      health = DataHealth.inactive;
    } else {
      health = DataHealth.ok;
    }

    /// lưu trạng thái theo key
    _lastHealth[key] = health;

    return DataHealthResult(health);
  }

  /// =========================
  /// COLOR
  /// =========================
  static Color color(DataHealth h) {
    switch (h) {
      case DataHealth.loading:
        return const Color(0xFFFFC107); // vàng

      case DataHealth.ok:
        return const Color(0xFF2CFF7A); // xanh

      case DataHealth.inactive:
        return Colors.grey; // xám
    }
  }

  /// =========================
  /// LABEL
  /// =========================
  static String label(DataHealth h) {
    switch (h) {
      case DataHealth.loading:
        return "Loading";

      case DataHealth.ok:
        return "Connected";

      case DataHealth.inactive:
        return "No Data";
    }
  }
}
