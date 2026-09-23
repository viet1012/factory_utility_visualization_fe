import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/widgets/chart_state_widgets.dart';
import '../api/signal_health_history_api.dart';
import '../controllers/signal_health_history_controller.dart';
import '../controllers/signal_health_matrix_controller.dart';
import '../signal_health_style.dart';
import '../utils/signal_health_utils.dart';
import '../widgets/history/signal_health_history_panel.dart';
import '../widgets/signal_health_detail_panel.dart';
import '../widgets/signal_health_error_summary.dart';
import '../widgets/signal_health_filter_row.dart';
import '../widgets/signal_health_header.dart';
import '../widgets/signal_health_kpi_row.dart';
import '../widgets/signal_health_matrix_table.dart';

/// Which dataset the screen is showing.
///
/// CURRENT keeps the original realtime matrix untouched; HISTORY swaps the body
/// for the hourly history panel. The two never render at the same time.
enum SignalHealthViewMode { current, history }

typedef _SignalHealthRemoteState = ({
  List<Map<String, dynamic>> data,
  bool loading,
  bool refreshing,
  Object? error,
  bool exporting,
});

class SignalHealthMatrixScreen extends StatefulWidget {
  final bool isActive;

  const SignalHealthMatrixScreen({super.key, required this.isActive});

  @override
  State<SignalHealthMatrixScreen> createState() =>
      _SignalHealthMatrixScreenState();
}

class _SignalHealthMatrixScreenState extends State<SignalHealthMatrixScreen> {
  String facFilter = 'ALL';
  String cateFilter = 'ALL';
  String scadaFilter = 'ALL';
  String boxDeviceFilter = 'ALL';
  String keyword = '';
  String? selectedErrorKey;
  String? selectedBoxDeviceId;

  Map<String, dynamic>? selected;

  // ============================================================
  // MODE / HISTORY LIFECYCLE
  // ============================================================

  SignalHealthViewMode _mode = SignalHealthViewMode.current;

  /*
   * History controller duoc so huu boi chinh screen nay.
   *
   * Ly do: chi man hinh nay dung du lieu history, va no KHONG duoc dang ky
   * vao PollingCoordinator - history chi fetch khi HISTORY duoc kich hoat,
   * khi doi filter, hoac khi nguoi dung bam Refresh.
   *
   * Realtime polling cua CURRENT van do SignalHealthMatrixController o
   * MultiProvider cap tren quan ly, khong bi anh huong.
   */
  late final SignalHealthHistoryController _historyController;

  @override
  void initState() {
    super.initState();

    _historyController = SignalHealthHistoryController(
      SignalHealthHistoryApi(),
    );
  }

  @override
  void didUpdateWidget(covariant SignalHealthMatrixScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Quay lai tab khi dang o HISTORY: nap lai neu filter chua tung load.
    if (!oldWidget.isActive &&
        widget.isActive &&
        _mode == SignalHealthViewMode.history) {
      _historyController.ensureLoaded();
    }
  }

  @override
  void dispose() {
    _historyController.dispose();

    super.dispose();
  }

  void _setMode(SignalHealthViewMode next) {
    if (_mode == next) return;

    setState(() {
      _mode = next;
    });

    // Fetch lan dau khi HISTORY tro thanh active.
    if (next == SignalHealthViewMode.history) {
      _historyController.ensureLoaded();
    }
  }

  Map<String, dynamic>? _findSelectedDevice(
    List<Map<String, dynamic>> data,
    String? oldBoxDeviceId,
  ) {
    if (data.isEmpty) return null;

    if (oldBoxDeviceId != null) {
      for (final row in data) {
        if ('${row['boxDeviceId']}' == oldBoxDeviceId) {
          return row;
        }
      }
    }

    return data.first;
  }

  List<Map<String, dynamic>> _filteredData(List<Map<String, dynamic>> data) {
    return data.where((e) {
      final facOk = facFilter == 'ALL' || e['fac'] == facFilter;

      final cateOk = cateFilter == 'ALL' || e['cate'] == cateFilter;

      final scadaOk = scadaFilter == 'ALL' || e['scadaId'] == scadaFilter;

      final boxOk =
          boxDeviceFilter == 'ALL' || e['boxDeviceId'] == boxDeviceFilter;

      final text = keyword.toLowerCase();

      final searchOk =
          text.isEmpty ||
          '${e['fac']}'.toLowerCase().contains(text) ||
          '${e['cate']}'.toLowerCase().contains(text) ||
          '${e['scadaId']}'.toLowerCase().contains(text) ||
          '${e['boxDeviceId']}'.toLowerCase().contains(text);

      return facOk && cateOk && scadaOk && boxOk && searchOk;
    }).toList();
  }

  List<String> _facOptions(List<Map<String, dynamic>> data) => [
    'ALL',
    ...data.map((e) => '${e['fac']}').toSet(),
  ];

