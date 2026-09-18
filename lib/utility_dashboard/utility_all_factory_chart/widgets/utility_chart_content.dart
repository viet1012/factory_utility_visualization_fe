import 'package:factory_utility_visualization/utility_dashboard/utility_all_factory_chart/widgets/utility_chart_top_bar.dart';
import 'package:flutter/material.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../tabs/utility_chart_tab_body.dart';
import '../tabs/utility_chart_view.dart';
import '../controllers/utility_chart_controller.dart';
import 'utility_chart_filters.dart';

class UtilityChartContent extends StatelessWidget {
  final UtilityChartController controller;
  final ChartTheme theme;
  final bool isActive;

  const UtilityChartContent({
    super.key,
    required this.controller,
    required this.theme,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final catalog = controller.catalog;

    // ============================================================
    // SAFE INDEXES
    // ============================================================

    final scadaIndex = controller.safeIndex(
      controller.selectedScadaIndex,
      catalog.scadaIds.length,
    );

    final boxIdIndex = controller.safeIndex(
      controller.selectedBoxIdIndex,
      catalog.boxIds.length,
    );

    final deviceIndex = controller.safeIndex(
      controller.selectedBoxDeviceIndex,
      catalog.boxDeviceIds.length,
    );

    // ============================================================
    // SELECTED VALUES
    // ============================================================

    final selectedScada = controller.valueAt(catalog.scadaIds, scadaIndex);

    final selectedBoxId = controller.valueAt(catalog.boxIds, boxIdIndex);

    final selectedDevice = controller.selectedAllDevices
        ? null
        : controller.valueAt(catalog.boxDeviceIds, deviceIndex);

    final selectedScadaDisplay = selectedScada ?? 'Not configured';

    final selectedBoxDisplay =
        selectedDevice ??
        (selectedBoxId == null
            ? 'Not configured'
            : '$selectedBoxId (ALL DEVICES)');

    // ============================================================
    // LOADING STATE
    // ============================================================

    final hasCatalog =
        catalog.scadaIds.isNotEmpty ||
        catalog.boxIds.isNotEmpty ||
        catalog.boxDeviceIds.isNotEmpty;

    final initialLoading = catalog.loading && !hasCatalog;
    final refreshing = catalog.loading && hasCatalog;

    final viewTabs = UtilityChartView.values
        .map((view) => view.label)
        .toList(growable: false);

    final selectedViewIndex = UtilityChartView.values.indexOf(
      controller.selectedView,
    );

    // ============================================================
    // PAGE CONTENT
    // ============================================================

    return Column(
      children: [
        UtilityChartTopBar(
          filtersExpanded: controller.filtersExpanded,

          selectedCate: controller.selectedCate,
          selectedFac: controller.selectedFac,
          selectedScada: selectedScadaDisplay,
          selectedBox: selectedBoxDisplay,

          viewTabs: viewTabs,
          selectedViewIndex: selectedViewIndex,

          onViewChanged: (index) {
            if (index < 0 || index >= UtilityChartView.values.length) {
              return;
            }

            controller.changeView(UtilityChartView.values[index]);
          },

          importantOnly: controller.importantOnly,
          onImportantChanged: controller.changeImportant,

          onToggleFilters: controller.toggleFilters,

          showImportantSwitch:
              controller.selectedView == UtilityChartView.minutes,

          importantEnabled: !initialLoading,
          refreshing: refreshing,

          theme: theme,
        ),

        const SizedBox(height: 8),

        UtilityChartFilters(
          expanded: controller.filtersExpanded,

          cateTabs: UtilityChartController.cateTabs,
          facTabs: UtilityChartController.facTabs,

          scadaTabs: catalog.scadaIds,
          boxIdTabs: catalog.boxIds,
          boxDeviceTabs: catalog.boxDeviceIds,

          loadingScadas: initialLoading,
          loadingBoxes: initialLoading,

          selectedCateIndex: controller.selectedCateIndex,
          selectedFacIndex: controller.selectedFacIndex,
          selectedScadaIndex: scadaIndex,
          selectedBoxIdIndex: boxIdIndex,
          selectedBoxDeviceIndex: deviceIndex,

          selectedAllDevices: controller.selectedAllDevices,

          onCateChanged: controller.changeCate,
          onFacChanged: controller.changeFacility,
          onScadaChanged: controller.changeScada,
          onBoxIdChanged: controller.changeBoxId,
          onBoxDeviceChanged: controller.changeDevice,

          onAllDevicesSelected: controller.selectAllDevices,

          theme: theme,
        ),

        const SizedBox(height: 6),

        Expanded(
          child: UtilityChartTabBody(
            controller: controller,
            isActive: isActive,
            selectedScada: selectedScada,
            selectedBoxId: selectedBoxId,
            selectedBoxDeviceId: selectedDevice,
            boxDeviceIds: List<String>.from(catalog.boxDeviceIds),
          ),
        ),
      ],
    );
  }
}
