class UtilityDailyDashboardResponse {
  final String boxDeviceId;
  final String month;
  final DateTime? fromTime;
  final DateTime? toTime;
  final List<UtilityDailySeries> series;

  const UtilityDailyDashboardResponse({
    required this.boxDeviceId,
    required this.month,
    required this.fromTime,
    required this.toTime,
    required this.series,
  });

  factory UtilityDailyDashboardResponse.fromJson(Map<String, dynamic> json) {
    final boxDeviceId = json['boxDeviceId']?.toString().trim() ?? '';

    final rawSeries = json['series'];

    final parsedSeries = rawSeries is List
        ? rawSeries
              .whereType<Map>()
              .map(
                (item) => UtilityDailySeries.fromJson(
                  Map<String, dynamic>.from(item),
                ).copyWith(boxDeviceId: boxDeviceId),
              )
              .toList(growable: false)
        : const <UtilityDailySeries>[];

    return UtilityDailyDashboardResponse(
      boxDeviceId: boxDeviceId,
      month: json['month']?.toString().trim() ?? '',
      fromTime: DateTime.tryParse(json['fromTime']?.toString() ?? ''),
      toTime: DateTime.tryParse(json['toTime']?.toString() ?? ''),
      series: parsedSeries,
    );
  }
}

class UtilityDailySeries {
  final String boxDeviceId;

  final String utilityType;
  final String plcAddress;
  final String nameEn;
  final String unit;
  final String aggregation;

  final List<UtilityDailyPoint> dailyValues;

  const UtilityDailySeries({
    required this.boxDeviceId,
    required this.utilityType,
    required this.plcAddress,
    required this.nameEn,
    required this.unit,
    required this.aggregation,
    required this.dailyValues,
  });

  bool get isEnergyConsumption {
    final normalizedName = nameEn.trim().toUpperCase();
    final normalizedAggregation = aggregation.trim().toUpperCase();

    return normalizedName == 'TOTAL ENERGY CONSUMPTION' ||
        normalizedAggregation == 'DAILY_DELTA';
  }

  List<UtilityDailyPoint> get sortedPoints {
    final result = List<UtilityDailyPoint>.from(dailyValues);

    result.sort(
      (first, second) => first.recordDate.compareTo(second.recordDate),
    );

    return result;
  }

  UtilityDailySeries copyWith({String? boxDeviceId}) {
    return UtilityDailySeries(
      boxDeviceId: boxDeviceId ?? this.boxDeviceId,
      utilityType: utilityType,
      plcAddress: plcAddress,
      nameEn: nameEn,
      unit: unit,
      aggregation: aggregation,
      dailyValues: dailyValues,
    );
  }

  factory UtilityDailySeries.fromJson(Map<String, dynamic> json) {
    final rawDailyValues = json['dailyValues'];

    return UtilityDailySeries(
      // API cũ chưa trả field này trong series.
      boxDeviceId: json['boxDeviceId']?.toString().trim() ?? '',
      utilityType: json['utilityType']?.toString().trim() ?? '',
      plcAddress: json['plcAddress']?.toString().trim() ?? '',
      nameEn: json['nameEn']?.toString().trim() ?? '',
      unit: json['unit']?.toString().trim() ?? '',
      aggregation: json['aggregation']?.toString().trim() ?? '',
      dailyValues: rawDailyValues is List
          ? rawDailyValues
                .whereType<Map>()
                .map(
                  (item) => UtilityDailyPoint.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const <UtilityDailyPoint>[],
    );
  }
}

class UtilityDailyPoint {
  final DateTime recordDate;

  final double? avgValue;
  final double? minValue;
  final double? maxValue;

  final double? firstValue;
  final double? lastValue;

  final double? consumption;
  final int sampleCount;

  const UtilityDailyPoint({
    required this.recordDate,
    required this.avgValue,
    required this.minValue,
    required this.maxValue,
    required this.firstValue,
    required this.lastValue,
    required this.consumption,
    required this.sampleCount,
  });

  factory UtilityDailyPoint.fromJson(Map<String, dynamic> json) {
    return UtilityDailyPoint(
      recordDate:
          _readDateTime(json['recordDate']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      avgValue: _readDouble(json['avgValue']),
      minValue: _readDouble(json['minValue']),
      maxValue: _readDouble(json['maxValue']),
      firstValue: _readDouble(json['firstValue']),
      lastValue: _readDouble(json['lastValue']),
      consumption: _readDouble(json['consumption']),
      sampleCount: _readInt(json['sampleCount']),
    );
  }
}

String _readString(dynamic value) {
  return value?.toString().trim() ?? '';
}

double? _readDouble(dynamic value) {
  if (value == null) return null;

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString());
}

int _readInt(dynamic value) {
  if (value == null) return 0;

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value.toString()) ?? 0;
}

DateTime? _readDateTime(dynamic value) {
  if (value == null) return null;

  if (value is DateTime) {
    return value;
  }

  return DateTime.tryParse(value.toString());
}
