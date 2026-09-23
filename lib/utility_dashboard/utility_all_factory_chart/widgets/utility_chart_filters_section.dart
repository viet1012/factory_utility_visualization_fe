import 'package:flutter/material.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../controllers/utility_chart_catalog_controller.dart';
import '../controllers/utility_chart_controller.dart';
import 'utility_chart_filters.dart';

/// Immutable snapshot of everything [UtilityChartFilters] renders.
///
/// Value equality is what lets the section skip rebuilding the filter row when
/// an unrelated controller change (most importantly `changeView`) fires.
@immutable
class _FiltersVm {
  final bool expanded;

  final List<String> scadaTabs;
  final List<String> boxIdTabs;
  final List<String> boxDeviceTabs;

  final bool initialLoading;

  /// False while the stored catalog still belongs to a previous request
  /// (e.g. Water options during a Water -> Electricity switch).
  final bool catalogMatches;

  final int selectedCateIndex;
  final int selectedFacIndex;
  final int selectedScadaIndex;
  final int selectedBoxIdIndex;
  final int selectedBoxDeviceIndex;

  final bool selectedAllDevices;

  const _FiltersVm({
    required this.expanded,
    required this.scadaTabs,
    required this.boxIdTabs,
    required this.boxDeviceTabs,
    required this.initialLoading,
    required this.catalogMatches,
    required this.selectedCateIndex,
    required this.selectedFacIndex,
    required this.selectedScadaIndex,
    required this.selectedBoxIdIndex,
    required this.selectedBoxDeviceIndex,
    required this.selectedAllDevices,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is _FiltersVm &&
        other.expanded == expanded &&
        // Catalog lists are rebuilt as new unmodifiable instances only when the
        // catalog actually changes, so identity is the correct (and cheap)
        // comparison here.
        identical(other.scadaTabs, scadaTabs) &&
        identical(other.boxIdTabs, boxIdTabs) &&
        identical(other.boxDeviceTabs, boxDeviceTabs) &&
        other.initialLoading == initialLoading &&
        other.catalogMatches == catalogMatches &&
        other.selectedCateIndex == selectedCateIndex &&
        other.selectedFacIndex == selectedFacIndex &&
        other.selectedScadaIndex == selectedScadaIndex &&
        other.selectedBoxIdIndex == selectedBoxIdIndex &&
        other.selectedBoxDeviceIndex == selectedBoxDeviceIndex &&
        other.selectedAllDevices == selectedAllDevices;
  }

  @override
  int get hashCode => Object.hash(
    expanded,
    identityHashCode(scadaTabs),
    identityHashCode(boxIdTabs),
    identityHashCode(boxDeviceTabs),
    initialLoading,
    catalogMatches,
    selectedCateIndex,
    selectedFacIndex,
    selectedScadaIndex,
    selectedBoxIdIndex,
    selectedBoxDeviceIndex,
    selectedAllDevices,
  );
}

/// Rebuild boundary around [UtilityChartFilters].
///
/// The filter row depends on no view-related state, so a `changeView`
/// notification must not rebuild it. This widget listens to the controller but
/// only rebuilds its child when the filter-relevant snapshot actually changes.
class UtilityChartFiltersSection extends StatefulWidget {
  final UtilityChartController controller;
  final ChartTheme theme;

  const UtilityChartFiltersSection({
    super.key,
    required this.controller,
    required this.theme,
  });

  @override
  State<UtilityChartFiltersSection> createState() =>
      _UtilityChartFiltersSectionState();
}

class _UtilityChartFiltersSectionState
    extends State<UtilityChartFiltersSection> {
  late _FiltersVm _vm;

  @override
  void initState() {
    super.initState();

    _vm = _readVm();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant UtilityChartFiltersSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);

      widget.controller.addListener(_handleControllerChanged);
    }

