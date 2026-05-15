class LatestRecordDto {
  final String boxDeviceId;
  final String plcAddress;
  final double? value;
  final DateTime recordedAt;
  final String? nameEn;

  final String? cateId;
  final String? scadaId;
  final String? fac;
  final String? cate;
  final String? boxId;

  // 🔥 thêm alarm + min max
  final String? alarm;
  final double? minVol;
  final double? maxVol;
  final double? minVolStd;
  final double? maxVolStd;

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
    this.nameEn,

    this.alarm,
    this.minVol,
    this.maxVol,
    this.minVolStd,
    this.maxVolStd,
  });

  factory LatestRecordDto.fromJson(Map<String, dynamic> json) {
    // value parse
    final rawValue = json['value'];
    double? v;
    if (rawValue == null) {
      v = null;
    } else if (rawValue is num) {
      v = rawValue.toDouble();
    } else {
      v = double.tryParse(rawValue.toString());
    }

    double? _toDouble(dynamic x) {
      if (x == null) return null;
      if (x is num) return x.toDouble();
      return double.tryParse(x.toString());
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
      nameEn: json['name_en']?.toString(),

      // 🔥 map alarm
      alarm: json['alarm']?.toString(),

      // optional
      minVol: _toDouble(json['minVol']),
      maxVol: _toDouble(json['maxVol']),
      minVolStd: _toDouble(json['minVolStd']),
      maxVolStd: _toDouble(json['maxVolStd']),
    );
  }
}
