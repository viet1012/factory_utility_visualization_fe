import 'package:flutter/material.dart';

enum DataHealth { loading, error, empty, ok, stale, noChange }

class DataHealthResult {
  final DataHealth health;
  final Duration? staleFor;

  const DataHealthResult(this.health, {this.staleFor});
}

class DataHealthAnalyzer {
  const DataHealthAnalyzer._();

  /// ===== PUBLIC API =====

  static DataHealthResult analyze({
    required bool loading,
    required Object? error,
    required List<DateTime> timestamps,
    required List<double> values,
    Duration staleThreshold = const Duration(minutes: 2),
  }) {
    if (loading) return const DataHealthResult(DataHealth.loading);
    if (error != null) return const DataHealthResult(DataHealth.error);
    if (values.isEmpty) return const DataHealthResult(DataHealth.empty);

    final lastTs = timestamps.last;
    final staleFor = DateTime.now().difference(lastTs);

    if (staleFor > staleThreshold) {
      return DataHealthResult(DataHealth.stale, staleFor: staleFor);
    }

    final noChange = _detectNoChange(values);
    if (noChange) return const DataHealthResult(DataHealth.noChange);

    return const DataHealthResult(DataHealth.ok);
  }

  static Color color(DataHealth h) {
    switch (h) {
      case DataHealth.loading:
        return const Color(0xFFFFC107);
      case DataHealth.error:
        return const Color(0xFFFF3B30);
      case DataHealth.empty:
        return Colors.white38;
      case DataHealth.ok:
        return const Color(0xFF2CFF7A);
      case DataHealth.stale:
        return const Color(0xFFFF9F0A);
      case DataHealth.noChange:
        return const Color(0xFF52D6FF);
    }
  }

  static String label(DataHealthResult r) {
    switch (r.health) {
      case DataHealth.loading:
        return 'Loading';
      case DataHealth.error:
        return 'Error';
      case DataHealth.empty:
        return 'No data';
      case DataHealth.ok:
        return 'OK';
      case DataHealth.stale:
        return 'Stale ${_fmtDuration(r.staleFor!)}';
      case DataHealth.noChange:
        return 'No change';
    }
  }

  /// ===== PRIVATE =====

  static bool _detectNoChange(List<double> values) {
    double minY = values.first;
    double maxY = values.first;

    for (final v in values) {
      if (v < minY) minY = v;
      if (v > maxY) maxY = v;
    }

    final delta = (maxY - minY).abs();

    final avg = (minY + maxY) / 2.0;
    final epsPct = avg.abs() * 0.0005;
    final eps = epsPct < 0.01 ? 0.01 : epsPct;

    return delta <= eps;
  }

  static String _fmtDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inHours}h';
  }
}
