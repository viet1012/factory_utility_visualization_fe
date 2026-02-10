import 'package:factory_utility_visualization/utility_models/utility_model.dart';

/// ======================
/// 2) f2_utility_scada_channel
/// ======================
class UtilityScadaChannel {
  final int id;
  final String scadaId;
  final String cate; // Electricity / Water / Air ...
  final String boxDeviceId; // DB-P1_Device 1 ...
  final String boxId; // DB-P1 / MCCB BOX ...

  const UtilityScadaChannel({
    required this.id,
    required this.scadaId,
    required this.cate,
    required this.boxDeviceId,
    required this.boxId,
  });

  factory UtilityScadaChannel.fromJson(Map<String, dynamic> json) {
    return UtilityScadaChannel(
      id: toInt(json['id']) ?? 0,
      scadaId: (toStr(json['scada_id']) ?? ''),
      cate: (toStr(json['cate']) ?? ''),
      boxDeviceId: (toStr(json['box_device_id']) ?? ''),
      boxId: (toStr(json['box_id']) ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'scada_id': scadaId,
        'cate': cate,
        'box_device_id': boxDeviceId,
        'box_id': boxId,
      };
}