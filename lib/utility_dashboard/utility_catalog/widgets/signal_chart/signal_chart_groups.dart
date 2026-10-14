/// Xep signal cua mot device cho che do Chart: STATUS len header (chip),
/// ANALOG / COUNTER thanh the; che do Merge gom theo (kind, code, unit).
library;

import '../../catalog_view_models.dart';
import '../../models/signal_history_models.dart';
import '../filter_results/filter_result_cells.dart' show isStatusSignal;

/// Mot signal trong mot the gop.
class SignalCardMember {
  final String signalId;
  final CatalogTableRow row;

  /// Nhan rut gon tren legend (vd "1A", "V12"; fallback PLC).
  final String label;

  const SignalCardMember({
    required this.signalId,
    required this.row,
    required this.label,
  });
}

/// Mot the cua che do Merge: cac signal cung (kind, code, unit).
class SignalCardGroup {
  final String key;

  /// Ten chung (bo phan khac nhau giua cac signal), fallback code.
  final String title;
  final String code;
  final String unit;
  final SignalKind kind;
  final List<SignalCardMember> members;

  const SignalCardGroup({
    required this.key,
    required this.title,
    required this.code,
    required this.unit,
    required this.kind,
    required this.members,
  });

  List<String> get signalIds => [for (final m in members) m.signalId];
}

/// Ket qua xep signal cua mot device.
class DeviceChartLayout {
  /// Signal STATUS: khong ve the, hien chip tren header.
  final List<String> statusIds;

  /// ANALOG / COUNTER theo thu tu goc (che do Split).
  final List<String> chartIds;

  /// The cua che do Merge, theo thu tu signal dau tien cua moi nhom.
  final List<SignalCardGroup> groups;

  const DeviceChartLayout({
    required this.statusIds,
    required this.chartIds,
    required this.groups,
  });

  static const empty = DeviceChartLayout(
    statusIds: <String>[],
    chartIds: <String>[],
    groups: <SignalCardGroup>[],
  );
}

/// Dinh danh cua cach xep: doi khi tap signal / kind / code / unit / ten doi,
/// khong doi khi chi du lieu (diem) doi.
String deviceChartLayoutSignature(
  List<String> signalIds,
  Map<String, CatalogTableRow> rowsById,
  SignalHistorySeries? Function(String signalId) seriesOf,
) {
  final buffer = StringBuffer();

  for (final id in signalIds) {
    final row = rowsById[id];
    final series = seriesOf(id);

    buffer
      ..write(id)
      ..write('|')
      ..write(series?.kind.name ?? row?.kind ?? '')
      ..write('|')
      ..write(_codeOf(row, series))
      ..write('|')
      ..write(_unitOf(row, series))
      ..write('|')
      ..write(_nameOf(row, series))
      ..write(';');
  }

  return buffer.toString();
}

DeviceChartLayout buildDeviceChartLayout(
  List<String> signalIds,
  Map<String, CatalogTableRow> rowsById,
  SignalHistorySeries? Function(String signalId) seriesOf,
) {
  final statusIds = <String>[];
  final chartIds = <String>[];

  final buckets = <String, List<String>>{};
  final kinds = <String, SignalKind>{};

  for (final id in signalIds) {
    final row = rowsById[id];
    if (row == null) continue;

    final series = seriesOf(id);

    if (isStatusSignal(row, series)) {
      statusIds.add(id);
      continue;
    }

    chartIds.add(id);

    final kind =
        series?.kind ??
        (row.kind == 'COUNTER' ? SignalKind.counter : SignalKind.analog);
    final code = _codeOf(row, series);

    // Khong co code: moi signal mot the.
    final key = code.isEmpty
        ? 'id:$id'
        : '${kind.name}|${code.toLowerCase()}|'
              '${_unitOf(row, series).toLowerCase()}';

    buckets.putIfAbsent(key, () => <String>[]).add(id);
    kinds[key] = kind;
  }

  final groups = <SignalCardGroup>[];

  for (final MapEntry(key: key, value: ids) in buckets.entries) {
    final rows = [for (final id in ids) rowsById[id]!];
    final names = [
      for (var i = 0; i < ids.length; i++) _nameOf(rows[i], seriesOf(ids[i])),
    ];
    final split = splitCommonName(names);
    final code = _codeOf(rows.first, seriesOf(ids.first));

    groups.add(
      SignalCardGroup(
        key: key,
        title: ids.length == 1
            ? names.first
            : (split.common.isNotEmpty ? split.common : code),
        code: code,
        unit: _unitOf(rows.first, seriesOf(ids.first)),
        kind: kinds[key]!,
        members: [
          for (var i = 0; i < ids.length; i++)
            SignalCardMember(
              signalId: ids[i],
              row: rows[i],
              label: ids.length > 1 && split.labels[i].isNotEmpty
                  ? split.labels[i]
                  : rows[i].plcAddress.trim(),
            ),
        ],
      ),
    );
  }

  return DeviceChartLayout(
    statusIds: List<String>.unmodifiable(statusIds),
    chartIds: List<String>.unmodifiable(chartIds),
    groups: List<SignalCardGroup>.unmodifiable(groups),
  );
}

/// Tach ten chung va phan rieng cua tung ten theo tu:
/// "Current 1A" / "Current 2A" -> common "Current", labels ["1A", "2A"].
/// So khop tien to va hau to chung (khong phan biet hoa thuong).
({String common, List<String> labels}) splitCommonName(List<String> names) {
  final words = [
    for (final name in names)
      name.trim().isEmpty ? <String>[] : name.trim().split(RegExp(r'\s+')),
  ];

  if (words.isEmpty) return (common: '', labels: const <String>[]);

  bool same(int Function(List<String>) indexOf) {
    final first = words.first;
    final i = indexOf(first);
    if (i < 0 || i >= first.length) return false;

    final value = first[i].toLowerCase();
    for (final list in words) {
      final j = indexOf(list);
      if (j < 0 || j >= list.length || list[j].toLowerCase() != value) {
        return false;
      }
    }
    return true;
  }

  final shortest = words
      .map((list) => list.length)
      .reduce((a, b) => a < b ? a : b);

  var prefix = 0;
  while (prefix < shortest && same((list) => prefix)) {
    prefix++;
  }

  var suffix = 0;
  while (prefix + suffix < shortest &&
      same((list) => list.length - 1 - suffix)) {
    suffix++;
  }

  final first = words.first;
  final common = [
    ...first.take(prefix),
    ...first.skip(first.length - suffix),
  ].join(' ');

  return (
    common: common,
    labels: [
      for (final list in words)
        list.sublist(prefix, list.length - suffix).join(' '),
    ],
  );
}

String _codeOf(CatalogTableRow? row, SignalHistorySeries? series) {
  final code = series?.code?.trim() ?? '';
  return code.isNotEmpty ? code : (row?.normalizedCateId ?? '');
}

String _unitOf(CatalogTableRow? row, SignalHistorySeries? series) {
  final unit = series?.unit?.trim() ?? '';
  return unit.isNotEmpty ? unit : (row?.normalizedUnit ?? '');
}

String _nameOf(CatalogTableRow? row, SignalHistorySeries? series) {
  final name = row?.displaySignalName ?? '';
  if (name.isNotEmpty && name != '--') return name;
  return series?.name ?? '--';
}
