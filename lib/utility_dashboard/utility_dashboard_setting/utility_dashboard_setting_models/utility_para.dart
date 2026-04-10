class UtilityPara {
  final int? id;
  final String? boxDeviceId;
  final String? plcAddress;
  final String? valueType;
  final String? unit;
  final String? cateId;
  final String? nameVi;
  final String? nameEn;
  final int? isImportant;
  final int? isAlert;
  final int? minAlert;
  final int? maxAlert;

  const UtilityPara({
    this.id,
    this.boxDeviceId,
    this.plcAddress,
    this.valueType,
    this.unit,
    this.cateId,
    this.nameVi,
    this.nameEn,
    this.isImportant,
    this.isAlert,
    this.minAlert,
    this.maxAlert,
  });

  factory UtilityPara.fromJson(Map<String, dynamic> json) {
    return UtilityPara(
      id: json['id'],
      boxDeviceId: json['boxDeviceId'],
      plcAddress: json['plcAddress'],
      valueType: json['valueType'],
      unit: json['unit'],
      cateId: json['cateId'],
      nameVi: json['nameVi'],
      nameEn: json['nameEn'],
      isImportant: json['isImportant'],
      isAlert: json['isAlert'],
      minAlert: json['minAlert'],
      maxAlert: json['maxAlert'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'boxDeviceId': boxDeviceId,
    'plcAddress': plcAddress,
    'valueType': valueType,
    'unit': unit,
    'cateId': cateId,
    'nameVi': nameVi,
    'nameEn': nameEn,
    'isImportant': isImportant,
    'isAlert': isAlert,
    'minAlert': minAlert,
    'maxAlert': maxAlert,
  }..removeWhere((k, v) => v == null);

  UtilityPara copyWith({
    int? id,
    String? boxDeviceId,
    String? plcAddress,
    String? valueType,
    String? unit,
    String? cateId,
    String? nameVi,
    String? nameEn,
    int? isImportant,
    int? isAlert,
    int? minAlert,
    int? maxAlert,
  }) {
    return UtilityPara(
      id: id ?? this.id,
      boxDeviceId: boxDeviceId ?? this.boxDeviceId,
      plcAddress: plcAddress ?? this.plcAddress,
      valueType: valueType ?? this.valueType,
      unit: unit ?? this.unit,
      cateId: cateId ?? this.cateId,
      nameVi: nameVi ?? this.nameVi,
      nameEn: nameEn ?? this.nameEn,
      isImportant: isImportant ?? this.isImportant,
      isAlert: isAlert ?? this.isAlert,
      minAlert: minAlert ?? this.minAlert,
      maxAlert: maxAlert ?? this.maxAlert,
    );
  }
}
