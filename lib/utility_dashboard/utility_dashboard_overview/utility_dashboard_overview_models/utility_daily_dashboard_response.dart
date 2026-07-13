class UtilityDailyPoint {
  final DateTime date;
  final double value;

  const UtilityDailyPoint({required this.date, required this.value});

  factory UtilityDailyPoint.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['date'] ?? '').toString().trim();
    final rawValue = json['value'];

    return UtilityDailyPoint(
      date: DateTime.tryParse(rawDate) ?? DateTime(1970),
      value: rawValue is num
          ? rawValue.toDouble()
          : double.tryParse(rawValue?.toString() ?? '') ?? 0,
    );
  }
}

class UtilityDailyDashboardResponse {
  final String facId;
  final String month;

  final List<UtilityDailyPoint> electricity;
  final List<UtilityDailyPoint> water;
  final List<UtilityDailyPoint> air;

  const UtilityDailyDashboardResponse({
    required this.facId,
    required this.month,
    required this.electricity,
    required this.water,
    required this.air,
  });

  factory UtilityDailyDashboardResponse.fromJson(Map<String, dynamic> json) {
    List<UtilityDailyPoint> parsePoints(dynamic raw) {
      if (raw is! List) {
        return const [];
      }

      final result =
          raw
              .whereType<Map>()
              .map(
                (item) =>
                    UtilityDailyPoint.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));

      return List<UtilityDailyPoint>.unmodifiable(result);
    }

    return UtilityDailyDashboardResponse(
      facId: (json['facId'] ?? '').toString().trim(),
      month: (json['month'] ?? '').toString().trim(),
      electricity: parsePoints(json['electricity']),
      water: parsePoints(json['water']),
      air: parsePoints(json['air']),
    );
  }
}
