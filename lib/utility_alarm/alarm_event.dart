enum AlarmSeverity { alarm, warning, info, offline }

class AlarmEvent {
  final String id;
  final DateTime ts;
  final String facId;
  final String cate; // Electricity/Water/Air...
  final String boxDeviceId;
  final String plcAddress;

  final AlarmSeverity severity;
  final String message;

  final double? value;
  final String? unit;

  final bool acked;
  final String? ackBy;
  final DateTime? ackAt;

  const AlarmEvent({
    required this.id,
    required this.ts,
    required this.facId,
    required this.cate,
    required this.boxDeviceId,
    required this.plcAddress,
    required this.severity,
    required this.message,
    this.value,
    this.unit,
    this.acked = false,
    this.ackBy,
    this.ackAt,
  });

  AlarmEvent copyWith({bool? acked, String? ackBy, DateTime? ackAt}) {
    return AlarmEvent(
      id: id,
      ts: ts,
      facId: facId,
      cate: cate,
      boxDeviceId: boxDeviceId,
      plcAddress: plcAddress,
      severity: severity,
      message: message,
      value: value,
      unit: unit,
      acked: acked ?? this.acked,
      ackBy: ackBy ?? this.ackBy,
      ackAt: ackAt ?? this.ackAt,
    );
  }
}
