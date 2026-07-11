import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_state/chart_catalog_provider.dart';
import '../utility_dashboard_common/chart_theme.dart';
import '../utility_dashboard_overview/utility_dashboard_overview_painter/utility_industrial_motion_background.dart';
import '../utility_dashboard_overview/utility_dashboard_overview_widgets/chart_state_widgets.dart';
import '../utility_dashboard_overview/utility_dashboard_overview_widgets/scada_tab_button.dart';
import 'utility_minute_chart_panel.dart';

enum _CatalogLoadStage { idle, scadas, boxes, charts }

class UtilityAllFactoriesChartsScreen extends StatefulWidget {
  const UtilityAllFactoriesChartsScreen({super.key});

  @override
  State<UtilityAllFactoriesChartsScreen> createState() =>
      _UtilityAllFactoriesChartsScreenState();
}

class _UtilityAllFactoriesChartsScreenState
    extends State<UtilityAllFactoriesChartsScreen> {
  static const _cateTabs = <String>['Electricity', 'Water', 'Compressed Air'];

  static const _facTabs = <String>['Fac_A', 'Fac_B', 'Fac_C'];

  static const _viewTabs = <String>['Minutes'];

  int _selectedCateIndex = 0;
  int _selectedFacIndex = 0;
  int _selectedViewIndex = 0;

  int _selectedScadaIndex = 0;
  int _selectedBoxIdIndex = 0;

  // -1 nghĩa là đang chọn ALL DEVICES.
  int _selectedBoxDeviceIndex = -1;

  bool _importantOnly = false;
  bool _filtersExpanded = true;

  // Request mới sẽ tăng token.
  // Response cũ không còn đúng token sẽ bị bỏ qua.
  int _requestToken = 0;

  ChartCatalogProvider get _catalog {
    return context.read<ChartCatalogProvider>();
  }

  String get selectedCate {
    return _cateTabs[_selectedCateIndex];
  }

  String get selectedFac {
    return _facTabs[_selectedFacIndex];
  }

  String get selectedView {
    return _viewTabs[_selectedViewIndex];
  }

  int get _importantValue {
    return _importantOnly ? 1 : 0;
  }

  _CatalogLoadStage _loadStage = _CatalogLoadStage.idle;

  bool get _loadingScadas {
    return _loadStage == _CatalogLoadStage.scadas;
  }

  bool get _loadingBoxes {
    return _loadStage == _CatalogLoadStage.boxes;
  }

  bool get _loadingCharts {
    return _loadStage == _CatalogLoadStage.charts;
  }

  bool get _catalogBusy {
    return _loadStage != _CatalogLoadStage.idle;
  }

  String get _loadingMessage {
    switch (_loadStage) {
      case _CatalogLoadStage.scadas:
        return 'Loading SCADA channels...';

      case _CatalogLoadStage.boxes:
        return 'Loading box groups and devices...';

      case _CatalogLoadStage.charts:
        return 'Loading signal charts...';

      case _CatalogLoadStage.idle:
        return '';
    }
  }

  void _setLoadStage(_CatalogLoadStage stage) {
    if (!mounted || _loadStage == stage) return;

    setState(() {
      _loadStage = stage;
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      unawaited(_reloadCatalog());
    });
  }

  // ============================================================
  // REQUEST GUARD
  // ============================================================

  int _beginRequest() {
    return ++_requestToken;
  }

  bool _isRequestValid(
    int token, {
    required String facId,
    required String cate,
  }) {
    return mounted &&
        token == _requestToken &&
        facId == selectedFac &&
        cate == selectedCate;
  }

  // ============================================================
  // SAFE VALUE HELPERS
  // ============================================================

  String? _valueAt(List<String> values, int index) {
    if (values.isEmpty) return null;
    if (index < 0 || index >= values.length) return null;

    return values[index];
  }

  int _safeUiIndex(int index, int itemCount) {
    if (itemCount <= 0) return 0;

    return index.clamp(0, itemCount - 1);
  }

  String? _currentScada() {
    return _valueAt(_catalog.scadaIds, _selectedScadaIndex);
  }

  String? _currentBoxDevice() {
    if (_selectedBoxDeviceIndex < 0) return null;

    return _valueAt(_catalog.boxDeviceIds, _selectedBoxDeviceIndex);
  }

  void _resetCatalogSelection() {
    _selectedScadaIndex = 0;
    _selectedBoxIdIndex = 0;
    _selectedBoxDeviceIndex = -1;
  }

  // ============================================================
  // INITIAL / ROOT LOAD
  // ============================================================

  Future<void> _reloadCatalog() async {
    final token = _beginRequest();

    final facId = selectedFac;
    final cate = selectedCate;
    final importantOnly = _importantValue;

    final catalog = _catalog;

    _setLoadStage(_CatalogLoadStage.scadas);

    try {
      await catalog.loadScadas(facId: facId, cate: cate);

      if (!_isRequestValid(token, facId: facId, cate: cate)) {
        return;
      }

      final scadas = List<String>.from(catalog.scadaIds);

      if (scadas.isEmpty) {
        return;
      }

      final scadaId = scadas.first;

      catalog.selectScadaId(scadaId);

      _setLoadStage(_CatalogLoadStage.boxes);

      await catalog.loadBoxes(facId: facId, cate: cate, scadaId: scadaId);

      if (!_isRequestValid(token, facId: facId, cate: cate)) {
        return;
      }

      final boxIds = List<String>.from(catalog.boxIds);

      if (boxIds.isEmpty) {
        return;
      }

      catalog.selectBoxId(boxIds.first);

      _setLoadStage(_CatalogLoadStage.charts);

      await catalog.loadChartsForBoxGroup(
        facId: facId,
        cate: cate,
        scadaId: scadaId,
        importantOnly: importantOnly,
      );
    } finally {
      if (_isRequestValid(token, facId: facId, cate: cate)) {
        _setLoadStage(_CatalogLoadStage.idle);
      }
    }
  }

  // ============================================================
  // CHART LOADERS
  // ============================================================

  Future<void> _loadCurrentBoxGroup() async {
    final token = _beginRequest();

    final facId = selectedFac;
    final cate = selectedCate;
    final scadaId = _currentScada();

    if (scadaId == null || scadaId.trim().isEmpty) {
      return;
    }

    _setLoadStage(_CatalogLoadStage.charts);

    try {
      await _catalog.loadChartsForBoxGroup(
        facId: facId,
        cate: cate,
        scadaId: scadaId,
        importantOnly: _importantValue,
      );
    } finally {
      if (_isRequestValid(token, facId: facId, cate: cate)) {
        _setLoadStage(_CatalogLoadStage.idle);
      }
    }
  }

  Future<void> _loadSelectedBoxDevice(String boxDeviceId) async {
    final token = _beginRequest();

    final facId = selectedFac;
    final cate = selectedCate;
    final scadaId = _currentScada();

    if (scadaId == null || scadaId.trim().isEmpty) {
      return;
    }

    _setLoadStage(_CatalogLoadStage.charts);

    try {
      await _catalog.loadChartsForBox(
        facId: facId,
        cate: cate,
        scadaId: scadaId,
        boxDeviceId: boxDeviceId,
        importantOnly: _importantValue,
      );
    } finally {
      if (_isRequestValid(token, facId: facId, cate: cate)) {
        _setLoadStage(_CatalogLoadStage.idle);
      }
    }
  }

  // ============================================================
  // FILTER CALLBACKS
  // ============================================================

  Future<void> _onCateChanged(int index) async {
    if (index < 0 || index >= _cateTabs.length) return;
    if (_selectedCateIndex == index) return;

    setState(() {
      _selectedCateIndex = index;
      _resetCatalogSelection();
    });

    await _reloadCatalog();
  }

  Future<void> _onFacChanged(int index) async {
    if (index < 0 || index >= _facTabs.length) return;
    if (_selectedFacIndex == index) return;

    setState(() {
      _selectedFacIndex = index;
      _resetCatalogSelection();
    });

    await _reloadCatalog();
  }

  Future<void> _onScadaChanged(List<String> tabs, int index) async {
    if (index < 0 || index >= tabs.length) return;
    if (_selectedScadaIndex == index) return;

    final token = _beginRequest();

    final facId = selectedFac;
    final cate = selectedCate;
    final scadaId = tabs[index];

    setState(() {
      _selectedScadaIndex = index;
      _selectedBoxIdIndex = 0;
      _selectedBoxDeviceIndex = -1;
    });

    final catalog = _catalog;

    catalog.selectScadaId(scadaId);

    await catalog.loadBoxes(facId: facId, cate: cate, scadaId: scadaId);

    if (!_isRequestValid(token, facId: facId, cate: cate)) {
      return;
    }

    final boxIds = List<String>.from(catalog.boxIds);

    if (boxIds.isNotEmpty) {
      catalog.selectBoxId(boxIds.first);
    }

    await catalog.loadChartsForBoxGroup(
      facId: facId,
      cate: cate,
      scadaId: scadaId,
      importantOnly: _importantValue,
    );

    if (!_isRequestValid(token, facId: facId, cate: cate)) {
      return;
    }
  }

  Future<void> _onBoxIdChanged(List<String> tabs, int index) async {
    if (index < 0 || index >= tabs.length) return;
    if (_selectedBoxIdIndex == index) return;

    setState(() {
      _selectedBoxIdIndex = index;
      _selectedBoxDeviceIndex = -1;
    });

    _catalog.selectBoxId(tabs[index]);

    await _loadCurrentBoxGroup();
  }

  Future<void> _onBoxDeviceChanged(List<String> tabs, int index) async {
    if (index < 0 || index >= tabs.length) return;
    if (_selectedBoxDeviceIndex == index) return;

    setState(() {
      _selectedBoxDeviceIndex = index;
    });

    await _loadSelectedBoxDevice(tabs[index]);
  }

  Future<void> _selectAllDevices() async {
    if (_selectedBoxDeviceIndex < 0) return;

    setState(() {
      _selectedBoxDeviceIndex = -1;
    });

    await _loadCurrentBoxGroup();
  }

  Future<void> _onImportantChanged(bool value) async {
    if (_importantOnly == value) return;

    setState(() {
      _importantOnly = value;
    });

    final selectedDevice = _currentBoxDevice();

    if (selectedDevice != null && selectedDevice.trim().isNotEmpty) {
      await _loadSelectedBoxDevice(selectedDevice);
      return;
    }

    await _loadCurrentBoxGroup();
  }

  void _onViewChanged(int index) {
    if (index < 0 || index >= _viewTabs.length) return;
    if (_selectedViewIndex == index) return;

    setState(() {
      _selectedViewIndex = index;
    });
  }

  void _toggleFilters() {
    setState(() {
      _filtersExpanded = !_filtersExpanded;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // Tạo immutable copy để Selector phát hiện được thay đổi,
    // kể cả khi Provider mutate list cũ.
    final scadaTabs = context.select<ChartCatalogProvider, List<String>>(
      (provider) => List<String>.unmodifiable(provider.scadaIds),
    );

    final boxIdTabs = context.select<ChartCatalogProvider, List<String>>(
      (provider) => List<String>.unmodifiable(provider.boxIds),
    );

    final boxDeviceTabs = context.select<ChartCatalogProvider, List<String>>(
      (provider) => List<String>.unmodifiable(provider.boxDeviceIds),
    );

    // Không mutate index trong build.
    final scadaUiIndex = _safeUiIndex(_selectedScadaIndex, scadaTabs.length);

    final boxIdUiIndex = _safeUiIndex(_selectedBoxIdIndex, boxIdTabs.length);

    final boxDeviceUiIndex = _safeUiIndex(
      _selectedBoxDeviceIndex,
      boxDeviceTabs.length,
    );

    final selectedScada = _valueAt(scadaTabs, scadaUiIndex);

    final selectedBoxId = _valueAt(boxIdTabs, boxIdUiIndex);

    final selectedBoxDevice = _selectedBoxDeviceIndex < 0
        ? null
        : _valueAt(boxDeviceTabs, boxDeviceUiIndex);

    final selectedScadaDisplay = _loadingScadas
        ? 'Loading...'
        : selectedScada ?? 'Not configured';

    final selectedDisplay = _loadingBoxes
        ? 'Loading...'
        : selectedBoxDevice ??
              (selectedBoxId == null
                  ? 'Not configured'
                  : '$selectedBoxId (ALL DEVICES)');

    final theme = ChartThemes.byCate(selectedCate);

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
              child: UtilityIndustrialMotionBackground(
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
                    selectedScada: selectedScadaDisplay,
                    selectedBox: selectedDisplay,
                    viewTabs: _viewTabs,
                    selectedViewIndex: _selectedViewIndex,
                    onViewChanged: _onViewChanged,
                    importantOnly: _importantOnly,
                    onToggleFilters: _toggleFilters,
                    onImportantChanged: (value) {
                      unawaited(_onImportantChanged(value));
                    },
                    showImportantSwitch: selectedView == 'Minutes',
                    importantEnabled: selectedBoxId != null && !_catalogBusy,
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

                    loadingScadas: _loadingScadas,
                    loadingBoxes: _loadingBoxes,

                    selectedCateIndex: _selectedCateIndex,
                    selectedFacIndex: _selectedFacIndex,
                    selectedScadaIndex: scadaUiIndex,
                    selectedBoxIdIndex: boxIdUiIndex,
                    selectedBoxDeviceIndex: boxDeviceUiIndex,
                    selectedAllDevices: _selectedBoxDeviceIndex < 0,

                    onCateChanged: (index) {
                      unawaited(_onCateChanged(index));
                    },
                    onFacChanged: (index) {
                      unawaited(_onFacChanged(index));
                    },
                    onScadaChanged: (index) {
                      unawaited(_onScadaChanged(scadaTabs, index));
                    },
                    onBoxIdChanged: (index) {
                      unawaited(_onBoxIdChanged(boxIdTabs, index));
                    },
                    onBoxDeviceChanged: (index) {
                      unawaited(_onBoxDeviceChanged(boxDeviceTabs, index));
                    },
                    onAllDevicesSelected: () {
                      unawaited(_selectAllDevices());
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
                      switching: _catalogBusy,
                      loadingMessage: _loadingMessage,
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

// ============================================================
// CATALOG BODY
// ============================================================

class _CatalogBodyVm {
  final bool loading;
  final Object? error;
  final List<dynamic> charts;

  const _CatalogBodyVm({
    required this.loading,
    required this.error,
    required this.charts,
  });
}

class _CatalogBody extends StatelessWidget {
  final String selectedBox;
  final String selectedCate;
  final String selectedFac;
  final String? selectedScada;
  final bool importantOnly;
  final bool switching;
  final String loadingMessage;

  const _CatalogBody({
    required this.selectedBox,
    required this.selectedCate,
    required this.selectedFac,
    required this.selectedScada,
    required this.importantOnly,
    required this.switching,
    required this.loadingMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ChartThemes.byCate(selectedCate);

    return Selector<ChartCatalogProvider, _CatalogBodyVm>(
      selector: (_, provider) {
        return _CatalogBodyVm(
          loading: provider.loading,
          error: provider.error,
          charts: provider.charts,
        );
      },
      shouldRebuild: (previous, next) {
        return previous.loading != next.loading ||
            previous.error != next.error ||
            !identical(previous.charts, next.charts);
      },
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
              unawaited(
                context.read<ChartCatalogProvider>().loadChartsForBoxGroup(
                  facId: selectedFac,
                  cate: selectedCate,
                  scadaId: selectedScada,
                  importantOnly: importantOnly ? 1 : 0,
                ),
              );
            },
          );
        }

        if (vm.charts.isEmpty) {
          return EmptyChartState(
            icon: Icons.sensors_off_rounded,
            title: 'No Signals Available',
            message:
                'No utility signals found in '
                '$selectedBox / ${selectedScada ?? "-"}',
            color: Colors.white.withOpacity(.58),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = _resolveGridColumnCount(
              constraints.maxWidth,
            );

            return GridView.builder(
              // Key cố định để không dispose toàn bộ chart
              // mỗi khi đổi FAC/category.
              key: const PageStorageKey('utility_chart_grid'),
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
                      // Không dùng FAC trong key.
                      // Khi FAC thay đổi, chart nhận
                      // didUpdateWidget thay vì bị dispose.
                      key: ValueKey(
                        '${chart.boxDeviceId}_'
                        '${chart.plcAddress}',
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

  final bool loadingScadas;
  final bool loadingBoxes;

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
    required this.loadingScadas,
    required this.loadingBoxes,
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
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
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
                const SizedBox(height: 10),

                _FilterSection(
                  title: 'SCADA',
                  icon: Icons.hub_rounded,
                  child: _AsyncFilterContent(
                    loading: loadingScadas,
                    loadingText: 'Loading SCADA channels',
                    empty: scadaTabs.isEmpty,
                    emptyText: 'No SCADA channel configured for this selection',
                    theme: theme,
                    child: _GlassTabRow(
                      labels: scadaTabs,
                      selectedIndex: selectedScadaIndex,
                      onSelect: onScadaChanged,
                      theme: theme,
                    ),
                  ),
                ),

                if (!loadingScadas && scadaTabs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _FilterSection(
                    title: 'BOX GROUP',
                    icon: Icons.inventory_2_outlined,
                    child: _AsyncFilterContent(
                      loading: loadingBoxes,
                      loadingText: 'Loading box groups',
                      empty: boxIdTabs.isEmpty,
                      emptyText: 'No box group available for this SCADA',
                      theme: theme,
                      child: _GlassTabRow(
                        labels: boxIdTabs,
                        selectedIndex: selectedBoxIdIndex,
                        onSelect: onBoxIdChanged,
                        theme: theme,
                      ),
                    ),
                  ),
                ],

                if (!loadingScadas &&
                    !loadingBoxes &&
                    scadaTabs.isNotEmpty &&
                    boxIdTabs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _FilterSection(
                    title: 'DEVICE',
                    icon: Icons.memory_rounded,
                    child: _AsyncFilterContent(
                      loading: false,
                      loadingText: 'Loading devices',
                      empty: boxDeviceTabs.isEmpty,
                      emptyText: 'No individual device available in this group',
                      theme: theme,
                      child: _GlassTabRow(
                        labels: boxDeviceTabs,
                        selectedIndex: selectedAllDevices
                            ? -1
                            : selectedBoxDeviceIndex,
                        onSelect: onBoxDeviceChanged,
                        theme: theme,
                        showAllChip: true,
                        allChipSelected: selectedAllDevices,
                        onAllTap: onAllDevicesSelected,
                      ),
                    ),
                  ),
                ],
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _FilterSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          height: 38,
          child: Row(
            children: [
              Icon(icon, size: 16, color: Colors.white.withOpacity(.48)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.58),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _AsyncFilterContent extends StatelessWidget {
  final bool loading;
  final String loadingText;

  final bool empty;
  final String emptyText;

  final ChartTheme theme;
  final Widget child;

  const _AsyncFilterContent({
    required this.loading,
    required this.loadingText,
    required this.empty,
    required this.emptyText,
    required this.theme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    late final Widget content;

    if (loading) {
      content = _FilterLoadingPill(
        key: ValueKey('loading-$loadingText'),
        text: loadingText,
        theme: theme,
      );
    } else if (empty) {
      content = _FilterEmptyHint(
        key: ValueKey('empty-$emptyText'),
        text: emptyText,
      );
    } else {
      content = KeyedSubtree(key: const ValueKey('filter-tabs'), child: child);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: content,
    );
  }
}

class _FilterLoadingPill extends StatelessWidget {
  final String text;
  final ChartTheme theme;

  const _FilterLoadingPill({
    super.key,
    required this.text,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.line.withOpacity(.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.line.withOpacity(.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: theme.line),
          ),
          const SizedBox(width: 9),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(.72),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterEmptyHint extends StatelessWidget {
  final String text;

  const _FilterEmptyHint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.025),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: Colors.white.withOpacity(.38),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(.46),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
