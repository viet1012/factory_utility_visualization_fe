import 'package:flutter/material.dart';

import '../../utility_models/response/latest_record.dart';

class UtilityFacStyle {
  static Color colorFromFac(String? facName) {
    switch ((facName ?? '').trim()) {
      case 'Fac_A':
      case 'A':
        return const Color(0xFF4FC3F7); // Light Blue
      case 'Fac_B':
      case 'B':
        return const Color(0xFF42A5F5); // Medium Blue
      case 'Fac_C':
      case 'C':
        return const Color(0xFF4FC3F7); // Indigo Blue
      default:
        return const Color(0xFF4FC3F7);
    }
  }

  static String resolveFacTitle({
    required List<LatestRecordDto> rows,
    String? fallbackFacId,
  }) {
    // ưu tiên API trả fac
    for (final r in rows) {
      final f = r.fac?.trim();
      if (f != null && f.isNotEmpty) return f;
    }

    // fallback theo param
    final fb = fallbackFacId?.trim();
    if (fb != null && fb.isNotEmpty) return fb;

    return 'Unknown FAC';
  }
}
