import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/charts/chart_config.dart';
import '../../../../shared/charts/chart_thresholds.dart';
import '../../../../shared/charts/signal_thresholds.dart';
import '../../../catalog_view_models.dart';
import '../../../models/signal_history_models.dart';
import '../../../providers/filter_chart_controller.dart';
import '../../signal_chart/signal_chart_groups.dart' show splitCommonName;
import '../filter_result_cells.dart';

/// Mau co dinh theo thu tu signal trong nhom.
const List<Color> kFilterChartColors = <Color>[
  Color(0xFF38BDF8),
  Color(0xFFFBBF24),
  Color(0xFF4ADE80),
  Color(0xFFF472B6),
  Color(0xFFA78BFA),
  Color(0xFFFB923C),
  Color(0xFF2DD4BF),
  Color(0xFFE2E8F0),
];

/// Kieu net xoay vong cung voi mau, de phan biet duong khi khong phan biet
/// duoc mau (in den trang, mu mau).
const List<List<double>?> kFilterChartDashes = <List<double>?>[
  null,
  <double>[6, 3],
  <double>[2, 3],
  <double>[8, 3, 2, 3],
];

/// Muc do cua mot signal so voi nguong (thu tu sap xep: over truoc).
enum ThresholdProximity { over, near, normal }

/// Mot signal trong mot nhom chart (Filter results hoac panel device).
class FilterChartMember {
  final CatalogTableRow row;
  final String signalId;

  /// Nhan rut gon tren legend / tooltip chart.
  final String label;

  /// Vi tri co dinh trong nhom -> mau + kieu net.
  final int styleIndex;

  /// Lich su cua range dang ve (null = chua tai / loi).
  final SignalHistorySeries? series;
  final FilterChartLoadState? state;

  /// Nguong tu lich su (range dang ve, hoac cache sparkline 1h):
  /// SignalHistorySeries.chartThresholds (chi ANALOG, bo trivial).
  final List<SignalThreshold> thresholds;

  const FilterChartMember({
    required this.row,
    required this.signalId,
    required this.label,
    required this.styleIndex,
    required this.series,
    required this.state,
    required this.thresholds,
  });

  String get deviceKey => row.deviceKey;

  Color get color => kFilterChartColors[styleIndex % kFilterChartColors.length];

  List<double>? get dash {
    // Doi ca net khi mau lap lai (signal thu 9 tro di).
    final index =
        (styleIndex + styleIndex ~/ kFilterChartColors.length) %
        kFilterChartDashes.length;
    return kFilterChartDashes[index];
  }

  bool get hasError =>
      state == FilterChartLoadState.error || (series?.error != null);

  /// Box / device / PLC day du (tooltip cua nhan rut gon).
  String get fullLabel =>
      '${row.boxId} / ${row.boxDeviceId} · ${row.plcAddress}\n'
      '${row.displaySignalName}';

  /// Gia tri hien tai (latest) so voi nguong.
  ThresholdProximity get proximity =>
      thresholdProximityOf(thresholds, row.value);

  /// Gia tri hien tai (latest) vuot nguong.
  bool get overThreshold => proximity == ThresholdProximity.over;
}

/// [value] so voi [thresholds]: vuot / gan (< ChartConfig.thresholdNearRatio
/// × max(|value|, 1)) / binh thuong.
ThresholdProximity thresholdProximityOf(
  List<SignalThreshold> thresholds,
  double? value,
) {
  if (value == null || !value.isFinite) return ThresholdProximity.normal;

  final match = nearestThreshold(thresholds, value);
  if (match == null) return ThresholdProximity.normal;
  if (match.breached) return ThresholdProximity.over;

  return match.gap < ChartConfig.thresholdNearRatio * math.max(value.abs(), 1)
      ? ThresholdProximity.near
      : ThresholdProximity.normal;
}

/// Mot nhom: cac signal cung (code, unit) cua moi device khop filter.
class FilterChartGroup {
  final String key;

  /// Ten chung cua cac signal (khong phai code).
  final String title;

