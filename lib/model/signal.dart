class Signal {
  final String plcAddress;
  final String description;
  final String? shortName;
  final String fullName;
  final double value;
  final String unit;
  final String dataType;
  final String position;
  final DateTime dateadd;

  Signal({
    required this.plcAddress,
    required this.description,
    this.shortName,
    required this.fullName,
    required this.value,
    required this.unit,
    required this.dataType,
    required this.position,
    required this.dateadd,
  });

  factory Signal.fromJson(Map<String, dynamic> json) {
    double parsedValue = 0.0;

    try {
      final rawValue = json['value'];
      if (rawValue is num) {
        parsedValue = rawValue.toDouble();
      } else if (rawValue is String) {
        parsedValue = double.tryParse(rawValue) ?? 0.0;
      }
    } catch (_) {
      parsedValue = 0.0;
    }

    return Signal(
      plcAddress: json['plcAddress'] ?? '',
      description: json['description'] ?? '',
      shortName: json['shortName'],
      fullName: json['fullName'] ?? '',
      value: parsedValue,
      unit: json['unit'] ?? '',
      dataType: json['dataType'] ?? '',
      position: json['position'] ?? '',
      dateadd: DateTime.tryParse(json['dateadd'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plcAddress': plcAddress,
      'description': description,
      'shortName': shortName,
      'fullName': fullName,
      'value': value,
      'unit': unit,
      'dataType': dataType,
      'position': position,
      'dateadd': dateadd.toIso8601String(),
    };
  }
}
