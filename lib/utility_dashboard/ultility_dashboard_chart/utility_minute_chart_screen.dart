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
  final List<String>? cateIds;

  const SignalChartConfig({
    required this.boxDeviceId,
    required this.plcAddress,
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
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = _viewTabs[_viewIdx];

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(16),
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

                const SizedBox(height: 14),

                Align(
                  alignment: Alignment.centerLeft,
                  child: _tabRow(
                    labels: _viewTabs,
                    selectedIndex: _viewIdx,
                    onSelect: (i) => setState(() => _viewIdx = i),
                  ),
                ),

                const SizedBox(height: 10),

                // box tabs dynamic
                if (view == 'Minutes')
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _tabRow(
                      labels: boxTabs.isEmpty ? const ['(no boxes)'] : boxTabs,
                      selectedIndex: boxTabs.isEmpty ? 0 : _boxIdx,
                      onSelect: (i) async {
                        setState(() => _boxIdx = i);
                        if (boxTabs.isEmpty) return;
                        await cat.loadChartsForBox(
                          facId: facId,
                          cate: cate,
                          boxDeviceId: boxTabs[i],
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 12),

                Expanded(
                  child: view == 'Summary'
                      ? Center(
                          child: Text(
                            'Summary chưa làm\ncate=$cate  •  fac=$facId',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
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
