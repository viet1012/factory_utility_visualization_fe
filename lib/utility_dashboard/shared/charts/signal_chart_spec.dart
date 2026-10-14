/// Cau hinh hien thi chart theo loai du lieu (xem signal_chart_spec_registry).
library;

enum ChartStyle {
  /// Line gia tri chinh + dai min–max (neu co).
  lineBand,

  /// Area to tu 0 len gia tri chinh (cong suat).
  area,

  /// Cot theo delta moi bucket (counter / dien nang).
  bar,

  /// Bac thang theo ma trang thai.
  step,
}

enum AxisMode {
  /// Om sat du lieu (dem ~10%), khong xuong duoi 0 neu du lieu khong am.
  fitData,

  /// Bat dau tu 0.
  zeroBased,

  /// [SignalChartSpec.fixedMin] – [SignalChartSpec.fixedMax].
  fixed,
}

class SignalChartSpec {
  final ChartStyle style;
  final AxisMode axis;
  final double? fixedMin;
  final double? fixedMax;

  /// So le toi da khi hien thi gia tri / nhan truc.
  final int decimals;

  final bool showThreshold;

  /// Bo nguong duoi khi = 0 va du lieu khong am: khong ve, khong keo truc.
  final bool hideTrivialLowerThreshold;

  /// Thay unit tu backend / catalog khi khac null.
  final String? unitOverride;

  const SignalChartSpec({
    required this.style,
    required this.axis,
    this.fixedMin,
    this.fixedMax,
    required this.decimals,
    required this.showThreshold,
    this.hideTrivialLowerThreshold = false,
    this.unitOverride,
  });

  String resolveUnit(String? unit) => unitOverride ?? unit?.trim() ?? '';

  SignalChartSpec copyWith({ChartStyle? style, AxisMode? axis}) {
    return SignalChartSpec(
      style: style ?? this.style,
      axis: axis ?? this.axis,
      fixedMin: fixedMin,
      fixedMax: fixedMax,
      decimals: decimals,
      showThreshold: showThreshold,
      hideTrivialLowerThreshold: hideTrivialLowerThreshold,
      unitOverride: unitOverride,
    );
  }

  @override
  String toString() {
    final range = axis == AxisMode.fixed ? ' $fixedMin–$fixedMax' : '';
    return 'SignalChartSpec(${style.name}, ${axis.name}$range, '
        'decimals: $decimals, threshold: $showThreshold'
        '${hideTrivialLowerThreshold ? ', hideTrivialLow' : ''})';
  }
}
