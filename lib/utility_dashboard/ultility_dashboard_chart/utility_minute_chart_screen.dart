import 'package:factory_utility_visualization/utility_dashboard/ultility_dashboard_chart/utility_hourly_bar_panel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_state/chart_catalog_provider.dart';
import 'utility_minute_chart_panel.dart';

class FacChartConfig {
  final String facId;
  final List<SignalChartConfig> charts;

  const FacChartConfig({required this.facId, required this.charts});
}

class SignalChartConfig {
  final String boxDeviceId;
  final String plcAddress;

  // ✅ NEW: 1 cateId cụ thể cho signal (vd: E_EneCon)
  final String? cateId;

  // optional nếu bạn vẫn muốn list
  final List<String>? cateIds;

  const SignalChartConfig({
    required this.boxDeviceId,
    required this.plcAddress,
    this.cateId,
    this.cateIds,
  });
}

class UtilityAllFactoriesChartsScreen extends StatefulWidget {
  const UtilityAllFactoriesChartsScreen({super.key});

  @override
  State<UtilityAllFactoriesChartsScreen> createState() =>
      _UtilityAllFactoriesChartsScreenState();
}

class _UtilityAllFactoriesChartsScreenState
    extends State<UtilityAllFactoriesChartsScreen> {
  final _cateTabs = const ['Electricity', 'Water', 'Compressed Air'];
  final _facTabs = const [
    'Fac_A',
    'Fac_B',
    'Fac_C',
  ]; // ✅ nếu muốn động thì lấy từ /scadas
  final _viewTabs = const ['Summary', 'Minutes'];

  int _cateIdx = 0;
  int _facIdx = 0;
  int _viewIdx = 1;
  int _boxIdx = 0;

  String get cate => _cateTabs[_cateIdx];

  String get facId => _facTabs[_facIdx];

  bool _importantOnly = true; // mặc định bật lọc important

  bool _filtersExpanded = true; // mặc định mở, muốn tiết kiệm thì set false
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<ChartCatalogProvider>();
      await p.loadBoxes(facId: facId, cate: cate);
      if (p.boxDeviceIds.isNotEmpty) {
        await p.loadChartsForBox(
          facId: facId,
          cate: cate,
          boxDeviceId: p.boxDeviceIds.first,
          importantOnly: _importantOnly ? 1 : 0,
        );
      }
    });
  }

  Future<void> _reloadBoxesAndSelectFirst() async {
    final p = context.read<ChartCatalogProvider>();
    _boxIdx = 0;
    await p.loadBoxes(facId: facId, cate: cate);
    if (p.boxDeviceIds.isNotEmpty) {
      await p.loadChartsForBox(
        facId: facId,
        cate: cate,
        boxDeviceId: p.boxDeviceIds.first,
        importantOnly: _importantOnly ? 1 : 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = _viewTabs[_viewIdx];

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0a0e27), Color(0xFF1a1a2e), Color(0xFF16213e)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Consumer<ChartCatalogProvider>(
          builder: (context, cat, _) {
            final boxTabs = cat.boxDeviceIds;
            if (boxTabs.isNotEmpty && _boxIdx >= boxTabs.length) _boxIdx = 0;
            final selectedBox = boxTabs.isEmpty ? null : boxTabs[_boxIdx];

            return Column(
              children: [
                // ===== Top compact bar (always visible) =====
                Row(
                  children: [
                    _collapseToggle(expanded: _filtersExpanded),
                    const SizedBox(width: 12),

                    // luôn hiện View tabs (Summary/Minutes)
                    Expanded(
                      child: _tabRow(
                        labels: _viewTabs,
                        selectedIndex: _viewIdx,
                        onSelect: (i) => setState(() => _viewIdx = i),
                      ),
                    ),
                    if (!_filtersExpanded)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Cate: $cate   •   Fac: $facId   •   Box: ${selectedBox ?? "-"}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.70),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),

                    // Important chỉ hiện khi Minutes
                    if (view == 'Minutes')
                      _importantSwitch(
                        cat: cat,
                        facId: facId,
                        cate: cate,
                        selectedBox: selectedBox,
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // ===== Expandable area: Cate + Fac + Box tabs =====
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 180),
                  crossFadeState: _filtersExpanded
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Column(
                    children: [
                      // cate + fac tabs
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _tabRow(
                              labels: _cateTabs,
                              selectedIndex: _cateIdx,
                              onSelect: (i) async {
                                setState(() => _cateIdx = i);
                                await _reloadBoxesAndSelectFirst();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          _tabRow(
                            labels: _facTabs,
                            selectedIndex: _facIdx,
                            onSelect: (i) async {
                              setState(() => _facIdx = i);
                              await _reloadBoxesAndSelectFirst();
                            },
                            alignRight: true,
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // box tabs (only when Minutes)
                      if (view == 'Minutes')
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _tabRow(
                            labels: boxTabs.isEmpty
                                ? const ['(no boxes)']
                                : boxTabs,
                            selectedIndex: boxTabs.isEmpty ? 0 : _boxIdx,
                            onSelect: (i) async {
                              setState(() => _boxIdx = i);
                              if (boxTabs.isEmpty) return;

                              final box = boxTabs[i];

                              debugPrint('==============================');
                              debugPrint(
                                '[BOX SELECT] facId=$facId  cate=$cate  idx=$i  boxDeviceId=$box',
                              );
                              debugPrint(
                                'All boxes (${boxTabs.length}): ${boxTabs.join(", ")}',
                              );

                              await cat.loadChartsForBox(
                                facId: facId,
                                cate: cate,
                                boxDeviceId: box,
                                importantOnly: _importantOnly ? 1 : 0,
                              );

                              debugPrint(
                                '[BOX SELECT DONE] charts.length=${cat.charts.length} for box=$box',
                              );
                              for (final c in cat.charts.take(30)) {
                                debugPrint(
                                  '  - plc=${c.plcAddress}  cateId=${c.cateId}  cateIds=${c.cateIds}',
                                );
                              }
                              debugPrint('==============================');
                            },
                          ),
                        ),
                    ],
                  ),

                  // collapsed child (almost empty)
                  secondChild: const SizedBox.shrink(),
                ),

                const SizedBox(height: 4),

                // ===== Body =====
                Expanded(
                  child: view == 'Summary'
                      ? _summaryBody(
                          cate: cate,
                          facId: facId,
                          loading: cat.loading,
                          error: cat.error,
                          charts: cat.charts,
                        )
                      : _minutesBody(
                          cate: cate,
                          facId: facId,
                          selectedBox: selectedBox,
                          loading: cat.loading,
                          error: cat.error,
                          charts: cat.charts,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _collapseToggle({required bool expanded}) {
    return InkWell(
      onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: Colors.white.withOpacity(0.85),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              expanded ? 'Hide Tabs' : 'Show Tabs',
              style: TextStyle(
                color: Colors.white.withOpacity(0.90),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _importantSwitch({
    required ChartCatalogProvider cat,
    required String facId,
    required String cate,
    required String? selectedBox,
  }) {
    // Summary của bạn đang FIXED nên không cần selectedBox.
    // Switch này chủ yếu apply cho Minutes (khi chọn box).
    final enabled = selectedBox != null && selectedBox.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 18,
            color: _importantOnly ? Colors.amberAccent : Colors.white54,
          ),
          const SizedBox(width: 8),
          Text(
            'Important',
            style: TextStyle(
              color: Colors.white.withOpacity(enabled ? 0.90 : 0.45),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: _importantOnly,
            onChanged: !enabled
                ? null
                : (v) async {
                    setState(() => _importantOnly = v);

                    // ✅ reload charts theo box đang chọn
                    await cat.loadChartsForBox(
                      facId: facId,
                      cate: cate,
                      boxDeviceId: selectedBox!,
                      importantOnly: _importantOnly ? 1 : 0,
                    );
                  },
          ),
        ],
      ),
    );
  }

  Widget _summaryBody({
    required String cate,
    required String facId,
    required bool loading,
    required Object? error,
    required List<SignalChartConfig> charts,
  }) {
    // time window today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final fromTs = today;
    final toTs = today.add(const Duration(days: 1));

    // ✅ HARD FILTER theo yêu cầu bạn
    const plcAddress = 'D30';
    const cateId = 'E_EneCon';

    debugPrint(
      '[SUMMARY FIXED] fac=$facId cate=$cate plc=$plcAddress cateId=$cateId',
    );

    return Center(
      child: UtilityHourlyBarChartPanel(
        facId: facId,
        cate: cate,
        boxDeviceId: null,
        // hoặc selectedBox nếu bạn muốn
        plcAddress: plcAddress,
        cateId: cateId,
        fromTs: fromTs,
        toTs: toTs,
        width: 700,
        height: 360,
      ),
    );
  }

  // Widget _summaryBody({
  //   required String cate,
  //   required String facId,
  //   required bool loading,
  //   required Object? error,
  //   required List<SignalChartConfig> charts,
  // }) {
  //   // Summary vẫn dựa vào charts đã load (theo selected box hoặc theo logic bạn đang dùng)
  //   if (loading && charts.isEmpty) {
  //     return const Center(child: CircularProgressIndicator());
  //   }
  //   if (error != null && charts.isEmpty) {
  //     return Center(
  //       child: Text(
  //         'API error:\n$error',
  //         textAlign: TextAlign.center,
  //         style: TextStyle(color: Colors.white.withOpacity(0.85)),
  //       ),
  //     );
  //   }
  //   if (charts.isEmpty) {
  //     return Center(
  //       child: Text(
  //         'Summary: no signals\ncate=$cate • fac=$facId',
  //         textAlign: TextAlign.center,
  //         style: TextStyle(color: Colors.white.withOpacity(0.85)),
  //       ),
  //     );
  //   }
  //
  //   // ✅ default: today (00:00 -> tomorrow 00:00)
  //   final now = DateTime.now();
  //   final today = DateTime(now.year, now.month, now.day);
  //   final fromTs = today;
  //   final toTs = today.add(const Duration(days: 1));
  //
  //   return LayoutBuilder(
  //     builder: (context, c) {
  //       final w = c.maxWidth;
  //       var cross = 1;
  //       if (w >= 1200) cross = 2;
  //       if (w >= 1700) cross = 3;
  //
  //       return GridView.builder(
  //         itemCount: charts.length,
  //         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
  //           crossAxisCount: cross,
  //           crossAxisSpacing: 12,
  //           mainAxisSpacing: 12,
  //           childAspectRatio: 16 / 10,
  //         ),
  //         itemBuilder: (context, i) {
  //           final cfg = charts[i];
  //
  //           // ✅ quan trọng: BE hourly bạn muốn filter cateId + plcAddress
  //           // cfg.cateIds đang là list cateIds (nếu bạn đã map cateIds theo param)
  //           // Nếu bạn chỉ có 1 cateId thì truyền cateId = cfg.cateIds?.first
  //
  //           final cateId = (cfg.cateId ?? '').trim().isNotEmpty
  //               ? cfg.cateId
  //               : (cfg.cateIds?.isNotEmpty == true ? cfg.cateIds!.first : null);
  //
  //           debugPrint(
  //             'SUMMARY cfg box=${cfg.boxDeviceId} plc=${cfg.plcAddress} cateId=$cateId cateIds=${cfg.cateIds}',
  //           );
  //
  //           return UtilityHourlyBarChartPanel(
  //             facId: facId,
  //             cate: cate,
  //             boxDeviceId: cfg.boxDeviceId,
  //             plcAddress: cfg.plcAddress,
  //             fromTs: fromTs,
  //             toTs: toTs,
  //             cateId: cateId,
  //             cateIds: cfg.cateIds,
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  Widget _minutesBody({
    required String cate,
    required String facId,
    required String? selectedBox,
    required bool loading,
    required Object? error,
    required List<SignalChartConfig> charts,
  }) {
    if (loading && charts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && charts.isEmpty) {
      return Center(
        child: Text(
          'API error:\n$error',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.85)),
        ),
      );
    }
    if (selectedBox == null) {
      return Center(
        child: Text(
          'No boxDeviceId for $cate / $facId',
          style: TextStyle(color: Colors.white.withOpacity(0.85)),
        ),
      );
    }
    if (charts.isEmpty) {
      return Center(
        child: Text(
          'No signals in $selectedBox',
          style: TextStyle(color: Colors.white.withOpacity(0.85)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        var cross = 1;
        if (w >= 1200) cross = 2;
        if (w >= 1700) cross = 3;

        return GridView.builder(
          itemCount: charts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 16 / 10,
          ),
          itemBuilder: (context, i) {
            final cfg = charts[i];
            return UtilityMinuteChartPanel(
              facId: facId,
              cate: cate,
              boxDeviceId: cfg.boxDeviceId,
              plcAddress: cfg.plcAddress,
              cateIds: cfg.cateIds,
            );
          },
        );
      },
    );
  }

  // giữ nguyên UI tab của bạn
  Widget _tabRow({
    required List<String> labels,
    required int selectedIndex,
    required ValueChanged<int> onSelect,
    bool alignRight = false,
  }) {
    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(labels.length, (i) {
        final selected = i == selectedIndex;
        return InkWell(
          onTap: () => onSelect(i),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withOpacity(0.14)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected
                    ? Colors.white.withOpacity(0.40)
                    : Colors.white.withOpacity(0.18),
                width: 1,
              ),
            ),
            child: Text(
              labels[i],
              style: TextStyle(
                color: Colors.white.withOpacity(selected ? 0.95 : 0.80),
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        );
      }),
    );

    if (!alignRight) return chips;
    return Align(alignment: Alignment.topRight, child: chips);
  }
}
