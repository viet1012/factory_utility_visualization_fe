import 'dart:convert';

import 'package:factory_utility_visualization/utility_models/utility_model.dart';

import 'f2_utility_parameter_master.dart';

/// ======================
/// 4) f2_utility_parameter_history
/// ======================
class UtilityParameterHistory {
  final int id;
  final String boxDeviceId;
  final String plcAddress;

  /// value để dynamic vì tuỳ valueType (int/long/float...)
  final dynamic value;

  final DateTime recordedAt;

  const UtilityParameterHistory({
    required this.id,
    required this.boxDeviceId,
    required this.plcAddress,
    required this.value,
    required this.recordedAt,
  });

  factory UtilityParameterHistory.fromJson(Map<String, dynamic> json) {
    final dt = toDateTime(json['recorded_at']) ?? DateTime.now();
    return UtilityParameterHistory(
      id: toInt(json['id']) ?? 0,
      boxDeviceId: (toStr(json['boxDeviceId']) ?? ''),
      plcAddress: (toStr(json['plcAddress']) ?? ''),
      value: json['value'],
      recordedAt: dt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'box_device_id': boxDeviceId,
    'plc_address': plcAddress,
    'value': value,
    'recorded_at': recordedAt.toIso8601String(),
  };

  /// Convert value theo master.valueType (dùng khi map history với master)
  dynamic castValue(UtilityValueType t) {
    switch (t) {
      case UtilityValueType.intType:
      case UtilityValueType.longType:
        return toInt(value);
      case UtilityValueType.floatType:
      case UtilityValueType.doubleType:
        return toDouble(value);
      case UtilityValueType.boolType:
        final s = (value ?? '').toString().trim().toLowerCase();
        return s == '1' || s == 'true' || s == 'yes';
      case UtilityValueType.stringType:
        return value?.toString();
      case UtilityValueType.unknown:
        return value;
    }
  }
}

/// ======================
/// Optional: DTO gộp để render dashboard nhanh
/// (master + latest history)
/// ======================
class UtilityRealtimePoint {
  final UtilityParameterMaster master;
  final UtilityParameterHistory? latest;

  const UtilityRealtimePoint({required this.master, required this.latest});

  String get displayName =>
      master.nameEn.isNotEmpty ? master.nameEn : master.nameVi;

  String get displayValue {
    if (latest == null) return '--';
    final v = latest!.castValue(master.valueType);
    if (v == null) return '--';
    return '$v ${master.unit}'.trim();
  }
}

/// Helper parse list from api
List<T> parseList<T>(
  dynamic jsonList,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (jsonList is! List) return <T>[];
  return jsonList
      .whereType<Map>()
      .map((e) => fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

/// Helper decode from string
List<T> parseListFromString<T>(
  String raw,
  T Function(Map<String, dynamic>) fromJson,
) {
  final data = jsonDecode(raw);
  return parseList<T>(data, fromJson);
}
