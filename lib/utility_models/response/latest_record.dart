class LatestRecordDto {
  final String boxDeviceId;
  final String plcAddress;
  final double? value;
  final DateTime recordedAt;

  final String? cateId;
  final String? scadaId;
  final String? fac;
  final String? cate;
  final String? boxId;

  LatestRecordDto({
    required this.boxDeviceId,
    required this.plcAddress,
    required this.value,
    required this.recordedAt,
    this.cateId,
    this.scadaId,
    this.fac,
    this.cate,
    this.boxId,
  });

  factory LatestRecordDto.fromJson(Map<String, dynamic> json) {
    // value có thể là int/double/string tùy backend serialize
    final rawValue = json['value'];
    double? v;
    if (rawValue == null) {
      v = null;
    } else if (rawValue is num) {
      v = rawValue.toDouble();
    } else {
      v = double.tryParse(rawValue.toString());
    }

    return LatestRecordDto(
      boxDeviceId: (json['boxDeviceId'] ?? '').toString(),
      plcAddress: (json['plcAddress'] ?? '').toString(),
      value: v,
      recordedAt: DateTime.parse(json['recordedAt'].toString()),
      cateId: json['cateId']?.toString(),
      scadaId: json['scadaId']?.toString(),
      fac: json['fac']?.toString(),
      cate: json['cate']?.toString(),
      boxId: json['boxId']?.toString(),
    );
  }
}
