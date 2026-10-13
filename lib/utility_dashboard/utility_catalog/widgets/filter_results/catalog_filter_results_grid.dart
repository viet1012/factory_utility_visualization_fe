import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../shared/polling/polling_coordinator.dart';
import '../../../shared/polling/polling_scope.dart';
import '../../catalog_view_models.dart';
import '../../providers/filter_sparkline_controller.dart';
import '../signal_chart/signal_chart_palette.dart';
import 'filter_result_cells.dart';

/// Bang Filter results: moi signal cua cac device tren TRANG HIEN TAI.
///
/// Cot: [SCADA] | BOX / DEVICE | PLC | SIGNAL | VALUE | 1h | UPDATED | STATUS.
/// SCADA bi an khi moi dong cung mot SCADA (header ket qua da ghi SCADA).
///
/// Lich su 1h (sparkline, kind, nguong) chi tai cho cac device co dong dang
/// nam trong khung nhin (theo vi tri cuon, debounce [_viewportDebounce]).
/// VALUE / UPDATED / STATUS van cap nhat theo polling qua [rows].
class CatalogFilterResultsGrid extends StatefulWidget {
  final List<CatalogTableRow> rows;
  final bool showScada;

  const CatalogFilterResultsGrid({
    super.key,
    required this.rows,
    required this.showScada,
  });

  @override
  State<CatalogFilterResultsGrid> createState() =>
      _CatalogFilterResultsGridState();
}

class _CatalogFilterResultsGridState extends State<CatalogFilterResultsGrid> {
  static const double _rowHeight = 58;
  static const double _headerHeight = 46;
  static const Duration _viewportDebounce = Duration(milliseconds: 300);

  final ScrollController _verticalController = ScrollController();

  late _FilterResultsSource _source;

  /// Giu tham chieu de dispose khong phai tra cuu context.
  late final FilterSparklineController _sparklines;
  late final PollingCoordinator _coordinator;

  Timer? _viewportTimer;

  /// Chieu cao vung dong (khi ScrollController chua gan vao grid).
  double _bodyHeight = 0;

  @override
  void initState() {
    super.initState();

    _sparklines = context.read<FilterSparklineController>();

    // Nhip lam moi 30s chi chay khi bang that su hien (cung gating voi
    // polling cua tab SCADA TABLE).
    _coordinator = context.read<PollingCoordinator>();
    _coordinator.activity.addListener(_syncOnScreen);
    _syncOnScreen();

    _source = _FilterResultsSource(
      rows: widget.rows,
      showScada: widget.showScada,
    );

    _verticalController.addListener(_scheduleViewportSync);

    // Lan dau: doi grid layout xong roi moi tinh khung nhin.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncViewport());
  }

  @override
  void didUpdateWidget(covariant CatalogFilterResultsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (identical(oldWidget.rows, widget.rows) &&
        oldWidget.showScada == widget.showScada) {
      return;
    }

    /*
     * Polling tao danh sach dong moi: dung lai source nhung giu thu tu sort
     * nguoi dung da chon, de cac dong khong nhay vi tri sau moi lan cap nhat.
     */
    final sorted = List<SortColumnDetails>.from(_source.sortedColumns);

    _source = _FilterResultsSource(
      rows: widget.rows,
      showScada: widget.showScada,
    );

    if (sorted.isNotEmpty) {
      _source.sortedColumns.addAll(
        sorted.where(
          (column) => widget.showScada || column.name != 'scadaId',
        ),
      );
      _source.sort();
    }

    _scheduleViewportSync();
  }

  void _syncOnScreen() {
    _sparklines.setOnScreen(
      _coordinator.isScopeActive(PollingScope.scadaTable),
    );
  }

  void _scheduleViewportSync() {
    _viewportTimer?.cancel();
    _viewportTimer = Timer(_viewportDebounce, _syncViewport);
  }

  /// Device co it nhat mot dong trong khung nhin hien tai.
  void _syncViewport() {
    if (!mounted) return;

    final rows = _source.effectiveRows;

    double offset = 0;
    double viewport = _bodyHeight;

    if (_verticalController.hasClients) {
      final position = _verticalController.position;
      offset = position.pixels;
      if (position.hasViewportDimension) viewport = position.viewportDimension;
    }

    final devices = <String, List<String>>{};

    if (rows.isNotEmpty && viewport > 0) {
      final first = (offset / _rowHeight).floor().clamp(0, rows.length - 1);
      final last = ((offset + viewport) / _rowHeight).ceil().clamp(
        0,
        rows.length - 1,
      );

      for (var i = first; i <= last; i++) {
        final model = _source.modelOf(rows[i]);
        if (model == null) continue;

        // Gui moi signal cua device (khong chi dong dang thay) de 1 request
        // du cho ca device va cache dung lai khi cuon.
        devices.putIfAbsent(
          model.row.deviceKey,
          () => _source.signalIdsOf(model.row.deviceKey),
        );
      }
    }

    _sparklines.syncVisible([
      for (final entry in devices.entries)
        SparklineDeviceRequest(deviceKey: entry.key, signalIds: entry.value),
    ]);
  }

