import 'dart:async';

import 'package:flutter/material.dart';

import 'utility_chart_catalog_controller.dart';
import '../tabs/utility_chart_view.dart';

/// Yeu cau mo CHARTS tai mot signal (vd tu WATER CHECK): moi lan mo la mot
/// object moi de ValueNotifier luon bao doi.
class ChartFocusRequest {
  final String facId;
  final String cate;
  final String boxDeviceId;
  final String plcAddress;
  final UtilityChartView view;

  const ChartFocusRequest({
    required this.facId,
    required this.cate,
    required this.boxDeviceId,
    required this.plcAddress,
    this.view = UtilityChartView.minutes,
  });
}

class UtilityChartController extends ChangeNotifier {
  final UtilityChartCatalogController catalog;

  UtilityChartController({required this.catalog});

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

  /// True when the catalog already holds valid, non-expired data for the
  /// current selection, so re-entering the screen needs no network round trip.
  bool get hasFreshCatalog => catalog.isFresh(
    facId: selectedFac,
    cate: selectedCate,
    importantOnly: importantValue,
  );

  /// Reloads only when the cached catalog is stale.
  ///
  /// Used on screen re-entry: an unconditional [loadCatalog] would toggle the
  /// catalog's loading flag twice and rebuild the entire chart tree even on a
  /// cache hit.
  Future<void> refreshIfStale() async {
    if (hasFreshCatalog) return;
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

  /// Chon fac / cate / view cua [request], tai catalog roi chon dung
  /// scada / box / device chua signal. Bo Important de signal khong bi an.
  Future<void> focusSignal(ChartFocusRequest request) async {
    final facIndex = _indexIgnoreCase(facTabs, request.facId);
    final cateIndex = _indexIgnoreCase(cateTabs, request.cate);
    if (facIndex < 0 || cateIndex < 0) return;

    _reloadDebounce?.cancel();

    selectedFacIndex = facIndex;
    selectedCateIndex = cateIndex;
    selectedView = request.view;
    importantOnly = false;
    resetLocalFilters();
    notifyListeners();

    await loadCatalog();

    final item = catalog.catalogItemFor(
      request.boxDeviceId,
      request.plcAddress,
    );
    if (item == null) return;

    catalog.selectScadaId(item.scadaId);
    catalog.selectBoxId(item.boxId);
    catalog.selectBoxDeviceId(item.boxDeviceId);

    syncIndexesFromProvider();
    notifyListeners();
  }

  static int _indexIgnoreCase(List<String> values, String value) {
    final target = value.trim().toLowerCase();
    return values.indexWhere((item) => item.toLowerCase() == target);
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
