class EnergyMonthlySummary {
  final String cate;
  final String name;
  final String month;

  final double? minValue;
  final double? maxValue;
  final double? prevMinValue;
  final double? prevMaxValue;

  final double? value;
  final double? avgValue;

  final double? vndCost;
  final double? usdCost;

  final double? prevValue;
  final double? prevAvgValue;

  final double? prevVndCost;
  final double? prevUsdCost;

  final double? deltaValue;
  final double? deltaPercent;

  final String unit;

  final DateTime? pickAt;
  final DateTime? generatedAt;

  const EnergyMonthlySummary({
    required this.cate,
    required this.name,
    required this.month,
    required this.minValue,
    required this.maxValue,
    required this.prevMinValue,
    required this.prevMaxValue,
    required this.value,
    required this.avgValue,
    required this.vndCost,
    required this.usdCost,
    required this.prevValue,
    required this.prevAvgValue,
    required this.prevVndCost,
    required this.prevUsdCost,
    required this.deltaValue,
    required this.deltaPercent,
    required this.unit,
    required this.pickAt,
    required this.generatedAt,
  });

  factory EnergyMonthlySummary.fromJson(Map<String, dynamic> json) {
    return EnergyMonthlySummary(
      cate: _JsonReader.string(json['cate']),
      name: _JsonReader.string(json['name']),
      month: _JsonReader.string(json['month']),

      minValue: _JsonReader.number(json['minValue']),
      maxValue: _JsonReader.number(json['maxValue']),

      prevMinValue: _JsonReader.number(json['prevMinValue']),

      prevMaxValue: _JsonReader.number(json['prevMaxValue']),

      value: _JsonReader.number(json['value']),
      avgValue: _JsonReader.number(json['avgValue']),

      vndCost: _JsonReader.number(json['vndCost']),
      usdCost: _JsonReader.number(json['usdCost']),

      prevValue: _JsonReader.number(json['prevValue']),

      prevAvgValue: _JsonReader.number(json['prevAvgValue']),

      prevVndCost: _JsonReader.number(json['prevVndCost']),

      prevUsdCost: _JsonReader.number(json['prevUsdCost']),

      deltaValue: _JsonReader.number(json['deltaValue']),

      deltaPercent: _JsonReader.number(json['deltaPercent']),

      unit: _JsonReader.string(json['unit']),

      pickAt: _JsonReader.dateTime(json['pickAt'] ?? json['timestamp']),

      generatedAt: _JsonReader.dateTime(json['generatedAt']),
    );
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

  double? get costDeltaValue {
    if (!hasComparableCost) {
      return null;
    }

    return currentCost! - previousCost!;
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

  static DateTime? dateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    final raw = value.toString().trim();

    if (raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw)?.toLocal();
  }
}
