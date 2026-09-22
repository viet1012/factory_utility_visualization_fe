import 'package:factory_utility_visualization/utility_dashboard/shared/widgets/scada_tab_button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/widgets/chart_state_widgets.dart';
import '../controllers/signal_health_matrix_controller.dart';

const kBg = Color(0xff0f172a);
const kCard = Color(0xff111827);
const kCard2 = Color(0xff1e293b);
const kBorder = Color(0xff334155);
const kText = Color(0xfff8fafc);
const kSubText = Color(0xffcbd5e1);
const kBlue = Color(0xff38bdf8);
const kGreen = Color(0xff22c55e);
const kOrange = Color(0xfff97316);
const kRed = Color(0xffef4444);

typedef _SignalHealthRemoteState = ({
  List<Map<String, dynamic>> data,
  bool loading,
  bool refreshing,
  Object? error,
});

typedef _ErrorSummaryItem = ({
  String errorKey,
  String signalName,
  String parameterCode,
  String ruleType,
  int deviceCount,
});

typedef _BoxIssueItem = ({String boxDeviceId, int issueCount});

bool _isSignalNg(Map<String, dynamic> signal) {
  final status = '${signal['status'] ?? ''}'.trim().toUpperCase();
  return status.isNotEmpty && status != 'OK';
}

