import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../catalog_view_models.dart';

class CatalogSignalDetail extends StatelessWidget {
  final CatalogDeviceGroup? device;
  final CatalogDataSource dataSource;

  /// Dang hien thi ket qua loc toan cuc thay vi mot device.
  final bool globalMode;

  /// Cac dong dang hien thi, dung de tinh badge trong global mode.
  final List<CatalogTableRow> rows;

  const CatalogSignalDetail({
    required this.device,
    required this.dataSource,
    this.globalMode = false,
    this.rows = const <CatalogTableRow>[],
  });

  @override
  Widget build(BuildContext context) {
    final selectedDevice = device;

    if (!globalMode && selectedDevice == null) {
      return const _NoDeviceSelected();
    }

    final now = DateTime.now();

    final signalCount = globalMode ? rows.length : selectedDevice!.signalCount;

    final onlineCount = globalMode
        ? rows.where((row) => !row.isStaleAt(now)).length
        : selectedDevice!.onlineCount;

    final staleCount = globalMode
        ? rows.where((row) => row.isStaleAt(now)).length
        : selectedDevice!.staleCount;

    final titleText = globalMode
        ? 'FILTER RESULTS'
        : selectedDevice!.boxDeviceId;

    final subtitleText = globalMode
        ? 'All matching signals across facilities'
        : '${selectedDevice!.facility}'
              '  •  ${selectedDevice.category}'
              '  •  ${selectedDevice.scadaId}'
              '  •  ${selectedDevice.boxId}';

    final isEmpty = globalMode ? rows.isEmpty : selectedDevice!.signals.isEmpty;

    return Container(
      color: const Color(0xFF07111F),
      child: Column(
        children: [
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF0D1B2B),
              border: Border(bottom: BorderSide(color: Color(0xFF20344D))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF7F94AD),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _DetailBadge(
                  label: '$signalCount Signals',
                  color: const Color(0xFF60A5FA),
                ),
                const SizedBox(width: 7),
                _DetailBadge(
                  label: '$onlineCount Online',
                  color: const Color(0xFF4ADE80),
                ),
                const SizedBox(width: 7),
                _DetailBadge(
                  label: '$staleCount Stale',
                  color: Colors.orangeAccent,
                ),
              ],
            ),
          ),
          Expanded(
            child: isEmpty
                ? const _CatalogEmptyState()
                : CatalogSignalGrid(source: dataSource, globalMode: globalMode),
          ),
        ],
      ),
    );
  }
}

class CatalogSignalGrid extends StatelessWidget {
  final CatalogDataSource source;

  /// Trong global mode can them cot nguon goc de phan biet cac device.
  final bool globalMode;

  const CatalogSignalGrid({required this.source, this.globalMode = false});

  @override
  Widget build(BuildContext context) {
    return SfDataGrid(
      source: source,
      allowSorting: true,
      allowMultiColumnSorting: true,
      rowHeight: 56,
      headerRowHeight: 46,
      /*
       * Normal mode: dong bang PLC (cot dau tien).
       * Global mode: dong bang ca khoi nguon goc SCADA + BOX + DEVICE
       * de van biet moi dong thuoc thiet bi nao khi cuon ngang.
       */
      frozenColumnsCount: globalMode ? 3 : 1,
      columnWidthMode: ColumnWidthMode.none,
      gridLinesVisibility: GridLinesVisibility.horizontal,
      headerGridLinesVisibility: GridLinesVisibility.both,
      horizontalScrollPhysics: const ClampingScrollPhysics(),
      verticalScrollPhysics: const ClampingScrollPhysics(),
      columns: [
        if (globalMode) ...[
          GridColumn(
            columnName: 'scadaId',
            width: 150,
            label: const _GridHeader(label: 'SCADA'),
          ),
          GridColumn(
            columnName: 'boxId',
            width: 150,
            label: const _GridHeader(label: 'BOX'),
          ),
          GridColumn(
            columnName: 'boxDeviceId',
            width: 180,
            label: const _GridHeader(label: 'DEVICE'),
          ),
        ],
        GridColumn(
          columnName: 'plcAddress',
          width: 110,
          label: const _GridHeader(label: 'PLC'),
        ),
        GridColumn(
          columnName: 'signalName',
          width: 360,
          label: const _GridHeader(label: 'SIGNAL'),
        ),
        GridColumn(
          columnName: 'value',
          width: 155,
          label: const _GridHeader(label: 'VALUE'),
        ),
        GridColumn(
          columnName: 'updated',
          width: 180,
          label: const _GridHeader(label: 'UPDATED'),
        ),
        GridColumn(
          columnName: 'status',
          width: 110,
          label: const _GridHeader(label: 'STATUS'),
        ),
      ],
    );
  }
}

class _DetailBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _DetailBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
// ============================================================
// DATA GRID
// ============================================================

class _GridHeader extends StatelessWidget {
  final String label;

  const _GridHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF16253A),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFB7C8DE),
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: .55,
        ),
      ),
    );
  }
}

// ============================================================
// DATA SOURCE
// ============================================================

class CatalogDataSource extends DataGridSource {
  final List<CatalogTableRow> rowsData;

  /// Co them cot SCADA / BOX / DEVICE hay khong.
  final bool globalMode;

  late final List<DataGridRow> _rows;

