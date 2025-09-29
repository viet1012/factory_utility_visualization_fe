class UtilityData {
  final String plcAddress;
  final String plcValue;
  final String position;
  final String comment;
  final DateTime dataTime;

  UtilityData({
    required this.plcAddress,
    required this.plcValue,
    required this.position,
    required this.comment,
    required this.dataTime,
  });

  // Factory constructor để parse từ JSON
  factory UtilityData.fromJson(Map<String, dynamic> json) {
    return UtilityData(
      plcAddress: json['plcAddress'] ?? '',
      plcValue: json['plcValue'] ?? '',
      position: json['position'] ?? '',
      comment: json['comment'] ?? '',
      dataTime: DateTime.parse(json['dataTime']),
    );
  }

  // Convert ngược lại từ object sang JSON
  Map<String, dynamic> toJson() {
    return {
      'plcAddress': plcAddress,
      'plcValue': plcValue,
      'position': position,
      'comment': comment,
      'dataTime': dataTime.toIso8601String(),
    };
  }
}
