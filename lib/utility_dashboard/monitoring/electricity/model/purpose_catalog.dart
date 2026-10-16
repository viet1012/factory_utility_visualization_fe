import 'power_usage.dart';

/// Cac dong purpose co dinh cua bang "Change by purpose" (dung thu tu).
enum PurposeSlot {
  machining('Machining equipment', ['MACHIN']),
  heatFurnace('Heat furnace', ['FURNACE', 'HEAT']),
  airConditioning('Air conditioning', ['AIR_COND', 'AIRCON', 'AIR COND', 'HVAC']),
  compressedAir('Compressed air', ['COMPRESS']),
  lighting('Lighting', ['LIGHT']),
  other('Other', []);

  const PurposeSlot(this.label, this.tokens);

  final String label;

  /// Khop theo code / name (in hoa). `Other` chi khop code OTHER.
  final List<String> tokens;

  bool matches(PowerPurposeUsage purpose) {
    final code = purpose.code.toUpperCase();
    if (this == PurposeSlot.other) return code == 'OTHER';

    final name = purpose.name.toUpperCase();
    return tokens.any((t) => code.contains(t) || name.contains(t));
  }
}

class PurposeRowData {
  final PurposeSlot slot;

  /// null: chua map meter nao cho purpose nay.
  final PowerPurposeUsage? purpose;

  const PurposeRowData(this.slot, this.purpose);

  bool get mapped => purpose != null;
}

List<PurposeRowData> resolvePurposeRows(List<PowerPurposeUsage> purposes) {
  // Moi tu khi nen (COMPRESSED_AIR_*) la mot purpose rieng: gom lai thanh
  // dong Compressed air, khong de dong khac khop nham.
  final cabinets = purposes.where(isCompressedAirCabinet).toList();
  final rest = purposes.where((p) => !isCompressedAirCabinet(p)).toList();

  final used = <PowerPurposeUsage>{};
  PowerPurposeUsage? match(PurposeSlot slot) {
    for (final p in rest) {
      if (!used.contains(p) && slot.matches(p)) {
        used.add(p);
        return p;
      }
    }
    return null;
  }

  return [
    for (final slot in PurposeSlot.values)
      PurposeRowData(
        slot,
        slot == PurposeSlot.compressedAir
            ? _compressedAirRow(match(slot), cabinets)
            : match(slot),
      ),
  ];
}

// ============================================================
// COMPRESSED AIR
// ============================================================

const String _cabinetPrefix = 'COMPRESSED_AIR_';

bool isCompressedAirCabinet(PowerPurposeUsage p) =>
    p.code.toUpperCase().startsWith(_cabinetPrefix);

/// `Fac_B`, `FAC-B`, `fac b` -> `Fac_B`; khong nhan ra thi tra nguyen chuoi.
String normalizeFacId(String facId) {
  final match = RegExp(r'^FAC[_\- ]?([A-Z])$').firstMatch(
    facId.trim().toUpperCase(),
  );
  return match == null ? facId.trim() : 'Fac_${match.group(1)}';
}

final RegExp _facPattern = RegExp(r'FAC[_\- ]?([A-Z])(?![A-Z])', caseSensitive: false);

/// Fac cua tu: tim `FAC_X` trong code, roi description, roi name; cuoi cung
/// la mot chu cai dung ngay sau `COMPRESSED_AIR_` (vd COMPRESSED_AIR_B_ACP).
String? _cabinetFacId(PowerPurposeUsage p) {
  for (final text in [p.code, p.description ?? '', p.name]) {
    final m = _facPattern.firstMatch(text);
    if (m != null) return 'Fac_${m.group(1)!.toUpperCase()}';
  }

  final rest = p.code.toUpperCase().substring(_cabinetPrefix.length);
  final m = RegExp(r'^([A-Z])(?:[_\-]|$)').firstMatch(rest);
  return m == null ? null : 'Fac_${m.group(1)}';
}

/// Ten tu (ACP, ACP1, DB-COMP...): uu tien name, neu name chung chung thi lay
/// phan con lai cua code sau prefix + fac.
String _cabinetLabel(PowerPurposeUsage p) {
  final name = p.name.trim();
  if (name.isNotEmpty && !name.toUpperCase().contains('COMPRESS')) {
    return name;
  }

  var rest = p.code.substring(_cabinetPrefix.length);
  rest = rest.replaceFirst(
    RegExp(r'^(FAC[_\- ]?)?[A-Z][_\-]', caseSensitive: false),
    '',
  );
  return rest.isEmpty ? p.code : rest;
}

List<PowerPurposeFactory> _groupCabinets(List<PowerPurposeUsage> cabinets) {
  final byFac = <String, List<PowerPurposeUsage>>{};
  for (final c in cabinets) {
    byFac.putIfAbsent(_cabinetFacId(c) ?? 'Unknown', () => []).add(c);
  }

  final facIds = byFac.keys.toList()..sort();
  return [
    for (final facId in facIds)
      () {
        final items = byFac[facId]!;
        final kwh = _sum(items.map((c) => c.kwh));
        final prev = _sum(items.map((c) => c.prevKwh));
        return PowerPurposeFactory(
          facId: facId,
          kwh: kwh,
          prevKwh: prev,
          changePct: _changePct(kwh, prev),
          meters: [
            for (final c in items)
              PowerPurposeMeter(
                // Chua co boxDeviceId rieng trong DTO: dung ten tu.
                boxDeviceId: _cabinetLabel(c),
                label: _cabinetLabel(c),
                kwh: c.kwh,
                prevKwh: c.prevKwh,
                changePct: c.changePct,
              ),
          ],
        );
      }(),
  ];
}

/// Dong tong Compressed air: purpose tong (neu co) + cay tu theo fac.
PowerPurposeUsage? _compressedAirRow(
  PowerPurposeUsage? aggregate,
  List<PowerPurposeUsage> cabinets,
) {
  if (cabinets.isEmpty) return aggregate;

  final grouped = _groupCabinets(cabinets);
  if (aggregate != null) {
    return PowerPurposeUsage(
      code: aggregate.code,
      name: aggregate.name,
      description: aggregate.description,
      kwh: aggregate.kwh,
      prevKwh: aggregate.prevKwh,
      changePct: aggregate.changePct,
      last7: aggregate.last7,
      byFactory: aggregate.byFactory.isNotEmpty ? aggregate.byFactory : grouped,
    );
  }

  final kwh = _sum(cabinets.map((c) => c.kwh));
  final prev = _sum(cabinets.map((c) => c.prevKwh));
  final days = cabinets.fold<int>(
    0,
    (n, c) => c.last7.length > n ? c.last7.length : n,
  );

  return PowerPurposeUsage(
    code: 'COMPRESSED_AIR',
    name: PurposeSlot.compressedAir.label,
    kwh: kwh,
    prevKwh: prev,
    changePct: _changePct(kwh, prev),
    last7: [
      for (var i = 0; i < days; i++)
        _sum(cabinets.map((c) => i < c.last7.length ? c.last7[i] : null)),
    ],
    byFactory: grouped,
  );
}

double? _sum(Iterable<double?> values) {
  double? total;
  for (final v in values) {
    if (v != null) total = (total ?? 0) + v;
  }
  return total;
}

/// Giong backend: null khi ky truoc bang 0.
double? _changePct(double? current, double? previous) {
  if (current == null || previous == null || previous == 0) return null;
  return (current - previous) / previous * 100;
}