String _firstNonEmpty(Iterable<dynamic> values, {String fallback = ''}) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String _normalizeSignalName(String value) {
  return value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// Grouping key for the Error Summary.
///
/// Represents the logical signal / error type, never the physical PLC address:
/// two devices exposing the same signal on different addresses must merge into
/// a single summary item.
String _signalErrorKey(Map<String, dynamic> signal) {
  final code = _firstNonEmpty([signal['parameterCode'], signal['cateId']]);
  if (code.isNotEmpty) return _normalizeSignalName(code);

  return _normalizeSignalName(
    _firstNonEmpty([signal['signalName'], signal['nameEn'], signal['name']]),
  );
}

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

  List<_ErrorSummaryItem> _errorSummary(List<Map<String, dynamic>> rows) {
    final grouped = <String, _ErrorSummaryAccumulator>{};

    for (final device in rows) {
      final boxDeviceId = '${device['boxDeviceId'] ?? ''}'.trim();
      final rawSignals = device['signals'];
      if (rawSignals is! List) continue;

      for (final rawSignal in rawSignals) {
        if (rawSignal is! Map) continue;
        final signal = Map<String, dynamic>.from(rawSignal);
        if (!_isSignalNg(signal)) continue;

        final signalName = _firstNonEmpty([
          signal['signalName'],
          signal['nameEn'],
          signal['name'],
        ]);
        final parameterCode = _firstNonEmpty([
          signal['parameterCode'],
          signal['cateId'],
        ]);
        final ruleType = _firstNonEmpty([
          signal['ruleType'],
          signal['rule'],
          signal['errorType'],
          signal['status'],
        ], fallback: '-');
        final key = _signalErrorKey(signal);
        if (key.isEmpty) continue;

        final entry = grouped.putIfAbsent(
          key,
          () => _ErrorSummaryAccumulator(
            errorKey: key,
            signalName: signalName.isEmpty ? parameterCode : signalName,
            parameterCode: parameterCode,
            ruleType: ruleType,
          ),
        );
        if (boxDeviceId.isNotEmpty) {
          entry.boxDeviceIds.add(boxDeviceId);
        }
      }
    }

    final result = grouped.values
        .map(
          (entry) => (
            errorKey: entry.errorKey,
            signalName: entry.signalName,
            parameterCode: entry.parameterCode,
            ruleType: entry.ruleType,
            deviceCount: entry.boxDeviceIds.length,
          ),
        )
        .toList(growable: false);
    result.sort((a, b) {
      final countCompare = b.deviceCount.compareTo(a.deviceCount);
      if (countCompare != 0) return countCompare;
      return a.signalName.toLowerCase().compareTo(b.signalName.toLowerCase());
    });
    return result;
  }

  /// Counts abnormal signals per box device over the toolbar/search filtered
  /// rows, independent of any Error Type selection.
  List<_BoxIssueItem> _boxIssueSummary(List<Map<String, dynamic>> rows) {
    final counts = <String, int>{};

    for (final device in rows) {
      final boxDeviceId = '${device['boxDeviceId'] ?? ''}'.trim();
      if (boxDeviceId.isEmpty) continue;

      final rawSignals = device['signals'];
      if (rawSignals is! List) continue;

      var issueCount = 0;
      for (final rawSignal in rawSignals) {
        if (rawSignal is! Map) continue;
        if (_isSignalNg(Map<String, dynamic>.from(rawSignal))) issueCount++;
      }
      if (issueCount == 0) continue;

      counts[boxDeviceId] = (counts[boxDeviceId] ?? 0) + issueCount;
    }

    final result = counts.entries
        .map((e) => (boxDeviceId: e.key, issueCount: e.value))
        .toList();
    result.sort((a, b) {
      final countCompare = b.issueCount.compareTo(a.issueCount);
      if (countCompare != 0) return countCompare;
      return a.boxDeviceId.toLowerCase().compareTo(b.boxDeviceId.toLowerCase());
    });
    return result;
  }

  List<Map<String, dynamic>> _applyErrorSummaryFilter(
    List<Map<String, dynamic>> filteredRows,
  ) {
    final errorKey = selectedErrorKey;
    if (errorKey == null) return filteredRows;

    return filteredRows
        .where((device) {
          final rawSignals = device['signals'];
          if (rawSignals is! List) return false;

          return rawSignals.whereType<Map>().any((rawSignal) {
            final signal = Map<String, dynamic>.from(rawSignal);
            return _isSignalNg(signal) && _signalErrorKey(signal) == errorKey;
          });
        })
        .toList(growable: false);
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

  Widget _body(_SignalHealthRemoteState state) {
    final data = state.data;
    final filteredRows = _filteredData(data);
    final errorSummary = _errorSummary(filteredRows);
    final boxIssueSummary = _boxIssueSummary(filteredRows);
    final visibleRows = _applyErrorSummaryFilter(filteredRows);

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
          _Header(
            lastUpdated: state.refreshing
                ? 'Refreshing...'
                : _lastUpdated(data),
            onRefresh: context.read<SignalHealthMatrixController>().refresh,
          ),
          const SizedBox(height: 4),
          _KpiRow(
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
                      _FilterRow(
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
                          selectedErrorKey = null;
                          selectedBoxDeviceId = null;
                        }),
                        onCateChanged: (v) => setState(() {
                          cateFilter = v!;
                          selectedErrorKey = null;
                          selectedBoxDeviceId = null;
                        }),
                        onScadaChanged: (v) => setState(() {
                          scadaFilter = v!;
                          selectedErrorKey = null;
                          selectedBoxDeviceId = null;
                        }),
                        onBoxDeviceChanged: (v) => setState(() {
                          boxDeviceFilter = v!;
                          selectedErrorKey = null;
                          selectedBoxDeviceId = null;
                        }),
                        onSearchChanged: (v) => setState(() {
                          keyword = v;
                          selectedErrorKey = null;
                          selectedBoxDeviceId = null;
                        }),
                      ),
                      const SizedBox(height: 6),
                      _ErrorSummaryPanel(
                        items: errorSummary,
                        boxItems: boxIssueSummary,
                        selectedErrorKey: selectedErrorKey,
                        selectedBoxDeviceId: selectedBoxDeviceId,

                        onSelected: (errorKey) {
                          setState(() {
                            selectedErrorKey = selectedErrorKey == errorKey
                                ? null
                                : errorKey;

                            // nên clear box khi chọn error type
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

                        // thêm
                        onClear: () {
                          setState(() {
                            selectedErrorKey = null;
                            selectedBoxDeviceId = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _MatrixTable(
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
                      : _DetailPanel(device: selected!),
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

class _ErrorSummaryAccumulator {
  final String errorKey;
  final String signalName;
  final String parameterCode;
  final String ruleType;
  final Set<String> boxDeviceIds = <String>{};

  _ErrorSummaryAccumulator({
    required this.errorKey,
    required this.signalName,
    required this.parameterCode,
    required this.ruleType,
  });
}

class _ErrorSummaryPanel extends StatefulWidget {
  final List<_ErrorSummaryItem> items;
  final List<_BoxIssueItem> boxItems;
  final String? selectedErrorKey;
  final String? selectedBoxDeviceId;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onBoxSelected;
  final VoidCallback onClear;

  const _ErrorSummaryPanel({
    required this.items,
    required this.boxItems,
    required this.selectedErrorKey,
    required this.selectedBoxDeviceId,
    required this.onSelected,
    required this.onBoxSelected,

    // thêm
    required this.onClear,
  });
  @override
  State<_ErrorSummaryPanel> createState() => _ErrorSummaryPanelState();
}

class _ErrorSummaryPanelState extends State<_ErrorSummaryPanel> {
  final ScrollController _errorScrollController = ScrollController();
  final ScrollController _boxScrollController = ScrollController();

  @override
  void dispose() {
    _errorScrollController.dispose();
    _boxScrollController.dispose();
    super.dispose();
  }

  Widget _rowLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: kSubText,
        fontSize: 9.5,
        height: 1.0,
        fontWeight: FontWeight.w800,
        letterSpacing: .5,
      ),
    );
  }

  Widget _emptyRow(String message) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        message,
        style: const TextStyle(color: kSubText, fontSize: 11),
      ),
    );
  }

  Widget _chipRow({
    required ScrollController controller,
    required int itemCount,
    required Widget Function(int index) itemBuilder,
  }) {
    return ScrollbarTheme(
      data: const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(Color(0xff00E5FF)),
        trackColor: WidgetStatePropertyAll(Color(0xff1e293b)),
        trackBorderColor: WidgetStatePropertyAll(Color(0xff38bdf8)),
        thickness: WidgetStatePropertyAll(4),
        radius: Radius.circular(10),
      ),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        child: ScrollConfiguration(
          // Flutter leaves the mouse out of dragDevices by default, so on web
          // and desktop these chip rows could not be panned by pointer drag.
          // Scoped to this row only; app-wide scroll behavior is untouched.
          // scrollbars: false keeps this from adding a second, unthemed bar
          // over the styled Scrollbar above.
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
            dragDevices: const {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: ListView.separated(
            controller: controller,
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 2),
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) => itemBuilder(index),
          ),
        ),
      ),
    );
  }

  Widget _summaryChip({
    required String label,
    required int count,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
    required double minWidth,
    required double maxWidth,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? kRed.withOpacity(.16) : kCard2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? kRed : kBorder,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: kRed, size: 14),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kText,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Container(width: 1, height: 15, color: kBorder),
              const SizedBox(width: 9),
              Text(
                '$count',
                style: const TextStyle(
                  color: kRed,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 4),
      decoration: BoxDecoration(
        color: kRed.withOpacity(.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kRed.withOpacity(.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ERROR SUMMARY — CURRENT FILTER',
                  style: TextStyle(
                    color: kRed,
                    fontSize: 11,
                    height: 1.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .4,
                  ),
                ),
              ),

              if (widget.selectedErrorKey != null ||
                  widget.selectedBoxDeviceId != null)
                ScadaTabButton(
                  label: 'CLEAR',
                  selected: true,
                  color: kRed,
                  minWidth: 58,
                  onTap: widget.onClear,
                ),
            ],
          ),
          const SizedBox(height: 2),
          Expanded(
            child: widget.items.isEmpty
                ? _emptyRow('No abnormal signals in the current filter.')
                : _chipRow(
                    controller: _errorScrollController,
                    itemCount: widget.items.length,
                    itemBuilder: (index) {
                      final item = widget.items[index];
                      final isSelected =
                          item.errorKey == widget.selectedErrorKey;
                      return _summaryChip(
                        label: item.signalName,
                        count: item.deviceCount,
                        isSelected: isSelected,
                        icon: isSelected
                            ? Icons.filter_alt_rounded
                            : Icons.warning_amber_rounded,
                        minWidth: 160,
                        maxWidth: 260,
                        onTap: () => widget.onSelected(item.errorKey),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: widget.boxItems.isEmpty
                ? _emptyRow('No box device with issues in the current filter.')
                : _chipRow(
                    controller: _boxScrollController,
                    itemCount: widget.boxItems.length,
                    itemBuilder: (index) {
                      final item = widget.boxItems[index];
                      final isSelected =
                          item.boxDeviceId == widget.selectedBoxDeviceId;
                      return _summaryChip(
                        label: item.boxDeviceId,
                        count: item.issueCount,
                        isSelected: isSelected,
                        icon: isSelected
                            ? Icons.check_circle_rounded
                            : Icons.developer_board_rounded,
                        minWidth: 140,
                        maxWidth: 240,
                        onTap: () => widget.onBoxSelected(item.boxDeviceId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String lastUpdated;
  final VoidCallback onRefresh;

  const _Header({required this.lastUpdated, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: kBlue.withOpacity(.18),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: kBlue.withOpacity(.35)),
          ),
          child: const Icon(Icons.monitor_heart, color: kBlue, size: 20),
        ),

        const SizedBox(width: 10),

        const Text(
          'Signal Health Matrix',
          style: TextStyle(
            fontSize: 20,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: kText,
          ),
        ),

        // Đẩy phần bên dưới sang góc phải
        const Spacer(),

        Text(
          'Last updated: $lastUpdated',
          style: const TextStyle(fontSize: 11, color: kSubText),
        ),

        const SizedBox(width: 10),

        SizedBox(
          height: 34,
          child: OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 17),
            label: const Text(
              'Refresh',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: kBlue,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: BorderSide(color: kBlue.withOpacity(.45)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  final int totalFac;
  final int totalBoxDevice;
  final int totalRegister;
  final int totalNgRegister;

  const _KpiRow({
    required this.totalFac,
    required this.totalBoxDevice,
    required this.totalRegister,
    required this.totalNgRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _KpiCard(
          title: 'FACILITY',
          value: totalFac,
          subtitle: 'Tổng số FAC',
          icon: Icons.factory,
          color: const Color(0xff2563eb),
        ),
        const SizedBox(width: 16),
        _KpiCard(
          title: 'BOX DEVICE',
          value: totalBoxDevice,
          subtitle: 'Tổng số BoxDevice',
          icon: Icons.memory,
          color: const Color(0xff7c3aed),
        ),
        const SizedBox(width: 16),
        _KpiCard(
          title: 'REGISTER',
          value: totalRegister,
          subtitle: 'Tổng số Register',
          icon: Icons.menu_book,
          color: const Color(0xfff97316),
        ),
        const SizedBox(width: 16),
        _KpiCard(
          title: 'NG REGISTER',
          value: totalNgRegister,
          subtitle: 'Tổng số Register lỗi',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xffdc2626),
          danger: true,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final int value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool danger;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: danger ? kRed.withOpacity(.10) : kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: danger ? kRed.withOpacity(.45) : kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: kText,
                    height: 1.1,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: kSubText,
                    fontSize: 11,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final List<String> facOptions;
  final List<String> cateOptions;
  final List<String> scadaOptions;
  final List<String> boxDeviceOptions;

  final String? facValue;
  final String? cateValue;
  final String? scadaValue;
  final String? boxDeviceValue;

  final ValueChanged<String?> onFacChanged;
  final ValueChanged<String?> onCateChanged;
  final ValueChanged<String?> onScadaChanged;
  final ValueChanged<String?> onBoxDeviceChanged;
  final ValueChanged<String> onSearchChanged;

  const _FilterRow({
    required this.facOptions,
    required this.cateOptions,
    required this.scadaOptions,
    required this.boxDeviceOptions,
    required this.facValue,
    required this.cateValue,
    required this.scadaValue,
    required this.boxDeviceValue,
    required this.onFacChanged,
    required this.onCateChanged,
    required this.onScadaChanged,
    required this.onBoxDeviceChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterDropdown(
          hint: 'Facility',
          value: facValue,
          items: facOptions,
          onChanged: onFacChanged,
        ),

        const SizedBox(width: 12),

        _FilterDropdown(
          hint: 'Category',
          value: cateValue,
          items: cateOptions,
          onChanged: onCateChanged,
        ),

        const SizedBox(width: 12),

        _FilterDropdown(
          hint: 'SCADA',
          value: scadaValue,
          items: scadaOptions,
          onChanged: onScadaChanged,
        ),

        const SizedBox(width: 12),

        _FilterDropdown(
          hint: 'Device',
          value: boxDeviceValue,
          items: boxDeviceOptions,
          width: 260,
          onChanged: onBoxDeviceChanged,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              onChanged: onSearchChanged,
              style: const TextStyle(color: kText, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search device...',
                hintStyle: const TextStyle(color: kSubText, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: kSubText, size: 18),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 34,
                  minHeight: 34,
                ),
                filled: true,
                fillColor: kCard,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBlue),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final double width;

  const _FilterDropdown({
    super.key,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.width = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,

          // ALL => hiện hint
          value: value == 'ALL' ? null : value,

          hint: Text(
            hint,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kSubText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),

          dropdownColor: kCard,
          iconEnabledColor: kText,

          items: items.map((e) {
            return DropdownMenuItem<String>(
              value: e,
              child: Text(
                e == 'ALL'
                    ? 'All ${hint.replaceAll(RegExp(r'[^\w\s]'), '').trim()}'
                    : e,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),

          onChanged: (v) {
            if (v != null) {
              onChanged(v);
            }
          },
        ),
      ),
    );
  }
}

class _MatrixTable extends StatefulWidget {
  final List<dynamic> data;
  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _MatrixTable({
    required this.data,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<_MatrixTable> createState() => _MatrixTableState();
}

class _MatrixTableState extends State<_MatrixTable> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: kCard2,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Row(
              children: [
                _HeaderCell('Facility', flex: 1),
                _HeaderCell('Category', flex: 1),
                _HeaderCell('SCADA', flex: 1),
                _HeaderCell('Box Device ID', flex: 3),
                _HeaderCell('Total', flex: 1, center: true),
                _HeaderCell('NG', flex: 1, center: true),
                _HeaderCell('Status', flex: 1, center: true),
                SizedBox(width: 44),
              ],
            ),
          ),

          Expanded(
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbColor: WidgetStatePropertyAll(Color(0xff00E5FF)),
                trackColor: WidgetStatePropertyAll(Color(0xff1e293b)),
                trackBorderColor: WidgetStatePropertyAll(Color(0xff38bdf8)),
                radius: Radius.circular(10),
              ),
              child: Scrollbar(
                controller: _controller,
                thumbVisibility: true,
                trackVisibility: true,
                interactive: true,
                radius: const Radius.circular(12),
                thickness: 10,

                child: ListView.separated(
                  controller: _controller,
                  padding: const EdgeInsets.all(8),
                  itemCount: widget.data.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final row = widget.data[index] as Map<String, dynamic>;
                    final isSelected = identical(row, widget.selected);
                    final isNg = row['status'] == 'NG';

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => widget.onSelect(row),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? kBlue.withOpacity(.14)
                              : isNg
                              ? kOrange.withOpacity(.10)
                              : kCard,
                          border: Border.all(
                            color: isSelected
                                ? kBlue
                                : isNg
                                ? kOrange.withOpacity(.45)
                                : kBorder,
                            width: isSelected ? 1.6 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _BodyCell('${row['fac']}', flex: 1, bold: true),
                            _BodyCell(
                              '${row['cate']}',
                              flex: 1,
                              child: _CategoryBadge('${row['cate']}'),
                            ),
                            _BodyCell(
                              '${row['scadaId']}',
                              flex: 1,
                              child: _SoftBadge('${row['scadaId']}'),
                            ),
                            _BodyCell(
                              '${row['boxDeviceId']}',
                              flex: 3,
                              bold: true,
                            ),
                            _BodyCell(
                              '${row['totalRegisters']}',
                              flex: 1,
                              center: true,
                              child: _RegisterNumber(
                                '${row['totalRegisters']}',
                                color: kText,
                              ),
                            ),
                            _BodyCell(
                              '${row['ngRegisters']}',
                              flex: 1,
                              center: true,
                              child: _RegisterNumber(
                                '${row['ngRegisters']}',
                                color: isNg
                                    ? const Color(0xffdc2626)
                                    : const Color(0xff16a34a),
                              ),
                            ),
                            _BodyCell(
                              '${row['status']}',
                              flex: 1,
                              center: true,
                              child: _StatusBadge('${row['status']}'),
                            ),
                            SizedBox(
                              width: 44,
                              child: Icon(
                                Icons.chevron_right,
                                color: isSelected
                                    ? const Color(0xff2563eb)
                                    : const Color(0xff94a3b8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: kBorder)),
            ),
            child: Row(
              children: [
                Text(
                  'Showing ${widget.data.length} records',
                  style: const TextStyle(
                    color: Color(0xff64748b),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Click a row to view details',
                  style: TextStyle(color: Color(0xff94a3b8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool center;

  const _HeaderCell(this.text, {required this.flex, this.center = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: center ? Alignment.center : Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: kSubText,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: .3,
          ),
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool center;
  final bool bold;
  final Widget? child;

  const _BodyCell(
    this.text, {
    required this.flex,
    this.center = false,
    this.bold = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: center ? Alignment.center : Alignment.centerLeft,
        child:
            child ??
            Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: kText,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
      ),
    );
  }
}

class _RegisterNumber extends StatelessWidget {
  final String value;
  final Color color;

  const _RegisterNumber(this.value, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String text;

  const _CategoryBadge(this.text);

  @override
  Widget build(BuildContext context) {
    final isElectric = text.toLowerCase().contains('electric');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isElectric ? const Color(0xfffff7ed) : const Color(0xffeff6ff),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isElectric ? const Color(0xffea580c) : const Color(0xff2563eb),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  final String text;

  const _SoftBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xfff1f5f9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xff334155),
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _DetailPanel extends StatefulWidget {
  final Map<String, dynamic> device;

  const _DetailPanel({required this.device});

  @override
  State<_DetailPanel> createState() => _DetailPanelState();
}

class _DetailPanelState extends State<_DetailPanel> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawSignals = widget.device['signals'];
    final signals = rawSignals is List
        ? rawSignals
              .whereType<Map>()
              .map((signal) => Map<String, dynamic>.from(signal))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final issueSignals = signals.where(_isSignalNg).toList(growable: false);
    final normalSignals = signals
        .where((signal) => !_isSignalNg(signal))
        .toList(growable: false);

    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Register Details',
                style: TextStyle(
                  color: kText,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${signals.length} signals',
                style: const TextStyle(
                  color: kSubText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbColor: WidgetStatePropertyAll(Color(0xff00E5FF)),
                trackColor: WidgetStatePropertyAll(Color(0xff1e293b)),
                trackBorderColor: WidgetStatePropertyAll(Color(0xff38bdf8)),
                thickness: const WidgetStatePropertyAll(4),
                radius: Radius.circular(3),
              ),
              child: Scrollbar(
                controller: _controller,
                trackVisibility: true,
                thumbVisibility: true,
                interactive: true,
                radius: const Radius.circular(12),
                child: ListView(
                  controller: _controller,
                  children: [
                    _SignalGroupHeader(
                      title: 'ISSUES',
                      count: issueSignals.length,
                      color: kRed,
                    ),
                    ...issueSignals.map(
                      (signal) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _SignalMetricCard(signal: signal),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SignalGroupHeader(
                      title: 'NORMAL',
                      count: normalSignals.length,
                      color: kGreen,
                    ),
                    ...normalSignals.map(
                      (signal) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _SignalMetricCard(signal: signal),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalGroupHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _SignalGroupHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$title ($count)',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: color.withOpacity(.35), height: 1)),
        ],
      ),
    );
  }
}

class _SignalMetricCard extends StatelessWidget {
  final Map<String, dynamic> signal;

  const _SignalMetricCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final status = '${signal['status']}';
    final isNg = _isSignalNg(signal);
    final borderColor = !isNg
        ? kGreen.withOpacity(.25)
        : kOrange.withOpacity(.55);
    final bgColor = !isNg ? kCard2 : kOrange.withOpacity(.10);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                !isNg ? Icons.check_circle : Icons.warning_amber_rounded,
                color: !isNg ? kGreen : kOrange,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${signal['signalName']}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kText,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    if ((signal['unit'] ?? '').toString().isNotEmpty)
                      Text(
                        'Unit: ${signal['unit']}',
                        style: const TextStyle(
                          color: kSubText,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              _StatusBadge(status, isNg: isNg),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _MetaChip('PLC', '${signal['plcAddress']}'),
              const Spacer(),
              Text(
                _formatTime('${signal['recordedAt']}'),
                style: const TextStyle(
                  color: kSubText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ValueBox(
                  label: 'PREV',
                  value:
                      '${signal['prevValue'] ?? '-'} '
                      '${signal['unit'] ?? ''}',
                  color: kText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ValueBox(
                  label: 'CURRENT',
                  value:
                      '${signal['currentValue'] ?? '-'} '
                      '${signal['unit'] ?? ''}',
                  color: !isNg ? kGreen : kRed,
                  highlight: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ValueBox(
                  label: 'JUMP',
                  value: '${signal['jumpSize']}',
                  color: _jumpColor(signal['jumpSize']),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: Text(
              '${signal['description']}',
              style: TextStyle(
                color: !isNg ? kSubText : const Color(0xffffd28a),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _jumpColor(dynamic value) {
    final number = num.tryParse('$value') ?? 0;
    if (number == 0) return kSubText;
    if (number > 1000) return kRed;
    return kOrange;
  }

  static String _formatTime(String value) {
    if (value.length >= 19) {
      return value.substring(0, 19).replaceFirst('T', ' ');
    }
    return value;
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetaChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: kSubText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ValueBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool highlight;

  const _ValueBox({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(highlight ? .16 : .09),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withOpacity(.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(.85),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: highlight ? 22 : 20,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool? isNg;

  const _StatusBadge(this.status, {this.isNg});

  @override
  Widget build(BuildContext context) {
    final isOk = isNg == null ? status == 'OK' : !isNg!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOk ? kGreen.withOpacity(.14) : kRed.withOpacity(.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOk ? kGreen.withOpacity(.55) : kRed.withOpacity(.55),
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isOk ? kGreen : kRed,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: kCard,
    border: Border.all(color: kBorder),
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.25),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
