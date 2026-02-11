class ParamDto {
  final int? id;
  final String boxDeviceId;
  final String plcAddress;
  final String valueType;
  final String unit;
  final String category;
  final String nameVi;
  final String nameEn;
  final bool? isImportant;
  final bool? isAlert;

  final String? cateId;
  final String? scadaId;
  final String? fac;
  final String? cate;
  final String? boxId;

  ParamDto({
    this.id,
    required this.boxDeviceId,
    required this.plcAddress,
    required this.valueType,
    required this.unit,
    required this.category,
    required this.nameVi,
    required this.nameEn,
    this.isImportant,
    this.isAlert,
    this.cateId,
    this.scadaId,
    this.fac,
    this.cate,
    this.boxId,
  });

  factory ParamDto.fromJson(Map<String, dynamic> j) => ParamDto(
    id: j['id'] == null ? null : int.tryParse('${j['id']}'),
    boxDeviceId: '${j['boxDeviceId'] ?? ''}',
    plcAddress: '${j['plcAddress'] ?? ''}',
    valueType: '${j['valueType'] ?? ''}',
    unit: '${j['unit'] ?? ''}',
    category: '${j['category'] ?? ''}',
    nameVi: '${j['nameVi'] ?? ''}',
    nameEn: '${j['nameEn'] ?? ''}',
    isImportant: j['isImportant'] as bool?,
    isAlert: j['isAlert'] as bool?,
    cateId: j['cateId']?.toString(),
    scadaId: j['scadaId']?.toString(),
    fac: j['fac']?.toString(),
    cate: j['cate']?.toString(),
    boxId: j['boxId']?.toString(),
  );
}
