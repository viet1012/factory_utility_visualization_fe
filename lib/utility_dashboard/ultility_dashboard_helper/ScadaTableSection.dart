import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../utility_models/utility_facade_service.dart';

class ScadaTableSection extends StatefulWidget {
  final List<FacTree> facs;

  const ScadaTableSection({super.key, required this.facs});

  @override
  State<ScadaTableSection> createState() => _ScadaTableSectionState();
}

class _ScadaTableSectionState extends State<ScadaTableSection> {
  String _mode = 'PARAM'; // PARAM | DEVICE | BOX

  // ===== UI filters =====
  final TextEditingController _searchCtrl = TextEditingController();
  String _facFilter = 'ALL';
  String _cateFilter = 'ALL';
  bool _importantOnly = false;

  // ===== cache =====
  late List<_TblRow> _boxRows;
  late List<_TblRow> _devRows;
  late List<_TblRow> _paramRows;

  late List<_TblRow> _filteredRows;
  late List<_ColDef> _cols;

  late _ScadaDataSource _ds;

  @override
  void initState() {
    super.initState();
    _rebuildCache();
    _rebuildView();
    _searchCtrl.addListener(_rebuildView);
  }

  @override
  void didUpdateWidget(covariant ScadaTableSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.facs, widget.facs)) {
      _rebuildCache();
      _rebuildView();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _rebuildCache() {
    _boxRows = _flattenBoxes(widget.facs);
    _devRows = _flattenDevices(widget.facs);
    _paramRows = _flattenParams(widget.facs);
  }

  void _rebuildView() {
    final rows = _rowsByMode();
    final cols = _colsByMode();

    final q = _searchCtrl.text.trim().toLowerCase();

    List<_TblRow> filtered = rows.where((r) {
      // fac filter
      if (_facFilter != 'ALL' && '${r.m['fac']}' != _facFilter) return false;

      // cate filter (only meaningful for DEVICE/PARAM)
      if (_cateFilter != 'ALL') {
        final cate = '${r.m['cate'] ?? ''}';
        if (cate != _cateFilter) return false;
      }

      // important only (PARAM only)
      if (_importantOnly && _mode == 'PARAM') {
        if ('${r.m['important'] ?? ''}'.isEmpty) return false;
      }

      // search
      if (q.isNotEmpty) {
        // search across all cells
        final hay = cols
            .map((c) => '${r.m[c.key] ?? ''}'.toLowerCase())
            .join('|');
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    setState(() {
      _cols = cols;
      _filteredRows = filtered;
      _ds = _ScadaDataSource(data: _filteredRows, columns: _cols);
    });
  }

  List<_TblRow> _rowsByMode() {
    switch (_mode) {
      case 'BOX':
        return _boxRows;
      case 'DEVICE':
        return _devRows;
      default:
        return _paramRows;
    }
  }

  List<_ColDef> _colsByMode() {
    switch (_mode) {
      case 'BOX':
        return const [
          _ColDef('fac', 100),
          _ColDef('scadaId', 90),
          _ColDef('plcIp', 150),
          _ColDef('plcPort', 80),
          _ColDef('wlan', 160),
        ];
      case 'DEVICE':
        return const [
          _ColDef('fac', 100),
          _ColDef('scadaId', 90),
          _ColDef('cate', 150),
          _ColDef('boxDeviceId', 190),
          _ColDef('boxId', 160),
        ];
      default:
        return const [
          _ColDef('fac', 100),
          _ColDef('scadaId', 90),
          _ColDef('cate', 150),
          _ColDef('boxDeviceId', 190),
          _ColDef('boxId', 130),
          _ColDef('nameEn', 240),
          _ColDef('plcAddress', 120),
          _ColDef('unit', 80),
          _ColDef('valueType', 120),
          _ColDef('important', 90),
          _ColDef('latestValue', 150),
          _ColDef('recordedAt', 200),
        ];
    }
  }

  List<String> _facOptions() {
    final set = <String>{'ALL'};
    for (final f in widget.facs) set.add(f.facId);
    final list = set.toList()..sort();
    return list;
  }

  List<String> _cateOptions() {
    // cate nằm trong DeviceTree.channel.cate, nên lấy từ _devRows/_paramRows
    final set = <String>{'ALL'};
    final src = (_mode == 'BOX') ? const <_TblRow>[] : _devRows;
    for (final r in src) {
      final c = '${r.m['cate'] ?? ''}';
      if (c.isNotEmpty) set.add(c);
    }
    final list = set.toList()..sort();
    return list;
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '--';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  Future<void> _exportCsvToClipboard() async {
    final cols = _cols.map((e) => e.key).toList();
    final sb = StringBuffer();

    sb.writeln(cols.join(','));
    for (final r in _filteredRows) {
      final line = cols
          .map((k) {
            final v = r.m[k];
            if (v is DateTime) return _escapeCsv(_fmtTime(v));
            return _escapeCsv('$v');
          })
          .join(',');
      sb.writeln(line);
    }

    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('CSV copied to clipboard')));
    }
  }

  String _escapeCsv(String s) {
    final t = s.replaceAll('"', '""');
    if (t.contains(',') || t.contains('\n') || t.contains('"')) {
      return '"$t"';
    }
    return t;
  }

  void _openRowDetail(_TblRow row) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1729),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        final entries = row.m.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ROW DETAIL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: const Color(0xFF1B2A44).withOpacity(0.7),
                    ),
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      final v = e.value;
                      final txt = v is DateTime
                          ? _fmtTime(v)
                          : (v == null ? '--' : '$v');
                      return ListTile(
                        dense: true,
                        title: Text(
                          e.key,
                          style: const TextStyle(
                            color: Color(0xFF9FB2D6),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        subtitle: SelectableText(
                          txt,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.copy,
                            color: Color(0xFF9FB2D6),
                          ),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: txt));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Copied: ${e.key}')),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // first build safety
    _filteredRows = _filteredRows ?? _rowsByMode();
    _cols = _cols ?? _colsByMode();
    _ds = _ds ?? _ScadaDataSource(data: _filteredRows, columns: _cols);

    final facOptions = _facOptions();
    final cateOptions = _cateOptions();

    return SafeArea(
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0E1729),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1B2A44)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== TOP BAR =====
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'SCADA TABLE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      _pill(
                        'PARAM',
                        _mode == 'PARAM',
                        onTap: () {
                          setState(() {
                            _mode = 'PARAM';
                            _cateFilter = 'ALL';
                            _importantOnly = false;
                          });
                          _rebuildView();
                        },
                      ),
                      _pill(
                        'DEVICE',
                        _mode == 'DEVICE',
                        onTap: () {
                          setState(() {
                            _mode = 'DEVICE';
                            _importantOnly = false;
                          });
                          _rebuildView();
                        },
                      ),
                      _pill(
                        'BOX',
                        _mode == 'BOX',
                        onTap: () {
                          setState(() {
                            _mode = 'BOX';
                            _cateFilter = 'ALL';
                            _importantOnly = false;
                          });
                          _rebuildView();
                        },
                      ),

                      Text(
                        'Rows: ${_filteredRows.length}',
                        style: const TextStyle(color: Color(0xFF9FB2D6)),
                      ),

                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _exportCsvToClipboard,
                        icon: const Icon(Icons.table_view, size: 18),
                        label: const Text('Copy CSV'),
                      ),
                    ],
                  ),
                ),

                // ===== FILTER BAR =====
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 320,
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search everything...',
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
                              borderSide: const BorderSide(
                                color: Color(0xFF1B2A44),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF1B2A44),
                              ),
                            ),
                          ),
                        ),
                      ),

                      _drop<String>(
                        label: 'FAC',
                        value: _facFilter,
                        items: facOptions,
                        onChanged: (v) {
                          setState(() => _facFilter = v!);
                          _rebuildView();
                        },
                      ),

                      if (_mode != 'BOX')
                        _drop<String>(
                          label: 'CATE',
                          value: _cateFilter,
                          items: cateOptions,
                          onChanged: (v) {
                            setState(() => _cateFilter = v!);
                            _rebuildView();
                          },
                        ),

                      if (_mode == 'PARAM')
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: _importantOnly,
                              onChanged: (v) {
                                setState(() => _importantOnly = v);
                                _rebuildView();
                              },
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Important only',
                              style: TextStyle(color: Color(0xFF9FB2D6)),
                            ),
                          ],
                        ),

                      TextButton(
                        onPressed: () {
                          setState(() {
                            _searchCtrl.clear();
                            _facFilter = 'ALL';
                            _cateFilter = 'ALL';
                            _importantOnly = false;
                          });
                          _rebuildView();
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFF1B2A44)),

                // ===== GRID (FULL) =====
                Expanded(
                  child: Container(
                    color: const Color(0xFF0B1220),
                    child: SfDataGrid(
                      source: _ds,
                      allowSorting: true,
                      allowMultiColumnSorting: true,
                      columnWidthMode: ColumnWidthMode.none,
                      // dùng width từng cột
                      rowHeight: 42,
                      headerRowHeight: 44,
                      gridLinesVisibility: GridLinesVisibility.both,
                      headerGridLinesVisibility: GridLinesVisibility.both,
                      onCellTap: (details) {
                        // ignore header row
                        if (details.rowColumnIndex.rowIndex <= 0) return;
                        final rowIndex = details.rowColumnIndex.rowIndex - 1;
                        if (rowIndex < 0 || rowIndex >= _filteredRows.length) {
                          return;
                        }
                        _openRowDetail(_filteredRows[rowIndex]);
                      },
                      columns: _cols
                          .map(
                            (c) => GridColumn(
                              columnName: c.key,
                              width: c.w,
                              label: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
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
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, bool active, {VoidCallback? onTap}) {
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

  Widget _drop<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1B2A44)),
      ),
      child: DropdownButton<T>(
        dropdownColor: const Color(0xFF0E1729),
        value: value,
        underline: const SizedBox.shrink(),
        iconEnabledColor: const Color(0xFF9FB2D6),
        items: items
            .map(
              (e) => DropdownMenuItem<T>(
                value: e,
                child: Text(
                  '$label: $e',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  // ===== FLATTEN =====

  List<_TblRow> _flattenBoxes(List<FacTree> facs) {
    final out = <_TblRow>[];
    for (final fac in facs) {
      for (final bt in fac.boxes) {
        final b = bt.box;
        out.add(
          _TblRow({
            'fac': fac.facId,
            'scadaId': b.scadaId,
            'plcIp': b.plcIp,
            'plcPort': b.plcPort,
            'wlan': b.wlan ?? '',
          }),
        );
      }
    }
    return out;
  }

  List<_TblRow> _flattenDevices(List<FacTree> facs) {
    final out = <_TblRow>[];
    for (final fac in facs) {
      for (final bt in fac.boxes) {
        final b = bt.box;
        for (final dt in bt.devices) {
          final c = dt.channel;
          out.add(
            _TblRow({
              'fac': fac.facId,
              'scadaId': b.scadaId,
              'cate': c.cate,
              'boxDeviceId': c.boxDeviceId,
              'boxId': c.boxId,
            }),
          );
        }
      }
    }
    return out;
  }

  List<_TblRow> _flattenParams(List<FacTree> facs) {
    final out = <_TblRow>[];
    for (final fac in facs) {
      for (final bt in fac.boxes) {
        final b = bt.box;
        for (final dt in bt.devices) {
          final c = dt.channel;
          for (final pn in dt.params) {
            final m = pn.master;
            final h = pn.latest;
            out.add(
              _TblRow({
                'fac': fac.facId,
                'scadaId': b.scadaId,
                'cate': c.cate,
                'boxDeviceId': c.boxDeviceId,
                'boxId': c.boxId,
                'nameEn': m.nameEn,
                'plcAddress': m.plcAddress,
                'unit': m.unit,
                'valueType': '${m.valueType}',
                'important': (m.isImportant == true) ? 'Y' : '',
                'latestValue': h?.value ?? '',
                'recordedAt': h?.recordedAt, // DateTime?
              }),
            );
          }
        }
      }
    }
    return out;
  }
}

// ===== definitions =====

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
  final List<_TblRow> data; // ✅ đổi tên, KHÔNG dùng "rows"
  final List<_ColDef> columns;

  _ScadaDataSource({required this.data, required this.columns}) {
    _build();
  }

  late List<DataGridRow> _gridRows;

  void _build() {
    _gridRows = data.map((r) {
      return DataGridRow(
        cells: columns.map((c) {
          final v = r.m[c.key];
          return DataGridCell<dynamic>(columnName: c.key, value: v);
        }).toList(),
      );
    }).toList();
  }

  @override
  List<DataGridRow> get rows => _gridRows; // ✅ đúng kiểu trả về

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
          txt =
              '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')} '
              '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}:${v.second.toString().padLeft(2, '0')}';
        } else {
          txt = v == null ? '--' : '$v';
        }

        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            txt,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF9FB2D6),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        );
      }).toList(),
    );
  }
}
