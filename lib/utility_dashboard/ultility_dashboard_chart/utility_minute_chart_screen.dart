import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_state/chart_catalog_provider.dart';
import 'utility_minute_chart_panel.dart';

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
  static const List<String> _viewTabs = ['Minutes'];

  int _selectedCateIndex = 0;
  int _selectedFacIndex = 0;
  int _selectedViewIndex = 0;
  int _selectedBoxIndex = 0;

  bool _importantOnly = false;
  bool _filtersExpanded = true;

  int _loadToken = 0;

  String get selectedCate => _cateTabs[_selectedCateIndex];

  String get selectedFac => _facTabs[_selectedFacIndex];

  String get selectedView => _viewTabs[_selectedViewIndex];

  ChartCatalogProvider get _catalog => context.read<ChartCatalogProvider>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCatalogForCurrentSelection();
    });
  }

  Future<void> _loadCatalogForCurrentSelection() async {
    final token = ++_loadToken;

    await _catalog.loadBoxes(facId: selectedFac, cate: selectedCate);

    if (!mounted || token != _loadToken) return;

    setState(() {
      _selectedBoxIndex = 0;
    });

    final firstBox = _safeSelectedBox(_catalog.boxDeviceIds);
    if (firstBox != null) {
      await _loadChartsForBox(firstBox, token: token);
    }
  }

  Future<void> _loadChartsForBox(String boxDeviceId, {int? token}) async {
    final currentToken = token ?? ++_loadToken;

    await _catalog.loadChartsForBox(
      facId: selectedFac,
      cate: selectedCate,
      boxDeviceId: boxDeviceId,
      importantOnly: _importantOnly ? 1 : 0,
    );

    if (!mounted || currentToken != _loadToken) return;
  }

  Future<void> _onCateChanged(int index) async {
    if (_selectedCateIndex == index) return;
    setState(() {
      _selectedCateIndex = index;
      _selectedBoxIndex = 0;
    });
    await _loadCatalogForCurrentSelection();
  }

  Future<void> _onFacChanged(int index) async {
    if (_selectedFacIndex == index) return;
    setState(() {
      _selectedFacIndex = index;
      _selectedBoxIndex = 0;
    });
    await _loadCatalogForCurrentSelection();
  }

  void _onViewChanged(int index) {
    if (_selectedViewIndex == index) return;
    setState(() {
      _selectedViewIndex = index;
    });
  }

  Future<void> _onBoxChanged(List<String> boxTabs, int index) async {
    if (boxTabs.isEmpty || index >= boxTabs.length) return;

    final nextBox = boxTabs[index];

    setState(() {
      _selectedBoxIndex = index;
    });

    await _loadChartsForBox(nextBox);
  }

  Future<void> _onImportantChanged(String? selectedBox, bool value) async {
    setState(() {
      _importantOnly = value;
    });

    if (selectedBox == null || selectedBox.trim().isEmpty) return;
    await _loadChartsForBox(selectedBox);
  }

  void _toggleFilters() {
    setState(() {
      _filtersExpanded = !_filtersExpanded;
    });
  }

  String? _safeSelectedBox(List<String> boxTabs) {
    if (boxTabs.isEmpty) return null;

    if (_selectedBoxIndex < 0 || _selectedBoxIndex >= boxTabs.length) {
      _selectedBoxIndex = 0;
    }

    return boxTabs[_selectedBoxIndex];
  }

  @override
  Widget build(BuildContext context) {
    final boxTabs = context.select<ChartCatalogProvider, List<String>>(
      (p) => p.boxDeviceIds,
    );
    final selectedBox = _safeSelectedBox(boxTabs);

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E27), Color(0xFF1A1A2E), Color(0xFF16213E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            _TopBar(
              filtersExpanded: _filtersExpanded,
              selectedCate: selectedCate,
              selectedFac: selectedFac,
              selectedBox: selectedBox,
              viewTabs: _viewTabs,
              selectedViewIndex: _selectedViewIndex,
              onViewChanged: _onViewChanged,
              importantOnly: _importantOnly,
              onToggleFilters: _toggleFilters,
              onImportantChanged: (value) =>
                  _onImportantChanged(selectedBox, value),
              showImportantSwitch: selectedView == 'Minutes',
              importantEnabled:
                  selectedBox != null && selectedBox.trim().isNotEmpty,
            ),
            const SizedBox(height: 8),
            _FiltersArea(
              expanded: _filtersExpanded,
              cateTabs: _cateTabs,
              facTabs: _facTabs,
              boxTabs: boxTabs,
              selectedCateIndex: _selectedCateIndex,
              selectedFacIndex: _selectedFacIndex,
              selectedBoxIndex: boxTabs.isEmpty ? 0 : _selectedBoxIndex,
              onCateChanged: _onCateChanged,
              onFacChanged: _onFacChanged,
              onBoxChanged: (index) => _onBoxChanged(boxTabs, index),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _CatalogBody(
                selectedBox: selectedBox,
                selectedCate: selectedCate,
                selectedFac: selectedFac,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogBodyState {
  final bool loading;
  final Object? error;
  final List charts;

  const _CatalogBodyState({
    required this.loading,
    required this.error,
    required this.charts,
  });
}

class _CatalogBody extends StatelessWidget {
  final String? selectedBox;
  final String selectedCate;
  final String selectedFac;

  const _CatalogBody({
    required this.selectedBox,
    required this.selectedCate,
    required this.selectedFac,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<ChartCatalogProvider, _CatalogBodyState>(
      selector: (_, p) => _CatalogBodyState(
        loading: p.loading,
        error: p.error,
        charts: p.charts,
      ),
      shouldRebuild: (prev, next) =>
          prev.loading != next.loading ||
          prev.error != next.error ||
          !identical(prev.charts, next.charts),
      builder: (context, vm, _) {
        if (vm.loading && vm.charts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (vm.error != null && vm.charts.isEmpty) {
          return _CenterMessage(message: 'API error:\n${vm.error}');
        }

        if (selectedBox == null) {
          return _CenterMessage(
            message: 'No boxDeviceId for $selectedCate / $selectedFac',
          );
        }

        if (vm.charts.isEmpty) {
          return _CenterMessage(message: 'No signals in $selectedBox');
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = _resolveGridColumnCount(
              constraints.maxWidth,
            );

            return GridView.builder(
              key: const PageStorageKey('utility_chart_grid'),
              padding: EdgeInsets.zero,
              cacheExtent: 1200,
              itemCount: vm.charts.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 16 / 10,
              ),
              itemBuilder: (context, index) {
                final chart = vm.charts[index];

                return RepaintBoundary(
                  child: UtilityMinuteChartPanel(
                    key: ValueKey(
                      '${selectedFac}_${selectedCate}_${chart.boxDeviceId}_${chart.plcAddress}',
                    ),
                    facId: selectedFac,
                    cate: selectedCate,
                    boxDeviceId: chart.boxDeviceId,
                    plcAddress: chart.plcAddress,
                    cateIds: chart.cateIds,
                  ),
                );
              },
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
}

class _TopBar extends StatelessWidget {
  final bool filtersExpanded;
  final String selectedCate;
  final String selectedFac;
  final String? selectedBox;
  final List<String> viewTabs;
  final int selectedViewIndex;
  final ValueChanged<int> onViewChanged;
  final bool importantOnly;
  final ValueChanged<bool> onImportantChanged;
  final VoidCallback onToggleFilters;
  final bool showImportantSwitch;
  final bool importantEnabled;

  const _TopBar({
    required this.filtersExpanded,
    required this.selectedCate,
    required this.selectedFac,
    required this.selectedBox,
    required this.viewTabs,
    required this.selectedViewIndex,
    required this.onViewChanged,
    required this.importantOnly,
    required this.onImportantChanged,
    required this.onToggleFilters,
    required this.showImportantSwitch,
    required this.importantEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CollapseToggle(expanded: filtersExpanded, onTap: onToggleFilters),
        const SizedBox(width: 12),
        Expanded(
          child: _GlassTabRow(
            labels: viewTabs,
            selectedIndex: selectedViewIndex,
            onSelect: onViewChanged,
          ),
        ),
        if (!filtersExpanded)
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
        if (showImportantSwitch)
          _ImportantSwitch(
            value: importantOnly,
            enabled: importantEnabled,
            onChanged: onImportantChanged,
          ),
      ],
    );
  }
}

class _FiltersArea extends StatelessWidget {
  final bool expanded;
  final List<String> cateTabs;
  final List<String> facTabs;
  final List<String> boxTabs;
  final int selectedCateIndex;
  final int selectedFacIndex;
  final int selectedBoxIndex;
  final ValueChanged<int> onCateChanged;
  final ValueChanged<int> onFacChanged;
  final ValueChanged<int> onBoxChanged;

  const _FiltersArea({
    required this.expanded,
    required this.cateTabs,
    required this.facTabs,
    required this.boxTabs,
    required this.selectedCateIndex,
    required this.selectedFacIndex,
    required this.selectedBoxIndex,
    required this.onCateChanged,
    required this.onFacChanged,
    required this.onBoxChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: expanded
          ? Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _GlassTabRow(
                        labels: cateTabs,
                        selectedIndex: selectedCateIndex,
                        onSelect: onCateChanged,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _GlassTabRow(
                      labels: facTabs,
                      selectedIndex: selectedFacIndex,
                      onSelect: onFacChanged,
                      alignRight: true,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _GlassTabRow(
                    labels: boxTabs.isEmpty ? const ['(no boxes)'] : boxTabs,
                    selectedIndex: boxTabs.isEmpty ? 0 : selectedBoxIndex,
                    onSelect: boxTabs.isEmpty ? (_) {} : onBoxChanged,
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}

class _CollapseToggle extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _CollapseToggle({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
}

class _ImportantSwitch extends StatelessWidget {
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ImportantSwitch({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
            color: value ? Colors.amberAccent : Colors.white54,
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
          Switch(value: value, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }
}

class _GlassTabRow extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool alignRight;

  const _GlassTabRow({
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(labels.length, (index) {
        final selected = index == selectedIndex;

        return InkWell(
          onTap: () => onSelect(index),
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(selected ? 0.18 : 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Text(
                      labels[index],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (selected)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF009FFF).withOpacity(0.35),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );

    return alignRight
        ? Align(alignment: Alignment.topRight, child: tabs)
        : tabs;
  }
}

class _CenterMessage extends StatelessWidget {
  final String message;

  const _CenterMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withOpacity(0.85)),
      ),
    );
  }
}
