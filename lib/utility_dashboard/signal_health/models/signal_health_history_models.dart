import 'package:flutter/material.dart';

/// Domain models for `GET /api/utility/signal-health/history/hourly`.
///
/// The endpoint returns a nested hierarchy:
///
/// ```
/// bucketTime
///  -> alerts
///     -> level
///        -> descriptions
///           -> devices
///              -> signals
/// ```
///
/// Every node is parsed defensively: a malformed or missing child collapses to
/// an empty list rather than throwing, so one bad bucket never blanks the whole
/// History panel.

/// Alert severity — the single source of truth for level 1/2/3 semantics.
///
/// Confirmed business mapping, preserved exactly as the UI already used it:
///
/// | code | severity      |
/// |------|---------------|
/// | 1    | Critical      |
/// | 2    | Warning       |
/// | 3    | Informational |
///
/// Every consumer (level cards, trend legend, tooltips, selected-level
/// filters) reads [label], [severity], [description] and [color] from here.
/// Do not restate a severity word or a level colour anywhere else — a second
/// copy is how the mapping drifts or gets reversed.
///
/// The backend sends 1 | 2 | 3; anything else maps to [unknown] so the UI
/// still has a bucket to put it in.
enum SignalHealthAlertLevel {
  level1(
    1,
    'Level 1',
    'Critical',
    'Highest severity. Needs immediate attention.',
  ),
  level2(2, 'Level 2', 'Warning', 'Abnormal, but not immediately critical.'),
  level3(3, 'Level 3', 'Informational', 'Low severity. Logged for awareness.'),
  unknown(0, 'Unknown', 'Unclassified', 'Severity not reported by the source.');

  const SignalHealthAlertLevel(
    this.code,
    this.label,
    this.severity,
    this.description,
  );

  /// Numeric code as sent by the backend.
  final int code;

  /// Short axis/legend label, e.g. `Level 1`.
  final String label;

  /// Business severity name, e.g. `Critical`.
  final String severity;

  /// One-line explanation shown as card help text.
  final String description;

  /// HISTORY severity palette - the ONLY place these values are declared.
  ///
  /// | level | severity      | colour            |
  /// |-------|---------------|-------------------|
  /// | 1     | Critical      | #EF4444 red       |
  /// | 2     | Warning       | #F97316 orange    |
  /// | 3     | Informational | #FACC15 amber     |
  ///
  /// Level 3 is amber, never cyan/blue/teal: a cool colour read as "fine"
  /// rather than as the low end of one warm severity ramp.
  ///
  /// Scoped to HISTORY only. CURRENT mode keeps the shared `kRed`/`kOrange`/
  /// `kBlue` tokens from `signal_health_style.dart`, which this does not
  /// touch. Never restate these values in a widget - read them from here so
  /// the palette cannot drift.
  Color get color {
    return switch (this) {
      SignalHealthAlertLevel.level1 => const Color(0xffef4444),
      SignalHealthAlertLevel.level2 => const Color(0xfff97316),
      SignalHealthAlertLevel.level3 => const Color(0xfffacc15),
      SignalHealthAlertLevel.unknown => const Color(0xff94a3b8),
    };
  }

  /// Combined label for legends and tooltips, e.g. `Level 1 - Critical`.
  String get legendLabel => '$label - $severity';

  static SignalHealthAlertLevel fromCode(int? code) {
    return switch (code) {
      1 => SignalHealthAlertLevel.level1,
      2 => SignalHealthAlertLevel.level2,
      3 => SignalHealthAlertLevel.level3,
      _ => SignalHealthAlertLevel.unknown,
    };
  }

  /// Levels rendered as cards, in display order. Excludes [unknown], which is
  /// still counted in totals but has no dedicated card.
  static const List<SignalHealthAlertLevel> displayOrder = [
    SignalHealthAlertLevel.level1,
    SignalHealthAlertLevel.level2,
    SignalHealthAlertLevel.level3,
  ];
}

/// Leaf node: one abnormal PLC register reading inside a device.
///
/// Fields mirror the backend contract exactly: `plcAddress`, `signalName`,
/// `currentValue`, `previousValue`, `recordedAt`, `count`. There is no
/// `status` or `unit` on this endpoint, so none is parsed or rendered.
@immutable
class SignalHealthHistorySignal {
  final String plcAddress;
  final String signalName;
  final double? currentValue;
  final double? previousValue;
  final DateTime? recordedAt;

  /// Occurrences of this signal inside its parent device for the bucket.
  final int count;

  const SignalHealthHistorySignal({
    required this.plcAddress,
    required this.signalName,
    required this.currentValue,
    required this.previousValue,
    required this.recordedAt,
    required this.count,
  });

  factory SignalHealthHistorySignal.fromJson(Map<String, dynamic> json) {
    return SignalHealthHistorySignal(
      plcAddress: readText(json['plcAddress']),
      signalName: readText(json['signalName']),
      currentValue: readDouble(json['currentValue']),
      previousValue: readDouble(json['previousValue']),
      recordedAt: readDateTime(json['recordedAt']),
      count: readInt(json['count']),
    );
  }

