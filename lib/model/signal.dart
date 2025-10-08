class Signal {
  final String plcAddress;
  final String description;
  final String? shortName;
  final String value;
  final String unit;
  final String dataType;
  final String position;
  final DateTime dateadd;

  Signal({
    required this.plcAddress,
    required this.description,
    this.shortName,
    required this.value,
    required this.unit,
    required this.dataType,
    required this.position,
    required this.dateadd,
  });

  factory Signal.fromJson(Map<String, dynamic> json) {
    return Signal(
      plcAddress: json['plcAddress'] ?? '',
      description: json['description'] ?? '',
      shortName: json['shortName'],
      value: json['value'] ?? '',
      unit: json['unit'] ?? '',
      dataType: json['dataType'] ?? '',
      position: json['position'] ?? '',
      dateadd: DateTime.parse(json['dateadd']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plcAddress': plcAddress,
      'description': description,
      'shortName': shortName,
      'value': value,
      'unit': unit,
      'dataType': dataType,
      'position': position,
      'dateadd': dateadd.toIso8601String(),
    };
  }
}
