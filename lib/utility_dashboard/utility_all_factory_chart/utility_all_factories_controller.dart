import 'dart:async';

import 'package:flutter/material.dart';

import '../../utility_state/chart_catalog_provider.dart';
import 'tabs/utility_chart_view.dart';

class UtilityAllFactoriesController extends ChangeNotifier {
  final ChartCatalogProvider catalog;

  UtilityAllFactoriesController({required this.catalog});

  static const cateTabs = <String>['Electricity', 'Water', 'Compressed Air'];

  static const facTabs = <String>['Fac_A', 'Fac_B', 'Fac_C'];

  Timer? _reloadDebounce;

  int selectedCateIndex = 0;
  int selectedFacIndex = 0;

  int selectedScadaIndex = 0;
  int selectedBoxIdIndex = 0;
  int selectedBoxDeviceIndex = -1;

  UtilityChartView selectedView = UtilityChartView.minutes;

  bool importantOnly = false;
  bool filtersExpanded = true;

  String get selectedCate => cateTabs[selectedCateIndex];

  String get selectedFac => facTabs[selectedFacIndex];

  int get importantValue => importantOnly ? 1 : 0;

  bool get selectedAllDevices => selectedBoxDeviceIndex < 0;

  Future<void> initialize() async {
    catalog.addListener(_onCatalogChanged);
    await loadCatalog();
  }

  void _onCatalogChanged() {
    syncIndexesFromProvider();
    notifyListeners();
  }

  Future<void> loadCatalog({bool forceRefresh = false}) async {
    await catalog.loadCatalog(
      facId: selectedFac,
      cate: selectedCate,
      importantOnly: importantValue,
      forceRefresh: forceRefresh,
    );

    syncIndexesFromProvider();
    notifyListeners();
  }

  void changeCate(int index) {
    if (index < 0 || index >= cateTabs.length) return;
    if (selectedCateIndex == index) return;

    selectedCateIndex = index;
    resetLocalFilters();

    notifyListeners();
    scheduleCatalogReload();
  }

  void changeFacility(int index) {
    if (index < 0 || index >= facTabs.length) return;
    if (selectedFacIndex == index) return;

    selectedFacIndex = index;
    resetLocalFilters();

    notifyListeners();
    scheduleCatalogReload();
  }

  void changeView(UtilityChartView view) {
    if (selectedView == view) return;

    selectedView = view;
    notifyListeners();
  }

  void changeImportant(bool value) {
    if (importantOnly == value) return;

    importantOnly = value;
    resetLocalFilters();

    notifyListeners();
    scheduleCatalogReload();
  }

  void changeScada(int index) {
    final values = catalog.scadaIds;

    if (index < 0 || index >= values.length) return;

    catalog.selectScadaId(values[index]);

    selectedScadaIndex = index;
    selectedBoxIdIndex = 0;
    selectedBoxDeviceIndex = -1;

    syncIndexesFromProvider();
    notifyListeners();
  }

  void changeBoxId(int index) {
    final values = catalog.boxIds;

    if (index < 0 || index >= values.length) return;

    catalog.selectBoxId(values[index]);

    selectedBoxIdIndex = index;
    selectedBoxDeviceIndex = -1;

    syncIndexesFromProvider();
    notifyListeners();
  }

  void changeDevice(int index) {
    final values = catalog.boxDeviceIds;

    if (index < 0 || index >= values.length) return;

    catalog.selectBoxDeviceId(values[index]);

    selectedBoxDeviceIndex = index;
    notifyListeners();
  }

  void selectAllDevices() {
    if (selectedBoxDeviceIndex < 0) return;

    catalog.selectAllDevices();

    selectedBoxDeviceIndex = -1;
    notifyListeners();
  }

  void toggleFilters() {
    filtersExpanded = !filtersExpanded;
    notifyListeners();
  }

  void resetLocalFilters() {
    selectedScadaIndex = 0;
    selectedBoxIdIndex = 0;
    selectedBoxDeviceIndex = -1;
  }

  void scheduleCatalogReload({bool forceRefresh = false}) {
    _reloadDebounce?.cancel();

    _reloadDebounce = Timer(const Duration(milliseconds: 180), () {
      loadCatalog(forceRefresh: forceRefresh);
    });
  }

  void syncIndexesFromProvider() {
    selectedScadaIndex = _resolveIndex(
      catalog.scadaIds,
      catalog.selectedScadaId,
      fallback: 0,
    );

    selectedBoxIdIndex = _resolveIndex(
      catalog.boxIds,
      catalog.selectedBoxId,
      fallback: 0,
    );

    selectedBoxDeviceIndex = _resolveIndex(
      catalog.boxDeviceIds,
      catalog.selectedBoxDeviceId,
      fallback: -1,
    );
  }

  int safeIndex(int index, int count) {
    if (count <= 0) return 0;
    return index.clamp(0, count - 1);
  }

  String? valueAt(List<String> values, int index) {
    if (index < 0 || index >= values.length) return null;
    return values[index];
  }

  int _resolveIndex(
    List<String> values,
    String? selected, {
    required int fallback,
  }) {
    if (selected == null) return fallback;

    final index = values.indexOf(selected);
    return index < 0 ? fallback : index;
  }

  @override
  void dispose() {
    _reloadDebounce?.cancel();
    catalog.removeListener(_onCatalogChanged);
    super.dispose();
  }
}
