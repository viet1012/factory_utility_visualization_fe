class UtilityPeriodDashboard {
  final String facId;
  final String utilityType;
  final String period;

  final DateTime fromDate;
  final DateTime toDate;

  final String unit;

  final DateTime? generatedAt;

  final double total;
  final double previousTotal;
  final double changePercent;

  final List<UtilityPeriodTrend> trend;

  final List<UtilityPeriodBox> byBox;

  final List<String> columns;

  final List<UtilityPeriodBoxTrend> boxTrend;

  final List<double> columnTotals;

  final double grandTotal;

  const UtilityPeriodDashboard({
    required this.facId,
    required this.utilityType,
    required this.period,
    required this.fromDate,
    required this.toDate,
    required this.unit,
    required this.generatedAt,
    required this.total,
    required this.previousTotal,
    required this.changePercent,
    required this.trend,
    required this.byBox,
    required this.columns,
    required this.boxTrend,
    required this.columnTotals,
    required this.grandTotal,
  });

  factory UtilityPeriodDashboard.fromJson(Map<String, dynamic> json) {
    return UtilityPeriodDashboard(
      facId: json['facId']?.toString() ?? '',

      utilityType: json['utilityType']?.toString() ?? 'ELECTRICITY',

      period: json['period']?.toString() ?? 'WEEK',

      fromDate: DateTime.parse(json['fromDate'].toString()),

      toDate: DateTime.parse(json['toDate'].toString()),

      unit: json['unit']?.toString() ?? '',

      generatedAt: json['generatedAt'] == null
          ? null
          : DateTime.tryParse(json['generatedAt'].toString()),

      total: _toDouble(json['total']),

      previousTotal: _toDouble(json['previousTotal']),

      changePercent: _toDouble(json['changePercent']),

      trend: (json['trend'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => UtilityPeriodTrend.fromJson(Map<String, dynamic>.from(e)))
          .toList(),

      byBox: (json['byBox'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => UtilityPeriodBox.fromJson(Map<String, dynamic>.from(e)))
          .toList(),

      columns: (json['columns'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),

      boxTrend: (json['boxTrend'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (e) => UtilityPeriodBoxTrend.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),

      columnTotals: (json['columnTotals'] as List? ?? const [])
          .map(_toDouble)
          .toList(),

      grandTotal: _toDouble(json['grandTotal']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }
}

class UtilityPeriodTrend {
  final DateTime date;
  final double value;

  const UtilityPeriodTrend({required this.date, required this.value});

  factory UtilityPeriodTrend.fromJson(Map<String, dynamic> json) {
    return UtilityPeriodTrend(
      date: DateTime.parse(json['date'].toString()),

      value: UtilityPeriodDashboard._toDouble(json['value']),
    );
  }
}

class UtilityPeriodBox {
  final String boxId;

  final double total;
  final double sharePercent;

  const UtilityPeriodBox({
    required this.boxId,
    required this.total,
    required this.sharePercent,
  });

  factory UtilityPeriodBox.fromJson(Map<String, dynamic> json) {
    return UtilityPeriodBox(
      boxId: json['boxId']?.toString() ?? '',

      total: UtilityPeriodDashboard._toDouble(json['total']),

      sharePercent: UtilityPeriodDashboard._toDouble(json['sharePercent']),
    );
  }
}

class UtilityPeriodBoxTrend {
  final String boxId;

  final List<double> values;

  final double total;

  const UtilityPeriodBoxTrend({
    required this.boxId,
    required this.values,
    required this.total,
  });

  factory UtilityPeriodBoxTrend.fromJson(Map<String, dynamic> json) {
    return UtilityPeriodBoxTrend(
      boxId: json['boxId']?.toString() ?? '',

      values: (json['values'] as List? ?? const [])
          .map(UtilityPeriodDashboard._toDouble)
          .toList(),

      total: UtilityPeriodDashboard._toDouble(json['total']),
    );
  }
}
