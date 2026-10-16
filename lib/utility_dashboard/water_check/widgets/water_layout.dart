/// Bo cuc 3 cot xuong cua Water check: chon he so scale s (0.7–2.0) va
/// cach xep khoi de ca man hinh vua khit mot khung nhin, khong can cuon.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/water_check_models.dart';
import 'water_check_format.dart';
import 'water_visuals.dart';

// ============================================================
// SCALE
// ============================================================

/// He so scale s cua hinh, dung chung cho ca 3 cot. Co so s = 1: gauge
/// 120×110, thermometer 96×136, tank 150×136, chu gia tri 16, ten 12; moi
/// kich thuoc nhan s. Chieu cao trong tile co dinh theo s de
/// [planWaterLayout] tinh dung.
@immutable
class WaterVisualSize {
  final double scale;

  const WaterVisualSize(this.scale);

  static const WaterVisualSize base = WaterVisualSize(1);

  static const double minScale = .7;
  static const double maxScale = 2;
  static const double step = .05;

  /// Co chu theo s (khong nho hon [min]).
  double font(double size, {double min = 8}) => math.max(min, size * scale);

  double get valueFont => math.max(14, 16 * scale);
  double get nameFont => math.max(11, 12 * scale);

  /// Chip trang thai: 12px, toi thieu 11px.
  double get chipFont => math.max(11, 12 * scale);

  /// Dong ly do duoi chip: 11px.
  double get captionFont => math.max(10, 11 * scale);

  /// Gia tri cua hinh co van de to hon 15%.
  static const double problemValueScale = 1.15;
  double get titleFont => math.max(11, 12 * scale);

  double get valueHeight =>
      (valueFont * problemValueScale * 1.3).ceilToDouble();
  double get nameHeight => (nameFont * 1.35).ceilToDouble();

  /// Chu 12 + padding doc 3×2.
  double get chipHeight => (chipFont * 1.25 + 6).ceilToDouble();
  double get captionHeight => (captionFont * 1.35).ceilToDouble();
  double get titleHeight => (titleFont * 1.75).ceilToDouble();

  /// Chip bang chu (luon co tu khi doi sang scale lien tuc).
  bool get showChip => true;

  /// Khoang cach giua cac hinh / khoi.
  double get spacing => (14 * scale).clamp(8.0, 24.0);

  /// s < 0.9: gauge chi hien nhan min / max.
  bool get minMaxLabelsOnly => scale < .9;

  Size figureSize(WaterVisualKind kind) {
    final base = switch (kind) {
      WaterVisualKind.dial => const Size(120, 110),
      // Rong hon de co cho pill nguong ben phai ong / thuoc.
      WaterVisualKind.thermometer => const Size(96, 136),
      WaterVisualKind.tank => const Size(150, 136),
      WaterVisualKind.compact => Size.zero,
    };
    return base * scale;
  }

  /// Chieu cao co dinh cua mot tile (hinh + gia tri + ten + chip + dong ly
  /// do). Cho chip / ly do luon giu de tile khong doi cao theo trang thai.
  double tileHeight(WaterVisualKind kind) {
    final figure = figureSize(kind).height;
    final value = kind == WaterVisualKind.thermometer ? valueHeight : 0.0;

    return figure + value + 2 + nameHeight + 2 + chipHeight + captionHeight;
  }

  @override
  bool operator ==(Object other) =>
      other is WaterVisualSize && other.scale == scale;

  @override
  int get hashCode => scale.hashCode;

  @override
  String toString() => 's=${scale.toStringAsFixed(2)}';
}

// ============================================================
// METRICS
// ============================================================

/// Kich thuoc khung co dinh cua cot / khoi (khop voi
/// water_facility_column.dart).
abstract final class WaterColumnMetrics {
  /// Padding ScadaPanelFrame: trai / phai / tren / duoi.
  static const double padLeft = 12;
  static const double padRight = 8;
  static const double padTop = 12;
  static const double padBottom = 8;

  /// Padding phai cua vung cuon.
  static const double scrollPad = 4;

  static const double headerHeight = 22;
  static const double headerGap = 6;

