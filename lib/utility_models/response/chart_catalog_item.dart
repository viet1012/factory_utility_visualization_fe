class ChartCatalogItem {
  final String fac;
  final String scadaId;
  final String cate;

  final String boxId;
  final String boxDeviceId;

  final int? paraId;
  final String plcAddress;

  final String? valueType;
  final String? unit;
  final String? cateId;

  final String? nameVi;
  final String? nameEn;

  final int isImportant;
  final int isAlert;

  final double? minAlert;
  final double? maxAlert;

  const ChartCatalogItem({
    required this.fac,
    required this.scadaId,
    required this.cate,
    required this.boxId,
    required this.boxDeviceId,
    required this.paraId,
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

  factory ChartCatalogItem.fromJson(Map<String, dynamic> json) {
    String requiredText(dynamic value) {
      return (value ?? '').toString().trim();
    }

    String? nullableText(dynamic value) {
      if (value == null) return null;

      final normalized = value.toString().trim();

      return normalized.isEmpty ? null : normalized;
    }

    int intValue(dynamic value, {int fallback = 0}) {
      if (value is num) return value.toInt();

      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    int? nullableInt(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();

      return int.tryParse(value.toString());
    }

    double? nullableDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();

      return double.tryParse(value.toString());
    }

    return ChartCatalogItem(
      fac: requiredText(json['fac']),
      scadaId: requiredText(json['scadaId']),
      cate: requiredText(json['cate']),
      boxId: requiredText(json['boxId']),
      boxDeviceId: requiredText(json['boxDeviceId']),
      paraId: nullableInt(json['paraId']),
      plcAddress: requiredText(json['plcAddress']),
      valueType: nullableText(json['valueType']),
      unit: nullableText(json['unit']),
      cateId: nullableText(json['cateId']),
      nameVi: nullableText(json['nameVi']),
      nameEn: nullableText(json['nameEn']),
      isImportant: intValue(json['isImportant']),
      isAlert: intValue(json['isAlert']),
      minAlert: nullableDouble(json['minAlert']),
      maxAlert: nullableDouble(json['maxAlert']),
    );
  }
}
