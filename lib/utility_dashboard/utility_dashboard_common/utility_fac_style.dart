import 'package:flutter/material.dart';

import '../../utility_models/response/latest_record.dart';

class UtilityFacStyle {
  static Color colorFromFac(String? facName) {
    switch ((facName ?? '').trim()) {
      case 'Fac_A':
        return const Color(0xFF4FC3F7);
      case 'Fac_B':
        return const Color(0xFF42A5F5);
      case 'Fac_C':
        return const Color(0xFF4FC3F7);
      default:
        return const Color(0xFF4FC3F7);
    }
  }

  static String resolveFacTitle({
    required List<LatestRecordDto> rows,
    String? fallbackFacId,
  }) {
    for (final r in rows) {
      final f = r.fac?.trim();
      if (f != null && f.isNotEmpty) {
        return f;
      }
    }

    final fb = fallbackFacId?.trim();
    if (fb != null && fb.isNotEmpty) {
      return fb;
    }

    return 'Unknown FAC';
  }

  static IconData iconByCate(String? cate) {
    switch ((cate ?? '').trim()) {
      case 'Electricity':
        return Icons.bolt_rounded;
      case 'Water':
        return Icons.water_drop_rounded;
      case 'Compressed Air':
        return Icons.air_rounded;
      default:
        return Icons.device_unknown_rounded;
    }
  }

  static Color colorByCate(String? cate) {
    switch ((cate ?? '').trim()) {
      case 'Electricity':
        return const Color(0xFFFFB300);
      case 'Water':
        return const Color(0xFF29B6F6);
      case 'Compressed Air':
        return const Color(0xFF26C6DA);
      default:
        return Colors.white70;
    }
  }
}
