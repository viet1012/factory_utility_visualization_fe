import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_state/chart_catalog_provider.dart';
import '../ultility_dashboard_chart/utility_hourly_bar_panel.dart';
import 'utility_minute_chart_panel.dart';

class FacChartConfig {
  final String facId;
  final List<SignalChartConfig> charts;

  const FacChartConfig({required this.facId, required this.charts});
}

class SignalChartConfig {
  final String boxDeviceId;
  final String plcAddress;
  final String? cateId;
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
  static const List<String> _cateTabs = [
    'Electricity',
    'Water',
    'Compressed Air',
  ];

  static const List<String> _facTabs = ['Fac_A', 'Fac_B', 'Fac_C'];

  static const List<String> _viewTabs = ['Summary', 'Minutes'];

  static const List<String> _summaryRanges = [
    'TODAY',
    'YESTERDAY',
    'LAST_7_DAYS',
    'THIS_MONTH',
  ];

  int _selectedCateIndex = 0;
  int _selectedFacIndex = 0;
  int _selectedViewIndex = 1;
  int _selectedBoxIndex = 0;
  int _selectedSummarySignalIndex = 0;

  String _selectedSummaryRange = 'LAST_7_DAYS';
  bool _importantOnly = false;
  bool _filtersExpanded = true;

  String get selectedCate => _cateTabs[_selectedCateIndex];
  String get selectedFac => _facTabs[_selectedFacIndex];
  String get selectedView => _viewTabs[_selectedViewIndex];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final catalog = context.read<ChartCatalogProvider>();

    await catalog.loadBoxes(facId: selectedFac, cate: selectedCate);

