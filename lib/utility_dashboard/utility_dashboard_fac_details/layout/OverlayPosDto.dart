class OverlayPosDto {
  final String plcAddress;
  final double x;
  final double y;

  OverlayPosDto({required this.plcAddress, required this.x, required this.y});

  factory OverlayPosDto.fromJson(Map<String, dynamic> j) => OverlayPosDto(
    plcAddress: (j['plcAddress'] ?? '').toString(),
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
  );
}
