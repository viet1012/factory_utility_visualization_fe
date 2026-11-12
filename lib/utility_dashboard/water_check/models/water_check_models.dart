/// Model cua `GET /api/utility/water-check`.
library;

import '../../shared/json/json_read.dart';

enum WaterStatus {
  ok('OK'),
  near('NEAR'),
  over('OVER'),
  stale('STALE'),
  noThreshold('NO_THRESHOLD'),

  /// Ap suat trong vung bom dung (chi signal ap suat).
  stopped('STOPPED'),

  /// Ap suat ngoai vung vat ly hop le (chi signal ap suat).
  sensorFault('SENSOR_FAULT');

  final String code;

  const WaterStatus(this.code);

  static WaterStatus parse(Object? raw) {
    final text = '${raw ?? ''}'.trim().toUpperCase();
    for (final status in values) {
      if (status.code == text) return status;
    }
    return noThreshold;
  }
}

class WaterCheckSummary {
  final int ok;
  final int near;
  final int over;
  final int stale;
  final int noThreshold;
  final int stopped;
  final int sensorFault;

  const WaterCheckSummary({
    this.ok = 0,
    this.near = 0,
    this.over = 0,
    this.stale = 0,
    this.noThreshold = 0,
    this.stopped = 0,
    this.sensorFault = 0,
  });

  factory WaterCheckSummary.fromJson(Map<String, dynamic> json) {
    return WaterCheckSummary(
      ok: _readInt(json['ok']),
      near: _readInt(json['near']),
      over: _readInt(json['over']),
      stale: _readInt(json['stale']),
      noThreshold: _readInt(json['noThreshold']),
      stopped: _readInt(json['stopped']),
      sensorFault: _readInt(json['sensorFault']),
    );
  }

  int countOf(WaterStatus status) {
    return switch (status) {
      WaterStatus.ok => ok,
      WaterStatus.near => near,
      WaterStatus.over => over,
      WaterStatus.stale => stale,
      WaterStatus.noThreshold => noThreshold,
      WaterStatus.stopped => stopped,
      WaterStatus.sensorFault => sensorFault,
    };
  }
}

/// Mot rule nguong cua group: `{ level, low, high, trivial }`.
class WaterThreshold {
  final int level;
  final double? low;
  final double? high;
  final bool trivial;

  const WaterThreshold({
    required this.level,
    this.low,
    this.high,
    this.trivial = false,
  });

  factory WaterThreshold.fromJson(Map<String, dynamic> json) {
    final rawTrivial = json['trivial'];

    return WaterThreshold(
      level: _readInt(json['level'], fallback: 3).clamp(1, 3),
      low: jsonDouble(json['low']),
      high: jsonDouble(json['high']),
      trivial:
          rawTrivial == true || '$rawTrivial'.trim().toLowerCase() == 'true',
    );
  }
}

class WaterSignal {
  final String boxDeviceId;
  final String deviceName;
  final String plcAddress;
  final String name;

  /// Ten hien thi ngan do backend dat (uu tien hon ten tu suy).
  final String label;

  /// Mau moi nhat (so hien tren board / To check / popup).
  final double? value;

  /// Mau goc moi nhat (thuong trung [value]).
  final double? rawValue;

  /// Nhom muc nuoc: median truot [WaterCheckConfig.levelMedianMinutes] phut
  /// (status danh gia theo so nay). Null khi backend khong tra.
  final double? median;
  final DateTime? recordedAt;
  final WaterStatus status;
  final double? distance;
  final double? trend1h;
  final DateTime? since;
  final double? lastValue;
  final DateTime? lastSeenAt;

  const WaterSignal({
    required this.boxDeviceId,
    required this.deviceName,
    required this.plcAddress,
    required this.name,
    this.label = '',
    required this.value,
    this.rawValue,
    this.median,
    required this.recordedAt,
    required this.status,
    required this.distance,
    required this.trend1h,
    required this.since,
    required this.lastValue,
    required this.lastSeenAt,
  });

