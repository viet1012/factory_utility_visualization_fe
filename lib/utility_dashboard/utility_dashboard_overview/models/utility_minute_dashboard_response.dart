class OverviewMinutePointDto {
  final DateTime ts;
  final double? value;
  final String? nameEn;

  const OverviewMinutePointDto({
    required this.ts,
    required this.value,
    required this.nameEn,
  });

  factory OverviewMinutePointDto.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();

      return double.tryParse(value.toString());
    }

    final rawTs = json['ts']?.toString();

    return OverviewMinutePointDto(
      ts:
          DateTime.tryParse(rawTs ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      value: toDouble(json['value']),
      nameEn: json['nameEn']?.toString() ?? json['name']?.toString(),
    );
  }
}

class UtilityMinuteDashboardResponse {
  final String facId;
  final int minutes;
  final DateTime? generatedAt;

  final List<OverviewMinutePointDto> electricity;
  final List<OverviewMinutePointDto> water;
  final List<OverviewMinutePointDto> air;

  const UtilityMinuteDashboardResponse({
    required this.facId,
    required this.minutes,
    required this.generatedAt,
    required this.electricity,
    required this.water,
    required this.air,
  });

  factory UtilityMinuteDashboardResponse.fromJson(Map<String, dynamic> json) {
    List<OverviewMinutePointDto> parsePoints(dynamic raw) {
      if (raw is! List) {
        return const [];
      }

      final points = <OverviewMinutePointDto>[];

      for (final item in raw) {
        if (item is! Map) continue;

        final point = OverviewMinutePointDto.fromJson(
          Map<String, dynamic>.from(item),
        );

        if (point.ts.millisecondsSinceEpoch <= 0) {
          continue;
        }

        points.add(point);
      }

      points.sort((a, b) => a.ts.compareTo(b.ts));

      return List<OverviewMinutePointDto>.unmodifiable(points);
    }

    int parseInt(dynamic value) {
      if (value is num) return value.toInt();

      return int.tryParse(value?.toString() ?? '') ?? 60;
    }

    return UtilityMinuteDashboardResponse(
      facId: json['facId']?.toString() ?? '',
      minutes: parseInt(json['minutes']),
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? ''),
      electricity: parsePoints(json['electricity']),
      water: parsePoints(json['water']),
      air: parsePoints(json['air']),
    );
  }
}