  /// Padding tren + duoi cua moi khoi.
  static const double blockPad = 12;

  /// Vien duoi + margin duoi cua tieu de khoi.
  static const double titleExtra = 9;

  /// Mot dong gon.
  static const double compactRowHeight = 26;

  /// Khoang cach giua cac cot.
  static const double columnGap = 8;

  /// Sai so cho lam tron / vien.
  static const double slack = 4;

  /// Be rong toi thieu cua khoi hep (de tieu de doc duoc).
  static const double minNarrowWidth = 120;

  static double innerWidth(double columnWidth) =>
      columnWidth - padLeft - padRight - scrollPad;

  static double chrome() =>
      padTop + padBottom + headerHeight + headerGap + slack;
}

// ============================================================
// BLOCK
// ============================================================

/// Mot diem do trong khoi (giu group goc: nguong rieng cua tung hinh).
class WaterBlockItem {
  final WaterSignal signal;
  final WaterGroup group;
  final String name;
  final String key;

  const WaterBlockItem({
    required this.signal,
    required this.group,
    required this.name,
    required this.key,
  });
}

/// Cac group cung loai hinh + cung unit trong mot xuong, gop thanh mot
/// khoi (vd NVD + VCH -> "Pipeline pressure"). Dong gon khong gop.
class WaterBlock {
  final String key;
  final WaterVisualKind kind;
  final String unit;
  final List<WaterGroup> groups;
  final List<WaterBlockItem> items;

  const WaterBlock({
    required this.key,
    required this.kind,
    required this.unit,
    required this.groups,
    required this.items,
  });

  int get count => items.length;

  bool get isNarrow =>
      kind == WaterVisualKind.thermometer || kind == WaterVisualKind.tank;

  String get title {
    if (groups.length == 1) {
      final group = groups.first;
      return group.name.isEmpty ? group.code : group.name;
    }
    return switch (kind) {
      WaterVisualKind.dial => 'Pipeline pressure',
      WaterVisualKind.thermometer => 'Water temperature',
      WaterVisualKind.tank => 'Water level',
      WaterVisualKind.compact => groups.first.name,
    };
  }

  /// Nguong chung cua khoi; cac group co nguong khac nhau thi null (moi
  /// hinh tu hien nguong rieng).
  String? thresholdText(int Function(WaterGroup group) decimalsOf) {
    String? shared;
    for (var i = 0; i < groups.length; i++) {
      final text = groupThresholdText(groups[i], decimalsOf(groups[i]));
      if (i == 0) {
        shared = text;
      } else if (text != shared) {
        return null;
      }
    }
    return shared;
  }
}

/// Khoi cua mot xuong, giu thu tu xuat hien dau tien cua group.
List<WaterBlock> waterBlocksOf(WaterFacility facility) {
  final order = <String>[];
  final groupsByKey = <String, List<WaterGroup>>{};
  final kinds = <String, WaterVisualKind>{};

  for (final group in facility.groups) {
    final kind = WaterVisualKind.of(group);
    final key = kind == WaterVisualKind.compact
        ? '${facility.facId}|COMPACT|${group.code}|${group.name}'.toUpperCase()
        : '${facility.facId}|${kind.name}|${group.unit.trim()}'.toUpperCase();

    if (!groupsByKey.containsKey(key)) {
      order.add(key);
      groupsByKey[key] = [];
      kinds[key] = kind;
    }
    groupsByKey[key]!.add(group);
  }

  return [
    for (final key in order)
      _buildBlock(facility.facId, key, kinds[key]!, groupsByKey[key]!),
  ];
}