  final Map<DataGridRow, CatalogTableRow> _modelByGridRow =
      <DataGridRow, CatalogTableRow>{};

  CatalogDataSource({
    required List<CatalogTableRow> rows,
    this.globalMode = false,
  }) : rowsData = List<CatalogTableRow>.unmodifiable(rows) {
    _rows = rowsData.map(_createGridRow).toList(growable: false);
  }

  DataGridRow _createGridRow(CatalogTableRow model) {
    final gridRow = DataGridRow(
      cells: [
        if (globalMode) ...[
          DataGridCell<String>(columnName: 'scadaId', value: model.scadaId),
          DataGridCell<String>(columnName: 'boxId', value: model.boxId),
          DataGridCell<String>(
            columnName: 'boxDeviceId',
            value: model.boxDeviceId,
          ),
        ],
        DataGridCell<String>(columnName: 'plcAddress', value: model.plcAddress),
        DataGridCell<String>(
          columnName: 'signalName',
          value: model.displaySignalName,
        ),
        DataGridCell<double>(
          columnName: 'value',
          value: model.value ?? double.negativeInfinity,
        ),
        DataGridCell<int>(
          columnName: 'updated',
          value: model.recordedAt?.millisecondsSinceEpoch ?? -1,
        ),
        DataGridCell<int>(columnName: 'status', value: model.isStale ? 1 : 0),
      ],
    );

    _modelByGridRow[gridRow] = model;

    return gridRow;
  }

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow gridRow) {
    final model = _modelByGridRow[gridRow];

    if (model == null) {
      return DataGridRowAdapter(
        cells: gridRow
            .getCells()
            .map((cell) => _textCell(cell.value?.toString() ?? '--'))
            .toList(growable: false),
      );
    }

    final index = _rows.indexOf(gridRow);

    final background = index.isEven
        ? const Color(0xFF081321)
        : const Color(0xFF0B1728);

    return DataGridRowAdapter(
      color: background,
      cells: gridRow
          .getCells()
          .map((cell) {
            switch (cell.columnName) {
              case 'scadaId':
                return _textCell(model.scadaId);

              case 'boxId':
                return _textCell(model.boxId);

              case 'boxDeviceId':
                return _textCell(model.boxDeviceId);

              case 'plcAddress':
                return _plcCell(model);

              case 'signalName':
                return _signalCell(model);

              case 'value':
                return _valueCell(model);

              case 'updated':
                return _updatedCell(model);

              case 'status':
                return _statusCell(model);

              default:
                return _textCell(cell.value?.toString() ?? '--');
            }
          })
          .toList(growable: false),
    );
  }

  Widget _textCell(String text) {
    final displayText = text.trim().isEmpty ? '--' : text.trim();

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        displayText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFC6D4E5),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _plcCell(CatalogTableRow row) {
    final style = _categoryStyle(row.category);

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: style.color.withOpacity(.08),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: style.color.withOpacity(.18)),
        ),
        child: Text(
          row.plcAddress.trim().isEmpty ? '--' : row.plcAddress.trim(),
          style: TextStyle(
            color: style.color,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _signalCell(CatalogTableRow row) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.displaySignalName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (row.cateId.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                row.cateId.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6F859F),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _valueCell(CatalogTableRow row) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        row.displayValue,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: row.isStale ? Colors.orangeAccent : const Color(0xFF4ADE80),
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _updatedCell(CatalogTableRow row) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        row.displayTime,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF9AAEC5),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statusCell(CatalogTableRow row) {
    final color = row.isStale ? Colors.orangeAccent : const Color(0xFF4ADE80);

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(.09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              row.statusLabel.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _CategoryVisualStyle _categoryStyle(String category) {
    final value = category.trim().toUpperCase();

    if (value.contains('ELECTRIC')) {
      return const _CategoryVisualStyle(
        color: Color(0xFFFBBF24),
        icon: Icons.bolt_rounded,
      );
    }

    if (value.contains('WATER')) {
      return const _CategoryVisualStyle(
        color: Color(0xFF22D3EE),
        icon: Icons.water_drop_rounded,
      );
    }

    if (value.contains('AIR') || value.contains('COMPRESSED')) {
      return const _CategoryVisualStyle(
        color: Color(0xFFA78BFA),
        icon: Icons.air_rounded,
      );
    }

    return const _CategoryVisualStyle(
      color: Color(0xFF94A3B8),
      icon: Icons.category_rounded,
    );
  }
}

class _CategoryVisualStyle {
  final Color color;
  final IconData icon;

  const _CategoryVisualStyle({required this.color, required this.icon});
}

class _NoDeviceSelected extends StatelessWidget {
  const _NoDeviceSelected();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded, color: Color(0xFF526A84), size: 44),
          SizedBox(height: 12),
          Text(
            'Select a device',
            style: TextStyle(
              color: Color(0xFFB7C8DE),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Signals will appear here',
            style: TextStyle(color: Color(0xFF71869F), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _CatalogEmptyState extends StatelessWidget {
  const _CatalogEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.table_rows_outlined,
            color: Colors.white.withOpacity(.28),
            size: 52,
          ),
          const SizedBox(height: 12),
          Text(
            'No utility signals found',
            style: TextStyle(
              color: Colors.white.withOpacity(.66),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Try changing or clearing the filters',
            style: TextStyle(
              color: Colors.white.withOpacity(.38),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