    await _loadFirstBoxChartsIfAny(catalog);
  }

  Future<void> _reloadBoxesAndCharts() async {
    final catalog = context.read<ChartCatalogProvider>();

    _selectedBoxIndex = 0;
    _selectedSummarySignalIndex = 0;

    await catalog.loadBoxes(facId: selectedFac, cate: selectedCate);

    await _loadFirstBoxChartsIfAny(catalog);
  }

  Future<void> _loadFirstBoxChartsIfAny(ChartCatalogProvider catalog) async {
    if (catalog.boxDeviceIds.isEmpty) return;

    await catalog.loadChartsForBox(
      facId: selectedFac,
      cate: selectedCate,
      boxDeviceId: catalog.boxDeviceIds.first,
      importantOnly: _importantOnly ? 1 : 0,
    );
  }

  Future<void> _loadChartsForSelectedBox(
    ChartCatalogProvider catalog,
    String boxDeviceId,
  ) async {
    await catalog.loadChartsForBox(
      facId: selectedFac,
      cate: selectedCate,
      boxDeviceId: boxDeviceId,
      importantOnly: _importantOnly ? 1 : 0,
    );
  }

  void _onViewChanged(int index) {
    setState(() {
      _selectedViewIndex = index;
    });
  }

  Future<void> _onCateChanged(int index) async {
    setState(() {
      _selectedCateIndex = index;
    });
    await _reloadBoxesAndCharts();
  }

  Future<void> _onFacChanged(int index) async {
    setState(() {
      _selectedFacIndex = index;
    });
    await _reloadBoxesAndCharts();
  }

  Future<void> _onBoxChanged(
    ChartCatalogProvider catalog,
    List<String> boxTabs,
    int index,
  ) async {
    if (boxTabs.isEmpty) return;

    setState(() {
      _selectedBoxIndex = index;
      _selectedSummarySignalIndex = 0;
    });

    final selectedBox = boxTabs[index];

    await _loadChartsForSelectedBox(catalog, selectedBox);
  }

  Future<void> _onImportantChanged(
    ChartCatalogProvider catalog,
    String? selectedBox,
    bool value,
  ) async {
    setState(() {
      _importantOnly = value;
    });

    if (selectedBox == null || selectedBox.trim().isEmpty) return;

    await catalog.loadChartsForBox(
      facId: selectedFac,
      cate: selectedCate,
      boxDeviceId: selectedBox,
      importantOnly: _importantOnly ? 1 : 0,
    );
  }

  void _toggleFilters() {
    setState(() {
      _filtersExpanded = !_filtersExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          builder: (context, catalog, _) {
            final boxTabs = catalog.boxDeviceIds;
            final selectedBox = _getSelectedBox(boxTabs);

            return Column(
              children: [
                _buildTopBar(catalog: catalog, selectedBox: selectedBox),
                const SizedBox(height: 8),
                _buildFiltersArea(catalog: catalog, boxTabs: boxTabs),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildBody(catalog: catalog, selectedBox: selectedBox),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String? _getSelectedBox(List<String> boxTabs) {
    if (boxTabs.isEmpty) return null;
    if (_selectedBoxIndex >= boxTabs.length) {
      _selectedBoxIndex = 0;
    }
    return boxTabs[_selectedBoxIndex];
  }

  Widget _buildTopBar({
    required ChartCatalogProvider catalog,
    required String? selectedBox,
  }) {
    return Row(
      children: [
        _buildCollapseToggle(),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTabRow(
            labels: _viewTabs,
            selectedIndex: _selectedViewIndex,
            onSelect: _onViewChanged,
          ),
        ),
        if (!_filtersExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Cate: $selectedCate   •   Fac: $selectedFac   •   Box: ${selectedBox ?? "-"}',
                style: TextStyle(color: Colors.white.withOpacity(0.70)),
              ),
            ),
          ),
        const SizedBox(width: 12),
        if (selectedView == 'Minutes')
          _buildImportantSwitch(catalog: catalog, selectedBox: selectedBox),
      ],
    );
  }

  Widget _buildFiltersArea({
    required ChartCatalogProvider catalog,
    required List<String> boxTabs,
  }) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 180),
      crossFadeState: _filtersExpanded
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      firstChild: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTabRow(
                  labels: _cateTabs,
                  selectedIndex: _selectedCateIndex,
                  onSelect: (index) => _onCateChanged(index),
                ),
              ),
              const SizedBox(width: 12),
              _buildTabRow(
                labels: _facTabs,
                selectedIndex: _selectedFacIndex,
                onSelect: (index) => _onFacChanged(index),
                alignRight: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: _buildTabRow(
              labels: boxTabs.isEmpty ? const ['(no boxes)'] : boxTabs,
              selectedIndex: boxTabs.isEmpty ? 0 : _selectedBoxIndex,
              onSelect: (index) => _onBoxChanged(catalog, boxTabs, index),
            ),
          ),
        ],
      ),
      secondChild: const SizedBox.shrink(),
    );
  }

  Widget _buildBody({
    required ChartCatalogProvider catalog,
    required String? selectedBox,
  }) {
    if (selectedView == 'Summary') {
      return _buildSummaryBody(
        loading: catalog.loading,
        error: catalog.error,
        charts: catalog.charts,
      );
    }

    return _buildMinutesBody(
      loading: catalog.loading,
      error: catalog.error,
      charts: catalog.charts,
      selectedBox: selectedBox,
    );
  }

  Widget _buildSummaryBody({
    required bool loading,
    required Object? error,
    required List<SignalChartConfig> charts,
  }) {
    if (loading && charts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && charts.isEmpty) {
      return _buildErrorState(error);
    }

    if (charts.isEmpty) {
      return _buildEmptyState(
        'No signals\ncate=$selectedCate • fac=$selectedFac',
      );
    }

    if (_selectedSummarySignalIndex >= charts.length) {
      _selectedSummarySignalIndex = 0;
    }

    final selectedSignal = charts[_selectedSummarySignalIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummaryToolbar(charts),
        Expanded(
          child: Center(
            child: UtilityHourlyBarChartPanel(
              facId: selectedFac,
              boxDeviceId: selectedSignal.boxDeviceId,
              plcAddress: selectedSignal.plcAddress,
              range: _selectedSummaryRange,
              width: 700,
              height: 360,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryToolbar(List<SignalChartConfig> charts) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Text(
            'Summary:',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSummaryRange,
              dropdownColor: const Color(0xFF16213e),
              style: const TextStyle(color: Colors.white),
              items: _summaryRanges
                  .map(
                    (range) =>
                        DropdownMenuItem(value: range, child: Text(range)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedSummaryRange = value;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedSummarySignalIndex,
                isExpanded: true,
                dropdownColor: const Color(0xFF16213e),
                style: const TextStyle(color: Colors.white),
                items: List.generate(charts.length, (index) {
                  final chart = charts[index];
                  return DropdownMenuItem(
                    value: index,
                    child: Text(
                      '${chart.boxDeviceId} • ${chart.plcAddress}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
                onChanged: (index) {
                  if (index == null) return;
                  setState(() {
                    _selectedSummarySignalIndex = index;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinutesBody({
    required bool loading,
    required Object? error,
    required List<SignalChartConfig> charts,
    required String? selectedBox,
  }) {
    if (loading && charts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && charts.isEmpty) {
      return _buildErrorState(error);
    }

    if (selectedBox == null) {
      return _buildEmptyState(
        'No boxDeviceId for $selectedCate / $selectedFac',
      );
    }

    if (charts.isEmpty) {
      return _buildEmptyState('No signals in $selectedBox');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _resolveGridColumnCount(constraints.maxWidth);

        return GridView.builder(
          itemCount: charts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 16 / 10,
          ),
          itemBuilder: (context, index) {
            final chart = charts[index];

            return UtilityMinuteChartPanel(
              facId: selectedFac,
              cate: selectedCate,
              boxDeviceId: chart.boxDeviceId,
              plcAddress: chart.plcAddress,
              cateIds: chart.cateIds,
            );
          },
        );
      },
    );
  }

  int _resolveGridColumnCount(double width) {
    if (width >= 1700) return 3;
    if (width >= 1200) return 2;
    return 1;
  }

  Widget _buildCollapseToggle() {
    return InkWell(
      onTap: _toggleFilters,
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
              _filtersExpanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              color: Colors.white.withOpacity(0.85),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              _filtersExpanded ? 'Hide Tabs' : 'Show Tabs',
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

  Widget _buildImportantSwitch({
    required ChartCatalogProvider catalog,
    required String? selectedBox,
  }) {
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
                : (value) => _onImportantChanged(catalog, selectedBox, value),
          ),
        ],
      ),
    );
  }

  Widget _buildTabRow({
    required List<String> labels,
    required int selectedIndex,
    required ValueChanged<int> onSelect,
    bool alignRight = false,
  }) {
    final tabs = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(labels.length, (index) {
        final selected = index == selectedIndex;

        return InkWell(
          onTap: () => onSelect(index),
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
              labels[index],
              style: TextStyle(
                color: Colors.white.withOpacity(selected ? 0.95 : 0.80),
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        );
      }),
    );

    if (alignRight) {
      return Align(alignment: Alignment.topRight, child: tabs);
    }

    return tabs;
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Text(
        'API error:\n$error',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withOpacity(0.85)),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withOpacity(0.85)),
      ),
    );
  }
}