WaterBlock _buildBlock(
  String facId,
  String key,
  WaterVisualKind kind,
  List<WaterGroup> groups,
) {
  final raw = <({WaterSignal signal, WaterGroup group, String name})>[
    for (final group in groups)
      for (final (i, name) in displayNamesOf(group).indexed)
        (signal: group.signals[i], group: group, name: name),
  ];

  // Ten trung nhau giua cac group trong khoi: kem device / ten group.
  final counts = <String, int>{};
  for (final item in raw) {
    final lower = item.name.toLowerCase();
    counts[lower] = (counts[lower] ?? 0) + 1;
  }

  return WaterBlock(
    key: key,
    kind: kind,
    unit: groups.first.unit,
    groups: List.unmodifiable(groups),
    items: List.unmodifiable([
      for (final item in raw)
        WaterBlockItem(
          signal: item.signal,
          group: item.group,
          name: groups.length > 1 && (counts[item.name.toLowerCase()] ?? 0) > 1
              ? '${item.signal.deviceName.isNotEmpty ? item.signal.deviceName : item.group.name} · ${item.name}'
              : item.name,
          key: waterSignalKey(
            facId,
            item.signal.boxDeviceId,
            item.signal.plcAddress,
          ),
        ),
    ]),
  );
}

// ============================================================
// ARRANGEMENT
// ============================================================

class WaterShelfItem {
  final WaterBlock block;
  final double width;
  final double height;

  /// Dong gon thay cho hinh.
  final bool compact;

  const WaterShelfItem({
    required this.block,
    required this.width,
    required this.height,
    required this.compact,
  });
}

/// Mot hang khoi: khoi rong chiem ca hang; khoi hep xep canh nhau.
class WaterShelf {
  final List<WaterShelfItem> items;

  const WaterShelf(this.items);

  double get height => items.fold(0, (max, item) => math.max(max, item.height));
}

class WaterColumnLayout {
  final List<WaterShelf> shelves;

  const WaterColumnLayout(this.shelves);

  double get height =>
      WaterColumnMetrics.chrome() +
      shelves.fold<double>(0, (sum, shelf) => sum + shelf.height);
}

/// Chieu cao mot khoi o be rong [width].
double waterBlockHeight({
  required WaterBlock block,
  required WaterVisualSize size,
  required double width,
  required bool compact,
}) {
  final chrome =
      WaterColumnMetrics.blockPad +
      size.titleHeight +
      WaterColumnMetrics.titleExtra;
  final count = block.count;

  if (count == 0) return chrome;
  if (compact) return chrome + count * WaterColumnMetrics.compactRowHeight;

  final tileWidth = size.figureSize(block.kind).width;
  final perRow = math.max(
    1,
    ((width + size.spacing) / (tileWidth + size.spacing)).floor(),
  );
  final rows = (count / perRow).ceil();

  return chrome +
      rows * size.tileHeight(block.kind) +
      (rows - 1) * size.spacing;
}

/// Xep khoi cua mot cot: khoi rong (dong ho, dong gon) chiem ca hang; khoi
/// hep (nhiet ke, bon) lien tiep xep canh nhau neu vua, phan du chia deu.
WaterColumnLayout arrangeWaterColumn(
  List<WaterBlock> blocks, {
  required WaterVisualSize size,
  required double innerWidth,
  required Set<String> compactBlocks,
}) {
  final shelves = <WaterShelf>[];
  final pending = <({WaterBlock block, double width})>[];
  final gap = size.spacing;

  bool isCompact(WaterBlock block) =>
      block.kind == WaterVisualKind.compact ||
      compactBlocks.contains(block.key);

  WaterShelfItem item(WaterBlock block, double width) {
    final compact = isCompact(block);
    return WaterShelfItem(
      block: block,
      width: width,
      compact: compact,
      height: waterBlockHeight(
        block: block,
        size: size,
        width: width,
        compact: compact,
      ),
    );
  }

  void flush() {
    if (pending.isEmpty) return;

    final used =
        pending.fold<double>(0, (sum, entry) => sum + entry.width) +
        gap * (pending.length - 1);
    final extra = math.max(0.0, innerWidth - used) / pending.length;

    shelves.add(
      WaterShelf([
        for (final entry in pending) item(entry.block, entry.width + extra),
      ]),
    );
    pending.clear();
  }

  for (final block in blocks) {
    if (!block.isNarrow || isCompact(block)) {
      flush();
      shelves.add(WaterShelf([item(block, innerWidth)]));
      continue;
    }

    final tileWidth = size.figureSize(block.kind).width;
    final natural = math.min(
      innerWidth,
      math.max(
        WaterColumnMetrics.minNarrowWidth,
        block.count * tileWidth + (block.count - 1) * gap,
      ),
    );

    final used =
        pending.fold<double>(0, (sum, entry) => sum + entry.width) +
        gap * pending.length;

    if (pending.isNotEmpty && used + natural > innerWidth) {
      // Khong vua o be rong tu nhien: so sanh "ep hep (hinh xuong dong) van
      // canh nhau" voi "sang hang moi", lay phuong an thap hon.
      final squeezed = _squeeze(
        [...pending, (block: block, width: natural)],
        innerWidth: innerWidth,
        gap: gap,
        size: size,
      );

      if (squeezed != null) {
        final separate =
            _shelfHeight(pending, innerWidth, gap, size) +
            waterBlockHeight(
              block: block,
              size: size,
              width: innerWidth,
              compact: false,
            );
        final together = squeezed.fold<double>(
          0,
          (max, entry) => math.max(
            max,
            waterBlockHeight(
              block: entry.block,
              size: size,
              width: entry.width,
              compact: false,
            ),
          ),
        );

        if (together <= separate) {
          pending
            ..clear()
            ..addAll(squeezed);
          continue;
        }
      }

      flush();
    }

    pending.add((block: block, width: natural));
  }
  flush();

  return WaterColumnLayout(List.unmodifiable(shelves));
}

