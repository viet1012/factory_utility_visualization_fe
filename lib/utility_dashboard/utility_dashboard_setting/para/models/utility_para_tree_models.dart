class UtilityParaTreeFacGroup {
  final String fac;
  final List<UtilityParaTreeFac> scadas;

  const UtilityParaTreeFacGroup({required this.fac, required this.scadas});
}

class UtilityParaTreeFac {
  final String fac;
  final String scadaId;
  final List<UtilityParaTreeBox> boxes;

  const UtilityParaTreeFac({
    required this.fac,
    required this.scadaId,
    required this.boxes,
  });

  factory UtilityParaTreeFac.fromJson(Map<String, dynamic> json) {
    return UtilityParaTreeFac(
      fac: json['fac']?.toString() ?? '',
      scadaId: json['scadaId']?.toString() ?? '',
      boxes: (json['boxes'] as List? ?? [])
          .map((e) => UtilityParaTreeBox.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class UtilityParaTreeBox {
  final String boxId;
  final List<UtilityParaTreeDevice> devices;

  const UtilityParaTreeBox({required this.boxId, required this.devices});

  factory UtilityParaTreeBox.fromJson(Map<String, dynamic> json) {
    return UtilityParaTreeBox(
      boxId: json['boxId']?.toString() ?? '',
      devices: (json['devices'] as List? ?? [])
          .map(
            (e) => UtilityParaTreeDevice.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
}

class UtilityParaTreeDevice {
  final int? channelId;
  final String cate;
  final String boxDeviceId;
  final List<UtilityParaItem> paras;

  const UtilityParaTreeDevice({
    required this.channelId,
    required this.cate,
    required this.boxDeviceId,
    required this.paras,
  });

  factory UtilityParaTreeDevice.fromJson(Map<String, dynamic> json) {
    return UtilityParaTreeDevice(
      channelId: json['channelId'] as int?,
      cate: json['cate']?.toString() ?? '',
      boxDeviceId: json['boxDeviceId']?.toString() ?? '',
      paras: (json['paras'] as List? ?? [])
          .map((e) => UtilityParaItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class UtilityParaItem {
  final int? id;
  final String plcAddress;
  final String valueType;
  final String unit;
  final String cateId;
  final String nameVi;
  final String nameEn;
  final int? isImportant;
  final int? isAlert;
  final int? minAlert;
  final int? maxAlert;

  const UtilityParaItem({
    required this.id,
    required this.plcAddress,
    required this.valueType,
    required this.unit,
    required this.cateId,
    required this.nameVi,
    required this.nameEn,
    required this.isImportant,
    required this.isAlert,
    required this.minAlert,
    required this.maxAlert,
  });

  factory UtilityParaItem.fromJson(Map<String, dynamic> json) {
    return UtilityParaItem(
      id: json['id'] as int?,
      plcAddress: json['plcAddress']?.toString() ?? '',
      valueType: json['valueType']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      cateId: json['cateId']?.toString() ?? '',
      nameVi: json['nameVi']?.toString() ?? '',
      nameEn: json['nameEn']?.toString() ?? '',
      isImportant: json['isImportant'] as int?,
      isAlert: json['isAlert'] as int?,
      minAlert: _toInt(json['minAlert']),
      maxAlert: _toInt(json['maxAlert']),
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
