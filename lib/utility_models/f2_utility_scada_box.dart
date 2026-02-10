import 'package:factory_utility_visualization/utility_models/utility_model.dart';

/// ======================
/// 1) f2_utility_scada_box
/// ======================
class UtilityScadaBox {
  final int id;
  final String scadaId;
  final String facName;
  final String plcIp;
  final int plcPort;
  final String? wlan;

  const UtilityScadaBox({
    required this.id,
    required this.scadaId,
    required this.facName,
    required this.plcIp,
    required this.plcPort,
    this.wlan,
  });

  factory UtilityScadaBox.fromJson(Map<String, dynamic> json) {
    return UtilityScadaBox(
      id: toInt(json['id']) ?? 0,
      scadaId: toStr(json['scadaId']) ?? '',
      facName: toStr(json['fac']) ?? '',
      plcIp: toStr(json['plcIp']) ?? '',
      plcPort: toInt(json['plcPort']) ?? 0,
      wlan: toStr(json['wlan']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'scadaId': scadaId,
    'fac': facName,
    'plcIp': plcIp,
    'plcPort': plcPort,
    'wlan': wlan,
  };
}
