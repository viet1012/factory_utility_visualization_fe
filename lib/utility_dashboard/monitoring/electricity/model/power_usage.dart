/// GET /api/utility/power-usage. kWh = grid kWh + solar kWh, USD / rate la
/// USD/kWh. changePct null khi ky truoc bang 0.
library;

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

double? _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int _toInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _toStr(Object? value) => value?.toString() ?? '';

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
      kwh: _toDouble(json['kwh']),
      prevKwh: _toDouble(json['prevKwh']),
      changePct: _toDouble(json['changePct']),
      usd: _toDouble(json['usd']),
      blendedRate: _toDouble(json['blendedRate']),
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
      monthToDateKwh: _toDouble(json['monthToDateKwh']),
      projectedKwh: _toDouble(json['projectedKwh']),
      dayOfMonth: _toInt(json['dayOfMonth']),
      daysInMonth: _toInt(json['daysInMonth']),
      changePctVsPrevMonth: _toDouble(json['changePctVsPrevMonth']),
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
      facId: _toStr(json['facId']),
      kwh: _toDouble(json['kwh']),
      prevKwh: _toDouble(json['prevKwh']),
      sharePct: _toDouble(json['sharePct']),
      changePct: _toDouble(json['changePct']),
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
      boxDeviceId: _toStr(json['boxDeviceId']),
      label: _toStr(json['label']),
      kwh: _toDouble(json['kwh']),
      prevKwh: _toDouble(json['prevKwh']),
      changePct: _toDouble(json['changePct']),
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
      facId: _toStr(json['facId']),
      kwh: _toDouble(json['kwh']),
      prevKwh: _toDouble(json['prevKwh']),
      changePct: _toDouble(json['changePct']),
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
      code: _toStr(json['code']),
      name: _toStr(json['name']),
      description: json['description']?.toString(),
      kwh: _toDouble(json['kwh']),
      prevKwh: _toDouble(json['prevKwh']),
      changePct: _toDouble(json['changePct']),
      last7: last7 is List
          ? last7.map(_toDouble).toList(growable: false)
          : const [],
      byFactory: _toList(json['byFactory'], PowerPurposeFactory.fromJson),
    );
  }
}

enum PowerSupplyBandType { highPeak, normal, lowPeak, solar, unknown }

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

  PowerSupplyBandType get type => switch (band.toUpperCase()) {
    'HIGH_PEAK' => PowerSupplyBandType.highPeak,
    'NORMAL' => PowerSupplyBandType.normal,
    'LOW_PEAK' => PowerSupplyBandType.lowPeak,
    'SOLAR' => PowerSupplyBandType.solar,
    _ => PowerSupplyBandType.unknown,
  };

  String get label => switch (type) {
    PowerSupplyBandType.highPeak => 'High-peak',
    PowerSupplyBandType.normal => 'Normal',
    PowerSupplyBandType.lowPeak => 'Low-peak',
    PowerSupplyBandType.solar => 'Solar',
    PowerSupplyBandType.unknown => band,
  };

  factory PowerSupplyBand.fromJson(Map<String, dynamic> json) {
    return PowerSupplyBand(
      band: _toStr(json['band']),
      kwh: _toDouble(json['kwh']),
      sharePct: _toDouble(json['sharePct']),
      rate: _toDouble(json['rate']),
      usd: _toDouble(json['usd']),
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
      date: _toStr(json['date']),
      kwh: _toDouble(json['kwh']),
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
      period: _toStr(json['period']),
      from: _toStr(json['from']),
      to: _toStr(json['to']),
      prevFrom: _toStr(json['prevFrom']),
      prevTo: _toStr(json['prevTo']),
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
