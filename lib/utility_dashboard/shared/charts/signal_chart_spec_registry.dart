import 'package:flutter/foundation.dart';

import 'signal_chart_spec.dart';

/// Chon [SignalChartSpec] cho mot signal.
///
/// Thu tu: khop code chinh xac -> khop mau code (tien to / `*`) -> unit ->
/// kind -> mac dinh. So khop code va unit khong phan biet hoa thuong.
class SignalChartSpecRegistry {
  SignalChartSpecRegistry._();

  // ------------------------------------------------------------
  // SPEC
  // ------------------------------------------------------------

  static const SignalChartSpec environment = SignalChartSpec(
    style: ChartStyle.lineBand,
    axis: AxisMode.fitData,
    decimals: 1,
    showThreshold: true,
  );

  static const SignalChartSpec voltage = SignalChartSpec(
    style: ChartStyle.lineBand,
    axis: AxisMode.fitData,
    decimals: 1,
    showThreshold: true,
  );

  static const SignalChartSpec current = SignalChartSpec(
    style: ChartStyle.lineBand,
    axis: AxisMode.zeroBased,
    decimals: 1,
    showThreshold: true,
    hideTrivialLowerThreshold: true,
  );

  static const SignalChartSpec power = SignalChartSpec(
    style: ChartStyle.area,
    axis: AxisMode.zeroBased,
    decimals: 2,
    showThreshold: true,
    hideTrivialLowerThreshold: true,
  );

  static const SignalChartSpec energy = SignalChartSpec(
    style: ChartStyle.bar,
    axis: AxisMode.zeroBased,
    decimals: 2,
    showThreshold: false,
  );

  static const SignalChartSpec powerFactor = SignalChartSpec(
    style: ChartStyle.lineBand,
    axis: AxisMode.fixed,
    fixedMin: 0,
    fixedMax: 1,
    decimals: 2,
    showThreshold: true,
  );

  static const SignalChartSpec harmonic = SignalChartSpec(
    style: ChartStyle.lineBand,
    axis: AxisMode.zeroBased,
    decimals: 2,
    showThreshold: true,
  );

  static const SignalChartSpec pressureLevel = SignalChartSpec(
    style: ChartStyle.lineBand,
    axis: AxisMode.fitData,
    decimals: 2,
    showThreshold: true,
  );

  static const SignalChartSpec status = SignalChartSpec(
    style: ChartStyle.step,
    axis: AxisMode.fitData,
    decimals: 0,
    showThreshold: false,
  );

  static const SignalChartSpec fallback = SignalChartSpec(
    style: ChartStyle.lineBand,
    axis: AxisMode.fitData,
    decimals: 2,
    showThreshold: true,
  );

  // ------------------------------------------------------------
  // MAPPING (key da chuan hoa: chu thuong)
  // ------------------------------------------------------------

  static const Map<String, SignalChartSpec> _byCode = {
    'e_temp': environment,
    'e_humity': environment,
    'w_cool': environment,
    'e_ttlpower': power,
    'e_avgpower': powerFactor,
    'a_scair': pressureLevel,
    'w_levcool': pressureLevel,
  };

  /// Mau code, `*` = chuoi bat ky. Xet theo thu tu khai bao.
  static final List<(RegExp, SignalChartSpec)> _byCodePattern = [
    (_glob('E_Vol*'), voltage),
    (_glob('E_Cur*'), current),
    (_glob('E_THD_*'), harmonic),
    (_glob('W_*Pres*'), pressureLevel),
  ];

  static const Map<String, SignalChartSpec> _byUnit = {
    'kw': power,
    'kvar': power,
    'kva': power,
    'kwh': energy,
    'kvarh': energy,
    'cosphi': powerFactor,
    'kg/cm2': pressureLevel,
    'm': pressureLevel,
  };

  static const Map<String, SignalChartSpec> _byKind = {
    'COUNTER': energy,
    'STATUS': status,
  };

  // ------------------------------------------------------------
  // RESOLVE
  // ------------------------------------------------------------

  static final Set<String> _unmapped = <String>{};

  /// Signal da roi vao spec mac dinh trong phien nay (`code | unit | kind |
  /// name`), de bo sung mapping.
  static Set<String> get unmapped => Set.unmodifiable(_unmapped);

  static SignalChartSpec resolve({
    String? code,
    String? unit,
    String? kind,
    String? name,
  }) {
    final normalizedCode = code?.trim().toLowerCase() ?? '';

    if (normalizedCode.isNotEmpty) {
      final exact = _byCode[normalizedCode];
      if (exact != null) return exact;

      for (final (pattern, spec) in _byCodePattern) {
        if (pattern.hasMatch(normalizedCode)) return spec;
      }
    }

    final byUnit = _byUnit[_normalizeUnit(unit)];
    if (byUnit != null) return byUnit;

    final byKind = _byKind[kind?.trim().toUpperCase() ?? ''];
    if (byKind != null) return byKind;

    final key = '${code ?? ''} | ${unit ?? ''} | ${kind ?? ''} | ${name ?? ''}';
    if (_unmapped.add(key) && kDebugMode) {
      debugPrint('[SignalChartSpec] default spec for: $key');
    }

    return fallback;
  }

  /// Ep kieu ve theo kind cua signal (code / unit chi chon truc, so le):
  /// COUNTER -> cot theo delta, STATUS -> bac thang, ANALOG -> khong ve cot
  /// hay bac thang (vd unit kWh nhung kind ANALOG). Kind rong: giu [spec].
  static SignalChartSpec forKind(SignalChartSpec spec, String? kind) {
    switch (kind?.trim().toUpperCase()) {
      case 'COUNTER':
        return spec.style == ChartStyle.bar
            ? spec
            : spec.copyWith(style: ChartStyle.bar, axis: AxisMode.zeroBased);
      case 'STATUS':
        return spec.style == ChartStyle.step ? spec : status;
      case 'ANALOG':
        return spec.style == ChartStyle.bar || spec.style == ChartStyle.step
            ? spec.copyWith(style: ChartStyle.lineBand)
            : spec;
      default:
        return spec;
    }
  }

  /// "Cos φ" -> "cosphi", "kg/cm²" -> "kg/cm2", "kW" -> "kw".
  static String _normalizeUnit(String? unit) {
    return (unit ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('²', '2')
        .replaceAll(RegExp('[φϕɸ]'), 'phi');
  }

  static RegExp _glob(String pattern) {
    final body = pattern.toLowerCase().split('*').map(RegExp.escape).join('.*');
    return RegExp('^$body\$');
  }
}