  factory WaterSignal.fromJson(Map<String, dynamic> json) {
    return WaterSignal(
      boxDeviceId: jsonText(json['boxDeviceId']),
      deviceName: jsonText(json['deviceName']),
      plcAddress: jsonText(json['plcAddress']),
      name: jsonText(json['name']),
      label: jsonText(json['label']),
      value: jsonDouble(json['value']),
      rawValue: jsonDouble(json['rawValue']),
      median: jsonDouble(json['median'] ?? json['medianValue']),
      recordedAt: jsonDateTime(json['recordedAt']),
      status: WaterStatus.parse(json['status']),
      distance: jsonDouble(json['distance']),
      trend1h: jsonDouble(json['trend1h']),
      since: jsonDateTime(json['since']),
      lastValue: jsonDouble(json['lastValue']),
      lastSeenAt: jsonDateTime(json['lastSeenAt']),
    );
  }
}

/// Cau hinh danh gia cua response: cua so median nhom muc nuoc va thoi gian
/// xac nhan status. Thieu thi dung mac dinh 10 / 3 phut.
class WaterCheckConfig {
  final int levelMedianMinutes;
  final int statusConfirmMinutes;

  const WaterCheckConfig({
    this.levelMedianMinutes = 10,
    this.statusConfirmMinutes = 3,
  });

  static const WaterCheckConfig fallback = WaterCheckConfig();

  /// Doc o goc response hoac trong `config`.
  factory WaterCheckConfig.fromJson(Map<String, dynamic> json) {
    final nested = json['config'];
    final config = nested is Map ? Map<String, dynamic>.from(nested) : json;

    int read(String key, int fallback) {
      final value = _readInt(config[key] ?? json[key], fallback: fallback);
      return value > 0 ? value : fallback;
    }

    return WaterCheckConfig(
      levelMedianMinutes: read('levelMedianMinutes', 10),
      statusConfirmMinutes: read('statusConfirmMinutes', 3),
    );
  }

  Duration get levelMedianWindow => Duration(minutes: levelMedianMinutes);
}

class WaterGroup {
  final String code;
  final String name;
  final String unit;
  final List<WaterThreshold> thresholds;
  final List<WaterSignal> signals;
  final WaterCheckConfig config;

  const WaterGroup({
    required this.code,
    required this.name,
    required this.unit,
    required this.thresholds,
    required this.signals,
    this.config = WaterCheckConfig.fallback,
  });

  factory WaterGroup.fromJson(
    Map<String, dynamic> json, {
    WaterCheckConfig config = WaterCheckConfig.fallback,
  }) {
    return WaterGroup(
      code: jsonText(json['code']),
      name: jsonText(json['name']),
      unit: jsonText(json['unit']),
      thresholds: List.unmodifiable(
        _readList(json['thresholds']).map(WaterThreshold.fromJson),
      ),
      signals: List.unmodifiable(
        _readList(json['signals']).map(WaterSignal.fromJson),
      ),
      config: config,
    );
  }

  /// Nguong ve / hien thi: bo rule trivial.
  List<WaterThreshold> get visibleThresholds => [
    for (final rule in thresholds)
      if (!rule.trivial) rule,
  ];

  /// Rule chinh (level cao nhat, khong trivial) cho tieu de va vung an toan.
  WaterThreshold? get primaryThreshold {
    WaterThreshold? best;
    for (final rule in visibleThresholds) {
      if (rule.low == null && rule.high == null) continue;
      if (best == null || rule.level > best.level) best = rule;
    }
    return best;
  }

  /// Muc nuoc: ve bon chua thay cho thanh nguong.
  bool get isLevel =>
      unit.trim().toLowerCase() == 'm' ||
      code.trim().toLowerCase() == 'w_levcool';
}

class WaterFacility {
  final String facId;
  final List<WaterGroup> groups;

  const WaterFacility({required this.facId, required this.groups});

