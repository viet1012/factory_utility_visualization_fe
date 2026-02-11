import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../utility_models/f2_utility_parameter_master.dart';
import '../../utility_models/response/utility_catalog.dart';
import '../../utility_state/latest_provider.dart';

class UtilityCatalogWidget extends StatefulWidget {
  final UtilityCatalogDto catalog;
  final String fac;
  final String? cate; // null => all cate
  final LatestProvider latestProvider;

  const UtilityCatalogWidget({
    super.key,
    required this.catalog,
    required this.fac,
    this.cate,
    required this.latestProvider,
  });

  @override
  State<UtilityCatalogWidget> createState() => _UtilityCatalogWidgetState();
}

class _UtilityCatalogWidgetState extends State<UtilityCatalogWidget> {
  String _mode = 'PARAM'; // PARAM | DEVICE | BOX | LATEST

  final TextEditingController _searchCtrl = TextEditingController();
  bool _importantOnly = false;

  List<_TblRow> _rows = [];
  List<_TblRow> _filteredRows = [];
  List<_ColDef> _cols = const [];

  late _ScadaDataSource _ds;

  @override
  void initState() {
    super.initState();

    _cols = _colsByMode();
    _ds = _ScadaDataSource(data: const [], columns: _cols);

    _searchCtrl.addListener(_applyFilter);

    widget.latestProvider.addListener(_onLatestUpdate);

    _rebuildRowsFromCatalog();
  }

