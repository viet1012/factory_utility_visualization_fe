class ScadaDto {
  final String scadaId;
  final String fac;
  final String plcIp;
  final int? plcPort;
  final String? wlan;

  ScadaDto({
    required this.scadaId,
    required this.fac,
    required this.plcIp,
    this.plcPort,
    this.wlan,
  });

  factory ScadaDto.fromJson(Map<String, dynamic> j) => ScadaDto(
    scadaId: '${j['scadaId'] ?? ''}',
    fac: '${j['fac'] ?? ''}',
    plcIp: '${j['plcIp'] ?? ''}',
    plcPort: j['plcPort'] == null ? null : int.tryParse('${j['plcPort']}'),
    wlan: j['wlan']?.toString(),
  );
}