  List<String> _cateOptions(List<Map<String, dynamic>> data) => [
    'ALL',
    ...data.map((e) => '${e['cate']}').toSet(),
  ];

  List<String> _scadaOptions(List<Map<String, dynamic>> data) => [
    'ALL',
    ...data.map((e) => '${e['scadaId']}').toSet(),
  ];

  List<String> _boxDeviceOptions(List<Map<String, dynamic>> data) => [
    'ALL',
    ...data.map((e) => '${e['boxDeviceId']}').toSet(),
  ];

  String _lastUpdated(List<Map<String, dynamic>> data) {
    String latest = '-';

    for (final device in data) {
      for (final signal in device['signals'] ?? []) {
        final time = '${signal['recordedAt'] ?? ''}';
        if (time.isNotEmpty && (latest == '-' || time.compareTo(latest) > 0)) {
          latest = time;
        }
      }
    }

    return latest;
  }

  /// Clears the Error Summary quick filters without touching the toolbar
  /// dropdowns or the search keyword.
  void _clearQuickFilters() {
    selectedErrorKey = null;
    selectedBoxDeviceId = null;
  }

  /// Runs the export and surfaces the outcome without blocking the screen.
  ///
  /// All download/API work lives in the controller: the screen only wires the
  /// callback and reports the result.
  Future<void> _handleExport() async {
    final controller = context.read<SignalHealthMatrixController>();

    final success = await controller.exportExcel();

    if (!mounted) return;

    // Chỉ báo lỗi export, không đụng tới lỗi tải ma trận.
    if (success) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 3),
          content: Text('Excel export failed. Please try again.'),
        ),
      );
  }

  /// Dispatches to the active mode. CURRENT keeps its original code path
  /// untouched; HISTORY renders the history panel instead.
  Widget _body(_SignalHealthRemoteState state) {
    return switch (_mode) {
      SignalHealthViewMode.current => _currentBody(state),
      SignalHealthViewMode.history => _historyBody(state),
    };
  }

  /// HISTORY mode.
  ///
  /// Reuses the CURRENT dataset only to populate the facet dropdown options, so
  /// both modes offer the same Facility/Category/SCADA/Device vocabulary. All
  /// history data, aggregation and fetching live in the history controller,
  /// panel and utils.
  Widget _historyBody(_SignalHealthRemoteState state) {
    final data = state.data;

    List<String> withoutAll(List<String> options) {
      return options
          .where((value) => value != 'ALL' && value.trim().isNotEmpty)
          .toList(growable: false);
    }

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          _modeHeader(),
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedBuilder(
              animation: _historyController,
              builder: (context, _) {
                return SignalHealthHistoryPanel(
                  controller: _historyController,
                  facOptions: withoutAll(_facOptions(data)),
                  cateOptions: withoutAll(_cateOptions(data)),
                  scadaOptions: withoutAll(_scadaOptions(data)),
                  boxDeviceOptions: withoutAll(_boxDeviceOptions(data)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Compact header for HISTORY mode: title, last-loaded stamp, mode switch.
  Widget _modeHeader() {
    return AnimatedBuilder(
      animation: _historyController,
      builder: (context, _) {
        final loadedAt = _historyController.lastLoadedAt;

        return Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: kBlue.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: kBlue.withValues(alpha: .35)),
              ),
              child: const Icon(Icons.history_rounded, color: kBlue, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Signal Health History',
              style: TextStyle(
                fontSize: 20,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: kText,
              ),
            ),
            const Spacer(),
            Text(
              loadedAt == null
                  ? 'Not loaded yet'
                  : 'Loaded: ${_formatClock(loadedAt)}',
              style: const TextStyle(fontSize: 11, color: kSubText),
            ),
            const SizedBox(width: 10),
            _ModeSwitch(value: _mode, onChanged: _setMode),
          ],
        );
      },
    );
  }

  static String _formatClock(DateTime value) {
    final local = value.toLocal();

    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  /// CURRENT mode: the original realtime matrix, unchanged.
  Widget _currentBody(_SignalHealthRemoteState state) {
    final data = state.data;
    final filteredRows = _filteredData(data);
    final errorSummary = buildErrorSummary(filteredRows);
    final boxIssueSummary = buildBoxIssueSummary(filteredRows);
    final visibleRows = applyErrorSummaryFilter(filteredRows, selectedErrorKey);

    // A box chosen from the Box-with-issues row wins over the previous
    // selection, but only while it is still inside the visible scope.
    final preferredBoxDeviceId =
        selectedBoxDeviceId ?? selected?['boxDeviceId']?.toString();
    selected = _findSelectedDevice(visibleRows, preferredBoxDeviceId);

    if (state.loading && data.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (state.error != null && data.isEmpty) {
      return ChartApiErrorState(
        color: Colors.redAccent,
        onRetry: context.read<SignalHealthMatrixController>().refresh,
      );
    }

    if (data.isEmpty) {
      return const EmptyChartState(
        title: 'No Signal Health Data',
        message: 'No signal health matrix data found.',
      );
    }

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          /*
           * Mode switch dat canh header goc. SignalHealthHeader giu nguyen
           * khong doi, nen toan bo UI/behaviour cua CURRENT khong thay doi.
           */
          Row(
            children: [
              Expanded(
                child: SignalHealthHeader(
                  lastUpdated: state.refreshing
                      ? 'Refreshing...'
                      : _lastUpdated(data),
                  onRefresh: context
                      .read<SignalHealthMatrixController>()
                      .refresh,
                  onExport: _handleExport,
                  exporting: state.exporting,
                ),
              ),
              const SizedBox(width: 10),
              _ModeSwitch(value: _mode, onChanged: _setMode),
            ],
          ),
          const SizedBox(height: 4),
          SignalHealthKpiRow(
            totalFac: filteredRows.map((e) => e['fac']).toSet().length,
            totalBoxDevice: filteredRows.length,
            totalRegister: filteredRows.fold(
              0,
              (sum, e) => sum + ((e['totalRegisters'] ?? 0) as num).toInt(),
            ),
            totalNgRegister: filteredRows.fold(
              0,
              (sum, e) => sum + ((e['ngRegisters'] ?? 0) as num).toInt(),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 18,
                  child: Column(
                    children: [
                      SignalHealthFilterRow(
                        facOptions: _facOptions(data),
                        cateOptions: _cateOptions(data),
                        scadaOptions: _scadaOptions(data),
                        boxDeviceOptions: _boxDeviceOptions(data),
                        facValue: facFilter,
                        cateValue: cateFilter,
                        scadaValue: scadaFilter,
                        boxDeviceValue: boxDeviceFilter,
                        onFacChanged: (v) => setState(() {
                          facFilter = v!;
                          _clearQuickFilters();
                        }),
                        onCateChanged: (v) => setState(() {
                          cateFilter = v!;
                          _clearQuickFilters();
                        }),
                        onScadaChanged: (v) => setState(() {
                          scadaFilter = v!;
                          _clearQuickFilters();
                        }),
                        onBoxDeviceChanged: (v) => setState(() {
                          boxDeviceFilter = v!;
                          _clearQuickFilters();
                        }),
                        onSearchChanged: (v) => setState(() {
                          keyword = v;
                          _clearQuickFilters();
                        }),
                      ),
                      const SizedBox(height: 6),
                      SignalHealthErrorSummary(
                        items: errorSummary,
                        boxItems: boxIssueSummary,
                        selectedErrorKey: selectedErrorKey,
                        selectedBoxDeviceId: selectedBoxDeviceId,
                        onSelected: (errorKey) {
                          setState(() {
                            selectedErrorKey = selectedErrorKey == errorKey
                                ? null
                                : errorKey;
                            selectedBoxDeviceId = null;
                          });
                        },
                        onBoxSelected: (boxDeviceId) {
                          setState(() {
                            if (selectedBoxDeviceId == boxDeviceId) {
                              selectedBoxDeviceId = null;
                              return;
                            }

                            selectedBoxDeviceId = boxDeviceId;
                            selectedErrorKey = null;
                          });
                        },
                        onClear: () {
                          setState(_clearQuickFilters);
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SignalHealthMatrixTable(
                          data: visibleRows,
                          selected: selected,
                          onSelect: (item) {
                            setState(() {
                              selected = item;
                              selectedBoxDeviceId =
                                  '${item['boxDeviceId'] ?? ''}'.trim();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 10,
                  child: selected == null
                      ? const SizedBox()
                      : SignalHealthDetailPanel(device: selected!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Selector<SignalHealthMatrixController, _SignalHealthRemoteState>(
      selector: (_, controller) => (
        data: controller.data,
        loading: controller.loading,
        refreshing: controller.refreshing,
        error: controller.error,
        exporting: controller.exporting,
      ),
      builder: (_, state, _) {
        return Scaffold(backgroundColor: kBg, body: _body(state));
      },
    );
  }
}

/// CURRENT | HISTORY segmented switch.
///
/// Presentation only: the screen owns the mode and decides what a change means.
class _ModeSwitch extends StatelessWidget {
  final SignalHealthViewMode value;
  final ValueChanged<SignalHealthViewMode> onChanged;

  const _ModeSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeButton(
            label: 'Current',
            icon: Icons.sensors_rounded,
            selected: value == SignalHealthViewMode.current,
            onTap: () => onChanged(SignalHealthViewMode.current),
          ),
          const SizedBox(width: 3),
          _ModeButton(
            label: 'History',
            icon: Icons.history_rounded,
            selected: value == SignalHealthViewMode.history,
            onTap: () => onChanged(SignalHealthViewMode.history),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        height: 30,
        decoration: BoxDecoration(
          color: selected ? kBlue.withValues(alpha: .20) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? kBlue.withValues(alpha: .55) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: selected ? kBlue : kSubText),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? kBlue : kSubText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
