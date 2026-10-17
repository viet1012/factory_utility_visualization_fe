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

/// Cach hien nhom ap suat, giong nhau o ca 3 xuong (muc a / b / c cua
/// [planWaterLayout]).
enum WaterDialMode {
  /// (a) dong ho day du: vach chia + nhan so.
  full('a'),

  /// (b) mini gauge 84×78: cung nguong, kim, gia tri; khong vach / nhan.
  mini('b'),

  /// (c) danh sach (dong gon).
  list('c');

  const WaterDialMode(this.stage);

  final String stage;
}

/// He so scale s cua hinh + cach hien nhom ap suat, dung chung cho ca 3 cot.
/// Co so s = 1: gauge 120×110 (mini 84×78), thermometer 96×136, tank
/// 150×136, chu gia tri 16, ten 12; moi kich thuoc nhan s. Chieu cao trong
/// tile co dinh theo s de [planWaterLayout] tinh dung.
@immutable
class WaterVisualSize {
  final double scale;
  final WaterDialMode dialMode;

  const WaterVisualSize(this.scale, {this.dialMode = WaterDialMode.full});

  static const WaterVisualSize base = WaterVisualSize(1);

  /// Buoc giam s khi do vua man hinh.
  static const double step = .05;

  bool get miniDial => dialMode == WaterDialMode.mini;

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
      WaterVisualKind.dial =>
        miniDial ? const Size(84, 78) : const Size(120, 110),
      // Rong hon de co cho pill nguong ben phai ong / thuoc.
      WaterVisualKind.thermometer => const Size(96, 136),
      WaterVisualKind.tank => const Size(150, 136),
      WaterVisualKind.compact => Size.zero,
    };
    return base * scale;
  }

  /// Mini gauge: khong co dong ly do duoi chip.
  bool hasCaption(WaterVisualKind kind) =>
      !(kind == WaterVisualKind.dial && miniDial);

  /// Chieu cao co dinh cua mot tile (hinh + gia tri + ten + chip + dong ly
  /// do). Cho chip / ly do luon giu de tile khong doi cao theo trang thai.
  double tileHeight(WaterVisualKind kind) {
    final figure = figureSize(kind).height;
    final value = kind == WaterVisualKind.thermometer ? valueHeight : 0.0;
    final caption = hasCaption(kind) ? captionHeight : 0.0;

    return figure + value + 2 + nameHeight + 2 + chipHeight + caption;
  }

  @override
  bool operator ==(Object other) =>
      other is WaterVisualSize &&
      other.scale == scale &&
      other.dialMode == dialMode;

  @override
  int get hashCode => Object.hash(scale, dialMode);

  @override
  String toString() =>
      '(${dialMode.stage}) ${dialMode.name} s=${scale.toStringAsFixed(2)}';
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

  /// Ten ngan cua khoi (xem [waterGroupShortName]); cac group ten ngan
  /// khac nhau thi dung ten theo loai hinh.
  String get title {
    final names = {for (final group in groups) waterGroupShortName(group)};
    if (names.length == 1) return names.first;

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

/// Ten day du cua cac group trong khoi (tooltip tieu de).
extension WaterBlockNames on WaterBlock {
  String get fullTitle {
    final names = <String>{
      for (final group in groups) group.name.isEmpty ? group.code : group.name,
    };
    return names.join('\n');
  }
}

/// Ten nhom ngan theo code; code khac dung group.name (backend da ngan).
String waterGroupShortName(WaterGroup group) {
  final short = switch (group.code.trim().toUpperCase()) {
    'W_COOL' => 'Cooling tanks',
    'W_LEVCOOL' => 'Cooling pit level',
    'W_DPIPEPRES' || 'W_VCH_DPIPEPRES' => 'Pipeline pressure',
    _ => null,
  };
  if (short != null) return short;
  return group.name.isEmpty ? group.code : group.name;
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

  /// Canh giua noi dung (tieu de + hinh + chip): khoi muc nuoc.
  final bool centered;

  const WaterShelfItem({
    required this.block,
    required this.width,
    required this.height,
    required this.compact,
    this.centered = false,
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

TextPainter _measure(String text, TextStyle style, {double? maxWidth}) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 2,
  )..layout(maxWidth: maxWidth ?? double.infinity);
}

/// Chu nguong chung cua khoi (cung so le voi widget).
String? waterBlockThresholdText(WaterBlock block) => block.thresholdText(
  (group) => waterDecimals(code: group.code, unit: group.unit),
);

/// Cho cua badge "N issues" (luon chua san: badge doi theo polling ma bo
/// cuc khong tinh lai).
double waterIssueBadgeWidth(WaterVisualSize size) =>
    _measure(
      '99 issues',
      TextStyle(fontSize: size.titleFont - 1.5, fontWeight: FontWeight.w800),
    ).width +
    14 +
    2 +
    6;

/// Chieu cao tieu de khoi o be rong [width]: tieu de khong ellipsis, thieu
/// cho thi xuong toi da 2 dong.
double waterTitleHeight(WaterBlock block, WaterVisualSize size, double width) {
  final threshold = waterBlockThresholdText(block);
  final thresholdWidth = threshold == null
      ? 0.0
      : 8 +
            _measure(
              threshold,
              TextStyle(
                fontSize: size.titleFont - .5,
                fontWeight: FontWeight.w600,
              ),
            ).width;
  final room = math.max(
    20.0,
    width -
        (size.titleFont + 2 + 5) -
        waterIssueBadgeWidth(size) -
        thresholdWidth,
  );

  final lines = _measure(
    block.title,
    TextStyle(fontSize: size.titleFont, fontWeight: FontWeight.w800),
    maxWidth: room,
  ).computeLineMetrics().length;

  return lines > 1
      ? size.titleHeight + (size.titleFont * 1.25).ceilToDouble()
      : size.titleHeight;
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
      waterTitleHeight(block, size, width) +
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

/// Thu tu hang co dinh trong cot: Cooling tanks (nhiet ke) → Cooling pit
/// level (muc nuoc) → Pipeline pressure (ap suat) → nhom khac.
int _rowOrder(WaterVisualKind kind) => switch (kind) {
  WaterVisualKind.thermometer => 0,
  WaterVisualKind.tank => 1,
  WaterVisualKind.dial => 2,
  WaterVisualKind.compact => 3,
};

/// Xep khoi cua mot cot, doc lap voi cac cot khac: moi khoi mot hang full
/// ngang cot theo [_rowOrder] (sap xep on dinh: cung loai giu thu tu hien
/// co); xuong khong co nhom nao thi khong co hang do. Hinh canh giua; nhom
/// ap suat dang danh sach khi [WaterDialMode.list].
WaterColumnLayout arrangeWaterColumn(
  List<WaterBlock> blocks, {
  required WaterVisualSize size,
  required double innerWidth,
}) {
  final ordered =
      [
        for (final (index, block) in blocks.indexed)
          (index: index, block: block),
      ]..sort((a, b) {
        final byKind = _rowOrder(
          a.block.kind,
        ).compareTo(_rowOrder(b.block.kind));
        return byKind != 0 ? byKind : a.index.compareTo(b.index);
      });

  WaterShelfItem item(WaterBlock block) {
    final compact =
        block.kind == WaterVisualKind.compact ||
        (block.kind == WaterVisualKind.dial &&
            size.dialMode == WaterDialMode.list);
    return WaterShelfItem(
      block: block,
      width: innerWidth,
      compact: compact,
      centered: !compact,
      height: waterBlockHeight(
        block: block,
        size: size,
        width: innerWidth,
        compact: compact,
      ),
    );
  }

  return WaterColumnLayout(
    List.unmodifiable([
      for (final entry in ordered)
        if (entry.block.count > 0) WaterShelf([item(entry.block)]),
    ]),
  );
}

// ============================================================
// PLAN
// ============================================================

class WaterLayoutPlan {
  /// s + cach hien nhom ap suat (giong nhau o ca 3 xuong).
  final WaterVisualSize size;

  /// Muc (c) o s nho nhat van tran: cot cuon doc.
  final bool overflows;

  /// Xep khoi cua tung cot (theo facId).
  final Map<String, WaterColumnLayout> columns;

  final double tallestColumn;

  const WaterLayoutPlan({
    required this.size,
    required this.overflows,
    required this.columns,
    required this.tallestColumn,
  });

  static const WaterLayoutPlan fallback = WaterLayoutPlan(
    size: WaterVisualSize.base,
    overflows: false,
    columns: {},
    tallestColumn: 0,
  );

  /// He so cua header / To check: clamp(s, 1.0, 1.3).
  double get chromeScale => size.scale.clamp(1.0, 1.3);

  @override
  String toString() =>
      'WaterLayoutPlan($size, overflows: $overflows, '
      'tallest: ${tallestColumn.toStringAsFixed(0)})';
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

/// Do vua man hinh: thu lan luot tung muc, moi muc giam s (buoc 0.05) tu
/// lon toi nho, toi khi cot cao nhat vua chieu cao con lai va hinh vua be
/// ngang cot:
///   (a) dong ho day du, s 1.5 → 0.8;
///   (b) nhom ap suat -> mini gauge, s 1.2 → 0.75 (nhiet ke / bon co theo s);
///   (c) chi khi (b) van tran: nhom ap suat -> danh sach, s 1.2 → 0.75.
/// (c) o s = 0.75 van tran thi [WaterLayoutPlan.overflows] (cot cuon doc).
/// Cach hien nhom ap suat giong nhau o ca 3 xuong.
///
/// [area] la ca vung noi dung; [reservedHeight] (s) = chieu cao header +
/// To check o he so clamp(s, 1, 1.3), tru di truoc khi xep cot.
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
      for (final block in list)
        if (block.kind != WaterVisualKind.compact) block.kind,
  };

  double available(double scale) =>
      area.height - (reservedHeight?.call(scale) ?? 0);

  WaterLayoutPlan arrange(WaterVisualSize size) {
    final result = <String, WaterColumnLayout>{};
    var tallest = 0.0;
    for (final MapEntry(key: facId, value: list) in blocks.entries) {
      final layout = arrangeWaterColumn(list, size: size, innerWidth: inner);
      result[facId] = layout;
      tallest = math.max(tallest, layout.height);
    }
    return WaterLayoutPlan(
      size: size,
      overflows: tallest > available(size.scale),
      columns: result,
      tallestColumn: tallest,
    );
  }

  bool fitsWidth(WaterVisualSize size) => kinds.every(
    (kind) =>
        (kind == WaterVisualKind.dial && size.dialMode == WaterDialMode.list) ||
        size.figureSize(kind).width <= inner,
  );

  const stages = [
    (mode: WaterDialMode.full, from: 1.5, to: .8),
    (mode: WaterDialMode.mini, from: 1.2, to: .75),
    (mode: WaterDialMode.list, from: 1.2, to: .75),
  ];

  for (final stage in stages) {
    final first = (stage.from / WaterVisualSize.step).round();
    final last = (stage.to / WaterVisualSize.step).round();

    for (var i = first; i >= last; i--) {
      final size = WaterVisualSize(
        i * WaterVisualSize.step,
        dialMode: stage.mode,
      );
      if (!fitsWidth(size)) continue;

      final plan = arrange(size);
      if (!plan.overflows) return plan;
    }
  }

  // (c) o s nho nhat van tran: giu hinh, cot cuon doc.
  return arrange(const WaterVisualSize(.75, dialMode: WaterDialMode.list));
}