  @override
  void didUpdateWidget(covariant UtilityCatalogWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalog != widget.catalog ||
        oldWidget.fac != widget.fac ||
        oldWidget.cate != widget.cate) {
      _rebuildRowsFromCatalog();
    }
  }

  @override
  void dispose() {
    widget.latestProvider.removeListener(_onLatestUpdate);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onLatestUpdate() {
    if (!mounted) return;

    if (_mode == 'PARAM' || _mode == 'LATEST') {
      _rebuildRowsFromCatalog();
    }
  }

  // ===================== BUILD ROWS (IN-MEMORY) =====================

  void _rebuildRowsFromCatalog() {
    final cat = widget.catalog;

    final scadaIdsOfFac = cat.scadas
        .where((s) => s.fac == widget.fac)
        .map((s) => s.scadaId)
        .toSet();

    final cate = widget.cate;

    bool cateOk(String c) => (cate == null || cate == 'ALL' || c == cate);

    if (_mode == 'BOX') {
      _rows = cat.scadas
          .where((s) => s.fac == widget.fac)
          .map(
            (s) => _TblRow({
              'fac': s.fac,
              'scadaId': s.scadaId,
              'plcIp': s.plcIp,
              'plcPort': s.plcPort ?? '',
              'wlan': s.wlan ?? '',
            }),
          )
          .toList();
    } else if (_mode == 'DEVICE') {
      _rows = cat.channels
          .where((c) => scadaIdsOfFac.contains(c.scadaId) && cateOk(c.cate))
          .map(
            (c) => _TblRow({
              'scadaId': c.scadaId,
              'cate': c.cate,
              'boxDeviceId': c.boxDeviceId,
              'boxId': c.boxId,
            }),
          )
          .toList();
    } else if (_mode == 'LATEST') {
      // latest chỉ có boxDeviceId+plcAddress+value+recordedAt
      // Filter theo FAC/CATE bằng cách join qua params/channels (dữ liệu enrich nằm trong ParamDto)
      final keyToMeta = <String, ParamDto>{};
      for (final p in cat.params) {
        if ((p.fac ?? '') != widget.fac) continue;
        if (!cateOk(p.cate ?? '')) continue;
        final k = '${p.boxDeviceId}|${p.plcAddress}';
        keyToMeta[k] = p;
      }

      _rows = cat.latest
          .map((l) {
            final k = '${l.boxDeviceId}|${l.plcAddress}';
            final meta = keyToMeta[k];
            if (meta == null) return null;

            return _TblRow({
              'fac': meta.fac ?? '',
              'scadaId': meta.scadaId ?? '',
              'cate': meta.cate ?? '',
              'boxDeviceId': l.boxDeviceId,
              'boxId': meta.boxId ?? '',
              'plcAddress': l.plcAddress,
              'latestValue': l.value,
              'recordedAt': l.recordedAt,
            });
          })
          .whereType<_TblRow>()
          .toList();
    } else {
      // PARAM: merge latest vào param
      final latestMap = {
        for (final l in cat.latest) '${l.boxDeviceId}|${l.plcAddress}': l,
      };

      _rows = cat.params
          .where((p) => (p.fac ?? '') == widget.fac && cateOk(p.cate ?? ''))
          .where((p) => !_importantOnly || (p.isImportant == true))
          .map((p) {
            final k = '${p.boxDeviceId}|${p.plcAddress}';
            final l = latestMap[k];

            return _TblRow({
              'fac': p.fac ?? '',
              'scadaId': p.scadaId ?? '',
              'cate': p.cate ?? '',
              'boxDeviceId': p.boxDeviceId,
              'boxId': p.boxId ?? '',
              'nameEn': p.nameEn,
              'plcAddress': p.plcAddress,
              'unit': p.unit,
              'valueType': p.valueType,
              'important': p.isImportant == true ? 'Y' : '',
              'alert': p.isAlert == true ? 'Y' : '',
              'latestValue': l?.value,
              'recordedAt': l?.recordedAt,
            });
          })
          .toList();
    }

    _applyFilter(setOuter: true);
  }

  // ===================== FILTER =====================

  void _applyFilter({bool setOuter = false}) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final cols = _colsByMode();

    final filtered = _rows.where((r) {
      if (q.isNotEmpty) {
        final hay = cols
            .map((c) => '${r.m[c.key] ?? ''}'.toLowerCase())
            .join('|');
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    void apply() {
      _cols = cols;
      _filteredRows = filtered;
      _ds = _ScadaDataSource(data: _filteredRows, columns: _cols);
    }

    setState(apply);
  }

  // ===================== COLUMNS =====================

  List<_ColDef> _colsByMode() {
    switch (_mode) {
      case 'BOX':
        return const [
          _ColDef('fac', 120),
          _ColDef('scadaId', 100),
          _ColDef('plcIp', 160),
          _ColDef('plcPort', 90),
          _ColDef('wlan', 160),
        ];

      case 'DEVICE':
        return const [
          _ColDef('scadaId', 100),
          _ColDef('cate', 150),
          _ColDef('boxDeviceId', 220),
          _ColDef('boxId', 180),
        ];

      case 'LATEST':
        return const [
          _ColDef('fac', 120),
          _ColDef('scadaId', 100),
          _ColDef('cate', 150),
          _ColDef('boxDeviceId', 220),
          _ColDef('boxId', 180),
          _ColDef('plcAddress', 120),
          _ColDef('latestValue', 120),
          _ColDef('recordedAt', 180),
        ];

      default: // PARAM
        return const [
          _ColDef('fac', 120),
          _ColDef('scadaId', 100),
          _ColDef('cate', 150),
          _ColDef('boxDeviceId', 220),
          _ColDef('boxId', 180),
          _ColDef('nameEn', 260),
          _ColDef('plcAddress', 120),
          _ColDef('unit', 80),
          _ColDef('valueType', 120),
          _ColDef('important', 90),
          _ColDef('alert', 90),
          _ColDef('latestValue', 120),
          _ColDef('recordedAt', 180),
        ];
    }
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1729),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1B2A44)),
      ),
      child: Column(
        children: [
          // ===== Top bar =====
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _pill('PARAM', _mode == 'PARAM', () {
                  setState(() => _mode = 'PARAM');
                  _rebuildRowsFromCatalog();
                }),
                _pill('DEVICE', _mode == 'DEVICE', () {
                  setState(() => _mode = 'DEVICE');
                  _rebuildRowsFromCatalog();
                }),
                _pill('BOX', _mode == 'BOX', () {
                  setState(() => _mode = 'BOX');
                  _rebuildRowsFromCatalog();
                }),
                _pill('LATEST', _mode == 'LATEST', () {
                  setState(() => _mode = 'LATEST');
                  _rebuildRowsFromCatalog();
                }),
                const SizedBox(width: 6),
                Text(
                  'Rows: ${_filteredRows.length}',
                  style: const TextStyle(color: Color(0xFF9FB2D6)),
                ),
              ],
            ),
          ),

          // ===== Filter bar =====
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 360,
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF9FB2D6),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0B1220),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1B2A44)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1B2A44)),
                      ),
                    ),
                  ),
                ),
                if (_mode == 'PARAM')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: _importantOnly,
                        onChanged: (v) {
                          setState(() => _importantOnly = v);
                          _rebuildRowsFromCatalog();
                        },
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Important only',
                        style: TextStyle(color: Color(0xFF9FB2D6)),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF1B2A44)),

          // ===== Grid =====
          Expanded(
            child: Container(
              color: const Color(0xFF0B1220),
              child: SfDataGrid(
                source: _ds,
                allowSorting: true,
                columnWidthMode: ColumnWidthMode.none,
                rowHeight: 42,
                headerRowHeight: 44,
                columns: _cols
                    .map(
                      (c) => GridColumn(
                        columnName: c.key,
                        width: c.w,
                        label: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          color: const Color(0xFF1B2A44),
                          child: Text(
                            c.key,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1B2A44) : const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF1B2A44)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF9FB2D6),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ===== defs =====

class _ColDef {
  final String key;
  final double w;

  const _ColDef(this.key, this.w);
}

class _TblRow {
  final Map<String, dynamic> m;

  const _TblRow(this.m);
}

class _ScadaDataSource extends DataGridSource {
  final List<_TblRow> data;
  final List<_ColDef> columns;

  _ScadaDataSource({required this.data, required this.columns}) {
    _build();
  }

  late List<DataGridRow> _gridRows;

  void _build() {
    _gridRows = data
        .map(
          (r) => DataGridRow(
            cells: columns
                .map(
                  (c) => DataGridCell<dynamic>(
                    columnName: c.key,
                    value: r.m[c.key],
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  @override
  List<DataGridRow> get rows => _gridRows;

  String _fmtDt(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final idx = _gridRows.indexOf(row);
    final zebra = idx.isEven;
    final bg = zebra ? const Color(0xFF0B1220) : const Color(0xFF0E1729);

    return DataGridRowAdapter(
      color: bg,
      cells: row.getCells().map((cell) {
        final v = cell.value;

        String txt;
        if (v is DateTime) {
          txt = _fmtDt(v);
        } else if (v is double) {
          txt = v.toStringAsFixed(2);
        } else {
          txt = v == null ? '--' : '$v';
        }

        // highlight value col
        final isValueCol = cell.columnName == 'latestValue';
        final color = isValueCol ? Colors.greenAccent : const Color(0xFF9FB2D6);
        final weight = isValueCol ? FontWeight.w900 : FontWeight.w700;

        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            txt,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: weight, fontSize: 12),
          ),
        );
      }).toList(),
    );
  }
}