/// Chia [innerWidth] cho cac khoi hep theo ty le be rong tu nhien; null khi
/// co khoi khong con chua noi mot hinh.
List<({WaterBlock block, double width})>? _squeeze(
  List<({WaterBlock block, double width})> entries, {
  required double innerWidth,
  required double gap,
  required WaterVisualSize size,
}) {
  final room = innerWidth - gap * (entries.length - 1);
  final total = entries.fold<double>(0, (sum, entry) => sum + entry.width);
  if (room <= 0 || total <= 0) return null;

  final result = [
    for (final entry in entries)
      (block: entry.block, width: entry.width * room / total),
  ];

  final fits = result.every(
    (entry) => entry.width >= size.figureSize(entry.block.kind).width,
  );
  return fits ? result : null;
}

/// Chieu cao hang cac khoi hep dang cho (phan du chia deu nhu flush).
double _shelfHeight(
  List<({WaterBlock block, double width})> entries,
  double innerWidth,
  double gap,
  WaterVisualSize size,
) {
  final used =
      entries.fold<double>(0, (sum, entry) => sum + entry.width) +
      gap * (entries.length - 1);
  final extra = math.max(0.0, innerWidth - used) / entries.length;

  return entries.fold<double>(
    0,
    (max, entry) => math.max(
      max,
      waterBlockHeight(
        block: entry.block,
        size: size,
        width: entry.width + extra,
        compact: false,
      ),
    ),
  );
}

// ============================================================
// PLAN
// ============================================================

class WaterLayoutPlan {
  final WaterVisualSize size;

  /// Khoi (theo [WaterBlock.key]) dang dong gon thay cho hinh.
  final Set<String> compactBlocks;

  /// Moi khoi da la dong gon ma van tran: cot cuon doc.
  final bool overflows;

  /// Xep khoi cua tung cot (theo facId).
  final Map<String, WaterColumnLayout> columns;

  final double tallestColumn;

  const WaterLayoutPlan({
    required this.size,
    required this.compactBlocks,
    required this.overflows,
    required this.columns,
    required this.tallestColumn,
  });

  static const WaterLayoutPlan fallback = WaterLayoutPlan(
    size: WaterVisualSize.base,
    compactBlocks: {},
    overflows: false,
    columns: {},
    tallestColumn: 0,
  );

  /// He so cua header / To check: clamp(s, 1.0, 1.3).
  double get chromeScale => size.scale.clamp(1.0, 1.3);

  @override
  String toString() =>
      'WaterLayoutPlan($size, compact: ${compactBlocks.length}, '
      'overflows: $overflows, tallest: ${tallestColumn.toStringAsFixed(0)})';
}

