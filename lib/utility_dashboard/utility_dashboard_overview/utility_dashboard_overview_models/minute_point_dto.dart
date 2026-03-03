class MinutePointDto {
  final DateTime ts;
  final double? value;

  MinutePointDto({required this.ts, required this.value});

  factory MinutePointDto.fromJson(Map<String, dynamic> json) {
    return MinutePointDto(
      ts: DateTime.parse(json['ts']),
      value: (json['value'] as num?)?.toDouble(),
    );
  }
}
