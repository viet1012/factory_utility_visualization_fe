import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/widgets/chart_state_widgets.dart';
import '../controllers/signal_health_matrix_controller.dart';
import '../signal_health_style.dart';
import '../utils/signal_health_utils.dart';
import '../widgets/signal_health_detail_panel.dart';
import '../widgets/signal_health_error_summary.dart';
import '../widgets/signal_health_filter_row.dart';
import '../widgets/signal_health_header.dart';
import '../widgets/signal_health_kpi_row.dart';
import '../widgets/signal_health_matrix_table.dart';

typedef _SignalHealthRemoteState = ({
  List<Map<String, dynamic>> data,
  bool loading,
  bool refreshing,
  Object? error,
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

  Widget _body(_SignalHealthRemoteState state) {
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
          SignalHealthHeader(
            lastUpdated: state.refreshing
                ? 'Refreshing...'
                : _lastUpdated(data),
            onRefresh: context.read<SignalHealthMatrixController>().refresh,
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
      ),
      builder: (_, state, _) {
        return Scaffold(backgroundColor: kBg, body: _body(state));
      },
    );
  }
}