  @override
  void dispose() {
    _viewportTimer?.cancel();
    _coordinator.activity.removeListener(_syncOnScreen);
    _verticalController.removeListener(_scheduleViewportSync);
    _verticalController.dispose();

    // Bang bi go (sang Chart / bo filter): khong con dong nao trong khung
    // nhin -> huy request dang chay, dung lam moi sparkline. Cache van giu.
    _sparklines.syncVisible(const <SparklineDeviceRequest>[]);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showScada = widget.showScada;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bodyHeight = constraints.maxHeight - _headerHeight;

        // Doi kich thuoc (resize cua so) cung doi so dong nhin thay.
        if (bodyHeight != _bodyHeight) {
          _bodyHeight = bodyHeight;
          _scheduleViewportSync();
        }

        return SfDataGrid(
          source: _source,
          verticalScrollController: _verticalController,
          allowSorting: true,
          allowMultiColumnSorting: true,
          // Sort doi thu tu dong -> doi tap device trong khung nhin.
          onColumnSortChanged: (_, _) => _scheduleViewportSync(),
          rowHeight: _rowHeight,
          headerRowHeight: _headerHeight,
          // Dong bang khoi nguon goc (SCADA neu co + BOX / DEVICE).
          frozenColumnsCount: showScada ? 2 : 1,
          columnWidthMode: ColumnWidthMode.none,
          gridLinesVisibility: GridLinesVisibility.horizontal,
          headerGridLinesVisibility: GridLinesVisibility.both,
          horizontalScrollPhysics: const ClampingScrollPhysics(),
          verticalScrollPhysics: const ClampingScrollPhysics(),
          columns: [
            if (showScada)
              GridColumn(
                columnName: 'scadaId',
                width: 130,
                label: const _Header('SCADA'),
              ),
            GridColumn(
              columnName: 'device',
              width: 200,
              label: const _Header('BOX / DEVICE'),
            ),
            GridColumn(
              columnName: 'plcAddress',
              width: 96,
              label: const _Header('PLC'),
            ),
            GridColumn(
              columnName: 'signalName',
              width: 250,
              label: const _Header('SIGNAL'),
            ),
            GridColumn(
              columnName: 'value',
              width: 150,
              label: const _Header('VALUE'),
            ),
            GridColumn(
              columnName: 'spark',
              width: 130,
              allowSorting: false,
              label: const _Header('1h'),
            ),
            GridColumn(
              columnName: 'updated',
              width: 130,
              label: const _Header('UPDATED'),
            ),
            GridColumn(
              columnName: 'status',
              width: 80,
              label: const _Header('STATUS', center: true),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String label;
  final bool center;

  const _Header(this.label, {this.center = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: center ? Alignment.center : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF16253A),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFB7C8DE),
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: .55,
        ),
      ),
    );
  }
}

class _FilterResultsSource extends DataGridSource {
  final bool showScada;

  late final List<DataGridRow> _rows;

  final Map<DataGridRow, _RowModel> _models = <DataGridRow, _RowModel>{};

  /// deviceKey -> id moi signal cua device (theo thu tu dong goc).
  final Map<String, List<String>> _signalIdsByDevice = <String, List<String>>{};

  _FilterResultsSource({
    required List<CatalogTableRow> rows,
    required this.showScada,
  }) {
    _rows = [for (final row in rows) _createRow(row)];
  }

  _RowModel? modelOf(DataGridRow row) => _models[row];

  List<String> signalIdsOf(String deviceKey) {
    return List<String>.unmodifiable(
      _signalIdsByDevice[deviceKey] ?? const <String>[],
    );
  }

  DataGridRow _createRow(CatalogTableRow row) {
    final gridRow = DataGridRow(
      cells: [
        if (showScada)
          DataGridCell<String>(columnName: 'scadaId', value: row.scadaId),
        DataGridCell<String>(
          columnName: 'device',
          value: '${row.boxId}|${row.boxDeviceId}',
        ),
        DataGridCell<String>(columnName: 'plcAddress', value: row.plcAddress),
        DataGridCell<String>(
          columnName: 'signalName',
          value: row.displaySignalName,
        ),
        DataGridCell<double>(
          columnName: 'value',
          value: row.value ?? double.negativeInfinity,
        ),
        const DataGridCell<Object?>(columnName: 'spark', value: null),
        DataGridCell<int>(
          columnName: 'updated',
          value: row.recordedAt?.millisecondsSinceEpoch ?? -1,
        ),
        DataGridCell<int>(columnName: 'status', value: row.isStale ? 1 : 0),
      ],
    );

    final signalId = filterSignalIdOf(row);

    _models[gridRow] = _RowModel(row, signalId);
    _signalIdsByDevice
        .putIfAbsent(row.deviceKey, () => <String>[])
        .add(signalId);

    return gridRow;
  }

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow gridRow) {
    final model = _models[gridRow]!;
    final row = model.row;
    final now = DateTime.now();

    // Dong stale noi bat ca dong.
    final stale = row.isStaleAt(now);

    return DataGridRowAdapter(
      color: stale
          ? SignalChartColors.stale.withValues(alpha: .07)
          : const Color(0xFF081321),
      cells: [
        for (final cell in gridRow.getCells())
          switch (cell.columnName) {
            'scadaId' => _ScadaCell(row.scadaId),
            'device' => FilterDeviceCell(row: row),
            'plcAddress' => FilterPlcCell(row: row),
            'signalName' => FilterSignalCell(row: row),
            'value' => FilterValueCell(row: row, signalId: model.signalId),
            'spark' => FilterSparklineCell(
              row: row,
              signalId: model.signalId,
              deviceKey: row.deviceKey,
            ),
            'updated' => FilterUpdatedCell(row: row, now: now),
            'status' => FilterStatusDotCell(row: row, now: now),
            _ => const SizedBox.shrink(),
          },
      ],
    );
  }
}

class _RowModel {
  final CatalogTableRow row;
  final String signalId;

  const _RowModel(this.row, this.signalId);
}

class _ScadaCell extends StatelessWidget {
  final String scadaId;

  const _ScadaCell(this.scadaId);

  @override
  Widget build(BuildContext context) {
    final text = scadaId.trim().isEmpty ? '--' : scadaId.trim();

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Tooltip(
        message: text,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFC6D4E5),
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