  /// Change between the previous and current reading.
  ///
  /// Null when either side is missing, so the Delta column can distinguish
  /// "no change" (0) from "cannot be computed" (-).
  double? get delta {
    final current = currentValue;
    final previous = previousValue;

    if (current == null || previous == null) return null;

    return current - previous;
  }

  /// Label for the drill-down table when the signal has no friendly name.
  String get displayName {
    if (signalName.isNotEmpty) return signalName;

    return plcAddress.isEmpty ? '-' : plcAddress;
  }
}

/// One box device carrying abnormal signals for a given description.
///
/// Backend contract: `boxDeviceId`, `count`, `signals`. `count` is scoped to
/// the parent description, so summing devices across descriptions is a valid
/// range-wide total (see buildTopDevices).
@immutable
class SignalHealthHistoryDevice {
  final String boxDeviceId;
  final int count;
  final List<SignalHealthHistorySignal> signals;

  const SignalHealthHistoryDevice({
    required this.boxDeviceId,
    required this.count,
    required this.signals,
  });

  factory SignalHealthHistoryDevice.fromJson(Map<String, dynamic> json) {
    return SignalHealthHistoryDevice(
      boxDeviceId: readText(json['boxDeviceId']),
      count: readInt(json['count']),
      signals: readList(json['signals'], SignalHealthHistorySignal.fromJson),
    );
  }

  /// Sum of the leaf signal counts, used to cross-check [count].
  int get signalCountSum {
    return signals.fold<int>(0, (sum, signal) => sum + signal.count);
  }
}

/// One alert description within a level.
///
/// Backend contract: `parameterCode`, `ruleType`, `description`, `count`,
/// `devices`.
@immutable
class SignalHealthHistoryDescription {
  final String parameterCode;
  final String ruleType;
  final String description;
  final int count;
  final List<SignalHealthHistoryDevice> devices;

  const SignalHealthHistoryDescription({
    required this.parameterCode,
    required this.ruleType,
    required this.description,
    required this.count,
    required this.devices,
  });

  factory SignalHealthHistoryDescription.fromJson(Map<String, dynamic> json) {
    return SignalHealthHistoryDescription(
      parameterCode: readText(json['parameterCode']),
      ruleType: readText(json['ruleType']),
      description: readText(json['description']),
      count: readInt(json['count']),
      devices: readList(json['devices'], SignalHealthHistoryDevice.fromJson),
    );
  }

  /// Identity of an alert description.
  ///
  /// Keyed on parameterCode + ruleType + description, never description text
  /// alone: two different parameter codes can share wording and must stay
  /// separate rows/bars.
  String get groupKey {
    return '${parameterCode.toUpperCase()}|'
        '${ruleType.toUpperCase()}|'
        '${description.toUpperCase()}';
  }

  /// Human label for charts, falling back through the identity fields.
  String get displayLabel {
    if (description.isNotEmpty) return description;
    if (ruleType.isNotEmpty) return ruleType;

    return parameterCode.isEmpty ? '-' : parameterCode;
  }

  /// Sum of the child device counts, used to cross-check [count].
  int get deviceCountSum {
    return devices.fold<int>(0, (sum, device) => sum + device.count);
  }
}

/// All alerts of one severity level inside a bucket.
///
/// Backend contract: `level`, `descriptions`. The level's own total is derived
/// from its descriptions, which is what `bucket.errorCount` is validated
/// against.
@immutable
class SignalHealthHistoryLevel {
  final SignalHealthAlertLevel level;
  final List<SignalHealthHistoryDescription> descriptions;

  const SignalHealthHistoryLevel({
    required this.level,
    required this.descriptions,
  });

  factory SignalHealthHistoryLevel.fromJson(Map<String, dynamic> json) {
    return SignalHealthHistoryLevel(
      level: SignalHealthAlertLevel.fromCode(readInt(json['level'])),
      descriptions: readList(
        json['descriptions'],
        SignalHealthHistoryDescription.fromJson,
      ),
    );
  }

  /// Alerts at this level, summed from the child description counts.
  int get count {
    return descriptions.fold<int>(0, (sum, item) => sum + item.count);
  }
}

/// One hourly bucket: the top level of the response.
///
/// Backend contract: `bucketTime`, `errorCount`, `alerts`. The endpoint does
/// NOT return `totalSignals` or `okCount`, so HISTORY shows no OK/total KPIs.
@immutable
class SignalHealthHistoryBucket {
  final DateTime bucketTime;

  /// Authoritative alert total for the bucket, as reported by the backend.
  final int errorCount;

  final List<SignalHealthHistoryLevel> alerts;

  const SignalHealthHistoryBucket({
    required this.bucketTime,
    required this.errorCount,
    required this.alerts,
  });