  /// Code backend (spec / tooltip); rong khi nhom theo ten.
  final String code;
  final String unit;
  final SignalKind kind;

  /// Theo thu tu co dinh (styleIndex tang dan).
  final List<FilterChartMember> members;

  const FilterChartGroup({
    required this.key,
    required this.title,
    required this.code,
    required this.unit,
    required this.kind,
    required this.members,
  });

  int get deviceCount => {for (final m in members) m.deviceKey}.length;

  int get overCount => members.where((member) => member.overThreshold).length;

  int get nearCount => members
      .where((member) => member.proximity == ThresholdProximity.near)
      .length;

  ThresholdProximity get proximity => overCount > 0
      ? ThresholdProximity.over
      : nearCount > 0
      ? ThresholdProximity.near
      : ThresholdProximity.normal;

  /// Nguong chung cua ca nhom (moi signal co cung nguong), de ve duong
  /// nguong tren truc chung. Nguong khac nhau giua signal -> null.
  List<SignalThreshold>? get commonThresholds {
    final withThreshold = members.where(
      (member) => member.thresholds.isNotEmpty,
    );

    if (withThreshold.isEmpty) return null;

    final first = withThreshold.first;

    for (final member in withThreshold) {
      if (!sameThresholds(member.thresholds, first.thresholds)) return null;
    }

    return first.thresholds;
  }

  bool get thresholdsDiffer {
    final hasAny = members.any((member) => member.thresholds.isNotEmpty);

    return hasAny && commonThresholds == null;
  }
}

/// Signal STATUS cua Filter results: chip "Slave ID" thay cho chart.
class FilterStatusItem {
  final CatalogTableRow row;
  final SignalHistorySeries? series;

  const FilterStatusItem({required this.row, required this.series});
}

/// "1 signal" / "3 signals".
String pluralize(int count, String noun) =>
    '$count ${count == 1 ? noun : '${noun}s'}';

/// Gom [rows] (moi signal cua cac device khop filter) thanh nhom chart.
///
/// - STATUS tach rieng ([FilterStatusItem]);
/// - ANALOG / COUNTER gom theo (code, unit) (khong code: theo ten, unit);
/// - thu tu: nhom co signal vuot nguong -> gan nguong -> con lai; trong moi
///   muc ANALOG truoc COUNTER.
///
/// [chartSeriesOf]: lich su cua range dang ve. [fallbackSeriesOf]: cache
/// sparkline 1h, dung cho kind / nguong khi range dang ve chua tai xong.
({List<FilterChartGroup> groups, List<FilterStatusItem> status})
buildFilterChartGroups(
  List<CatalogTableRow> rows, {
  required SignalHistorySeries? Function(CatalogTableRow row, String signalId)
  chartSeriesOf,
  required SignalHistorySeries? Function(String signalId) fallbackSeriesOf,
  required FilterChartLoadState? Function(String deviceKey) stateOf,
}) {
  final buckets = <String, List<CatalogTableRow>>{};
  final status = <FilterStatusItem>[];

  for (final row in rows) {
    final signalId = filterSignalIdOf(row);
    final reference =
        chartSeriesOf(row, signalId) ?? fallbackSeriesOf(signalId);

    if (isStatusSignal(row, reference)) {
      status.add(
        FilterStatusItem(row: row, series: chartSeriesOf(row, signalId)),
      );
      continue;
    }

    final code = row.cateId.trim();
    final unit = row.unit.trim();

    final key = code.isNotEmpty
        ? 'code:${code.toLowerCase()}|$unit'
        : 'name:${row.displaySignalName.toLowerCase()}|$unit';

    buckets.putIfAbsent(key, () => <CatalogTableRow>[]).add(row);
  }

  final groups = <FilterChartGroup>[];

  for (final entry in buckets.entries) {
    final groupRows = entry.value;
    final names = [for (final row in groupRows) row.displaySignalName];
    final labels = _memberLabels(groupRows);

    SignalKind? kind;
    final members = <FilterChartMember>[];

    for (var i = 0; i < groupRows.length; i++) {
      final row = groupRows[i];
      final signalId = filterSignalIdOf(row);

      final series = chartSeriesOf(row, signalId);
      final reference = series ?? fallbackSeriesOf(signalId);

      kind ??= reference?.kind;

      members.add(
        FilterChartMember(
          row: row,
          signalId: signalId,
          label: labels[i],
          styleIndex: i,
          series: series,
          state: stateOf(row.deviceKey),
          thresholds: reference?.chartThresholds ?? const <SignalThreshold>[],
        ),
      );
    }

    groups.add(
      FilterChartGroup(
        key: entry.key,
        title: _groupTitle(names),
        code: groupRows.first.cateId.trim(),
        unit: groupRows.first.unit.trim(),
        kind:
            kind ??
            (groupRows.first.kind == 'COUNTER'
                ? SignalKind.counter
                : SignalKind.analog),
        members: List<FilterChartMember>.unmodifiable(members),
      ),
    );
  }

  int kindOrder(SignalKind kind) => switch (kind) {
    SignalKind.analog => 0,
    SignalKind.counter => 1,
    SignalKind.status => 2,
  };

  groups.sort((a, b) {
    final severity = a.proximity.index - b.proximity.index;
    if (severity != 0) return severity;

    final kind = kindOrder(a.kind) - kindOrder(b.kind);
    if (kind != 0) return kind;

    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });

  return (groups: groups, status: status);
}

