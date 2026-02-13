class HourPointDto {
  final DateTime ts;
  final double value;

  final String? boxDeviceId;
  final String? plcAddress;

  final String? cateId;
  final String? nameEn;
  final String? nameVi;

  final String? fac;
  final String? cate;

  HourPointDto({
    required this.ts,
    required this.value,
    this.boxDeviceId,
    this.plcAddress,
    this.cateId,
    this.nameEn,
    this.nameVi,
    this.fac,
    this.cate,
  });

  factory HourPointDto.fromJson(Map<String, dynamic> j) {
    // Backend trả LocalDateTime -> ISO string
    final ts = DateTime.parse(j['ts'] as String);

    final v = j['value'];
    final value = v == null ? 0.0 : (v as num).toDouble();

    return HourPointDto(
      ts: ts,
      value: value,
      boxDeviceId: j['boxDeviceId'] as String?,
      plcAddress: j['plcAddress'] as String?,
      cateId: j['cateId'] as String?,
      nameEn: j['nameEn'] as String?,
      nameVi: j['nameVi'] as String?,
      fac: j['fac'] as String?,
      cate: j['cate'] as String?,
    );
  }
}