  factory WaterFacility.fromJson(
    Map<String, dynamic> json, {
    WaterCheckConfig config = WaterCheckConfig.fallback,
  }) {
    return WaterFacility(
      facId: jsonText(json['facId']),
      groups: List.unmodifiable(
        _readList(
          json['groups'],
        ).map((group) => WaterGroup.fromJson(group, config: config)),
      ),
    );
  }

  int get signalCount =>
      groups.fold<int>(0, (sum, group) => sum + group.signals.length);

  Iterable<WaterSignal> get signals sync* {
    for (final group in groups) {
      yield* group.signals;
    }
  }
}

class WaterIssue {
  final String facId;
  final String boxDeviceId;
  final String plcAddress;
  final String name;
  final String unit;

  /// Trung [WaterSignal.value] (mau moi nhat).
  final double? value;
  final double? rawValue;
  final DateTime? recordedAt;
  final WaterStatus status;
  final String thresholdText;
  final DateTime? since;
  final double? trend1h;
  final double? lastValue;
  final DateTime? lastSeenAt;

  const WaterIssue({
    required this.facId,
    required this.boxDeviceId,
    required this.plcAddress,
    required this.name,
    required this.unit,
    required this.value,
    this.rawValue,
    this.recordedAt,
    required this.status,
    required this.thresholdText,
    required this.since,
    required this.trend1h,
    required this.lastValue,
    required this.lastSeenAt,
  });

  factory WaterIssue.fromJson(Map<String, dynamic> json) {
    return WaterIssue(
      facId: jsonText(json['facId']),
      boxDeviceId: jsonText(json['boxDeviceId']),
      plcAddress: jsonText(json['plcAddress']),
      name: jsonText(json['name']),
      unit: jsonText(json['unit']),
      value: jsonDouble(json['value']),
      rawValue: jsonDouble(json['rawValue']),
      recordedAt: jsonDateTime(json['recordedAt']),
      status: WaterStatus.parse(json['status']),
      thresholdText: jsonText(json['thresholdText']),
      since: jsonDateTime(json['since']),
      trend1h: jsonDouble(json['trend1h']),
      lastValue: jsonDouble(json['lastValue']),
      lastSeenAt: jsonDateTime(json['lastSeenAt']),
    );
  }
}

class WaterCheckResponse {
  final DateTime? generatedAt;
  final WaterCheckSummary summary;
  final WaterCheckConfig config;
  final List<WaterFacility> facilities;
  final List<WaterIssue> issues;

  const WaterCheckResponse({
    required this.generatedAt,
    required this.summary,
    this.config = WaterCheckConfig.fallback,
    required this.facilities,
    required this.issues,
  });

  factory WaterCheckResponse.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'];
    final config = WaterCheckConfig.fromJson(json);

    return WaterCheckResponse(
      generatedAt: jsonDateTime(json['generatedAt']),
      summary: summary is Map
          ? WaterCheckSummary.fromJson(Map<String, dynamic>.from(summary))
          : const WaterCheckSummary(),
      config: config,
      facilities: List.unmodifiable(
        _readList(
          json['facilities'],
        ).map((fac) => WaterFacility.fromJson(fac, config: config)),
      ),
      issues: List.unmodifiable(
        _readList(json['issues']).map(WaterIssue.fromJson),
      ),
    );
  }
}

/// Khoa duy nhat cua mot diem do (cuon toi / nhap nhay).
String waterSignalKey(String facId, String boxDeviceId, String plcAddress) {
  return '${facId.trim().toUpperCase()}|'
      '${boxDeviceId.trim().toUpperCase()}|'
      '${plcAddress.trim().toUpperCase()}';
}

// ============================================================
// PARSE HELPERS
// ============================================================

List<Map<String, dynamic>> _readList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw.whereType<Map>()) Map<String, dynamic>.from(item),
  ];
}

int _readInt(Object? raw, {int fallback = 0}) => jsonInt(raw) ?? fallback;
