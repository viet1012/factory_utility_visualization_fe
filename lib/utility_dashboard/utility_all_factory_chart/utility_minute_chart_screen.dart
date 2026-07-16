// import 'dart:async';
//
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import '../../utility_state/chart_catalog_provider.dart';
// import '../utility_dashboard_common/chart_theme.dart';
// import '../utility_dashboard_overview/utility_dashboard_overview_painter/utility_industrial_motion_background.dart';
// import '../utility_dashboard_overview/utility_dashboard_overview_widgets/chart_state_widgets.dart';
// import '../utility_dashboard_overview/utility_dashboard_overview_widgets/scada_tab_button.dart';
// import 'utility_minute_chart_panel.dart';
//
// class UtilityAllFactoriesChartsScreen extends StatefulWidget {
//   const UtilityAllFactoriesChartsScreen({super.key});
//
//   @override
//   State<UtilityAllFactoriesChartsScreen> createState() =>
//       _UtilityAllFactoriesChartsScreenState();
// }
//
// class _UtilityAllFactoriesChartsScreenState
//     extends State<UtilityAllFactoriesChartsScreen> {
//   static const List<String> _cateTabs = [
//     'Electricity',
//     'Water',
//     'Compressed Air',
//   ];
//
//   static const List<String> _facTabs = ['Fac_A', 'Fac_B', 'Fac_C'];
//
//   static const List<String> _viewTabs = ['Minutes'];
//
//   late final ChartCatalogProvider _catalog;
//
//   Timer? _reloadDebounce;
//
//   int _selectedCateIndex = 0;
//   int _selectedFacIndex = 0;
//   int _selectedViewIndex = 0;
//
//   int _selectedScadaIndex = 0;
//   int _selectedBoxIdIndex = 0;
//
//   // -1 = ALL DEVICES.
//   int _selectedBoxDeviceIndex = -1;
//
//   bool _importantOnly = false;
//   bool _filtersExpanded = true;
//
//   String get selectedCate {
//     return _cateTabs[_selectedCateIndex];
//   }
//
//   String get selectedFac {
//     return _facTabs[_selectedFacIndex];
//   }
//
//   String get selectedView {
//     return _viewTabs[_selectedViewIndex];
//   }
//
//   int get _importantValue {
//     return _importantOnly ? 1 : 0;
//   }
//
//   @override
//   void initState() {
//     super.initState();
//
//     _catalog = context.read<ChartCatalogProvider>();
//
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!mounted) return;
//
//       unawaited(_loadCatalog());
//     });
//   }
//
//   @override
//   void dispose() {
//     _reloadDebounce?.cancel();
//     super.dispose();
//   }
//
//   // ============================================================
//   // SAFE HELPERS
//   // ============================================================
//
//   int _safeIndex(int index, int itemCount) {
//     if (itemCount <= 0) return 0;
//
//     return index.clamp(0, itemCount - 1);
//   }
//
//   String? _valueAt(List<String> values, int index) {
//     if (index < 0 || index >= values.length) {
//       return null;
//     }
//
//     return values[index];
//   }
//
//   void _resetSelectionIndexes() {
//     _selectedScadaIndex = 0;
//     _selectedBoxIdIndex = 0;
//     _selectedBoxDeviceIndex = -1;
//   }
//
//   void _scheduleCatalogReload({bool forceRefresh = false}) {
//     _reloadDebounce?.cancel();
//
//     _reloadDebounce = Timer(const Duration(milliseconds: 180), () {
//       if (!mounted) return;
//
//       unawaited(_loadCatalog(forceRefresh: forceRefresh));
//     });
//   }
//
//   // ============================================================
//   // API
//   // ============================================================
//
//   Future<void> _loadCatalog({bool forceRefresh = false}) async {
//     await _catalog.loadCatalog(
//       facId: selectedFac,
//       cate: selectedCate,
//       importantOnly: _importantValue,
//       forceRefresh: forceRefresh,
//     );
//
//     if (!mounted) return;
//
//     setState(() {
//       _syncIndexesFromProvider();
//     });
//   }
//
//   void _syncIndexesFromProvider() {
//     final selectedScada = _catalog.selectedScadaId;
//     final selectedBox = _catalog.selectedBoxId;
//     final selectedDevice = _catalog.selectedBoxDeviceId;
//
//     final scadaIndex = selectedScada == null
//         ? -1
//         : _catalog.scadaIds.indexOf(selectedScada);
//
//     final boxIndex = selectedBox == null
//         ? -1
//         : _catalog.boxIds.indexOf(selectedBox);
//
//     final deviceIndex = selectedDevice == null
//         ? -1
//         : _catalog.boxDeviceIds.indexOf(selectedDevice);
//
//     _selectedScadaIndex = scadaIndex < 0 ? 0 : scadaIndex;
//     _selectedBoxIdIndex = boxIndex < 0 ? 0 : boxIndex;
//     _selectedBoxDeviceIndex = deviceIndex;
//   }
//
//   // ============================================================
//   // REMOTE FILTERS
//   // FAC / CATEGORY / IMPORTANT mới gọi API.
//   // ============================================================
//
//   void _onCateChanged(int index) {
//     if (index < 0 || index >= _cateTabs.length) {
//       return;
//     }
//
//     if (_selectedCateIndex == index) {
//       return;
//     }
//
//     setState(() {
//       _selectedCateIndex = index;
//       _resetSelectionIndexes();
//     });
//
//     _scheduleCatalogReload();
//   }
//
//   void _onFacChanged(int index) {
//     if (index < 0 || index >= _facTabs.length) {
//       return;
//     }
//
//     if (_selectedFacIndex == index) {
//       return;
//     }
//
//     setState(() {
//       _selectedFacIndex = index;
//       _resetSelectionIndexes();
//     });
//
//     _scheduleCatalogReload();
//   }
//
//   void _onImportantChanged(bool value) {
//     if (_importantOnly == value) {
//       return;
//     }
//
//     setState(() {
//       _importantOnly = value;
//       _resetSelectionIndexes();
//     });
//
//     _scheduleCatalogReload();
//   }
//
//   // ============================================================
//   // LOCAL FILTERS
//   // SCADA / BOX / DEVICE không gọi API.
//   // ============================================================
//
//   void _onScadaChanged(List<String> scadaTabs, int index) {
//     if (index < 0 || index >= scadaTabs.length) {
//       return;
//     }
//
//     if (_selectedScadaIndex == index) {
//       return;
//     }
//
//     final scadaId = scadaTabs[index];
//
//     _catalog.selectScadaId(scadaId);
//
//     setState(() {
//       _selectedScadaIndex = index;
//       _selectedBoxIdIndex = 0;
//       _selectedBoxDeviceIndex = -1;
//
//       _syncIndexesFromProvider();
//     });
//   }
//
//   void _onBoxIdChanged(List<String> boxIdTabs, int index) {
//     if (index < 0 || index >= boxIdTabs.length) {
//       return;
//     }
//
//     if (_selectedBoxIdIndex == index) {
//       return;
//     }
//
//     final boxId = boxIdTabs[index];
//
//     _catalog.selectBoxId(boxId);
//
//     setState(() {
//       _selectedBoxIdIndex = index;
//       _selectedBoxDeviceIndex = -1;
//
//       _syncIndexesFromProvider();
//     });
//   }
//
//   void _onBoxDeviceChanged(List<String> boxDeviceTabs, int index) {
//     if (index < 0 || index >= boxDeviceTabs.length) {
//       return;
//     }
//
//     if (_selectedBoxDeviceIndex == index) {
//       return;
//     }
//
//     final boxDeviceId = boxDeviceTabs[index];
//
//     _catalog.selectBoxDeviceId(boxDeviceId);
//
//     setState(() {
//       _selectedBoxDeviceIndex = index;
//     });
//   }
//
//   void _selectAllDevices() {
//     if (_selectedBoxDeviceIndex < 0) {
//       return;
//     }
//
//     _catalog.selectAllDevices();
//
//     setState(() {
//       _selectedBoxDeviceIndex = -1;
//     });
//   }
//
//   void _onViewChanged(int index) {
//     if (index < 0 || index >= _viewTabs.length) {
//       return;
//     }
//
//     if (_selectedViewIndex == index) {
//       return;
//     }
//
//     setState(() {
//       _selectedViewIndex = index;
//     });
//   }
//
//   void _toggleFilters() {
//     setState(() {
//       _filtersExpanded = !_filtersExpanded;
//     });
//   }
//
//   // ============================================================
//   // BUILD
//   // ============================================================
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = ChartThemes.byCate(selectedCate);
//
//     return Scaffold(
//       body: DecoratedBox(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Color(0xFF0A0E27), Color(0xFF020B16)],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//         child: Stack(
//           children: [
//             Positioned.fill(
//               child: RepaintBoundary(
//                 child: IgnorePointer(
//                   child: UtilityIndustrialMotionBackground(
//                     cate: selectedCate,
//                     color: theme.line,
//                   ),
//                 ),
//               ),
//             ),
//             Positioned.fill(
//               child: Padding(
//                 padding: const EdgeInsets.all(8),
//                 child: Selector<ChartCatalogProvider, _CatalogScreenVm>(
//                   selector: (_, provider) {
//                     return _CatalogScreenVm(
//                       loading: provider.loading,
//                       error: provider.error,
//                       scadaIds: provider.scadaIds,
//                       boxIds: provider.boxIds,
//                       boxDeviceIds: provider.boxDeviceIds,
//                     );
//                   },
//                   shouldRebuild: (previous, next) {
//                     return previous.loading != next.loading ||
//                         previous.error != next.error ||
//                         !identical(previous.scadaIds, next.scadaIds) ||
//                         !identical(previous.boxIds, next.boxIds) ||
//                         !identical(previous.boxDeviceIds, next.boxDeviceIds);
//                   },
//                   builder: (context, vm, _) {
//                     return _buildPageContent(vm: vm, theme: theme);
//                   },
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildPageContent({
//     required _CatalogScreenVm vm,
//     required ChartTheme theme,
//   }) {
//     final scadaUiIndex = _safeIndex(_selectedScadaIndex, vm.scadaIds.length);
//
//     final boxIdUiIndex = _safeIndex(_selectedBoxIdIndex, vm.boxIds.length);
//
//     final boxDeviceUiIndex = _safeIndex(
//       _selectedBoxDeviceIndex,
//       vm.boxDeviceIds.length,
//     );
//
//     final selectedScada = _valueAt(vm.scadaIds, scadaUiIndex);
//
//     final selectedBoxId = _valueAt(vm.boxIds, boxIdUiIndex);
//
//     final selectedBoxDevice = _selectedBoxDeviceIndex < 0
//         ? null
//         : _valueAt(vm.boxDeviceIds, boxDeviceUiIndex);
//
//     // Khi refresh vẫn giữ giá trị hiện tại,
//     // không đổi thành "Loading...".
//     final selectedScadaDisplay = selectedScada ?? 'Not configured';
//
//     final selectedBoxDisplay =
//         selectedBoxDevice ??
//         (selectedBoxId == null
//             ? 'Not configured'
//             : '$selectedBoxId (ALL DEVICES)');
//
//     return Column(
//       children: [
//         _TopBar(
//           filtersExpanded: _filtersExpanded,
//           selectedCate: selectedCate,
//           selectedFac: selectedFac,
//           selectedScada: selectedScadaDisplay,
//           selectedBox: selectedBoxDisplay,
//           viewTabs: _viewTabs,
//           selectedViewIndex: _selectedViewIndex,
//           onViewChanged: _onViewChanged,
//           importantOnly: _importantOnly,
//           onToggleFilters: _toggleFilters,
//           onImportantChanged: _onImportantChanged,
//           showImportantSwitch: selectedView == 'Minutes',
//
//           // Chỉ disable khi load lần đầu.
//           importantEnabled: !vm.initialLoading,
//
//           refreshing: vm.refreshing,
//           theme: theme,
//         ),
//         const SizedBox(height: 8),
//         _FiltersArea(
//           expanded: _filtersExpanded,
//           cateTabs: _cateTabs,
//           facTabs: _facTabs,
//           scadaTabs: vm.scadaIds,
//           boxIdTabs: vm.boxIds,
//           boxDeviceTabs: vm.boxDeviceIds,
//
//           // Chỉ hiện loading filter ở lần đầu.
//           loadingScadas: vm.initialLoading,
//           loadingBoxes: vm.initialLoading,
//
//           selectedCateIndex: _selectedCateIndex,
//           selectedFacIndex: _selectedFacIndex,
//           selectedScadaIndex: scadaUiIndex,
//           selectedBoxIdIndex: boxIdUiIndex,
//           selectedBoxDeviceIndex: boxDeviceUiIndex,
//           selectedAllDevices: _selectedBoxDeviceIndex < 0,
//           onCateChanged: _onCateChanged,
//           onFacChanged: _onFacChanged,
//           onScadaChanged: (index) {
//             _onScadaChanged(vm.scadaIds, index);
//           },
//           onBoxIdChanged: (index) {
//             _onBoxIdChanged(vm.boxIds, index);
//           },
//           onBoxDeviceChanged: (index) {
//             _onBoxDeviceChanged(vm.boxDeviceIds, index);
//           },
//           onAllDevicesSelected: _selectAllDevices,
//           theme: theme,
//         ),
//         const SizedBox(height: 4),
//         Expanded(
//           child: _CatalogBody(
//             selectedBox: selectedBoxDisplay,
//             selectedCate: selectedCate,
//             selectedFac: selectedFac,
//             selectedScada: selectedScada,
//             importantOnly: _importantOnly,
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// // ============================================================
// // SCREEN VIEW MODEL
// // ============================================================
//
// class _CatalogScreenVm {
//   final bool loading;
//   final Object? error;
//
//   final List<String> scadaIds;
//   final List<String> boxIds;
//   final List<String> boxDeviceIds;
//
//   const _CatalogScreenVm({
//     required this.loading,
//     required this.error,
//     required this.scadaIds,
//     required this.boxIds,
//     required this.boxDeviceIds,
//   });
//
//   bool get hasCatalog {
//     return scadaIds.isNotEmpty || boxIds.isNotEmpty || boxDeviceIds.isNotEmpty;
//   }
//
//   bool get initialLoading {
//     return loading && !hasCatalog;
//   }
//
//   bool get refreshing {
//     return loading && hasCatalog;
//   }
// }
//
// // ============================================================
// // CATALOG BODY
// // ============================================================
//
// class _CatalogBodyVm {
//   final bool loading;
//   final Object? error;
//   final List<SignalChartConfig> charts;
//
//   const _CatalogBodyVm({
//     required this.loading,
//     required this.error,
//     required this.charts,
//   });
// }
//
// class _CatalogBody extends StatelessWidget {
//   final String selectedBox;
//   final String selectedCate;
//   final String selectedFac;
//   final String? selectedScada;
//   final bool importantOnly;
//
//   const _CatalogBody({
//     required this.selectedBox,
//     required this.selectedCate,
//     required this.selectedFac,
//     required this.selectedScada,
//     required this.importantOnly,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = ChartThemes.byCate(selectedCate);
//
//     return Selector<ChartCatalogProvider, _CatalogBodyVm>(
//       selector: (_, provider) {
//         return _CatalogBodyVm(
//           loading: provider.loading,
//           error: provider.error,
//           charts: provider.charts,
//         );
//       },
//       shouldRebuild: (previous, next) {
//         return previous.loading != next.loading ||
//             previous.error != next.error ||
//             !identical(previous.charts, next.charts);
//       },
//       builder: (context, vm, _) {
//         final initialLoading = vm.loading && vm.charts.isEmpty;
//
//         if (initialLoading) {
//           return Center(
//             child: SizedBox.square(
//               dimension: 28,
//               child: CircularProgressIndicator(
//                 color: theme.line,
//                 strokeWidth: 2.4,
//               ),
//             ),
//           );
//         }
//
//         if (vm.error != null && vm.charts.isEmpty) {
//           return ChartApiErrorState(
//             color: theme.line,
//             onRetry: () {
//               unawaited(
//                 context.read<ChartCatalogProvider>().loadCatalog(
//                   facId: selectedFac,
//                   cate: selectedCate,
//                   importantOnly: importantOnly ? 1 : 0,
//                   forceRefresh: true,
//                 ),
//               );
//             },
//           );
//         }
//
//         if (vm.charts.isEmpty) {
//           return EmptyChartState(
//             icon: Icons.sensors_off_rounded,
//             title: 'No Signals Available',
//             message:
//                 'No utility signals found in '
//                 '$selectedBox / ${selectedScada ?? "-"}',
//             color: Colors.white.withOpacity(.58),
//           );
//         }
//
//         return LayoutBuilder(
//           builder: (context, constraints) {
//             final columnCount = _resolveGridColumnCount(constraints.maxWidth);
//
//             return GridView.builder(
//               key: const PageStorageKey<String>('utility_chart_grid'),
//               padding: const EdgeInsets.only(top: 4),
//
//               // Chỉ cache một phần viewport.
//               cacheExtent: constraints.maxHeight * .30,
//
//               addRepaintBoundaries: false,
//               addAutomaticKeepAlives: false,
//               addSemanticIndexes: false,
//
//               keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
//
//               itemCount: vm.charts.length,
//
//               gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: columnCount,
//                 crossAxisSpacing: 10,
//                 mainAxisSpacing: 10,
//                 childAspectRatio: 16 / 10,
//               ),
//
//               itemBuilder: (context, index) {
//                 final chart = vm.charts[index];
//
//                 return RepaintBoundary(
//                   key: ValueKey<String>(
//                     '${selectedFac}_'
//                     '${selectedCate}_'
//                     '${selectedScada ?? ''}_'
//                     '${chart.boxDeviceId}_'
//                     '${chart.plcAddress}',
//                   ),
//                   child: UtilityMinuteChartPanel(
//                     facId: selectedFac,
//                     scadaId: selectedScada,
//                     cate: selectedCate,
//                     boxDeviceId: chart.boxDeviceId,
//                     plcAddress: chart.plcAddress,
//                     cateIds: chart.cateIds,
//                   ),
//                 );
//               },
//             );
//           },
//         );
//       },
//     );
//   }
//
//   int _resolveGridColumnCount(double width) {
//     if (width >= 1700) return 3;
//     if (width >= 1150) return 2;
//
//     return 1;
//   }
// }
//
// // ============================================================
// // TOP BAR
// // ============================================================
//
// class _TopBar extends StatelessWidget {
//   final bool filtersExpanded;
//
//   final String selectedCate;
//   final String selectedFac;
//   final String? selectedScada;
//   final String? selectedBox;
//
//   final List<String> viewTabs;
//   final int selectedViewIndex;
//
//   final ValueChanged<int> onViewChanged;
//
//   final bool importantOnly;
//   final ValueChanged<bool> onImportantChanged;
//
//   final VoidCallback onToggleFilters;
//
//   final bool showImportantSwitch;
//   final bool importantEnabled;
//
//   final bool refreshing;
//
//   final ChartTheme theme;
//
//   const _TopBar({
//     required this.filtersExpanded,
//     required this.selectedCate,
//     required this.selectedFac,
//     required this.selectedScada,
//     required this.selectedBox,
//     required this.viewTabs,
//     required this.selectedViewIndex,
//     required this.onViewChanged,
//     required this.importantOnly,
//     required this.onImportantChanged,
//     required this.onToggleFilters,
//     required this.showImportantSwitch,
//     required this.importantEnabled,
//     required this.refreshing,
//     required this.theme,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         _CollapseToggle(
//           expanded: filtersExpanded,
//           onTap: onToggleFilters,
//           theme: theme,
//         ),
//         const SizedBox(width: 12),
//         _GlassTabRow(
//           labels: viewTabs,
//           selectedIndex: selectedViewIndex,
//           onSelect: onViewChanged,
//           theme: theme,
//         ),
//         if (!filtersExpanded) ...[
//           const SizedBox(width: 14),
//           Expanded(
//             child: Text(
//               'Cate: $selectedCate'
//               '   •   Fac: $selectedFac'
//               '   •   SCADA: ${selectedScada ?? "-"}'
//               '   •   Box: ${selectedBox ?? "-"}',
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(
//                 color: Colors.white.withOpacity(.68),
//                 fontSize: 12,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//         ] else
//           const Spacer(),
//         if (refreshing) ...[
//           _CatalogSyncBadge(color: theme.line),
//           const SizedBox(width: 10),
//         ],
//         if (showImportantSwitch)
//           _ImportantSwitch(
//             value: importantOnly,
//             enabled: importantEnabled,
//             onChanged: onImportantChanged,
//             theme: theme,
//           ),
//       ],
//     );
//   }
// }
//
// // ============================================================
// // SYNC BADGE
// // ============================================================
//
// class _CatalogSyncBadge extends StatelessWidget {
//   final Color color;
//
//   const _CatalogSyncBadge({required this.color});
//
//   @override
//   Widget build(BuildContext context) {
//     return RepaintBoundary(
//       child: Container(
//         height: 36,
//         padding: const EdgeInsets.symmetric(horizontal: 11),
//         decoration: BoxDecoration(
//           color: color.withOpacity(.07),
//           borderRadius: BorderRadius.circular(10),
//           border: Border.all(color: color.withOpacity(.20)),
//           boxShadow: [
//             BoxShadow(
//               color: color.withOpacity(.10),
//               blurRadius: 10,
//               offset: const Offset(0, 3),
//             ),
//           ],
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             SizedBox.square(
//               dimension: 13,
//               child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
//             ),
//             const SizedBox(width: 8),
//             Text(
//               'Syncing',
//               style: TextStyle(
//                 color: Colors.white.withOpacity(.74),
//                 fontSize: 11,
//                 fontWeight: FontWeight.w800,
//                 letterSpacing: .2,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // ============================================================
// // FILTER AREA
// // ============================================================
//
// class _FiltersArea extends StatelessWidget {
//   final bool expanded;
//
//   final List<String> cateTabs;
//   final List<String> facTabs;
//   final List<String> scadaTabs;
//   final List<String> boxIdTabs;
//   final List<String> boxDeviceTabs;
//
//   final bool loadingScadas;
//   final bool loadingBoxes;
//
//   final int selectedCateIndex;
//   final int selectedFacIndex;
//   final int selectedScadaIndex;
//   final int selectedBoxIdIndex;
//   final int selectedBoxDeviceIndex;
//
//   final bool selectedAllDevices;
//
//   final ValueChanged<int> onCateChanged;
//   final ValueChanged<int> onFacChanged;
//   final ValueChanged<int> onScadaChanged;
//   final ValueChanged<int> onBoxIdChanged;
//   final ValueChanged<int> onBoxDeviceChanged;
//
//   final VoidCallback onAllDevicesSelected;
//
//   final ChartTheme theme;
//
//   const _FiltersArea({
//     required this.expanded,
//     required this.cateTabs,
//     required this.facTabs,
//     required this.scadaTabs,
//     required this.boxIdTabs,
//     required this.boxDeviceTabs,
//     required this.loadingScadas,
//     required this.loadingBoxes,
//     required this.selectedCateIndex,
//     required this.selectedFacIndex,
//     required this.selectedScadaIndex,
//     required this.selectedBoxIdIndex,
//     required this.selectedBoxDeviceIndex,
//     required this.selectedAllDevices,
//     required this.onCateChanged,
//     required this.onFacChanged,
//     required this.onScadaChanged,
//     required this.onBoxIdChanged,
//     required this.onBoxDeviceChanged,
//     required this.onAllDevicesSelected,
//     required this.theme,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedSize(
//       duration: const Duration(milliseconds: 180),
//       curve: Curves.easeOutCubic,
//       alignment: Alignment.topCenter,
//       child: expanded
//           ? Column(
//               children: [
//                 Row(
//                   children: [
//                     Expanded(
//                       child: _GlassTabRow(
//                         labels: cateTabs,
//                         selectedIndex: selectedCateIndex,
//                         onSelect: onCateChanged,
//                         theme: theme,
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     _GlassTabRow(
//                       labels: facTabs,
//                       selectedIndex: selectedFacIndex,
//                       onSelect: onFacChanged,
//                       alignRight: true,
//                       theme: theme,
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 10),
//                 _FilterSection(
//                   title: 'SCADA',
//                   icon: Icons.hub_rounded,
//                   child: _AsyncFilterContent(
//                     loading: loadingScadas,
//                     loadingText: 'Loading SCADA channels',
//                     empty: scadaTabs.isEmpty,
//                     emptyText: 'No SCADA channel configured',
//                     theme: theme,
//                     child: _GlassTabRow(
//                       labels: scadaTabs,
//                       selectedIndex: selectedScadaIndex,
//                       onSelect: onScadaChanged,
//                       theme: theme,
//                     ),
//                   ),
//                 ),
//                 if (!loadingScadas && scadaTabs.isNotEmpty) ...[
//                   const SizedBox(height: 8),
//                   _FilterSection(
//                     title: 'BOX GROUP',
//                     icon: Icons.inventory_2_outlined,
//                     child: _AsyncFilterContent(
//                       loading: loadingBoxes,
//                       loadingText: 'Loading box groups',
//                       empty: boxIdTabs.isEmpty,
//                       emptyText: 'No box group available',
//                       theme: theme,
//                       child: _GlassTabRow(
//                         labels: boxIdTabs,
//                         selectedIndex: selectedBoxIdIndex,
//                         onSelect: onBoxIdChanged,
//                         theme: theme,
//                       ),
//                     ),
//                   ),
//                 ],
//                 if (!loadingScadas &&
//                     !loadingBoxes &&
//                     scadaTabs.isNotEmpty &&
//                     boxIdTabs.isNotEmpty) ...[
//                   const SizedBox(height: 8),
//                   _FilterSection(
//                     title: 'DEVICE',
//                     icon: Icons.memory_rounded,
//                     child: _AsyncFilterContent(
//                       loading: false,
//                       loadingText: 'Loading devices',
//                       empty: boxDeviceTabs.isEmpty,
//                       emptyText: 'No device available',
//                       theme: theme,
//                       child: _GlassTabRow(
//                         labels: boxDeviceTabs,
//                         selectedIndex: selectedAllDevices
//                             ? -1
//                             : selectedBoxDeviceIndex,
//                         onSelect: onBoxDeviceChanged,
//                         theme: theme,
//                         showAllChip: true,
//                         allChipSelected: selectedAllDevices,
//                         onAllTap: onAllDevicesSelected,
//                       ),
//                     ),
//                   ),
//                 ],
//               ],
//             )
//           : const SizedBox.shrink(),
//     );
//   }
// }
//
// // ============================================================
// // FILTER SECTION
// // ============================================================
//
// class _FilterSection extends StatelessWidget {
//   final String title;
//   final IconData icon;
//   final Widget child;
//
//   const _FilterSection({
//     required this.title,
//     required this.icon,
//     required this.child,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(
//           width: 112,
//           height: 38,
//           child: Row(
//             children: [
//               Icon(icon, size: 16, color: Colors.white.withOpacity(.48)),
//               const SizedBox(width: 7),
//               Expanded(
//                 child: Text(
//                   title,
//                   maxLines: 1,
//                   style: TextStyle(
//                     color: Colors.white.withOpacity(.58),
//                     fontSize: 11,
//                     fontWeight: FontWeight.w900,
//                     letterSpacing: .7,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         child,
//       ],
//     );
//   }
// }
//
// // ============================================================
// // ASYNC FILTER CONTENT
// // ============================================================
//
// class _AsyncFilterContent extends StatelessWidget {
//   final bool loading;
//   final String loadingText;
//
//   final bool empty;
//   final String emptyText;
//
//   final ChartTheme theme;
//   final Widget child;
//
//   const _AsyncFilterContent({
//     required this.loading,
//     required this.loadingText,
//     required this.empty,
//     required this.emptyText,
//     required this.theme,
//     required this.child,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     late final Widget content;
//
//     if (loading) {
//       content = _FilterLoadingPill(
//         key: ValueKey<String>('loading-$loadingText'),
//         text: loadingText,
//         theme: theme,
//       );
//     } else if (empty) {
//       content = _FilterEmptyHint(
//         key: ValueKey<String>('empty-$emptyText'),
//         text: emptyText,
//       );
//     } else {
//       content = KeyedSubtree(
//         key: const ValueKey<String>('filter-tabs'),
//         child: child,
//       );
//     }
//
//     return AnimatedSwitcher(
//       duration: const Duration(milliseconds: 160),
//       switchInCurve: Curves.easeOut,
//       switchOutCurve: Curves.easeIn,
//       child: content,
//     );
//   }
// }
//
// // ============================================================
// // FILTER LOADING
// // ============================================================
//
// class _FilterLoadingPill extends StatelessWidget {
//   final String text;
//   final ChartTheme theme;
//
//   const _FilterLoadingPill({
//     super.key,
//     required this.text,
//     required this.theme,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 38,
//       padding: const EdgeInsets.symmetric(horizontal: 12),
//       decoration: BoxDecoration(
//         color: theme.line.withOpacity(.07),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: theme.line.withOpacity(.20)),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           SizedBox.square(
//             dimension: 14,
//             child: CircularProgressIndicator(strokeWidth: 2, color: theme.line),
//           ),
//           const SizedBox(width: 9),
//           Text(
//             text,
//             style: TextStyle(
//               color: Colors.white.withOpacity(.72),
//               fontSize: 12,
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ============================================================
// // EMPTY FILTER
// // ============================================================
//
// class _FilterEmptyHint extends StatelessWidget {
//   final String text;
//
//   const _FilterEmptyHint({super.key, required this.text});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 38,
//       padding: const EdgeInsets.symmetric(horizontal: 12),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(.025),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: Colors.white.withOpacity(.08)),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(
//             Icons.info_outline_rounded,
//             size: 15,
//             color: Colors.white.withOpacity(.38),
//           ),
//           const SizedBox(width: 8),
//           Flexible(
//             child: Text(
//               text,
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(
//                 color: Colors.white.withOpacity(.46),
//                 fontSize: 12,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ============================================================
// // COLLAPSE TOGGLE
// // ============================================================
//
// class _CollapseToggle extends StatelessWidget {
//   final bool expanded;
//   final VoidCallback onTap;
//   final ChartTheme theme;
//
//   const _CollapseToggle({
//     required this.expanded,
//     required this.onTap,
//     required this.theme,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(10),
//       child: Container(
//         height: 38,
//         padding: const EdgeInsets.symmetric(horizontal: 12),
//         decoration: BoxDecoration(
//           color: Colors.white.withOpacity(.05),
//           borderRadius: BorderRadius.circular(10),
//           border: Border.all(
//             color: expanded
//                 ? theme.line.withOpacity(.30)
//                 : Colors.white.withOpacity(.14),
//           ),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(
//               expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
//               color: Colors.white.withOpacity(.85),
//               size: 18,
//             ),
//             const SizedBox(width: 7),
//             Text(
//               expanded ? 'Hide Tabs' : 'Show Tabs',
//               style: TextStyle(
//                 color: Colors.white.withOpacity(.88),
//                 fontSize: 12,
//                 fontWeight: FontWeight.w800,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // ============================================================
// // IMPORTANT SWITCH
// // ============================================================
//
// class _ImportantSwitch extends StatelessWidget {
//   final bool value;
//   final bool enabled;
//
//   final ValueChanged<bool> onChanged;
//
//   final ChartTheme theme;
//
//   const _ImportantSwitch({
//     required this.value,
//     required this.enabled,
//     required this.onChanged,
//     required this.theme,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 38,
//       padding: const EdgeInsets.only(left: 10, right: 4),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(.05),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(
//           color: value
//               ? theme.line.withOpacity(.30)
//               : Colors.white.withOpacity(.14),
//         ),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(
//             Icons.star_rounded,
//             size: 17,
//             color: value ? theme.line : Colors.white54,
//           ),
//           const SizedBox(width: 7),
//           Text(
//             'Important',
//             style: TextStyle(
//               color: Colors.white.withOpacity(enabled ? .88 : .42),
//               fontSize: 12,
//               fontWeight: FontWeight.w800,
//             ),
//           ),
//           const SizedBox(width: 3),
//           Transform.scale(
//             scale: .78,
//             child: Switch(
//               value: value,
//               activeColor: theme.line,
//               onChanged: enabled ? onChanged : null,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ============================================================
// // TAB ROW
// // ============================================================
//
// class _GlassTabRow extends StatelessWidget {
//   final List<String> labels;
//   final int selectedIndex;
//
//   final ValueChanged<int> onSelect;
//
//   final bool alignRight;
//
//   final ChartTheme theme;
//
//   final bool showAllChip;
//   final bool allChipSelected;
//
//   final VoidCallback? onAllTap;
//
//   const _GlassTabRow({
//     required this.labels,
//     required this.selectedIndex,
//     required this.onSelect,
//     required this.theme,
//     this.alignRight = false,
//     this.showAllChip = false,
//     this.allChipSelected = false,
//     this.onAllTap,
//   });
//
//   Widget _buildChip({
//     required String label,
//     required bool selected,
//     required VoidCallback onTap,
//   }) {
//     return ScadaTabButton(
//       label: label,
//       selected: selected,
//       onTap: onTap,
//       color: theme.line,
//       minWidth: label.length <= 4 ? 66 : 92,
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final children = <Widget>[];
//
//     if (showAllChip) {
//       children.add(
//         _buildChip(
//           label: 'ALL',
//           selected: allChipSelected,
//           onTap: onAllTap ?? () {},
//         ),
//       );
//     }
//
//     for (var index = 0; index < labels.length; index++) {
//       children.add(
//         _buildChip(
//           label: labels[index],
//           selected: index == selectedIndex,
//           onTap: () => onSelect(index),
//         ),
//       );
//     }
//
//     final tabs = Wrap(spacing: 8, runSpacing: 8, children: children);
//
//     if (alignRight) {
//       return Align(alignment: Alignment.topRight, child: tabs);
//     }
//
//     return tabs;
//   }
// }
