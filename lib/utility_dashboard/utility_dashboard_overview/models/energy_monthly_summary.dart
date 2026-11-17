class EnergyMonthlySummary {
  final String cate;
  final String name;
  final String month;

  final double? minValue;
  final double? maxValue;

  /// Electricity: dien luoi (grid) official = so EVN neu co, khong thi so do
  /// (xem [gridSourceLabel]). Tong sub-meter (load = grid + solar) nam o field
  /// `totalEnergyValue` cua BE, khong dung cho the MTD.
  final double? value;
  final double? avgValue;

  /// Electricity: tien dien luoi (grid).
  final double? vndCost;
  final double? usdCost;

  final double? prevValue;
  final double? prevAvgValue;

  final double? prevVndCost;
  final double? prevUsdCost;

  final double? deltaPercent;

  final String unit;

  /// Co gio khong co bang gia -> tien ky nay / ky truoc chi mot phan.
  final bool priceMissing;
  final bool prevPriceMissing;

  /// Gio cua du lieu moi nhat (chuoi ISO gio nha may); null khi chua co.
  final String? pickAt;

  /// Electricity: so ngay cua ky nay / ky truoc lay tu EVN / tu so do
  /// (`official*`); null khi BE chua tra (dong Water / Air, BE cu).
  final int? evnDays;
  final int? measuredDays;
  final int? prevEvnDays;
  final int? prevMeasuredDays;

  const EnergyMonthlySummary({
    required this.cate,
    required this.name,
    required this.month,
    required this.minValue,
    required this.maxValue,
    required this.value,
    required this.avgValue,
    required this.vndCost,
    required this.usdCost,
    required this.prevValue,
    required this.prevAvgValue,
    required this.prevVndCost,
    required this.prevUsdCost,
    required this.deltaPercent,
    required this.unit,
    this.priceMissing = false,
    this.prevPriceMissing = false,
    this.pickAt,
    this.evnDays,
    this.measuredDays,
    this.prevEvnDays,
    this.prevMeasuredDays,
  });

  /// Electricity: value / cost / prev / delta = so official (EVN neu co, khong
  /// thi so do) do BE tinh; field official* thieu / null -> field cu.
  factory EnergyMonthlySummary.fromJson(Map<String, dynamic> json) {
    double? read(String official, String legacy) =>
        _JsonReader.number(json[official]) ?? _JsonReader.number(json[legacy]);

    return EnergyMonthlySummary(
      cate: _JsonReader.string(json['cate']),
      name: _JsonReader.string(json['name']),
      month: _JsonReader.string(json['month']),

      minValue: _JsonReader.number(json['minValue']),
      maxValue: _JsonReader.number(json['maxValue']),

      value: read('officialValue', 'value'),
      avgValue: _JsonReader.number(json['avgValue']),

      vndCost: read('officialVndCost', 'vndCost'),
      usdCost: read('officialUsdCost', 'usdCost'),

      prevValue: read('officialPrevValue', 'prevValue'),

      prevAvgValue: _JsonReader.number(json['prevAvgValue']),

      prevVndCost: read('officialPrevVndCost', 'prevVndCost'),

      prevUsdCost: read('officialPrevUsdCost', 'prevUsdCost'),

      deltaPercent: read('officialDeltaPercent', 'deltaPercent'),

      unit: _JsonReader.string(json['unit']),

      priceMissing: json['priceMissing'] == true,
      prevPriceMissing: json['prevPriceMissing'] == true,
      pickAt: _JsonReader.optionalString(json['pickAt']),

      evnDays: _JsonReader.integer(json['evnDays']),
      measuredDays: _JsonReader.integer(json['measuredDays']),
      prevEvnDays: _JsonReader.integer(json['prevEvnDays']),
      prevMeasuredDays: _JsonReader.integer(json['prevMeasuredDays']),
    );
  }

  // ============================================================
  // GRID SOURCE (EVN / so do)
  // ============================================================

  /// Nhan nguon so ky nay: `EVN` (khong co ngay do), `EVN + Đo`, `Đo` (khong
  /// co ngay EVN - Fac A, Fac B luon vay). null khi BE chua tra so ngay hoac
  /// ky chua co ngay nao.
  String? get gridSourceLabel {
    final evn = evnDays;
    final measured = measuredDays;
    if (evn == null && measured == null) return null;
    final e = evn ?? 0;
    final m = measured ?? 0;
    if (e == 0 && m == 0) return null;
    if (e == 0) return 'Đo';
    if (m == 0) return 'EVN';
    return 'EVN + Đo';
  }

  /// Tooltip cua [gridSourceLabel].
  String? get gridSourceTooltip {
    if (gridSourceLabel == null) return null;
    return '${evnDays ?? 0} ngày EVN, ${measuredDays ?? 0} ngày đo '
        '(số đo thường thấp hơn EVN ~7%)';
  }

  // ============================================================
  // UTILITY TYPE
  // ============================================================

  bool get isElectricity {
    return cate.trim().toUpperCase().contains('ELECTRIC');
  }

  bool get isWater {
    return cate.trim().toUpperCase().contains('WATER');
  }

  bool get isAir {
    final normalized = cate.trim().toUpperCase();

    return normalized.contains('AIR') || normalized.contains('COMPRESSED');
  }

  // ============================================================
  // VALUE
  // ============================================================

  double get displayValue {
    return value ?? avgValue ?? 0;
  }

  double? get previousDisplayValue {
    return prevValue ?? prevAvgValue;
  }

  // ============================================================
  // COST
  // ============================================================

  double? get currentCost {
    return usdCost ?? vndCost;
  }

  double? get previousCost {
    if (usdCost != null) {
      return prevUsdCost;
    }

    if (vndCost != null) {
      return prevVndCost;
    }

    return null;
  }

  String get currentCostUnit {
    if (usdCost != null) {
      return 'USD';
    }

    if (vndCost != null) {
      return 'VND';
    }

    return '';
  }

  String get previousCostUnit {
    if (usdCost != null && prevUsdCost != null) {
      return 'USD';
    }

    if (vndCost != null && prevVndCost != null) {
      return 'VND';
    }

    return '';
  }

  bool get hasComparableCost {
    return currentCost != null &&
        previousCost != null &&
        currentCostUnit.isNotEmpty &&
        currentCostUnit == previousCostUnit;
  }

  double? get costDeltaPercent {
    if (!hasComparableCost) {
      return null;
    }

    final previous = previousCost!;

    if (previous == 0) {
      return null;
    }

    return ((currentCost! - previous) / previous * 100);
  }
}

// ============================================================
// JSON READER
// ============================================================

class _JsonReader {
  const _JsonReader._();

  static String string(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static String? optionalString(dynamic value) {
    final text = string(value);
    return text.isEmpty ? null : text;
  }

  static double? number(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    final raw = value.toString().trim();

    if (raw.isEmpty) {
      return null;
    }

    return double.tryParse(raw.replaceAll(',', ''));
  }

  static int? integer(dynamic value) => number(value)?.toInt();
}