  /// Returns null when `bucketTime` is missing or unparseable: a bucket with no
  /// time cannot be placed on the trend chart, so the caller drops it.
  static SignalHealthHistoryBucket? tryFromJson(Map<String, dynamic> json) {
    final bucketTime = readDateTime(json['bucketTime']);

    if (bucketTime == null) return null;

    return SignalHealthHistoryBucket(
      bucketTime: bucketTime,
      errorCount: readInt(json['errorCount']),
      alerts: readList(json['alerts'], SignalHealthHistoryLevel.fromJson),
    );
  }

  /// Alerts summed from the level nodes.
  ///
  /// Should equal [errorCount]; [hasConsistentErrorCount] reports when it does
  /// not so a backend drift is visible instead of silently skewing the charts.
  int get derivedAlertCount {
    return alerts.fold<int>(0, (sum, item) => sum + item.count);
  }

  /// Contract check: `bucket.errorCount == sum(bucket.alerts[].count)`.
  bool get hasConsistentErrorCount => errorCount == derivedAlertCount;

  /// Total used by the charts.
  ///
  /// Prefers the backend's [errorCount]. Falls back to the derived sum only
  /// when errorCount is absent/zero while alerts clearly exist, so a missing
  /// field never renders an empty chart.
  int get totalAlerts {
    if (errorCount > 0) return errorCount;

    return derivedAlertCount;
  }

  int countFor(SignalHealthAlertLevel level) {
    var total = 0;

    for (final item in alerts) {
      if (item.level == level) total += item.count;
    }

    return total;
  }
}

/// Filter state for a History query. Immutable so the controller can compare
/// the requested filter against the in-flight one by value.
@immutable
class SignalHealthHistoryFilter {
  final DateTime from;
  final DateTime to;
  final String? fac;
  final String? cate;
  final String? scadaId;
  final String? boxDeviceId;

  const SignalHealthHistoryFilter({
    required this.from,
    required this.to,
    this.fac,
    this.cate,
    this.scadaId,
    this.boxDeviceId,
  });

  /// Default range: the last 24 hours, aligned down to the hour so the trend
  /// chart's buckets line up with whole hours.
  factory SignalHealthHistoryFilter.last24Hours() {
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day, now.hour);

    return SignalHealthHistoryFilter(
      from: to.subtract(const Duration(hours: 24)),
      to: to.add(const Duration(hours: 1)),
    );
  }

  SignalHealthHistoryFilter copyWith({
    DateTime? from,
    DateTime? to,
    String? fac,
    String? cate,
    String? scadaId,
    String? boxDeviceId,
    bool clearFac = false,
    bool clearCate = false,
    bool clearScadaId = false,
    bool clearBoxDeviceId = false,
  }) {
    return SignalHealthHistoryFilter(
      from: from ?? this.from,
      to: to ?? this.to,
      fac: clearFac ? null : (fac ?? this.fac),
      cate: clearCate ? null : (cate ?? this.cate),
      scadaId: clearScadaId ? null : (scadaId ?? this.scadaId),
      boxDeviceId: clearBoxDeviceId ? null : (boxDeviceId ?? this.boxDeviceId),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SignalHealthHistoryFilter &&
        other.from == from &&
        other.to == to &&
        other.fac == fac &&
        other.cate == cate &&
        other.scadaId == scadaId &&
        other.boxDeviceId == boxDeviceId;
  }

  @override
  int get hashCode => Object.hash(from, to, fac, cate, scadaId, boxDeviceId);
}

// ============================================================
// PARSE HELPERS
// ============================================================

/// Parses a history timestamp as local wall-clock time.
///
/// Mirrors the Utility Minute contract: the backend sends offset-less ISO-8601
/// strings, which `DateTime.parse` already treats as local. Converting an
/// explicit UTC instant back to local keeps age/ordering maths correct if the
/// backend ever starts emitting `Z`.
DateTime? readDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.isUtc ? value.toLocal() : value;

  final text = value.toString().trim();

  if (text.isEmpty) return null;

  final parsed = DateTime.tryParse(text);

  if (parsed == null) return null;

  return parsed.isUtc ? parsed.toLocal() : parsed;
}

String readText(dynamic value) => value?.toString().trim() ?? '';

String readFirstText(Iterable<dynamic> values, {String fallback = ''}) {
  for (final value in values) {
    final text = readText(value);
    if (text.isNotEmpty) return text;
  }

  return fallback;
}

int readInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();

  return int.tryParse(value.toString().trim()) ?? 0;
}

double? readDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();

  return double.tryParse(value.toString().trim());
}

List<T> readList<T>(dynamic raw, T Function(Map<String, dynamic>) parser) {
  if (raw is! List) return const [];

  final result = <T>[];

  for (final item in raw) {
    if (item is Map) {
      result.add(parser(Map<String, dynamic>.from(item)));
    }
  }

  return List<T>.unmodifiable(result);
}
