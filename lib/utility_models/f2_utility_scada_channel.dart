class ChannelDto {
  final int? id;
  final String scadaId;
  final String cate;
  final String boxDeviceId;
  final String boxId;

  ChannelDto({
    this.id,
    required this.scadaId,
    required this.cate,
    required this.boxDeviceId,
    required this.boxId,
  });

  factory ChannelDto.fromJson(Map<String, dynamic> j) => ChannelDto(
    id: j['id'] == null ? null : int.tryParse('${j['id']}'),
    scadaId: '${j['scadaId'] ?? ''}',
    cate: '${j['cate'] ?? ''}',
    boxDeviceId: '${j['boxDeviceId'] ?? ''}',
    boxId: '${j['boxId'] ?? ''}',
  );
}
