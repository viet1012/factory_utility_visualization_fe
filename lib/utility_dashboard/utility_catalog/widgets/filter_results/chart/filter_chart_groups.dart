import 'package:flutter/material.dart';

import '../../../../shared/charts/signal_thresholds.dart';
import '../../../catalog_view_models.dart';
import '../../../models/signal_history_models.dart';
import '../../../providers/filter_chart_controller.dart';
import '../filter_result_cells.dart';

/// So device hien mac dinh trong mot nhom; con lai sau nut "Show all (N)".
const int kFilterChartVisibleMembers = 8;

/// Mau co dinh theo thu tu device trong nhom.
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

/// Mot device trong mot nhom signal.
class FilterChartMember {
  final CatalogTableRow row;
  final String signalId;
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
    // Doi ca net khi mau lap lai (device thu 9 tro di).
    final index =
        (styleIndex + styleIndex ~/ kFilterChartColors.length) %
        kFilterChartDashes.length;
    return kFilterChartDashes[index];
  }

  bool get hasError =>
      state == FilterChartLoadState.error || (series?.error != null);

  /// Gia tri hien tai (latest) vuot nguong.
  bool get overThreshold {
    final value = row.value;
    if (value == null || !value.isFinite) return false;

    return thresholdBreachLevel(thresholds, value: value) != null;
  }
}

/// Mot nhom: cung (code, unit), hoac cung (ten, unit) khi khong co code.
class FilterChartGroup {
  final String key;
  final String title;
  final String? subtitle;
  final String unit;
  final SignalKind kind;

  /// Theo thu tu device co dinh (styleIndex tang dan).
  final List<FilterChartMember> members;

  const FilterChartGroup({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.unit,
    required this.kind,
    required this.members,
  });

  int get overCount => members.where((member) => member.overThreshold).length;

  /// Device hien mac dinh: uu tien device vuot nguong, toi da
  /// [kFilterChartVisibleMembers]; giu thu tu goc trong moi phan.
  List<FilterChartMember> get priorityMembers {
    if (members.length <= kFilterChartVisibleMembers) return members;

    final over = members.where((member) => member.overThreshold);
    final rest = members.where((member) => !member.overThreshold);

    final picked = [...over, ...rest].take(kFilterChartVisibleMembers).toSet();

    return [
      for (final member in members)
        if (picked.contains(member)) member,
    ];
  }

  /// Nguong chung cua ca nhom (moi device co cung nguong), de ve duong
  /// nguong tren truc chung. Nguong khac nhau giua device -> null.
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

/// Gom [rows] (moi signal cua cac device khop filter) thanh nhom chart.
///
/// [chartSeriesOf]: lich su cua range dang ve. [fallbackSeriesOf]: cache
/// sparkline 1h, dung cho kind / nguong khi range dang ve chua tai xong.
List<FilterChartGroup> buildFilterChartGroups(
  List<CatalogTableRow> rows, {
  required SignalHistorySeries? Function(CatalogTableRow row, String signalId)
  chartSeriesOf,
  required SignalHistorySeries? Function(String signalId) fallbackSeriesOf,
  required FilterChartLoadState? Function(String deviceKey) stateOf,
}) {
  final buckets = <String, List<CatalogTableRow>>{};

  for (final row in rows) {
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
    final first = groupRows.first;

    // Ten device trung nhau giua cac box -> kem ten box.
    final names = <String, int>{};
    for (final row in groupRows) {
      names.update(row.boxDeviceId, (count) => count + 1, ifAbsent: () => 1);
    }

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
          label: (names[row.boxDeviceId] ?? 0) > 1
              ? '${row.boxId} / ${row.boxDeviceId}'
              : row.boxDeviceId,
          styleIndex: i,
          series: series,
          state: stateOf(row.deviceKey),
          thresholds:
              reference?.chartThresholds ?? const <SignalThreshold>[],
        ),
      );
    }

    final code = first.cateId.trim();

    groups.add(
      FilterChartGroup(
        key: entry.key,
        title: code.isNotEmpty ? code : first.displaySignalName,
        subtitle: code.isNotEmpty ? first.displaySignalName : null,
        unit: first.unit.trim(),
        kind:
            kind ??
            (isStatusSignal(first, null) ? SignalKind.status : SignalKind.analog),
        members: List<FilterChartMember>.unmodifiable(members),
      ),
    );
  }

  int kindOrder(SignalKind kind) => switch (kind) {
    SignalKind.analog => 0,
    SignalKind.counter => 1,
    SignalKind.status => 2,
  };

  // Nhom co device vuot nguong len dau, sau do ANALOG, COUNTER, STATUS.
  groups.sort((a, b) {
    final over = (b.overCount > 0 ? 1 : 0) - (a.overCount > 0 ? 1 : 0);
    if (over != 0) return over;

    final kind = kindOrder(a.kind) - kindOrder(b.kind);
    if (kind != 0) return kind;

    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });

  return groups;
}
