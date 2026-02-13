class MinutePointDto {
  final DateTime ts;
  final double? value;

  final String boxDeviceId;
  final String plcAddress;

  final String? cateId;

  // ✅ NEW
  final String? nameEn;
  final String? nameVi;
  final String? fac;
  final String? cate;

  MinutePointDto({
    required this.ts,
    required this.value,
    required this.boxDeviceId,
    required this.plcAddress,
    this.cateId,

    this.nameEn,
    this.nameVi,
    this.fac,
    this.cate,
  });

  factory MinutePointDto.fromJson(Map<String, dynamic> json) {
    final raw = json['value'];
    double? v;
    if (raw == null) {
      v = null;
    } else if (raw is num) {
      v = raw.toDouble();
    } else {
      v = double.tryParse(raw.toString());
    }

    return MinutePointDto(
      ts: DateTime.parse(json['ts'].toString()),
      value: v,
      boxDeviceId: (json['boxDeviceId'] ?? '').toString(),
      plcAddress: (json['plcAddress'] ?? '').toString(),
      cateId: json['cateId']?.toString(),

      // ✅ NEW fields (tên key phải đúng với backend record)
      nameEn: json['nameEn']?.toString(),
      nameVi: json['nameVi']?.toString(),
      fac: json['fac']?.toString(),
      cate: json['cate']?.toString(),
    );
  }
}
