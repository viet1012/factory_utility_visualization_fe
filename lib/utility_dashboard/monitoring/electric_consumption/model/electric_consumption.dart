/// GET /api/utility/electric-consumption (sheet "FY26-Sep + Solar1").
///
/// Ky hoa don `2026-09` = 21/08 – 20/09. `monthly[]`: trung binh / ngay cua
/// cac ky truoc; `daily[]`: du so ngay cua ky, ngay chua co du lieu thi
/// `mwh` / `kusd` null. `tariffAvailable = false`: normal / highPeak / lowPeak,
/// toan bo kusd va unitPrices null, cac field tong van co.
library;

import '../../../shared/formatters/period_basis_formatter.dart';
import '../../../shared/json/json_read.dart';

int _toInt(Object? value) => jsonInt(value) ?? 0;

bool? _toBool(Object? value) => value is bool ? value : null;

/// Chuoi rong -> null.
String? _toText(Object? value) {
  final text = jsonText(value);
  return text.isEmpty ? null : text;
}

Map<String, dynamic>? _toMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<T> _toList<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => parse(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

enum ConsumptionUnit {
  mwh('MWh', 'Consumption'),
  kusd('K\$', 'Amount');

  const ConsumptionUnit(this.label, this.description);

  final String label;
  final String description;
}

/// Mot bo gia tri MWh hoac K$. totalElectricity = dien luoi; total = luoi +
/// solar.
class EnergyValues {
  final double? normal;
  final double? highPeak;
  final double? lowPeak;
  final double? solar;
  final double? totalElectricity;
  final double? total;

  const EnergyValues({
    this.normal,
    this.highPeak,
    this.lowPeak,
    this.solar,
    this.totalElectricity,
    this.total,
  });

  /// Moi gia tri null hoac 0.
  bool get isBlank => [
    normal,
    highPeak,
    lowPeak,
    solar,
    totalElectricity,
    total,
  ].every((v) => v == null || v == 0);

  static EnergyValues? fromJson(Object? json) {
    final map = _toMap(json);
    if (map == null) return null;
    return EnergyValues(
      normal: jsonDouble(map['normal']),
      highPeak: jsonDouble(map['highPeak']),
      lowPeak: jsonDouble(map['lowPeak']),
      solar: jsonDouble(map['solar']),
      totalElectricity: jsonDouble(map['totalElectricity']),
      total: jsonDouble(map['total']),
    );
  }
}

class BillPeriod {
  final String month;
  final String label;
  final String from;

  /// Moc ket thuc (exclusive): 2026-09-21 cho ky Sep.
  final String to;
  final int days;

  const BillPeriod({
    required this.month,
    required this.label,
    required this.from,
    required this.to,
    required this.days,
  });

  factory BillPeriod.fromJson(Map<String, dynamic> json) {
    return BillPeriod(
      month: jsonText(json['month']),
      label: jsonText(json['label']),
      from: jsonText(json['from']),
      to: jsonText(json['to']),
      days: _toInt(json['days']),
    );
  }
}

class UnitPrices {
  final double? gridNormal;
  final double? gridHighPeak;
  final double? gridLowPeak;
  final double? solarNormal;
  final double? solarHighPeak;
  final double? solarLowPeak;

  /// Ngay bang gia bat dau hieu luc (`yyyy-MM-dd`), null khi BE khong tra.
  final String? effectiveFrom;

  const UnitPrices({
    this.gridNormal,
    this.gridHighPeak,
    this.gridLowPeak,
    this.solarNormal,
    this.solarHighPeak,
    this.solarLowPeak,
    this.effectiveFrom,
  });

  static UnitPrices? fromJson(Object? json) {
    final map = _toMap(json);
    if (map == null) return null;
    return UnitPrices(
      gridNormal: jsonDouble(map['gridNormal']),
      gridHighPeak: jsonDouble(map['gridHighPeak']),
      gridLowPeak: jsonDouble(map['gridLowPeak']),
      solarNormal: jsonDouble(map['solarNormal']),
      solarHighPeak: jsonDouble(map['solarHighPeak']),
      solarLowPeak: jsonDouble(map['solarLowPeak']),
      effectiveFrom: _toText(map['effectiveFrom']),
    );
  }
}

/// Ly do meter thieu du lieu trong mot ngay.
enum MissingReason {
  noData,
  partial,
  outlier,
  unknown;

  static MissingReason parse(Object? value) =>
      switch (jsonText(value).toUpperCase()) {
        'NO_DATA' => noData,
        'PARTIAL' => partial,
        'OUTLIER' => outlier,
        _ => unknown,
      };
}

/// `daily[].missingMeters[]`: meter thieu gio trong ngay.
class MissingMeter {
  final String meter;
  final String fac;

  /// So gio co du lieu (PARTIAL) / so gio bi loai (OUTLIER).
  final int? hours;
  final MissingReason reason;

  /// ISO kem offset nha may, null khi meter chua tung gui du lieu.
  final String? lastDataAt;

  const MissingMeter({
    required this.meter,
    required this.fac,
    this.hours,
    required this.reason,
    this.lastDataAt,
  });

  factory MissingMeter.fromJson(Map<String, dynamic> json) {
    return MissingMeter(
      meter: jsonText(json['meter']),
      fac: jsonText(json['fac']),
      hours: jsonInt(json['hours']),
      reason: MissingReason.parse(json['reason']),
      lastDataAt: _toText(json['lastDataAt']),
    );
  }
}

/// `scope.meterIssues[]`: meter thieu gio trong ca ky.
class MeterIssue {
  final String meter;
  final String fac;
  final int? missingHours;
  final String? lastDataAt;

  const MeterIssue({
    required this.meter,
    required this.fac,
    this.missingHours,
    this.lastDataAt,
  });

  factory MeterIssue.fromJson(Map<String, dynamic> json) {
    return MeterIssue(
      meter: jsonText(json['meter']),
      fac: jsonText(json['fac']),
      missingHours: jsonInt(json['missingHours']),
      lastDataAt: _toText(json['lastDataAt']),
    );
  }
}

/// Mot cot tren truc X: ky truoc (trung binh / ngay) hoac mot ngay cua ky.
class ConsumptionPoint {
  /// `2026-08` (monthly) hoac `2026-08-21` (daily).
  final String key;
  final bool isMonthly;

  /// Monthly: `Aug (Jul21 ~ Aug20]`; daily: `Fri`.
  final String label;

  /// Chi monthly.
  final int? days;

  final EnergyValues? mwh;
  final EnergyValues? kusd;

  /// Backend: ngay / ky chua du du lieu (coverage < minCoveragePct). null
  /// khi backend cu chua tra field nay.
  final bool? partialFlag;

  /// Daily: % gio co du lieu.
  final double? coveragePct;
  final int? hoursWithData;

  /// So meter dong gop.
  final int? meters;

  /// Monthly: so ngay co du lieu / so ngay du du lieu.
  final int? daysWithData;
  final int? completeDays;

  /// MWh bi loai (meter loi / delta bat thuong).
  final double? excludedMwh;

  /// Daily: so meter co gui du lieu ([meters] = so meter cau hinh).
  final int? reportingMeters;

  /// Daily: meter thieu gio trong ngay.
  final List<MissingMeter> missingMeters;

  /// Co gio khong co bang gia -> K$ thieu.
  final bool priceMissing;

  const ConsumptionPoint({
    required this.key,
    required this.isMonthly,
    required this.label,
    this.days,
    this.mwh,
    this.kusd,
    this.partialFlag,
    this.coveragePct,
    this.hoursWithData,
    this.meters,
    this.daysWithData,
    this.completeDays,
    this.excludedMwh,
    this.reportingMeters,
    this.missingMeters = const [],
    this.priceMissing = false,
  });

  /// Daily co MWh nhung khong co K$ (ngay chua co bang gia).
  bool get noTariff =>
      !isMonthly && mwh != null && (kusd == null || kusd!.isBlank);

  /// Ngay chua du du lieu: uu tien co `partial` cua backend, khong co thi
  /// suy tu `dataUntil` ([partialDate]). Monthly luon false (gia tri la
  /// trung binh / ngay).
  bool isPartial(String? partialDate) {
    if (isMonthly || isNoData) return false;
    return partialFlag ?? key == partialDate;
  }

  /// Gia tri tho tu API.
  EnergyValues? rawValuesOf(ConsumptionUnit unit) =>
      unit == ConsumptionUnit.mwh ? mwh : kusd;

  /// Gia tri de hien thi: null khi [isNoData], K$ null khi [noTariff]
  /// (khong ve cot 0).
  EnergyValues? valuesOf(ConsumptionUnit unit) {
    if (isNoData) return null;
    if (unit == ConsumptionUnit.kusd && noTariff) return null;
    return rawValuesOf(unit);
  }

  /// Daily: mwh / kusd null (ngay chua toi). Monthly: backend tra 0.000 cho
  /// ky chua co du lieu thay vi null -> ky toan 0 coi la khong co du lieu.
  bool get isNoData {
    if (!isMonthly) return mwh == null && kusd == null;
    return (mwh?.isBlank ?? true) && (kusd?.isBlank ?? true);
  }

  bool get hasData => !isNoData;

  factory ConsumptionPoint.monthly(Map<String, dynamic> json) {
    return ConsumptionPoint(
      key: jsonText(json['month']),
      isMonthly: true,
      label: jsonText(json['label']),
      days: _toInt(json['days']),
      mwh: EnergyValues.fromJson(json['perDayMwh']),
      kusd: EnergyValues.fromJson(json['perDayKusd']),
      partialFlag: _toBool(json['partial']),
      meters: jsonInt(json['meters']),
      daysWithData: jsonInt(json['daysWithData']),
      completeDays: jsonInt(json['completeDays']),
      excludedMwh: jsonDouble(json['excludedMwh']),
      priceMissing: json['priceMissing'] == true,
    );
  }

  factory ConsumptionPoint.daily(Map<String, dynamic> json) {
    return ConsumptionPoint(
      key: jsonText(json['date']),
      isMonthly: false,
      label: jsonText(json['weekday']),
      mwh: EnergyValues.fromJson(json['mwh']),
      kusd: EnergyValues.fromJson(json['kusd']),
      partialFlag: _toBool(json['partial']),
      coveragePct: jsonDouble(json['coveragePct']),
      hoursWithData: jsonInt(json['hoursWithData']),
      meters: jsonInt(json['meters']),
      excludedMwh: jsonDouble(json['excludedMwh']),
      reportingMeters: jsonInt(json['reportingMeters']),
      missingMeters: _toList(json['missingMeters'], MissingMeter.fromJson),
      priceMissing: json['priceMissing'] == true,
    );
  }
}

/// KVH (A&B + C) / FAC_AB / FAC_C.
class ConsumptionScope {
  final String code;
  final String name;
  final List<ConsumptionPoint> monthly;
  final List<ConsumptionPoint> daily;
  final EnergyValues? dailyTotalMwh;
  final EnergyValues? dailyTotalKusd;
  final EnergyValues? dailyAverageMwh;
  final EnergyValues? dailyAverageKusd;
  final int elapsedDays;

  /// Backend moi: so meter, so ngay co du lieu / du du lieu cua ky.
  final int? meters;
  final int? daysWithData;
  final int? completeDays;

  /// Meter thieu gio trong ky.
  final List<MeterIssue> meterIssues;

  /// Co gio trong ky khong co bang gia -> K$ chi mot phan.
  final bool priceMissing;

  const ConsumptionScope({
    required this.code,
    required this.name,
    required this.monthly,
    required this.daily,
    this.dailyTotalMwh,
    this.dailyTotalKusd,
    this.dailyAverageMwh,
    this.dailyAverageKusd,
    required this.elapsedDays,
    this.meters,
    this.daysWithData,
    this.completeDays,
    this.meterIssues = const [],
    this.priceMissing = false,
  });

  /// KVH co solar (Excel: cot chong + Solar, duong Total); fac chi dien luoi.
  bool get includesSolar => code.toUpperCase() == 'KVH';

  List<ConsumptionPoint> get points => [...monthly, ...daily];

  EnergyValues? totalOf(ConsumptionUnit unit) =>
      unit == ConsumptionUnit.mwh ? dailyTotalMwh : dailyTotalKusd;

  EnergyValues? averageOf(ConsumptionUnit unit) =>
      unit == ConsumptionUnit.mwh ? dailyAverageMwh : dailyAverageKusd;

  /// Gia tri tong cua scope: KVH = luoi + solar, fac = dien luoi.
  double? headlineOf(EnergyValues? v) =>
      v == null ? null : (includesSolar ? v.total : v.totalElectricity);

  /// Ngay da du du lieu (xem [ConsumptionPoint.isPartial]).
  List<ConsumptionPoint> fullDays(String? partialDate) => [
    for (final p in daily)
      if (p.hasData && !p.isPartial(partialDate)) p,
  ];

  /// Ngay co du lieu nhung chua du.
  List<ConsumptionPoint> partialDays(String? partialDate) => [
    for (final p in daily)
      if (p.isPartial(partialDate)) p,
  ];

  /// Trung binh / ngay chi tren cac ngay du du lieu (cung cach backend moi
  /// tinh `dailyAverage*`; backend cu chia ca ngay do dang).
  double? fullDayAverage(ConsumptionUnit unit, String? partialDate) {
    var sum = 0.0;
    var count = 0;
    for (final p in fullDays(partialDate)) {
      final value = headlineOf(p.valuesOf(unit));
      if (value == null) continue;
      sum += value;
      count++;
    }
    return count == 0 ? null : sum / count;
  }

  factory ConsumptionScope.fromJson(Map<String, dynamic> json) {
    return ConsumptionScope(
      code: jsonText(json['code']),
      name: jsonText(json['name']),
      monthly: _toList(json['monthly'], ConsumptionPoint.monthly),
      daily: _toList(json['daily'], ConsumptionPoint.daily),
      dailyTotalMwh: EnergyValues.fromJson(json['dailyTotalMwh']),
      dailyTotalKusd: EnergyValues.fromJson(json['dailyTotalKusd']),
      dailyAverageMwh: EnergyValues.fromJson(json['dailyAverageMwh']),
      dailyAverageKusd: EnergyValues.fromJson(json['dailyAverageKusd']),
      elapsedDays: _toInt(json['elapsedDays']),
      meters: jsonInt(json['meters']),
      daysWithData: jsonInt(json['daysWithData']),
      completeDays: jsonInt(json['completeDays']),
      meterIssues: _toList(json['meterIssues'], MeterIssue.fromJson),
      priceMissing: json['priceMissing'] == true,
    );
  }
}

class ElectricConsumptionResponse {
  final String month;
  final BillPeriod billPeriod;

  /// ISO kem offset nha may, vd `2026-09-21T00:00:00+07:00`.
  final String dataUntil;
  final bool tariffAvailable;
  final UnitPrices? unitPrices;
  final List<ConsumptionScope> scopes;

  /// Ngay du du lieu khi coverage >= nguong nay (%).
  final double? minCoveragePct;

  /// Truoc ngay nay backend khong co du lieu.
  final String? historyStartDate;

  /// Meter bi loai khoi moi tong.
  final List<String> excludedMeters;

  const ElectricConsumptionResponse({
    required this.month,
    required this.billPeriod,
    required this.dataUntil,
    required this.tariffAvailable,
    this.unitPrices,
    required this.scopes,
    this.minCoveragePct,
    this.historyStartDate,
    this.excludedMeters = const [],
  });

  static final RegExp _untilPattern = RegExp(
    r'^(\d{4}-\d{2}-\d{2})[T ](\d{2}):(\d{2})',
  );

  /// Ngay `yyyy-MM-dd` dang do dang: `dataUntil` khong roi vao 00:00 (vd
  /// `2026-11-12T09:00` -> ngay 12 moi co du lieu den 09:00). null khi moi
  /// ngay da tron.
  String? get partialDate {
    final match = _untilPattern.firstMatch(dataUntil.trim());
    if (match == null) return null;
    if (match.group(2) == '00' && match.group(3) == '00') return null;
    return match.group(1);
  }

  /// `09:00` cua ngay dang do dang.
  String? get partialUntil {
    if (partialDate == null) return null;
    final match = _untilPattern.firstMatch(dataUntil.trim())!;
    return '${match.group(2)}:${match.group(3)}';
  }

  factory ElectricConsumptionResponse.fromJson(Map<String, dynamic> json) {
    return ElectricConsumptionResponse(
      month: jsonText(json['month']),
      billPeriod: BillPeriod.fromJson(_toMap(json['billPeriod']) ?? const {}),
      dataUntil: jsonText(json['dataUntil']),
      tariffAvailable: json['tariffAvailable'] == true,
      unitPrices: UnitPrices.fromJson(json['unitPrices']),
      scopes: _toList(json['scopes'], ConsumptionScope.fromJson),
      minCoveragePct: jsonDouble(json['minCoveragePct']),
      historyStartDate: switch (jsonText(json['historyStartDate'])) {
        '' => null,
        final text => text,
      },
      excludedMeters: [
        if (json['excludedMeters'] case final List list)
          for (final item in list)
            if (jsonText(item).isNotEmpty) jsonText(item),
      ],
    );
  }
}

// ============================================================
// BILL MONTH (yyyy-MM, ky 21 thang truoc ~ 20 thang nay)
// ============================================================

/// Ngay `billCutoffDay` (21) tro di thuoc ky cua thang sau.
DateTime billMonthOf(DateTime date) {
  final first = DateTime(date.year, date.month);
  return date.day >= PeriodBasisFormatter.billCutoffDay
      ? DateTime(first.year, first.month + 1)
      : first;
}

DateTime? parseBillMonth(String? text) {
  final match = RegExp(r'^(\d{4})-(\d{2})').firstMatch(text?.trim() ?? '');
  if (match == null) return null;
  return DateTime(int.parse(match.group(1)!), int.parse(match.group(2)!));
}

String formatBillMonth(DateTime month) =>
    '${month.year}-${month.month.toString().padLeft(2, '0')}';