    // Re-read on every parent rebuild as well as on notifications. The
    // listener already keeps _vm current, but refreshing here removes any
    // dependency on listener-vs-rebuild ordering, so the filter row can never
    // render a stale snapshot. Assigning outside setState is safe: we are
    // already inside a build pass triggered by the parent.
    _vm = _readVm();
  }

  _FiltersVm _readVm() {
    final controller = widget.controller;
    final catalog = controller.catalog;

    /*
     * Options SCADA/BOX/DEVICE được dựng từ catalog nên phụ thuộc request.
     * Khi đổi category, catalog cũ vẫn còn cho tới khi response mới về,
     * vì vậy phải so signature trước khi dùng.
     */
    final catalogMatches =
        catalog.loadedRequestSignature ==
        UtilityChartCatalogController.buildRequestSignature(
          facId: controller.selectedFac,
          cate: controller.selectedCate,
          importantOnly: controller.importantValue,
        );

    // Không dùng list cũ khi request đã đổi.
    final scadaTabs = catalogMatches ? catalog.scadaIds : const <String>[];
    final boxIdTabs = catalogMatches ? catalog.boxIds : const <String>[];
    final boxDeviceTabs = catalogMatches
        ? catalog.boxDeviceIds
        : const <String>[];

    final hasCatalog =
        scadaTabs.isNotEmpty ||
        boxIdTabs.isNotEmpty ||
        boxDeviceTabs.isNotEmpty;

    return _FiltersVm(
      expanded: controller.filtersExpanded,
      scadaTabs: scadaTabs,
      boxIdTabs: boxIdTabs,
      boxDeviceTabs: boxDeviceTabs,
      // Mismatch cũng là trạng thái "chưa có dữ liệu cho request này".
      initialLoading: !catalogMatches || (catalog.loading && !hasCatalog),
      catalogMatches: catalogMatches,
      selectedCateIndex: controller.selectedCateIndex,
      selectedFacIndex: controller.selectedFacIndex,
      // Index chỉ có nghĩa khi list thuộc đúng request.
      selectedScadaIndex: catalogMatches
          ? controller.safeIndex(
              controller.selectedScadaIndex,
              scadaTabs.length,
            )
          : 0,
      selectedBoxIdIndex: catalogMatches
          ? controller.safeIndex(
              controller.selectedBoxIdIndex,
              boxIdTabs.length,
            )
          : 0,
      selectedBoxDeviceIndex: catalogMatches
          ? controller.safeIndex(
              controller.selectedBoxDeviceIndex,
              boxDeviceTabs.length,
            )
          : 0,
      selectedAllDevices: controller.selectedAllDevices,
    );
  }

  void _handleControllerChanged() {
    if (!mounted) return;

    final next = _readVm();
    if (next == _vm) return;

    setState(() {
      _vm = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return UtilityChartFilters(
      expanded: _vm.expanded,

      cateTabs: UtilityChartController.cateTabs,
      facTabs: UtilityChartController.facTabs,

      scadaTabs: _vm.scadaTabs,
      boxIdTabs: _vm.boxIdTabs,
      boxDeviceTabs: _vm.boxDeviceTabs,

      loadingScadas: _vm.initialLoading,
      loadingBoxes: _vm.initialLoading,

      selectedCateIndex: _vm.selectedCateIndex,
      selectedFacIndex: _vm.selectedFacIndex,
      selectedScadaIndex: _vm.selectedScadaIndex,
      selectedBoxIdIndex: _vm.selectedBoxIdIndex,
      selectedBoxDeviceIndex: _vm.selectedBoxDeviceIndex,

      selectedAllDevices: _vm.selectedAllDevices,

      onCateChanged: controller.changeCate,
      onFacChanged: controller.changeFacility,
      onScadaChanged: controller.changeScada,
      onBoxIdChanged: controller.changeBoxId,
      onBoxDeviceChanged: controller.changeDevice,

      onAllDevicesSelected: controller.selectAllDevices,

      theme: widget.theme,
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);

    super.dispose();
  }
}
