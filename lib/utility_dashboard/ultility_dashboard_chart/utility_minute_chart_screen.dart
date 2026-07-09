import 'dart:math' as math;
import 'dart:ui';

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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E27), Color(0xFF020B16)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: UtilityPaintBackground(
                cate: selectedCate,
                color: theme.line,
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(8),
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
                    selectedScadaIndex: scadaTabs.isEmpty
                        ? 0
                        : _selectedScadaIndex,
                    selectedBoxIdIndex: boxIdTabs.isEmpty
                        ? 0
                        : _selectedBoxIdIndex,
                    selectedBoxDeviceIndex:
                        boxDeviceTabs.isEmpty || _selectedBoxDeviceIndex < 0
                        ? 0
                        : _selectedBoxDeviceIndex,
                    selectedAllDevices: _selectedBoxDeviceIndex < 0,
                    onCateChanged: _onCateChanged,
                    onFacChanged: _onFacChanged,
                    onScadaChanged: (i) => _onScadaChanged(scadaTabs, i),
                    onBoxIdChanged: (i) => _onBoxIdChanged(boxIdTabs, i),
                    onBoxDeviceChanged: (i) =>
                        _onBoxDeviceChanged(boxDeviceTabs, i),
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
    final theme = ChartThemes.byCate(selectedCate);

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

enum UtilityPaintType { electricity, water, air }

class UtilityPaintBackground extends StatefulWidget {
  final String cate;
  final Color color;
  final bool animated;

  const UtilityPaintBackground({
    super.key,
    required this.cate,
    required this.color,
    this.animated = true,
  });

  @override
  State<UtilityPaintBackground> createState() => _UtilityPaintBackgroundState();
}

class _UtilityPaintBackgroundState extends State<UtilityPaintBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  UtilityPaintType get _type {
    final value = widget.cate.trim().toLowerCase();

    if (value.contains('water')) {
      return UtilityPaintType.water;
    }

    if (value.contains('air') || value.contains('compressed')) {
      return UtilityPaintType.air;
    }

    return UtilityPaintType.electricity;
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );

    if (widget.animated) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant UtilityPaintBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.animated != widget.animated) {
      if (widget.animated) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          child: Stack(
            key: ValueKey('premium_bg_${_type.name}'),
            fit: StackFit.expand,
            children: [
              // STATIC LAYER: không repaint theo animation
              CustomPaint(
                painter: _UtilityPremiumBackgroundPainter(
                  color: widget.color,
                  type: _type,
                  drawStatic: true,
                  drawMotion: false,
                ),
              ),

              // MOTION LAYER: chỉ repaint phần động
              if (widget.animated)
                CustomPaint(
                  painter: _UtilityPremiumBackgroundPainter(
                    color: widget.color,
                    type: _type,
                    animation: _controller,
                    drawStatic: false,
                    drawMotion: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UtilityPremiumBackgroundPainter extends CustomPainter {
  final Color color;
  final UtilityPaintType type;
  final Animation<double>? animation;
  final bool drawStatic;
  final bool drawMotion;

  Size? _cachedWaterSize;
  List<PathMetric> _cachedWaterMetrics = const [];

  _UtilityPremiumBackgroundPainter({
    required this.color,
    required this.type,
    this.animation,
    this.drawStatic = true,
    this.drawMotion = false,
  }) : super(repaint: animation);

  double get t => animation?.value ?? 0.0;

  Paint _stroke(double opacity, double width) {
    return Paint()
      ..color = color.withOpacity(opacity)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }

  Paint _glow(double opacity, double width, double blur) {
    return Paint()
      ..color = color.withOpacity(opacity)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
  }

  Paint _motionLine({
    required double opacity,
    required double width,
    bool glow = false,
  }) {
    return Paint()
      ..color = color.withOpacity(opacity)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      // Không dùng BlendMode.plus nữa, vì nó làm nét sáng bị gắt và thô.
      ..maskFilter = glow ? const MaskFilter.blur(BlurStyle.normal, 3) : null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (drawStatic) {
      _drawAmbientGlow(canvas, size);
      _drawBlueprintGrid(canvas, size);

      switch (type) {
        case UtilityPaintType.electricity:
          _drawElectricity(canvas, size);
          break;
        case UtilityPaintType.water:
          _drawWater(canvas, size);
          break;
        case UtilityPaintType.air:
          _drawAir(canvas, size);
          break;
      }

      _drawVignette(canvas, size);
    }

    if (drawMotion) {
      switch (type) {
        case UtilityPaintType.electricity:
          _drawElectricMovingCurrent(canvas, size);
          break;
        case UtilityPaintType.water:
          _drawWaterMovingFlow(canvas, size);
          break;
        case UtilityPaintType.air:
          _drawAirMovingFlow(canvas, size);
          break;
      }
    }
  }

  // ============================================================
  // COMMON BACKGROUND
  // ============================================================

  void _drawAmbientGlow(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final topGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              color.withOpacity(.1),
              color.withOpacity(.045),
              Colors.transparent,
            ],
            stops: const [0, .42, 1],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .18, size.height * .16),
              radius: size.width * .58,
            ),
          );

    final bottomGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              color.withOpacity(.12),
              color.withOpacity(.032),
              Colors.transparent,
            ],
            stops: const [0, .46, 1],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .86, size.height * .82),
              radius: size.width * .50,
            ),
          );

    canvas.drawRect(rect, topGlow);
    canvas.drawRect(rect, bottomGlow);
  }

  void _drawBlueprintGrid(Canvas canvas, Size size) {
    final minorPaint = Paint()
      ..color = Colors.white.withOpacity(.025)
      ..strokeWidth = .65
      ..style = PaintingStyle.stroke;

    final majorPaint = Paint()
      ..color = color.withOpacity(.045)
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke;

    const minor = 36.0;
    const major = 144.0;

    for (double x = 0; x <= size.width; x += minor) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorPaint);
    }

    for (double y = 0; y <= size.height; y += minor) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minorPaint);
    }

    for (double x = 0; x <= size.width; x += major) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), majorPaint);
    }

    for (double y = 0; y <= size.height; y += major) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), majorPaint);
    }

    final diagonalPaint = Paint()
      ..color = Colors.white.withOpacity(.018)
      ..strokeWidth = .7
      ..style = PaintingStyle.stroke;

    for (double x = -size.height; x < size.width; x += 120) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        diagonalPaint,
      );
    }
  }

  void _drawVignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final p = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(.10),
          Colors.black.withOpacity(.22),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);

    canvas.drawRect(rect, p);
  }

  // ============================================================
  // ELECTRICITY
  // ============================================================

  // ============================================================
  // ELECTRICITY — HIGH VOLTAGE STYLE
  // ============================================================

  void _drawElectricity(Canvas canvas, Size size) {
    _drawHighVoltageWatermark(canvas, size);
    _drawHighVoltageGrid(canvas, size);
    _drawVoltageArcs(canvas, size);
  }

  /// Watermark cột điện lớn rất mờ ở góc phải.
  /// Nhìn như silhouette, tạo cảm giác industrial/high-voltage.
  void _drawHighVoltageWatermark(Canvas canvas, Size size) {
    final center = Offset(size.width * .82, size.height * .50);
    final height = math.min(size.height * .72, 420.0);
    final base = Offset(center.dx, center.dy + height * .42);

    final glow = _glow(.018, 6, 8);
    final paint = _stroke(.18, 1.45);

    _drawTransmissionTower(
      canvas,
      base: base,
      height: height,
      width: height * .42,
      paint: paint,
      glowPaint: glow,
      opacityBoost: .85,
    );

    // Vùng sáng nhẹ sau cột.
    final halo = Paint()
      ..shader =
          RadialGradient(
            colors: [
              color.withOpacity(.12),
              color.withOpacity(.035),
              Colors.transparent,
            ],
            stops: const [0, .42, 1],
          ).createShader(
            Rect.fromCircle(
              center: Offset(center.dx, center.dy - height * .08),
              radius: height * .58,
            ),
          );

    canvas.drawCircle(
      Offset(center.dx, center.dy - height * .08),
      height * .58,
      halo,
    );
  }

  /// Lưới cột điện cao thế nhỏ chạy ngang nền.
  /// Có dây điện võng, chuỗi sứ và cross-arm.
  void _drawHighVoltageGrid(Canvas canvas, Size size) {
    final towerPaint = _stroke(.18, 1.22);
    final towerGlow = _glow(.018, 4.2, 6);

    final wirePaint = _stroke(.16, 1.05);
    final wireGlow = _glow(.014, 3.6, 5);

    const stepX = 245.0;
    const stepY = 185.0;

    final rows = (size.height / stepY).ceil() + 2;
    final cols = (size.width / stepX).ceil() + 3;

    for (int row = -1; row < rows; row++) {
      final y = row * stepY + 150;
      final offsetX = row.isOdd ? stepX * .45 : 0.0;

      final tops = <Offset>[];
      final leftWirePoints = <Offset>[];
      final rightWirePoints = <Offset>[];

      for (int col = -1; col < cols; col++) {
        final x = col * stepX + offsetX;
        final base = Offset(x, y);
        final h = row.isEven ? 88.0 : 76.0;
        final w = h * .42;

        _drawTransmissionTower(
          canvas,
          base: base,
          height: h,
          width: w,
          paint: towerPaint,
          glowPaint: towerGlow,
        );

        tops.add(Offset(x, y - h));

        leftWirePoints.add(Offset(x - w * .48, y - h * .74));
        rightWirePoints.add(Offset(x + w * .48, y - h * .74));
      }

      _connectSaggingWires(canvas, leftWirePoints, wirePaint, wireGlow);
      _connectSaggingWires(canvas, rightWirePoints, wirePaint, wireGlow);
      _connectSaggingWires(canvas, tops, wirePaint, wireGlow);
    }
  }

  /// Vẽ một cột điện cao thế.
  /// Có 2 chân xiên, thân giàn, cross-arm và chuỗi sứ.
  void _drawTowerIndustrialDetails(
    Canvas canvas, {
    required Offset base,
    required Offset top,
    required double height,
    required double width,
  }) {
    final detailPaint = _stroke(.18, .75);
    final nodePaint = Paint()
      ..color = color.withOpacity(.20)
      ..style = PaintingStyle.fill;

    // Xương sống giữa trụ.
    canvas.drawLine(
      top + Offset(0, height * .08),
      base - Offset(0, height * .06),
      detailPaint,
    );

    // Base plate / chân móng.
    final baseY = base.dy;
    canvas.drawLine(
      Offset(base.dx - width * .58, baseY + 3),
      Offset(base.dx + width * .58, baseY + 3),
      detailPaint,
    );

    canvas.drawLine(
      Offset(base.dx - width * .42, baseY + 7),
      Offset(base.dx - width * .22, baseY + 7),
      detailPaint,
    );

    canvas.drawLine(
      Offset(base.dx + width * .22, baseY + 7),
      Offset(base.dx + width * .42, baseY + 7),
      detailPaint,
    );

    // Bolt/node ở các tầng giàn.
    final levels = <double>[.22, .42, .62, .82];

    for (final k in levels) {
      final y = top.dy + height * k;
      final spread = width * .46 * k;

      canvas.drawCircle(Offset(base.dx - spread, y), 1.45, nodePaint);
      canvas.drawCircle(Offset(base.dx + spread, y), 1.45, nodePaint);
      canvas.drawCircle(Offset(base.dx, y), 1.15, nodePaint);
    }

    // End-cap ở cross arm để nhìn rõ sứ/dây.
    final armYs = [
      top.dy + height * .18,
      top.dy + height * .32,
      top.dy + height * .48,
    ];

    final armWidths = [width * 1.18, width * 1.45, width * 1.05];

    for (int i = 0; i < armYs.length; i++) {
      final y = armYs[i];
      final w = armWidths[i];

      canvas.drawCircle(Offset(base.dx - w / 2, y), 1.6, nodePaint);
      canvas.drawCircle(Offset(base.dx + w / 2, y), 1.6, nodePaint);

      canvas.drawLine(
        Offset(base.dx - w / 2, y - 4),
        Offset(base.dx - w / 2, y + 4),
        detailPaint,
      );

      canvas.drawLine(
        Offset(base.dx + w / 2, y - 4),
        Offset(base.dx + w / 2, y + 4),
        detailPaint,
      );
    }
  }

  void _drawTransmissionTower(
    Canvas canvas, {
    required Offset base,
    required double height,
    required double width,
    required Paint paint,
    required Paint glowPaint,
    double opacityBoost = 1.0,
  }) {
    final top = Offset(base.dx, base.dy - height);
    final bottomLeft = Offset(base.dx - width * .46, base.dy);
    final bottomRight = Offset(base.dx + width * .46, base.dy);

    final p = Path()
      // 2 chân chính
      ..moveTo(top.dx, top.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..moveTo(top.dx, top.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      // chân đáy
      ..moveTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy);

    // Các thanh ngang + giằng chéo.
    final levels = <double>[.22, .42, .62, .82];

    for (final t in levels) {
      final y = top.dy + height * t;
      final spread = width * .46 * t;

      final left = Offset(base.dx - spread, y);
      final right = Offset(base.dx + spread, y);

      p
        ..moveTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy);
    }

    for (int i = 0; i < levels.length - 1; i++) {
      final t1 = levels[i];
      final t2 = levels[i + 1];

      final y1 = top.dy + height * t1;
      final y2 = top.dy + height * t2;

      final s1 = width * .46 * t1;
      final s2 = width * .46 * t2;

      p
        ..moveTo(base.dx - s1, y1)
        ..lineTo(base.dx + s2, y2)
        ..moveTo(base.dx + s1, y1)
        ..lineTo(base.dx - s2, y2);
    }

    // Cross arms.
    final arm1Y = top.dy + height * .18;
    final arm2Y = top.dy + height * .32;
    final arm3Y = top.dy + height * .48;

    _drawCrossArm(
      canvas,
      center: Offset(base.dx, arm1Y),
      width: width * 1.18,
      paint: paint,
    );
    _drawCrossArm(
      canvas,
      center: Offset(base.dx, arm2Y),
      width: width * 1.45,
      paint: paint,
    );
    _drawCrossArm(
      canvas,
      center: Offset(base.dx, arm3Y),
      width: width * 1.05,
      paint: paint,
    );

    canvas.drawPath(p, glowPaint);
    canvas.drawPath(p, paint);

    // Chuỗi sứ hai bên.
    _drawInsulatorString(canvas, Offset(base.dx - width * .58, arm2Y), paint);
    _drawInsulatorString(canvas, Offset(base.dx + width * .58, arm2Y), paint);
    _drawInsulatorString(canvas, Offset(base.dx - width * .42, arm3Y), paint);
    _drawInsulatorString(canvas, Offset(base.dx + width * .42, arm3Y), paint);

    // Đỉnh cột glow nhẹ.
    canvas.drawCircle(
      top,
      2.2,
      Paint()..color = color.withOpacity(.18 * opacityBoost),
    );
    _drawTowerIndustrialDetails(
      canvas,
      base: base,
      top: top,
      height: height,
      width: width,
    );
  }

  void _drawCrossArm(
    Canvas canvas, {
    required Offset center,
    required double width,
    required Paint paint,
  }) {
    final left = Offset(center.dx - width / 2, center.dy);
    final right = Offset(center.dx + width / 2, center.dy);

    canvas.drawLine(left, right, paint);

    // Hai thanh chống xiên nhỏ.
    canvas.drawLine(
      Offset(center.dx - width * .26, center.dy),
      Offset(center.dx, center.dy + 12),
      paint,
    );

    canvas.drawLine(
      Offset(center.dx + width * .26, center.dy),
      Offset(center.dx, center.dy + 12),
      paint,
    );
  }

  /// Chuỗi sứ cách điện dạng các hạt nhỏ nối xuống dưới.
  void _drawInsulatorString(Canvas canvas, Offset start, Paint paint) {
    final beadPaint = Paint()
      ..color = color.withOpacity(.105)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;

    canvas.drawLine(start, start + const Offset(0, 17), paint);

    for (int i = 0; i < 4; i++) {
      final c = start + Offset(0, 4.0 + i * 3.8);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 7, height: 2.8),
        beadPaint,
      );
    }
  }

  /// Nối dây điện võng giữa các cột.
  void _connectSaggingWires(
    Canvas canvas,
    List<Offset> points,
    Paint paint,
    Paint glowPaint,
  ) {
    if (points.length < 2) return;

    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];

      final distance = (b - a).distance;
      final sag = math.min(18.0, distance * .08);

      final mid = Offset((a.dx + b.dx) / 2, math.max(a.dy, b.dy) + sag);

      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, paint);
    }
  }

  /// Các tia điện nhỏ trang trí, rất mờ.
  void _drawVoltageArcs(Canvas canvas, Size size) {
    final arcPaint = _stroke(.12, 1.05);
    final arcGlow = _glow(.026, 5, 9);

    for (double x = 80; x < size.width; x += 260) {
      for (double y = 70; y < size.height; y += 210) {
        final path = Path()
          ..moveTo(x, y)
          ..lineTo(x + 14, y - 10)
          ..lineTo(x + 6, y + 6)
          ..lineTo(x + 22, y - 2)
          ..lineTo(x + 12, y + 16);

        canvas.drawPath(path, arcGlow);
        canvas.drawPath(path, arcPaint);
      }
    }

    // Một vài node sáng nhỏ.
    final nodePaint = Paint()
      ..color = color.withOpacity(.15)
      ..style = PaintingStyle.fill;

    final ringPaint = _stroke(.075, .8);

    for (double x = 120; x < size.width; x += 220) {
      for (double y = 120; y < size.height; y += 180) {
        canvas.drawCircle(Offset(x, y), 2.1, nodePaint);
        canvas.drawCircle(Offset(x + 32, y - 26), 5.5, ringPaint);
      }
    }
  }

  // ============================================================
  // WATER
  // ============================================================

  // ============================================================
  // WATER — COOLING WATER / INDUSTRIAL PIPE NETWORK STYLE
  // ============================================================

  void _drawWater(Canvas canvas, Size size) {
    _drawCoolingTankSystem(canvas, size);
    _drawWaterPressureHeader(canvas, size);
    _drawWaterPipeNetwork(canvas, size);
    _drawWaterDropsAndBubbles(canvas, size);
    _drawWaterLevelMarks(canvas, size);
  }

  /// Watermark bồn nước lớn rất mờ phía phải.
  /// Tạo cảm giác cooling tank / water utility.
  ///
  void _drawCoolingTankSystem(Canvas canvas, Size size) {
    final tankW = math.min(size.width * .15, 128.0);
    final tankH = math.min(size.height * .38, 245.0);

    final startX = size.width * .58;
    final baseY = size.height * .72;

    final tanks = [
      Rect.fromLTWH(startX, baseY - tankH, tankW, tankH),
      Rect.fromLTWH(
        startX + tankW * .72,
        baseY - tankH * .92,
        tankW,
        tankH * .92,
      ),
      Rect.fromLTWH(
        startX + tankW * 1.42,
        baseY - tankH * .82,
        tankW,
        tankH * .82,
      ),
    ];

    for (int i = 0; i < tanks.length; i++) {
      _drawCoolingTowerCell(canvas, tanks[i], index: i);
    }

    // Header pipe nối các cooling tank.
    final headerY = baseY - tankH * .48;
    final headerPaint = _stroke(.18, 1.35);
    final headerGlow = _glow(.020, 5, 6);

    final header = Path()
      ..moveTo(startX - tankW * .36, headerY)
      ..lineTo(startX + tankW * 2.58, headerY);

    canvas.drawPath(header, headerGlow);
    canvas.drawPath(header, headerPaint);

    // Áp kế nước lớn.
    _drawLargeWaterPressureGauge(
      canvas,
      Offset(startX - tankW * .18, headerY - 28),
      label: 'H2O',
    );

    // Pump icon.
    _drawWaterPumpIcon(canvas, Offset(startX + tankW * .95, headerY + 42));

    // Van lớn trên header.
    _drawWaterValve(canvas, Offset(startX + tankW * 1.92, headerY));
  }

  void _drawCoolingTowerCell(Canvas canvas, Rect rect, {required int index}) {
    final body = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.width * .16),
    );

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(.105), color.withOpacity(.030)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    final linePaint = _stroke(.18, 1.25);
    final softLine = _stroke(.095, .9);
    final glow = _glow(.018, 5, 7);

    canvas.drawRRect(body, fillPaint);
    canvas.drawRRect(body, glow);
    canvas.drawRRect(body, linePaint);

    // Miệng tank / cooling tower top.
    final topOval = Rect.fromCenter(
      center: Offset(rect.center.dx, rect.top + rect.width * .12),
      width: rect.width * .76,
      height: rect.width * .18,
    );

    canvas.drawOval(topOval, linePaint);

    // Fan grille phía trên.
    final fanCenter = Offset(rect.center.dx, rect.top + rect.width * .12);
    canvas.drawCircle(fanCenter, rect.width * .16, softLine);

    for (int i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      canvas.drawLine(
        fanCenter,
        fanCenter + Offset(math.cos(a), math.sin(a)) * rect.width * .14,
        softLine,
      );
    }

    // Vạch nước trong tank.
    final waterY = rect.top + rect.height * (.56 + index * .035);
    final wave = Path();

    for (double x = rect.left + 12; x <= rect.right - 12; x += 8) {
      final y = waterY + math.sin((x / 18) + index) * 2.8;

      if (x == rect.left + 12) {
        wave.moveTo(x, y);
      } else {
        wave.lineTo(x, y);
      }
    }

    canvas.drawPath(wave, _stroke(.24, 1.25));

    // Cooling fins / lưới tản nhiệt.
    for (int i = 0; i < 5; i++) {
      final y = rect.top + rect.height * (.26 + i * .09);

      canvas.drawLine(
        Offset(rect.left + rect.width * .18, y),
        Offset(rect.right - rect.width * .18, y),
        softLine,
      );
    }

    // Level gauge bên hông tank.
    final gaugeX = rect.right - rect.width * .18;
    canvas.drawLine(
      Offset(gaugeX, rect.top + rect.height * .30),
      Offset(gaugeX, rect.bottom - rect.height * .18),
      softLine,
    );

    for (int i = 0; i < 5; i++) {
      final y = rect.top + rect.height * (.34 + i * .095);
      canvas.drawLine(Offset(gaugeX - 8, y), Offset(gaugeX + 8, y), softLine);
    }
  }

  void _drawWaterPressureHeader(Canvas canvas, Size size) {
    final y = size.height * .34;

    final mainPaint = _stroke(.17, 1.35);
    final glowPaint = _glow(.018, 5, 6);

    final path = Path()
      ..moveTo(-30, y)
      ..lineTo(size.width * .22, y)
      ..quadraticBezierTo(size.width * .28, y, size.width * .28, y + 38)
      ..lineTo(size.width * .45, y + 38)
      ..quadraticBezierTo(size.width * .51, y + 38, size.width * .51, y)
      ..lineTo(size.width + 30, y);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, mainPaint);

    // Đồng hồ áp lực nước lớn trên pipe chính.
    _drawLargeWaterPressureGauge(
      canvas,
      Offset(size.width * .34, y - 34),
      label: 'BAR',
    );

    // Pressure pulse marks.
    final markPaint = _stroke(.20, .95);

    for (double x = size.width * .10; x < size.width * .88; x += 92) {
      canvas.drawLine(Offset(x, y - 7), Offset(x + 18, y - 7), markPaint);
      canvas.drawLine(Offset(x + 6, y + 7), Offset(x + 24, y + 7), markPaint);
    }
  }

  void _drawLargeWaterPressureGauge(
    Canvas canvas,
    Offset center, {
    required String label,
  }) {
    final ring = _stroke(.20, 1.2);
    final glow = _glow(.020, 5, 6);
    final tick = _stroke(.13, .8);

    canvas.drawCircle(center, 15, glow);
    canvas.drawCircle(center, 15, ring);

    for (int i = 0; i <= 6; i++) {
      final a = -math.pi * .82 + i * math.pi * .27;
      final p1 = center + Offset(math.cos(a), math.sin(a)) * 10;
      final p2 = center + Offset(math.cos(a), math.sin(a)) * 13;

      canvas.drawLine(p1, p2, tick);
    }

    final needleAngle = -math.pi * .58;
    canvas.drawLine(
      center,
      center + Offset(math.cos(needleAngle), math.sin(needleAngle)) * 10,
      _stroke(.24, 1.15),
    );

    canvas.drawCircle(center, 2.2, Paint()..color = color.withOpacity(.22));

    // Chân gauge nối xuống pipe.
    canvas.drawLine(
      center + const Offset(0, 15),
      center + const Offset(0, 28),
      ring,
    );
  }

  void _drawWaterPumpIcon(Canvas canvas, Offset center) {
    final paint = _stroke(.17, 1.1);
    final glow = _glow(.018, 5, 6);

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 54, height: 30),
      const Radius.circular(8),
    );

    canvas.drawRRect(body, glow);
    canvas.drawRRect(body, paint);

    canvas.drawCircle(center + const Offset(-14, 0), 8, paint);

    canvas.drawLine(
      center + const Offset(-27, 0),
      center + const Offset(-48, 0),
      paint,
    );

    canvas.drawLine(
      center + const Offset(27, 0),
      center + const Offset(48, 0),
      paint,
    );

    // Motor fins.
    for (int i = 0; i < 4; i++) {
      final x = center.dx + 2 + i * 7;
      canvas.drawLine(
        Offset(x, center.dy - 11),
        Offset(x, center.dy + 11),
        _stroke(.10, .75),
      );
    }
  }

  /// Hệ ống nước dạng network, ít lặp hơn và nhìn có chiều sâu hơn.
  void _drawWaterPipeNetwork(Canvas canvas, Size size) {
    final mainGlow = _glow(.030, 7, 10);
    final mainLine = _stroke(.13, 1.25);
    final subLine = _stroke(.095, 1.0);

    final y1 = size.height * .24;
    final y2 = size.height * .48;
    final y3 = size.height * .72;

    final path1 = Path()
      ..moveTo(-40, y1)
      ..lineTo(size.width * .24, y1)
      ..quadraticBezierTo(size.width * .30, y1, size.width * .30, y1 + 42)
      ..lineTo(size.width * .52, y1 + 42)
      ..quadraticBezierTo(size.width * .58, y1 + 42, size.width * .58, y1)
      ..lineTo(size.width + 40, y1);

    final path2 = Path()
      ..moveTo(-40, y2)
      ..lineTo(size.width * .18, y2)
      ..quadraticBezierTo(size.width * .24, y2, size.width * .24, y2 - 38)
      ..lineTo(size.width * .44, y2 - 38)
      ..quadraticBezierTo(size.width * .50, y2 - 38, size.width * .50, y2)
      ..lineTo(size.width + 40, y2);

    final path3 = Path()
      ..moveTo(-40, y3)
      ..lineTo(size.width * .36, y3)
      ..quadraticBezierTo(size.width * .42, y3, size.width * .42, y3 - 34)
      ..lineTo(size.width * .70, y3 - 34)
      ..quadraticBezierTo(size.width * .76, y3 - 34, size.width * .76, y3)
      ..lineTo(size.width + 40, y3);

    for (final path in [path1, path2, path3]) {
      canvas.drawPath(path, mainGlow);
      canvas.drawPath(path, mainLine);
    }

    // Nhánh dọc nối các đường ống.
    final connectors = <Offset>[
      Offset(size.width * .18, y1),
      Offset(size.width * .30, y1 + 42),
      Offset(size.width * .50, y2),
      Offset(size.width * .68, y3 - 34),
    ];

    for (final p in connectors) {
      final path = Path()
        ..moveTo(p.dx, p.dy - 32)
        ..lineTo(p.dx, p.dy + 52);

      canvas.drawPath(path, _glow(.018, 5, 8));
      canvas.drawPath(path, subLine);
    }

    // Flow line bên trong ống.
    _drawPipeFlowLine(canvas, y1, size.width, phase: .0);
    _drawPipeFlowLine(canvas, y2, size.width, phase: 1.7);
    _drawPipeFlowLine(canvas, y3, size.width, phase: 3.1);

    // Van + joint + flange.
    _drawWaterValve(canvas, Offset(size.width * .30, y1 + 42));
    _drawWaterValve(canvas, Offset(size.width * .50, y2));
    _drawWaterValve(canvas, Offset(size.width * .76, y3));

    _drawPipeJoint(canvas, Offset(size.width * .24, y1));
    _drawPipeJoint(canvas, Offset(size.width * .58, y1));
    _drawPipeJoint(canvas, Offset(size.width * .24, y2 - 38));
    _drawPipeJoint(canvas, Offset(size.width * .42, y3 - 34));

    _drawPipeFlanges(canvas, y1, size.width, offset: 30);
    _drawPipeFlanges(canvas, y2, size.width, offset: 95);
    _drawPipeFlanges(canvas, y3, size.width, offset: 60);

    // Đồng hồ áp suất nhỏ.
    _drawWaterGauge(canvas, Offset(size.width * .62, y1 - 26));
    _drawWaterGauge(canvas, Offset(size.width * .38, y3 - 58));
  }

  void _drawPipeFlowLine(
    Canvas canvas,
    double y,
    double width, {
    required double phase,
  }) {
    final flowPaint = Paint()
      ..color = color.withOpacity(.17)
      ..strokeWidth = 1.15
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final flowGlow = Paint()
      ..color = color.withOpacity(.035)
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    final path = Path();

    for (double x = -30; x <= width + 30; x += 12) {
      final yy = y + math.sin((x / 34) + phase) * 4.8;

      if (x == -30) {
        path.moveTo(x, yy);
      } else {
        path.lineTo(x, yy);
      }
    }

    canvas.drawPath(path, flowGlow);
    canvas.drawPath(path, flowPaint);
  }

  /// Van tròn có tay xoay, vẽ nhỏ để không rối nền.
  void _drawWaterValve(Canvas canvas, Offset center) {
    final paint = _stroke(.13, 1.05);
    final glow = _glow(.022, 5, 8);

    canvas.drawCircle(center, 13, glow);
    canvas.drawCircle(center, 13, paint);

    for (int i = 0; i < 4; i++) {
      final a = i * math.pi / 2;

      canvas.drawLine(
        center + Offset(math.cos(a), math.sin(a)) * 3,
        center + Offset(math.cos(a), math.sin(a)) * 11,
        paint,
      );
    }

    canvas.drawCircle(center, 2.4, Paint()..color = color.withOpacity(.16));

    canvas.drawLine(
      center + const Offset(0, -13),
      center + const Offset(0, -24),
      paint,
    );

    canvas.drawLine(
      center + const Offset(-8, -24),
      center + const Offset(8, -24),
      paint,
    );
  }

  /// Joint/khớp nối ống.
  void _drawPipeJoint(Canvas canvas, Offset center) {
    final paint = _stroke(.105, .95);

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 24, height: 18),
      const Radius.circular(4),
    );

    canvas.drawRRect(rect, paint);

    canvas.drawLine(
      center + const Offset(-6, -9),
      center + const Offset(-6, 9),
      paint,
    );

    canvas.drawLine(
      center + const Offset(6, -9),
      center + const Offset(6, 9),
      paint,
    );
  }

  /// Mặt bích lặp theo ống, nhưng opacity nhẹ.
  void _drawPipeFlanges(
    Canvas canvas,
    double y,
    double width, {
    required double offset,
  }) {
    final paint = _stroke(.075, .85);

    for (double x = offset; x < width; x += 170) {
      canvas.drawLine(Offset(x, y - 11), Offset(x, y + 11), paint);

      canvas.drawLine(Offset(x + 6, y - 11), Offset(x + 6, y + 11), paint);
    }
  }

  /// Đồng hồ nhỏ trên pipe.
  void _drawWaterGauge(Canvas canvas, Offset center) {
    final paint = _stroke(.105, .9);

    canvas.drawCircle(center, 7, paint);

    canvas.drawLine(center, center + const Offset(3.5, -3.5), paint);

    canvas.drawLine(
      center + const Offset(0, 7),
      center + const Offset(0, 16),
      paint,
    );
  }

  /// Giọt nước và bubble rải nền, không đều để tự nhiên hơn.
  void _drawWaterDropsAndBubbles(Canvas canvas, Size size) {
    final bubblePaint = _stroke(.07, .85);

    for (double x = 72; x < size.width; x += 235) {
      for (double y = 88; y < size.height; y += 178) {
        canvas.drawCircle(Offset(x, y), 6.5, bubblePaint);
        canvas.drawCircle(Offset(x + 38, y + 28), 3.5, bubblePaint);
        canvas.drawCircle(Offset(x + 78, y - 20), 4.8, bubblePaint);
      }
    }

    final dropPaint = Paint()
      ..color = color.withOpacity(.055)
      ..style = PaintingStyle.fill;

    for (double x = 135; x < size.width; x += 290) {
      for (double y = 135; y < size.height; y += 220) {
        _drawMiniWaterDrop(canvas, Offset(x, y), 10, dropPaint);
      }
    }
  }

  void _drawMiniWaterDrop(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - r)
      ..cubicTo(
        center.dx - r * .68,
        center.dy - r * .20,
        center.dx - r * .52,
        center.dy + r * .72,
        center.dx,
        center.dy + r,
      )
      ..cubicTo(
        center.dx + r * .52,
        center.dy + r * .72,
        center.dx + r * .68,
        center.dy - r * .20,
        center.dx,
        center.dy - r,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  /// Vạch kỹ thuật nhẹ giống blueprint/water level marks.
  void _drawWaterLevelMarks(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(.055)
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (double x = 42; x < size.width; x += 220) {
      final top = size.height * .14;
      final bottom = size.height * .86;

      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);

      for (int i = 0; i < 8; i++) {
        final y = top + i * ((bottom - top) / 7);

        canvas.drawLine(
          Offset(x, y),
          Offset(x + (i.isEven ? 18 : 11), y),
          paint,
        );
      }
    }
  }

  // ============================================================
  // COMPRESSED AIR
  // ============================================================

  void _drawAir(Canvas canvas, Size size) {
    _drawAirFanWatermark(canvas, size);
    _drawAirStreamLines(canvas, size);
    _drawAirDuctNetwork(canvas, size);
  }

  void _drawAirFanWatermark(Canvas canvas, Size size) {
    final center = Offset(size.width * .84, size.height * .24);
    final radius = math.min(size.width, size.height) * .17;

    final ringPaint = _stroke(.10, 1.3);
    final fillPaint = Paint()
      ..color = color.withOpacity(.035)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawCircle(
      center,
      radius * .12,
      Paint()..color = color.withOpacity(.12),
    );

    for (int i = 0; i < 3; i++) {
      final a = -math.pi / 2 + i * math.pi * 2 / 3;

      final p1 =
          center + Offset(math.cos(a - .26), math.sin(a - .26)) * radius * .18;
      final p2 =
          center + Offset(math.cos(a + .18), math.sin(a + .18)) * radius * .78;
      final p3 =
          center + Offset(math.cos(a + .76), math.sin(a + .76)) * radius * .55;

      final blade = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(p3.dx, p3.dy, p2.dx, p2.dy);

      canvas.drawPath(blade, _stroke(.12, 1.4));
    }
  }

  void _drawAirStreamLines(Canvas canvas, Size size) {
    final paint = _stroke(.105, 1.05);
    final glow = _glow(.024, 5, 8);

    for (double y = 78; y < size.height + 80; y += 92) {
      final path = Path()..moveTo(-50, y);

      for (double x = -50; x < size.width + 100; x += 132) {
        path.cubicTo(x + 34, y - 24, x + 86, y + 24, x + 132, y);
      }

      canvas.drawPath(path, glow);
      canvas.drawPath(path, paint);
    }

    final arrowPaint = Paint()
      ..color = color.withOpacity(.11)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (double x = 100; x < size.width; x += 210) {
      for (double y = 80; y < size.height; y += 180) {
        canvas.drawLine(Offset(x, y), Offset(x + 18, y), arrowPaint);
        canvas.drawLine(Offset(x + 18, y), Offset(x + 12, y - 5), arrowPaint);
        canvas.drawLine(Offset(x + 18, y), Offset(x + 12, y + 5), arrowPaint);
      }
    }
  }

  void _drawAirDuctNetwork(Canvas canvas, Size size) {
    final ductPaint = _stroke(.085, 1);
    final machinePaint = _stroke(.12, 1.1);

    for (double y = 122; y < size.height; y += 180) {
      _drawDashedLine(
        canvas,
        Offset(-30, y),
        Offset(size.width + 30, y),
        ductPaint,
      );

      for (double x = 70; x < size.width; x += 260) {
        _drawCompressorIcon(canvas, Offset(x, y));
        _drawPressureGauge(canvas, Offset(x + 70, y - 20), machinePaint);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 9.0;
    const gap = 7.0;

    final total = (b - a).distance;
    final dir = (b - a) / total;

    double current = 0;

    while (current < total) {
      final start = a + dir * current;
      final end = a + dir * math.min(current + dash, total);

      canvas.drawLine(start, end, paint);

      current += dash + gap;
    }
  }

  void _drawCompressorIcon(Canvas canvas, Offset center) {
    final paint = _stroke(.12, 1.05);
    final glow = _glow(.025, 5, 8);

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 48, height: 26),
      const Radius.circular(8),
    );

    canvas.drawRRect(body, glow);
    canvas.drawRRect(body, paint);

    canvas.drawCircle(center + const Offset(-13, 0), 6, paint);
    canvas.drawCircle(center + const Offset(13, 0), 6, paint);

    canvas.drawLine(
      center + const Offset(-24, 0),
      center + const Offset(-42, 0),
      paint,
    );

    canvas.drawLine(
      center + const Offset(24, 0),
      center + const Offset(44, 0),
      paint,
    );
  }

  void _drawPressureGauge(Canvas canvas, Offset center, Paint paint) {
    canvas.drawCircle(center, 7, paint);
    canvas.drawLine(center, center + const Offset(3, -4), paint);
    canvas.drawLine(
      center + const Offset(0, 7),
      center + const Offset(0, 15),
      paint,
    );
  }

  // ============================================================
  // ANIMATED OVERLAYS - SMOOTH VERSION
  // ============================================================

  // ============================================================
  // ANIMATED OVERLAYS - REAL UTILITY MOTION STYLE
  // ============================================================

  void _drawElectricMovingCurrent(Canvas canvas, Size size) {
    // Điện cao thế không nên vẽ như hạt chạy liên tục.
    // Nhìn đúng hơn là corona shimmer + dây điện nhấp nháy nhẹ + spark nhỏ ở sứ.
    _drawHighVoltageWirePulse(canvas, size);
    _drawCoronaAtInsulators(canvas, size);
    _drawRandomVoltageFlicker(canvas, size);
  }

  void _drawWaterMovingFlow(Canvas canvas, Size size) {
    // Nước: highlight dòng chảy chạy bên trong đúng network ống.
    // Không vẽ ngoài ống.
    final y1 = size.height * .24;
    final y2 = size.height * .48;
    final y3 = size.height * .72;

    final path1 = Path()
      ..moveTo(-40, y1)
      ..lineTo(size.width * .24, y1)
      ..quadraticBezierTo(size.width * .30, y1, size.width * .30, y1 + 42)
      ..lineTo(size.width * .52, y1 + 42)
      ..quadraticBezierTo(size.width * .58, y1 + 42, size.width * .58, y1)
      ..lineTo(size.width + 40, y1);

    final path2 = Path()
      ..moveTo(-40, y2)
      ..lineTo(size.width * .18, y2)
      ..quadraticBezierTo(size.width * .24, y2, size.width * .24, y2 - 38)
      ..lineTo(size.width * .44, y2 - 38)
      ..quadraticBezierTo(size.width * .50, y2 - 38, size.width * .50, y2)
      ..lineTo(size.width + 40, y2);

    final path3 = Path()
      ..moveTo(-40, y3)
      ..lineTo(size.width * .36, y3)
      ..quadraticBezierTo(size.width * .42, y3, size.width * .42, y3 - 34)
      ..lineTo(size.width * .70, y3 - 34)
      ..quadraticBezierTo(size.width * .76, y3 - 34, size.width * .76, y3)
      ..lineTo(size.width + 40, y3);

    _drawWaterFlowOnPipe(canvas, path1, phase: t);
    _drawWaterFlowOnPipe(canvas, path2, phase: (t + .33) % 1);
    _drawWaterFlowOnPipe(canvas, path3, phase: (t + .66) % 1);

    _drawTankWaterSurfaceMotion(canvas, size);
    _drawBubbleInsideTank(canvas, size);
  }

  void _drawAirMovingFlow(Canvas canvas, Size size) {
    // Khí nén: không vẽ nước/sóng mềm.
    // Nên là các xung áp suất ngắn, nét đứt, chạy nhanh trong ống.
    _drawCompressedAirPressurePulses(canvas, size);
    _drawCompressorVibration(canvas, size);
    _drawGaugeNeedleVibration(canvas, size);
  }

  // ============================================================
  // ELECTRICITY MOTION
  // ============================================================

  void _drawHighVoltageWirePulse(Canvas canvas, Size size) {
    final pulse = .5 + math.sin(t * math.pi * 2) * .5;

    final wirePaint = Paint()
      ..color = color.withOpacity(.2 + .10 * pulse)
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    const stepX = 245.0;
    const stepY = 185.0;

    final rows = (size.height / stepY).ceil() + 2;
    final cols = (size.width / stepX).ceil() + 3;

    for (int row = -1; row < rows; row++) {
      final y = row * stepY + 150;
      final offsetX = row.isOdd ? stepX * .45 : 0.0;
      final h = row.isEven ? 88.0 : 76.0;
      final w = h * .42;

      final topWire = <Offset>[];
      final leftWire = <Offset>[];
      final rightWire = <Offset>[];

      for (int col = -1; col < cols; col++) {
        final x = col * stepX + offsetX;

        topWire.add(Offset(x, y - h));
        leftWire.add(Offset(x - w * .48, y - h * .74));
        rightWire.add(Offset(x + w * .48, y - h * .74));
      }

      _drawPulseSaggingWire(canvas, topWire, wirePaint, rowOffset: row * .08);
      _drawPulseSaggingWire(canvas, leftWire, wirePaint, rowOffset: row * .11);
      _drawPulseSaggingWire(canvas, rightWire, wirePaint, rowOffset: row * .14);
    }
  }

  void _drawPulseSaggingWire(
    Canvas canvas,
    List<Offset> points,
    Paint paint, {
    required double rowOffset,
  }) {
    if (points.length < 2) return;

    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];

      final distance = (b - a).distance;
      final sag = math.min(18.0, distance * .08);

      final mid = Offset((a.dx + b.dx) / 2, math.max(a.dy, b.dy) + sag);

      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);

      final flash = .5 + math.sin((t + rowOffset + i * .17) * math.pi * 2) * .5;

      if (flash > .72) {
        final flashPaint = Paint()
          ..color = color.withOpacity(.11 * flash)
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

        canvas.drawPath(path, flashPaint);
      }

      canvas.drawPath(path, paint);
    }
  }

  void _drawCoronaAtInsulators(Canvas canvas, Size size) {
    const stepX = 245.0;
    const stepY = 185.0;

    final rows = (size.height / stepY).ceil() + 2;
    final cols = (size.width / stepX).ceil() + 3;

    for (int row = -1; row < rows; row++) {
      final y = row * stepY + 150;
      final offsetX = row.isOdd ? stepX * .45 : 0.0;
      final h = row.isEven ? 88.0 : 76.0;
      final w = h * .42;

      for (int col = -1; col < cols; col++) {
        final x = col * stepX + offsetX;
        final topY = y - h;

        final arm2Y = topY + h * .32;
        final arm3Y = topY + h * .48;

        final points = [
          Offset(x - w * .58, arm2Y),
          Offset(x + w * .58, arm2Y),
          Offset(x - w * .42, arm3Y),
          Offset(x + w * .42, arm3Y),
        ];

        for (int i = 0; i < points.length; i++) {
          final p = points[i];

          final phase = (t + row * .09 + col * .07 + i * .13) % 1;
          final strength = .5 + math.sin(phase * math.pi * 2) * .5;

          if (strength < .42) continue;

          final coronaPaint = Paint()
            ..color = color.withOpacity(.055 + .075 * strength)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .9 + strength
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

          canvas.drawCircle(
            p + const Offset(0, 9),
            4.5 + strength * 4,
            coronaPaint,
          );
        }
      }
    }
  }

  void _drawRandomVoltageFlicker(Canvas canvas, Size size) {
    // Không random thật để tránh repaint không ổn định.
    // Dùng sin phase để tạo tia điện lúc có lúc không.
    final flickerPaint = Paint()
      ..color = color.withOpacity(.26)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (double x = 90; x < size.width; x += 280) {
      for (double y = 76; y < size.height; y += 240) {
        final phase = (t + x * .0017 + y * .0021) % 1;
        final visible = math.sin(phase * math.pi * 2);

        if (visible < .72) continue;

        final path = Path()
          ..moveTo(x, y)
          ..lineTo(x + 9, y - 7)
          ..lineTo(x + 4, y + 5)
          ..lineTo(x + 15, y - 2);

        canvas.drawPath(path, flickerPaint);
      }
    }
  }

  // ============================================================
  // WATER MOTION
  // ============================================================

  void _drawWaterFlowOnPipe(
    Canvas canvas,
    Path pipePath, {
    required double phase,
  }) {
    final metrics = pipePath.computeMetrics().toList();

    final glowPaint = Paint()
      ..color = color.withOpacity(.09)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    final flowPaint = Paint()
      ..color = color.withOpacity(.30)
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final metric in metrics) {
      final length = metric.length;

      if (length <= 0) continue;

      // 3 đoạn nước sáng chạy nối tiếp trong cùng ống.
      for (int i = 0; i < 3; i++) {
        final local = ((phase + i / 3) % 1.0);
        final center = local * length;

        final segLength = math.min(70.0, length * .18);

        final start = (center - segLength / 2).clamp(0.0, length);
        final end = (center + segLength / 2).clamp(0.0, length);

        if (end <= start) continue;

        final extract = metric.extractPath(start, end);

        canvas.drawPath(extract, glowPaint);
        canvas.drawPath(extract, flowPaint);

        final tangent = metric.getTangentForOffset(end);
        if (tangent != null) {
          canvas.drawCircle(
            tangent.position,
            2.2,
            Paint()..color = color.withOpacity(.32),
          );
        }
      }
    }
  }

  void _drawTankWaterSurfaceMotion(Canvas canvas, Size size) {
    final tankW = math.min(size.width * .26, 260.0);
    final tankH = math.min(size.height * .58, 390.0);

    final center = Offset(size.width * .82, size.height * .52);
    final rect = Rect.fromCenter(center: center, width: tankW, height: tankH);

    final waterY = center.dy + tankH * .12;

    final wavePaint = Paint()
      ..color = color.withOpacity(.22)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final waveGlow = Paint()
      ..color = color.withOpacity(.055)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final path = Path();

    for (double x = rect.left + 18; x <= rect.right - 18; x += 8) {
      final y = waterY + math.sin((x / 22) + t * math.pi * 2) * 5;

      if (x == rect.left + 18) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, waveGlow);
    canvas.drawPath(path, wavePaint);
  }

  void _drawBubbleInsideTank(Canvas canvas, Size size) {
    final tankW = math.min(size.width * .26, 260.0);
    final tankH = math.min(size.height * .58, 390.0);

    final center = Offset(size.width * .82, size.height * .52);
    final rect = Rect.fromCenter(center: center, width: tankW, height: tankH);

    final bubblePaint = Paint()
      ..color = color.withOpacity(.12)
      ..strokeWidth = .9
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 8; i++) {
      final baseX = rect.left + tankW * (.25 + (i % 4) * .16);
      final baseY = rect.bottom - tankH * (.18 + (i ~/ 4) * .18);

      final rise = ((t + i * .11) % 1.0) * tankH * .32;
      final sway = math.sin(t * math.pi * 2 + i) * 4;

      final p = Offset(baseX + sway, baseY - rise);

      if (!rect.contains(p)) continue;

      canvas.drawCircle(p, 2.5 + (i % 3), bubblePaint);
    }
  }

  // ============================================================
  // COMPRESSED AIR MOTION
  // ============================================================

  void _drawCompressedAirPressurePulses(Canvas canvas, Size size) {
    final pulsePaint = Paint()
      ..color = color.withOpacity(.24)
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pulseGlow = Paint()
      ..color = color.withOpacity(.065)
      ..strokeWidth = 5.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);

    // Theo duct network hiện tại: các đường y = 122, 302, ...
    for (double y = 122; y < size.height; y += 180) {
      final speed = (t * 340 + y * .23) % 180;

      for (double x = -180; x < size.width + 180; x += 180) {
        final cx = x + speed;

        // Xung áp suất là cụm 3 vạch ngắn, không phải mũi tên.
        for (int i = 0; i < 3; i++) {
          final dx = i * 13.0;

          final a = Offset(cx - dx, y);
          final b = Offset(cx - dx + 7, y);

          canvas.drawLine(a, b, pulseGlow);
          canvas.drawLine(a, b, pulsePaint);
        }
      }
    }

    // Một số sóng áp suất dạng vòng nhỏ quanh compressor.
    for (double y = 122; y < size.height; y += 180) {
      for (double x = 70; x < size.width; x += 260) {
        final phase = (t + x * .002 + y * .001) % 1;
        final r = 12 + phase * 18;

        final ringPaint = Paint()
          ..color = color.withOpacity((1 - phase) * .075)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;

        canvas.drawCircle(Offset(x, y), r, ringPaint);
      }
    }
  }

  void _drawCompressorVibration(Canvas canvas, Size size) {
    final vib = math.sin(t * math.pi * 2 * 5) * 1.3;

    final vibPaint = Paint()
      ..color = color.withOpacity(.09)
      ..strokeWidth = .9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (double y = 122; y < size.height; y += 180) {
      for (double x = 70; x < size.width; x += 260) {
        final c = Offset(x + vib, y);

        canvas.drawLine(
          c + const Offset(-30, -18),
          c + const Offset(-38, -24),
          vibPaint,
        );
        canvas.drawLine(
          c + const Offset(30, -18),
          c + const Offset(38, -24),
          vibPaint,
        );
        canvas.drawLine(
          c + const Offset(-30, 18),
          c + const Offset(-38, 24),
          vibPaint,
        );
        canvas.drawLine(
          c + const Offset(30, 18),
          c + const Offset(38, 24),
          vibPaint,
        );
      }
    }
  }

  void _drawGaugeNeedleVibration(Canvas canvas, Size size) {
    final needlePaint = Paint()
      ..color = color.withOpacity(.18)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (double y = 122; y < size.height; y += 180) {
      for (double x = 70; x < size.width; x += 260) {
        final center = Offset(x + 70, y - 20);

        final angle = -math.pi / 2.6 + math.sin(t * math.pi * 2 * 3 + x) * .22;
        final end = center + Offset(math.cos(angle), math.sin(angle)) * 6;

        canvas.drawLine(center, end, needlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _UtilityPremiumBackgroundPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.type != type ||
        oldDelegate.drawStatic != drawStatic ||
        oldDelegate.drawMotion != drawMotion;
  }
}