/// Ten chung cua [names]; khong con gi chung thi ten dau bo tu cuoi
/// ("Pressure Tank 1A" -> "Pressure Tank").
String _groupTitle(List<String> names) {
  if (names.length > 1) {
    final common = splitCommonName(names).common;
    if (common.isNotEmpty) return common;
  }

  final first = names.first.trim();
  if (names.length == 1) return first;

  final words = first.split(RegExp(r'\s+'));
  return words.length > 1 ? words.take(words.length - 1).join(' ') : first;
}

/// Nhan legend phan biet duoc:
/// - moi signal cung mot device: phan khac nhau cua ten signal (fallback PLC);
/// - khac device: ten device rut gon (bo phan chung), trung thi them PLC,
///   van trung thi dung box / device.
List<String> _memberLabels(List<CatalogTableRow> rows) {
  if (rows.length == 1) return [rows.first.boxDeviceId];

  final sameDevice = {for (final row in rows) row.deviceKey}.length == 1;

  if (sameDevice) {
    final split = splitCommonName([
      for (final row in rows) row.displaySignalName,
    ]);

    return [
      for (var i = 0; i < rows.length; i++)
        split.labels[i].isNotEmpty ? split.labels[i] : rows[i].plcAddress,
    ];
  }

  final devices = shortDeviceNames([for (final row in rows) row.boxDeviceId]);

  List<String> dedupe(List<String> labels, String Function(int i) extra) {
    final counts = <String, int>{};
    for (final label in labels) {
      counts.update(label, (n) => n + 1, ifAbsent: () => 1);
    }
    return [
      for (var i = 0; i < labels.length; i++)
        counts[labels[i]]! > 1 ? '${labels[i]} · ${extra(i)}' : labels[i],
    ];
  }

  final withPlc = dedupe(devices, (i) => rows[i].plcAddress);
  return dedupe(withPlc, (i) => rows[i].boxId);
}

/// Bo phan dau / cuoi chung cua ten device theo khuc ('_' hoac khoang
/// trang): "VCH24-9_ES-PR-S-01", "VCH24-10_ES-PR-S-01" -> "VCH24-9",
/// "VCH24-10". Ten rut gon rong thi giu nguyen ten goc.
List<String> shortDeviceNames(List<String> deviceIds) {
  final split = splitCommonName([
    for (final id in deviceIds) id.trim().replaceAll('_', ' '),
  ]);

  return [
    for (var i = 0; i < deviceIds.length; i++)
      split.labels[i].isEmpty
          ? deviceIds[i]
          : split.labels[i].replaceAll(' ', '_'),
  ];
}
