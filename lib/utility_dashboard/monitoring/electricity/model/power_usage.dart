/// GET /api/utility/power-usage. kWh = grid kWh + solar kWh, USD / rate la
/// USD/kWh. changePct null khi ky truoc bang 0.
library;

import '../../../shared/json/json_read.dart';

enum PowerPeriod {
  day('day', 'Day'),
  week('week', 'Week'),
  month('month', 'Month');

  const PowerPeriod(this.query, this.label);

  final String query;
  final String label;
}

enum PowerUnit {
  kwh('kWh'),
  usd('USD');

  const PowerUnit(this.label);

  final String label;
}

int _toInt(Object? value) => jsonInt(value) ?? 0;

List<T> _toList<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => parse(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

class PowerUsageTotal {
  final double? kwh;
  final double? prevKwh;
  final double? changePct;

  /// null khi supplyMix rong (bang gia / ty gia chua dung duoc).
  final double? usd;
  final double? blendedRate;

  const PowerUsageTotal({
    this.kwh,
    this.prevKwh,
    this.changePct,
    this.usd,
    this.blendedRate,
  });

  factory PowerUsageTotal.fromJson(Map<String, dynamic> json) {
    return PowerUsageTotal(
      kwh: jsonDouble(json['kwh']),
      prevKwh: jsonDouble(json['prevKwh']),
      changePct: jsonDouble(json['changePct']),
      usd: jsonDouble(json['usd']),
      blendedRate: jsonDouble(json['blendedRate']),
    );
  }
}

/// Chi co khi period = day | month.
class PowerUsageForecast {
  final double? monthToDateKwh;
  final double? projectedKwh;
  final int dayOfMonth;
  final int daysInMonth;
  final double? changePctVsPrevMonth;

  const PowerUsageForecast({
    this.monthToDateKwh,
    this.projectedKwh,
    required this.dayOfMonth,
    required this.daysInMonth,
    this.changePctVsPrevMonth,
  });

  factory PowerUsageForecast.fromJson(Map<String, dynamic> json) {
    return PowerUsageForecast(
      monthToDateKwh: jsonDouble(json['monthToDateKwh']),
      projectedKwh: jsonDouble(json['projectedKwh']),
      dayOfMonth: _toInt(json['dayOfMonth']),
      daysInMonth: _toInt(json['daysInMonth']),
      changePctVsPrevMonth: jsonDouble(json['changePctVsPrevMonth']),
    );
  }
}

class PowerFactoryUsage {
  final String facId;
  final double? kwh;
  final double? prevKwh;
  final double? sharePct;
  final double? changePct;

  const PowerFactoryUsage({
    required this.facId,
    this.kwh,
    this.prevKwh,
    this.sharePct,
    this.changePct,
  });

  factory PowerFactoryUsage.fromJson(Map<String, dynamic> json) {
    return PowerFactoryUsage(
      facId: jsonText(json['facId']),
      kwh: jsonDouble(json['kwh']),
      prevKwh: jsonDouble(json['prevKwh']),
      sharePct: jsonDouble(json['sharePct']),
      changePct: jsonDouble(json['changePct']),
    );
  }
}

class PowerPurposeMeter {
  final String boxDeviceId;
  final String label;
  final double? kwh;
  final double? prevKwh;
  final double? changePct;

  const PowerPurposeMeter({
    required this.boxDeviceId,
    required this.label,
    this.kwh,
    this.prevKwh,
    this.changePct,
  });

  factory PowerPurposeMeter.fromJson(Map<String, dynamic> json) {
    return PowerPurposeMeter(
      boxDeviceId: jsonText(json['boxDeviceId']),
      label: jsonText(json['label']),
      kwh: jsonDouble(json['kwh']),
      prevKwh: jsonDouble(json['prevKwh']),
      changePct: jsonDouble(json['changePct']),
    );
  }
}

/// Mot fac trong mot purpose (vd Compressed air cua Fac_B) va cac meter cua no.
class PowerPurposeFactory {
  final String facId;
  final double? kwh;
  final double? prevKwh;
  final double? changePct;
  final List<PowerPurposeMeter> meters;

  const PowerPurposeFactory({
    required this.facId,
    this.kwh,
    this.prevKwh,
    this.changePct,
    this.meters = const [],
  });

  factory PowerPurposeFactory.fromJson(Map<String, dynamic> json) {
    return PowerPurposeFactory(
      facId: jsonText(json['facId']),
      kwh: jsonDouble(json['kwh']),
      prevKwh: jsonDouble(json['prevKwh']),
      changePct: jsonDouble(json['changePct']),
      meters: _toList(json['meters'], PowerPurposeMeter.fromJson),
    );
  }
}

class PowerPurposeUsage {
  final String code;
  final String name;
  final String? description;
  final double? kwh;
  final double? prevKwh;
  final double? changePct;
  final List<double?> last7;

  /// Khong co trong PowerUsageResponseDto hien tai: rong neu backend chua tra.
  final List<PowerPurposeFactory> byFactory;

  const PowerPurposeUsage({
    required this.code,
    required this.name,
    this.description,
    this.kwh,
    this.prevKwh,
    this.changePct,
    this.last7 = const [],
    this.byFactory = const [],
  });

  factory PowerPurposeUsage.fromJson(Map<String, dynamic> json) {
    final last7 = json['last7'];
    return PowerPurposeUsage(
      code: jsonText(json['code']),
      name: jsonText(json['name']),
      description: json['description']?.toString(),
      kwh: jsonDouble(json['kwh']),
      prevKwh: jsonDouble(json['prevKwh']),
      changePct: jsonDouble(json['changePct']),
      last7: last7 is List
          ? last7.map(jsonDouble).toList(growable: false)
          : const [],
      byFactory: _toList(json['byFactory'], PowerPurposeFactory.fromJson),
    );
  }
}

/// unpriced = grid kWh cua gio khong co version gia (backend band 'UNPRICED',
/// rate / usd null); unknown = band khac chua biet (khong crash, hien ten goc).
enum PowerSupplyBandType { highPeak, normal, lowPeak, solar, unpriced, unknown }

class PowerSupplyBand {
  final String band;
  final double? kwh;
  final double? sharePct;
  final double? rate;
  final double? usd;

  const PowerSupplyBand({
    required this.band,
    this.kwh,
    this.sharePct,
    this.rate,
    this.usd,
  });

  PowerSupplyBandType get type => switch (band.trim().toUpperCase()) {
    'HIGH_PEAK' => PowerSupplyBandType.highPeak,
    'NORMAL' => PowerSupplyBandType.normal,
    'LOW_PEAK' => PowerSupplyBandType.lowPeak,
    'SOLAR' => PowerSupplyBandType.solar,
    'UNPRICED' => PowerSupplyBandType.unpriced,
    _ => PowerSupplyBandType.unknown,
  };

  String get label => switch (type) {
    PowerSupplyBandType.highPeak => 'High-peak',
    PowerSupplyBandType.normal => 'Normal',
    PowerSupplyBandType.lowPeak => 'Low-peak',
    PowerSupplyBandType.solar => 'Solar',
    PowerSupplyBandType.unpriced => 'Unpriced',
    PowerSupplyBandType.unknown => band.trim().isEmpty ? 'Unknown' : band,
  };

  factory PowerSupplyBand.fromJson(Map<String, dynamic> json) {
    return PowerSupplyBand(
      band: jsonText(json['band']),
      kwh: jsonDouble(json['kwh']),
      sharePct: jsonDouble(json['sharePct']),
      rate: jsonDouble(json['rate']),
      usd: jsonDouble(json['usd']),
    );
  }
}

class PowerDayTotal {
  /// yyyy-MM-dd
  final String date;
  final double? kwh;

  const PowerDayTotal({required this.date, this.kwh});

  factory PowerDayTotal.fromJson(Map<String, dynamic> json) {
    return PowerDayTotal(
      date: jsonText(json['date']),
      kwh: jsonDouble(json['kwh']),
    );
  }
}

class PowerUsageResponse {
  final String period;

  /// ISO-8601 kem offset nha may (+07:00).
  final String from;
  final String to;
  final String prevFrom;
  final String prevTo;
  final PowerUsageTotal total;
  final PowerUsageForecast? forecast;
  final List<PowerFactoryUsage> byFactory;
  final List<PowerPurposeUsage> byPurpose;
  final bool purposeConfigured;
  final List<PowerSupplyBand> supplyMix;
  final List<PowerDayTotal> last7Total;

  const PowerUsageResponse({
    required this.period,
    required this.from,
    required this.to,
    required this.prevFrom,
    required this.prevTo,
    required this.total,
    this.forecast,
    this.byFactory = const [],
    this.byPurpose = const [],
    this.purposeConfigured = false,
    this.supplyMix = const [],
    this.last7Total = const [],
  });

  factory PowerUsageResponse.fromJson(Map<String, dynamic> json) {
    final total = json['total'];
    final forecast = json['forecast'];
    return PowerUsageResponse(
      period: jsonText(json['period']),
      from: jsonText(json['from']),
      to: jsonText(json['to']),
      prevFrom: jsonText(json['prevFrom']),
      prevTo: jsonText(json['prevTo']),
      total: total is Map
          ? PowerUsageTotal.fromJson(Map<String, dynamic>.from(total))
          : const PowerUsageTotal(),
      forecast: forecast is Map
          ? PowerUsageForecast.fromJson(Map<String, dynamic>.from(forecast))
          : null,
      byFactory: _toList(json['byFactory'], PowerFactoryUsage.fromJson),
      byPurpose: _toList(json['byPurpose'], PowerPurposeUsage.fromJson),
      purposeConfigured: json['purposeConfigured'] == true,
      supplyMix: _toList(json['supplyMix'], PowerSupplyBand.fromJson),
      last7Total: _toList(json['last7Total'], PowerDayTotal.fromJson),
    );
  }

  PowerSupplyBand? get solarBand {
    for (final band in supplyMix) {
      if (band.type == PowerSupplyBandType.solar) return band;
    }
    return null;
  }
}
