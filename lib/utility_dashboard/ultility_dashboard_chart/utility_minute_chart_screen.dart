import 'package:factory_utility_visualization/utility_dashboard/ultility_dashboard_chart/signal_widget_resolver.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_state/chart_catalog_provider.dart';
import '../utility_dashboard_common/chart_theme.dart';
import '../utility_dashboard_overview/utility_dashboard_overview_widgets/chart_state_widgets.dart';
import '../utility_dashboard_overview/utility_dashboard_overview_widgets/scada_tab_button.dart';
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
  int _selectedScadaIndex = 0;
  int _selectedBoxIdIndex = 0;
  int _selectedBoxDeviceIndex = -1;

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

    await _catalog.loadScadas(facId: selectedFac, cate: selectedCate);

    if (!mounted || token != _loadToken) return;

    final scadas = _catalog.scadaIds;

    setState(() {
      _selectedScadaIndex = 0;
      _selectedBoxIdIndex = 0;
      _selectedBoxDeviceIndex = -1;
    });

    if (scadas.isEmpty) return;

    final scadaId = scadas.first;

    _catalog.selectScadaId(scadaId);

    await _catalog.loadBoxes(
      facId: selectedFac,
      cate: selectedCate,
      scadaId: scadaId,
    );

    if (!mounted || token != _loadToken) return;

    final boxIds = _catalog.boxIds;

    if (boxIds.isEmpty) return;

    _catalog.selectBoxId(boxIds.first);

    await _catalog.loadChartsForBoxGroup(
      facId: selectedFac,
      cate: selectedCate,
      scadaId: scadaId,
      importantOnly: _importantOnly ? 1 : 0,
    );
  }

  Future<void> _loadChartsForBox(String boxDeviceId, {int? token}) async {
    final currentToken = token ?? ++_loadToken;
    final scadaId = _safeSelectedScada(_catalog.scadaIds);

    await _catalog.loadChartsForBox(
      facId: selectedFac,
      cate: selectedCate,
      scadaId: scadaId,
      boxDeviceId: boxDeviceId,
      importantOnly: _importantOnly ? 1 : 0,
    );

    if (!mounted || currentToken != _loadToken) return;
  }

  Future<void> _loadChartsForCurrentBoxGroup({int? token}) async {
    final currentToken = token ?? ++_loadToken;
    final scadaId = _safeSelectedScada(_catalog.scadaIds);

    await _catalog.loadChartsForBoxGroup(
      facId: selectedFac,
      cate: selectedCate,
      scadaId: scadaId,
      importantOnly: _importantOnly ? 1 : 0,
    );

    if (!mounted || currentToken != _loadToken) return;
  }

  Future<void> _onCateChanged(int index) async {
    if (_selectedCateIndex == index) return;

    setState(() {
      _selectedCateIndex = index;
      _selectedScadaIndex = 0;
      _selectedBoxIdIndex = 0;
      _selectedBoxDeviceIndex = -1;
    });

    await _loadCatalogForCurrentSelection();
  }

  Future<void> _onFacChanged(int index) async {
    if (_selectedFacIndex == index) return;

    setState(() {
      _selectedFacIndex = index;
      _selectedScadaIndex = 0;
      _selectedBoxIdIndex = 0;
      _selectedBoxDeviceIndex = -1;
    });

    await _loadCatalogForCurrentSelection();
  }

  Future<void> _onScadaChanged(List<String> tabs, int index) async {
    if (tabs.isEmpty || index >= tabs.length) return;

    final scadaId = tabs[index];

    setState(() {
      _selectedScadaIndex = index;
      _selectedBoxIdIndex = 0;
      _selectedBoxDeviceIndex = -1;
    });

    _catalog.selectScadaId(scadaId);

    await _catalog.loadBoxes(
      facId: selectedFac,
      cate: selectedCate,
      scadaId: scadaId,
    );

    final boxIds = _catalog.boxIds;

    if (boxIds.isNotEmpty) {
      _catalog.selectBoxId(boxIds.first);
    }

    await _loadChartsForCurrentBoxGroup();
  }

  void _onViewChanged(int index) {
    if (_selectedViewIndex == index) return;

    setState(() {
      _selectedViewIndex = index;
    });
  }

  Future<void> _onBoxIdChanged(List<String> tabs, int index) async {
    if (tabs.isEmpty || index >= tabs.length) return;

    final boxId = tabs[index];

    setState(() {
      _selectedBoxIdIndex = index;
      _selectedBoxDeviceIndex = -1;
    });

    _catalog.selectBoxId(boxId);

    await _loadChartsForCurrentBoxGroup();
  }

  Future<void> _onBoxDeviceChanged(List<String> tabs, int index) async {
    if (tabs.isEmpty || index >= tabs.length) return;

    final boxDevice = tabs[index];

    setState(() {
      _selectedBoxDeviceIndex = index;
    });

    await _loadChartsForBox(boxDevice);
  }

  Future<void> _onImportantChanged(bool value) async {
    setState(() {
      _importantOnly = value;
    });

    if (_selectedBoxDeviceIndex >= 0) {
      final selectedBoxDevice = _safeSelectedBoxDevice(
        context.read<ChartCatalogProvider>().boxDeviceIds,
      );

      if (selectedBoxDevice != null && selectedBoxDevice.trim().isNotEmpty) {
        await _loadChartsForBox(selectedBoxDevice);
      }

      return;
    }

    await _loadChartsForCurrentBoxGroup();
  }

  void _toggleFilters() {
    setState(() {
      _filtersExpanded = !_filtersExpanded;
    });
  }

  String? _safeSelectedScada(List<String> tabs) {
    if (tabs.isEmpty) return null;

    if (_selectedScadaIndex < 0 || _selectedScadaIndex >= tabs.length) {
      _selectedScadaIndex = 0;
    }

    return tabs[_selectedScadaIndex];
  }

  String? _safeSelectedBoxId(List<String> tabs) {
    if (tabs.isEmpty) return null;

    if (_selectedBoxIdIndex < 0 || _selectedBoxIdIndex >= tabs.length) {
      _selectedBoxIdIndex = 0;
    }

    return tabs[_selectedBoxIdIndex];
  }

  String? _safeSelectedBoxDevice(List<String> tabs) {
    if (tabs.isEmpty) return null;
    if (_selectedBoxDeviceIndex < 0) return null;

    if (_selectedBoxDeviceIndex >= tabs.length) {
      _selectedBoxDeviceIndex = 0;
    }

    return tabs[_selectedBoxDeviceIndex];
  }

  ChartTheme getThemeByCate(String? cate) {
    switch (cate?.toLowerCase()) {
      case 'electricity':
        return ChartThemes.power;
      case 'water':
        return ChartThemes.water;
      case 'compressed air':
      case 'compressor_air':
        return ChartThemes.air;
      default:
        return ChartThemes.power;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scadaTabs = context.select<ChartCatalogProvider, List<String>>(
      (p) => p.scadaIds,
    );

    final boxIdTabs = context.select<ChartCatalogProvider, List<String>>(
      (p) => p.boxIds,
    );

    final boxDeviceTabs = context.select<ChartCatalogProvider, List<String>>(
      (p) => p.boxDeviceIds,
    );

    final selectedScada = _safeSelectedScada(scadaTabs);
    final selectedBoxId = _safeSelectedBoxId(boxIdTabs);
    final selectedBoxDevice = _safeSelectedBoxDevice(boxDeviceTabs);

    final selectedDisplay = _selectedBoxDeviceIndex >= 0
        ? (selectedBoxDevice ?? '-')
        : (selectedBoxId == null ? '-' : '$selectedBoxId (ALL DEVICES)');

    final theme = getThemeByCate(selectedCate);

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E27), Color(0xFF020B16)],
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
              selectedScada: selectedScada,
              selectedBox: selectedDisplay,
              viewTabs: _viewTabs,
              selectedViewIndex: _selectedViewIndex,
              onViewChanged: _onViewChanged,
              importantOnly: _importantOnly,
              onToggleFilters: _toggleFilters,
              onImportantChanged: _onImportantChanged,
              showImportantSwitch: selectedView == 'Minutes',
              importantEnabled: selectedBoxId != null,
              theme: theme,
            ),
            const SizedBox(height: 8),
            _FiltersArea(
              expanded: _filtersExpanded,
              cateTabs: _cateTabs,
              facTabs: _facTabs,
              scadaTabs: scadaTabs,
              boxIdTabs: boxIdTabs,
              boxDeviceTabs: boxDeviceTabs,
              selectedCateIndex: _selectedCateIndex,
              selectedFacIndex: _selectedFacIndex,
              selectedScadaIndex: scadaTabs.isEmpty ? 0 : _selectedScadaIndex,
              selectedBoxIdIndex: boxIdTabs.isEmpty ? 0 : _selectedBoxIdIndex,
              selectedBoxDeviceIndex:
                  boxDeviceTabs.isEmpty || _selectedBoxDeviceIndex < 0
                  ? 0
                  : _selectedBoxDeviceIndex,
              selectedAllDevices: _selectedBoxDeviceIndex < 0,
              onCateChanged: _onCateChanged,
              onFacChanged: _onFacChanged,
              onScadaChanged: (i) => _onScadaChanged(scadaTabs, i),
              onBoxIdChanged: (i) => _onBoxIdChanged(boxIdTabs, i),
              onBoxDeviceChanged: (i) => _onBoxDeviceChanged(boxDeviceTabs, i),
              onAllDevicesSelected: () async {
                setState(() {
                  _selectedBoxDeviceIndex = -1;
                });

                await _loadChartsForCurrentBoxGroup();
              },
              theme: theme,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _CatalogBody(
                selectedBox: selectedDisplay,
                selectedCate: selectedCate,
                selectedFac: selectedFac,
                selectedScada: selectedScada,
                importantOnly: _importantOnly,
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
  final String? selectedScada;
  final bool importantOnly;

  const _CatalogBody({
    required this.selectedBox,
    required this.selectedCate,
    required this.selectedFac,
    required this.selectedScada,
    required this.importantOnly,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ChartThemes.getThemeByCate(selectedCate);

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
          return Center(
            child: CircularProgressIndicator(
              color: theme.line,
              strokeWidth: 2.4,
            ),
          );
        }

        if (vm.error != null && vm.charts.isEmpty) {
          return ChartApiErrorState(
            color: theme.line,
            onRetry: () {
              context.read<ChartCatalogProvider>().loadChartsForBoxGroup(
                facId: selectedFac,
                cate: selectedCate,
                scadaId: selectedScada,
                importantOnly: importantOnly ? 1 : 0,
              );
            },
          );
        }

        if (vm.charts.isEmpty) {
          return EmptyChartState(
            icon: Icons.sensors_off_rounded,
            title: 'No Signals Available',
            message:
                'No utility signals found in ${selectedBox ?? "-"} / ${selectedScada ?? "-"}',
            color: Colors.white.withOpacity(0.58),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = _resolveGridColumnCount(
              constraints.maxWidth,
            );

            return GridView.builder(
              key: PageStorageKey(
                'utility_chart_grid_${selectedFac}_${selectedCate}_${selectedScada ?? ""}',
              ),
              padding: const EdgeInsets.only(top: 4),
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

                debugPrint(
                  '${chart.nameEn} => '
                  '${SignalWidgetResolver.resolve(chart.nameEn)}',
                );
                return RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: UtilityMinuteChartPanel(
                      key: ValueKey(
                        '${selectedFac}_${selectedCate}_${selectedScada}_${chart.boxDeviceId}_${chart.plcAddress}',
                      ),
                      facId: selectedFac,
                      scadaId: selectedScada,
                      cate: selectedCate,
                      boxDeviceId: chart.boxDeviceId,
                      plcAddress: chart.plcAddress,
                      cateIds: chart.cateIds,
                    ),
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
  final String? selectedScada;
  final String? selectedBox;
  final List<String> viewTabs;
  final int selectedViewIndex;
  final ValueChanged<int> onViewChanged;
  final bool importantOnly;
  final ValueChanged<bool> onImportantChanged;
  final VoidCallback onToggleFilters;
  final bool showImportantSwitch;
  final bool importantEnabled;
  final ChartTheme theme;

  const _TopBar({
    required this.filtersExpanded,
    required this.selectedCate,
    required this.selectedFac,
    required this.selectedScada,
    required this.selectedBox,
    required this.viewTabs,
    required this.selectedViewIndex,
    required this.onViewChanged,
    required this.importantOnly,
    required this.onImportantChanged,
    required this.onToggleFilters,
    required this.showImportantSwitch,
    required this.importantEnabled,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CollapseToggle(
          expanded: filtersExpanded,
          onTap: onToggleFilters,
          theme: theme,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GlassTabRow(
            labels: viewTabs,
            selectedIndex: selectedViewIndex,
            onSelect: onViewChanged,
            theme: theme,
          ),
        ),
        if (!filtersExpanded)
          Expanded(
            child: Text(
              'Cate: $selectedCate   •   Fac: $selectedFac   •   SCADA: ${selectedScada ?? "-"}   •   Box: ${selectedBox ?? "-"}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withOpacity(0.70)),
            ),
          ),
        const SizedBox(width: 12),
        if (showImportantSwitch)
          _ImportantSwitch(
            value: importantOnly,
            enabled: importantEnabled,
            onChanged: onImportantChanged,
            theme: theme,
          ),
      ],
    );
  }
}

class _FiltersArea extends StatelessWidget {
  final bool expanded;
  final List<String> cateTabs;
  final List<String> facTabs;
  final List<String> scadaTabs;
  final List<String> boxIdTabs;
  final List<String> boxDeviceTabs;
  final int selectedCateIndex;
  final int selectedFacIndex;
  final int selectedScadaIndex;
  final int selectedBoxIdIndex;
  final int selectedBoxDeviceIndex;
  final bool selectedAllDevices;
  final ValueChanged<int> onCateChanged;
  final ValueChanged<int> onFacChanged;
  final ValueChanged<int> onScadaChanged;
  final ValueChanged<int> onBoxIdChanged;
  final ValueChanged<int> onBoxDeviceChanged;
  final VoidCallback onAllDevicesSelected;
  final ChartTheme theme;

  const _FiltersArea({
    required this.expanded,
    required this.cateTabs,
    required this.facTabs,
    required this.scadaTabs,
    required this.boxIdTabs,
    required this.boxDeviceTabs,
    required this.selectedCateIndex,
    required this.selectedFacIndex,
    required this.selectedScadaIndex,
    required this.selectedBoxIdIndex,
    required this.selectedBoxDeviceIndex,
    required this.selectedAllDevices,
    required this.onCateChanged,
    required this.onFacChanged,
    required this.onScadaChanged,
    required this.onBoxIdChanged,
    required this.onBoxDeviceChanged,
    required this.onAllDevicesSelected,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: expanded
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _GlassTabRow(
                        labels: cateTabs,
                        selectedIndex: selectedCateIndex,
                        onSelect: onCateChanged,
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _GlassTabRow(
                      labels: facTabs,
                      selectedIndex: selectedFacIndex,
                      onSelect: onFacChanged,
                      alignRight: true,
                      theme: theme,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _GlassTabRow(
                    labels: scadaTabs.isEmpty
                        ? const ['(no scada)']
                        : scadaTabs,
                    selectedIndex: scadaTabs.isEmpty ? 0 : selectedScadaIndex,
                    onSelect: scadaTabs.isEmpty ? (_) {} : onScadaChanged,
                    theme: theme,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _GlassTabRow(
                    labels: boxIdTabs.isEmpty
                        ? const ['(no boxId)']
                        : boxIdTabs,
                    selectedIndex: boxIdTabs.isEmpty ? 0 : selectedBoxIdIndex,
                    onSelect: boxIdTabs.isEmpty ? (_) {} : onBoxIdChanged,
                    theme: theme,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _GlassTabRow(
                    labels: boxDeviceTabs.isEmpty
                        ? const ['(no device)']
                        : boxDeviceTabs,
                    selectedIndex: boxDeviceTabs.isEmpty || selectedAllDevices
                        ? -1
                        : selectedBoxDeviceIndex,
                    onSelect: boxDeviceTabs.isEmpty
                        ? (_) {}
                        : onBoxDeviceChanged,
                    theme: theme,
                    showAllChip: true,
                    allChipSelected: selectedAllDevices,
                    onAllTap: onAllDevicesSelected,
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
  final ChartTheme theme;

  const _CollapseToggle({
    required this.expanded,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: expanded
                ? theme.line.withOpacity(0.30)
                : Colors.white.withOpacity(0.14),
          ),
          boxShadow: expanded
              ? [
                  BoxShadow(
                    color: theme.line.withOpacity(0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
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
  final ChartTheme theme;

  const _ImportantSwitch({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value
              ? theme.line.withOpacity(0.30)
              : Colors.white.withOpacity(0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 18,
            color: value ? theme.line : Colors.white54,
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
            value: value,
            activeColor: theme.line,
            onChanged: enabled ? onChanged : null,
          ),
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
  final ChartTheme theme;
  final bool showAllChip;
  final bool allChipSelected;
  final VoidCallback? onAllTap;

  const _GlassTabRow({
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
    required this.theme,
    this.alignRight = false,
    this.showAllChip = false,
    this.allChipSelected = false,
    this.onAllTap,
  });

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ScadaTabButton(
      label: label,
      selected: selected,
      onTap: onTap,
      color: theme.line,
      minWidth: label.length <= 4 ? 66 : 92,
    );
  }

  // Widget _buildChip({
  //   required String label,
  //   required bool selected,
  //   required VoidCallback onTap,
  // }) {
  //   return InkWell(
  //     onTap: onTap,
  //     borderRadius: BorderRadius.circular(12),
  //     child: AnimatedContainer(
  //       duration: const Duration(milliseconds: 180),
  //       curve: Curves.easeOut,
  //       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  //       decoration: BoxDecoration(
  //         color: selected
  //             ? theme.line.withOpacity(0.14)
  //             : Colors.white.withOpacity(0.04),
  //         borderRadius: BorderRadius.circular(6),
  //         border: Border.all(
  //           color: selected
  //               ? theme.line.withOpacity(0.55)
  //               : Colors.white.withOpacity(0.10),
  //         ),
  //         boxShadow: selected
  //             ? [
  //                 BoxShadow(
  //                   color: theme.line.withOpacity(0.22),
  //                   blurRadius: 14,
  //                   offset: const Offset(0, 4),
  //                 ),
  //               ]
  //             : [
  //                 BoxShadow(
  //                   color: Colors.black.withOpacity(0.18),
  //                   blurRadius: 8,
  //                   offset: const Offset(0, 2),
  //                 ),
  //               ],
  //       ),
  //       child: Text(
  //         label,
  //         style: TextStyle(
  //           color: selected ? theme.line : Colors.white.withOpacity(0.78),
  //           fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
  //         ),
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (showAllChip) {
      children.add(
        _buildChip(
          label: 'ALL',
          selected: allChipSelected,
          onTap: onAllTap ?? () {},
        ),
      );
    }
    children.addAll(
      List.generate(labels.length, (index) {
        final selected = index == selectedIndex;

        return _buildChip(
          label: labels[index],
          selected: selected,
          onTap: () => onSelect(index),
        );
      }),
    );

    final tabs = Wrap(spacing: 8, runSpacing: 8, children: children);

    return alignRight
        ? Align(alignment: Alignment.topRight, child: tabs)
        : tabs;
  }
}
