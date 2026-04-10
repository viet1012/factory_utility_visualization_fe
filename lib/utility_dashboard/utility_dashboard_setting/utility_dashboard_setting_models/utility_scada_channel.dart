import 'dart:convert';

class UtilityScadaChannel {
  final int? id;
  final String? scadaId;
  final String? cate;
  final String? boxDeviceId;
  final String? boxId;
  final Map<String, dynamic> raw;

  const UtilityScadaChannel({
    this.id,
    this.scadaId,
    this.cate,
    this.boxDeviceId,
    this.boxId,
    this.raw = const {},
  });

  factory UtilityScadaChannel.fromJson(Map<String, dynamic> json) {
    return UtilityScadaChannel(
      id: _toInt(json['id']),
      scadaId: json['scadaId']?.toString(),
      cate: json['cate']?.toString(),
      boxDeviceId: json['boxDeviceId']?.toString(),
      boxId: json['boxId']?.toString(),
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      ...raw,
      'id': id,
      'scadaId': scadaId,
      'cate': cate,
      'boxDeviceId': boxDeviceId,
      'boxId': boxId,
    };

    data.removeWhere((key, value) => value == null);
    return data;
  }

  UtilityScadaChannel copyWith({
    int? id,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    String? boxId,
    Map<String, dynamic>? raw,
  }) {
    return UtilityScadaChannel(
      id: id ?? this.id,
      scadaId: scadaId ?? this.scadaId,
      cate: cate ?? this.cate,
      boxDeviceId: boxDeviceId ?? this.boxDeviceId,
      boxId: boxId ?? this.boxId,
      raw: raw ?? this.raw,
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  @override
  String toString() => jsonEncode(toJson());
}

// Constants
const String labelCreateChannel = 'Create SCADA Channel';
const String labelEditChannel = 'Edit SCADA Channel';
const String labelAddChannel = 'Add Channel';
const String labelRefresh = 'Refresh';
const String labelRetry = 'Retry';
const String labelCancel = 'Cancel';
const String labelUpdate = 'Update';
const String labelCreate = 'Create';
const String labelEdit = 'Edit';
const String labelTotal = 'Total';
const String labelShowing = 'Showing';
const String labelNoData = 'No data found';
const String labelCreatedSuccess = 'Created successfully';
const String labelUpdatedSuccess = 'Updated successfully';
const String labelSearchHint = 'Search by SCADA, category, box, device...';
const String labelChannels = 'Utility SCADA Channels';

const String labelScadaId = 'SCADA ID';
const String labelCategory = 'Category';
const String labelBoxDeviceId = 'Box Device ID';
const String labelBoxId = 'Box ID';

const String validatorScadaRequired = 'SCADA ID is required';
const String validatorCateRequired = 'Category is required';
const String validatorBoxDeviceRequired = 'Box Device ID is required';
const String validatorBoxIdRequired = 'Box ID is required';
