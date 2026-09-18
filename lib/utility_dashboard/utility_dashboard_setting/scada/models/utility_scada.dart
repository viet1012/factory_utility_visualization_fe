import 'dart:convert';

class UtilityScada {
  final int? id;
  final String? scadaId;
  final String? fac;
  final String? plcIp;
  final int? plcPort;
  final String? pcName;
  final String? wlan;
  final String? connected;
  final bool? alert;
  final String? timeUpdate;
  final Map<String, dynamic> raw;

  const UtilityScada({
    this.id,
    this.scadaId,
    this.fac,
    this.plcIp,
    this.plcPort,
    this.pcName,
    this.wlan,
    this.connected,
    this.alert,
    this.timeUpdate,
    this.raw = const {},
  });

  factory UtilityScada.fromJson(Map<String, dynamic> json) {
    return UtilityScada(
      id: _toInt(json['id']),
      scadaId: json['scadaId']?.toString(),
      fac: json['fac']?.toString(),
      plcIp: json['plcIp']?.toString(),
      plcPort: _toInt(json['plcPort']),
      pcName: json['pcName']?.toString(),
      wlan: json['wlan']?.toString(),
      connected: json['connected'],
      alert: _toBool(json['alert']),
      timeUpdate: json['timeUpdate']?.toString(),
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      ...raw,
      'id': id,
      'scadaId': scadaId,
      'fac': fac,
      'plcIp': plcIp,
      'plcPort': plcPort,
      'pcName': pcName,
      'wlan': wlan,
      'connected': connected,
      'alert': alert,
      'timeUpdate': timeUpdate,
    };

    data.removeWhere((key, value) => value == null);
    return data;
  }

  UtilityScada copyWith({
    int? id,
    String? scadaId,
    String? fac,
    String? plcIp,
    int? plcPort,
    String? pcName,
    String? wlan,
    String? connected,
    bool? alert,
    String? timeUpdate,
    Map<String, dynamic>? raw,
  }) {
    return UtilityScada(
      id: id ?? this.id,
      scadaId: scadaId ?? this.scadaId,
      fac: fac ?? this.fac,
      plcIp: plcIp ?? this.plcIp,
      plcPort: plcPort ?? this.plcPort,
      pcName: pcName ?? this.pcName,
      wlan: wlan ?? this.wlan,
      connected: connected ?? this.connected,
      alert: alert ?? this.alert,
      timeUpdate: timeUpdate ?? this.timeUpdate,
      raw: raw ?? this.raw,
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static bool? _toBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;

    final normalized = value.toString().toLowerCase().trim();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;

    return null;
  }

  @override
  String toString() => jsonEncode(toJson());
}