/// Chu ky du lieu anh huong bo cuc: xuong, nhom, loai hinh, so diem do.
/// Polling khong doi so diem do thi chu ky giu nguyen.
String waterLayoutSignature(List<WaterFacility> facilities) {
  final buffer = StringBuffer();
  for (final fac in facilities) {
    buffer.write(fac.facId);
    for (final group in fac.groups) {
      buffer
        ..write('|')
        ..write(group.code)
        ..write('/')
        ..write(group.name)
        ..write('/')
        ..write(group.unit)
        ..write(':')
        ..write(group.signals.length);
    }
    buffer.write(';');
  }
  return buffer.toString();
}

/// Chon s lon nhat (buoc 0.05, 0.7–2.0) ma cot cao nhat vua chieu cao con
/// lai va hinh vua be ngang cot.
///
/// [area] la ca vung noi dung; [reservedHeight] (s) = chieu cao header +
/// To check o he so clamp(s, 1, 1.3), tru di truoc khi xep cot. s = 0.7 van
/// tran: lan luot chuyen khoi nhieu diem do nhat sang dong gon; moi khoi da
/// gon ma van tran thi [WaterLayoutPlan.overflows].
WaterLayoutPlan planWaterLayout(
  List<WaterFacility> facilities,
  Size area, {
  double Function(double scale)? reservedHeight,
}) {
  if (facilities.isEmpty || !area.height.isFinite || area.width <= 0) {
    return WaterLayoutPlan.fallback;
  }

  final columns = facilities.length;
  final columnWidth =
      (area.width - WaterColumnMetrics.columnGap * (columns - 1)) / columns;
  final inner = WaterColumnMetrics.innerWidth(columnWidth);
  final blocks = {for (final fac in facilities) fac.facId: waterBlocksOf(fac)};

  final kinds = {
    for (final list in blocks.values)
      for (final block in list) block.kind,
  };

  double available(double scale) =>
      area.height - (reservedHeight?.call(scale) ?? 0);

  ({Map<String, WaterColumnLayout> columns, double tallest}) arrange(
    WaterVisualSize size,
    Set<String> compact,
  ) {
    final result = <String, WaterColumnLayout>{};
    var tallest = 0.0;
    for (final MapEntry(key: facId, value: list) in blocks.entries) {
      final layout = arrangeWaterColumn(
        list,
        size: size,
        innerWidth: inner,
        compactBlocks: compact,
      );
      result[facId] = layout;
      tallest = math.max(tallest, layout.height);
    }
    return (columns: result, tallest: tallest);
  }

  final maxSteps = (WaterVisualSize.maxScale / WaterVisualSize.step).round();
  final minSteps = (WaterVisualSize.minScale / WaterVisualSize.step).round();

  for (var stepIndex = maxSteps; stepIndex >= minSteps; stepIndex--) {
    final size = WaterVisualSize(stepIndex * WaterVisualSize.step);

    final fitsWidth = kinds.every(
      (kind) => size.figureSize(kind).width <= inner,
    );
    if (!fitsWidth) continue;

    final result = arrange(size, const {});
    if (result.tallest <= available(size.scale)) {
      return WaterLayoutPlan(
        size: size,
        compactBlocks: const {},
        overflows: false,
        columns: result.columns,
        tallestColumn: result.tallest,
      );
    }
  }

  const size = WaterVisualSize(WaterVisualSize.minScale);
  final room = available(size.scale);

  // Khoi co the gon lai, nhieu diem do truoc.
  final candidates = [
    for (final list in blocks.values)
      for (final block in list)
        if (block.kind != WaterVisualKind.compact && block.count > 0) block,
  ]..sort((a, b) => b.count.compareTo(a.count));

  // Hinh rong hon cot ngay o s nho nhat (bon 150·s, nhiet ke 96·s): gon
  // ngay, khong thi tran ngang.
  final compact = <String>{
    for (final block in candidates)
      if (size.figureSize(block.kind).width > inner) block.key,
  };
  var result = arrange(size, compact);

  for (final block in candidates) {
    if (result.tallest <= room) break;
    compact.add(block.key);
    result = arrange(size, compact);
  }

  return WaterLayoutPlan(
    size: size,
    compactBlocks: Set.unmodifiable(compact),
    overflows: result.tallest > room,
    columns: result.columns,
    tallestColumn: result.tallest,
  );
}
