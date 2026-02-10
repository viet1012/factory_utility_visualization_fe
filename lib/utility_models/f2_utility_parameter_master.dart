import 'package:factory_utility_visualization/utility_models/utility_model.dart';

/// ======================
/// 3) f2_utility_parameter_master
/// ======================
class UtilityParameterMaster {
  final int id;
  final String category; // Current, Energy Consumption...
  final String nameVi;
  final String nameEn;
  final String unit; // A, kWh, %
  final String boxDeviceId; // DB-P1_Device 1
  final String plcAddress; // D1, E1...
  final UtilityValueType valueType;
  final bool isImportant;

  const UtilityParameterMaster({
    required this.id,
    required this.category,
    required this.nameVi,
    required this.nameEn,
    required this.unit,
    required this.boxDeviceId,
    required this.plcAddress,
    required this.valueType,
    required this.isImportant,
  });

  factory UtilityParameterMaster.fromJson(Map<String, dynamic> json) {
    final impRaw = json['is_important'];
    final imp =
        (impRaw == true) ||
        (impRaw is num && impRaw.toInt() == 1) ||
        (impRaw?.toString().trim() == '1');

    return UtilityParameterMaster(
      id: toInt(json['id']) ?? 0,
      category: (toStr(json['category']) ?? ''),
      nameVi: (toStr(json['nameVi']) ?? ''),
      nameEn: (toStr(json['nameEn']) ?? ''),
      unit: (toStr(json['unit']) ?? ''),
      boxDeviceId: (toStr(json['boxDeviceId']) ?? ''),
      plcAddress: (toStr(json['plcAddress']) ?? ''),
      valueType: UtilityValueType.fromDb(json['value_type']),
      isImportant: imp,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'name_vi': nameVi,
    'name_en': nameEn,
    'unit': unit,
    'box_device_id': boxDeviceId,
    'plc_address': plcAddress,
    'value_type': valueType.toDb(),
    'is_important': isImportant ? 1 : 0,
  };
}
