class ChartCatalogItem {
  final String scadaId;

  final String boxId;
  final String boxDeviceId;

  final String plcAddress;

  /// "ANALOG" | "COUNTER" | "STATUS" (null khi backend khong tra).
  final String? kind;
  final String? unit;
  final String? cateId;

  final String? nameEn;

  const ChartCatalogItem({
    required this.scadaId,
    required this.boxId,
    required this.boxDeviceId,
    required this.plcAddress,
    this.kind,
    required this.unit,
    required this.cateId,
    required this.nameEn,
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

    return ChartCatalogItem(
      scadaId: requiredText(json['scadaId']),
      boxId: requiredText(json['boxId']),
      boxDeviceId: requiredText(json['boxDeviceId']),
      plcAddress: requiredText(json['plcAddress']),
      kind: nullableText(json['kind'])?.toUpperCase(),
      unit: nullableText(json['unit']),
      cateId: nullableText(json['cateId']),
      nameEn: nullableText(json['nameEn']),
    );
  }
}
