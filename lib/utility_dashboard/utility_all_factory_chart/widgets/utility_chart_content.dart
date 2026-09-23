import 'package:factory_utility_visualization/utility_dashboard/utility_all_factory_chart/widgets/utility_chart_top_bar.dart';
import 'package:flutter/material.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../tabs/utility_chart_tab_body.dart';
import '../tabs/utility_chart_view.dart';
import '../controllers/utility_chart_catalog_controller.dart';
import '../controllers/utility_chart_controller.dart';
import 'utility_chart_filters_section.dart';

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

    /*
     * Catalog đang lưu có thể thuộc request trước đó (ví dụ Water) trong khi
     * người dùng đã chọn Electricity. Khi đó không được suy ra selection từ
     * dữ liệu cũ, tránh truyền SCADA/BOX/DEVICE sai xuống các tab con.
     */
    final catalogMatches =
        catalog.loadedRequestSignature ==
        UtilityChartCatalogController.buildRequestSignature(
          facId: controller.selectedFac,
          cate: controller.selectedCate,
          importantOnly: controller.importantValue,
        );

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

    final selectedScada = catalogMatches
        ? controller.valueAt(catalog.scadaIds, scadaIndex)
        : null;

    final selectedBoxId = catalogMatches
        ? controller.valueAt(catalog.boxIds, boxIdIndex)
        : null;

    final selectedDevice = !catalogMatches || controller.selectedAllDevices
        ? null
        : controller.valueAt(catalog.boxDeviceIds, deviceIndex);

    final selectedScadaDisplay = catalogMatches
        ? (selectedScada ?? 'Not configured')
        : 'Loading...';

    final selectedBoxDisplay = !catalogMatches
        ? 'Loading...'
        : selectedDevice ??
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

        UtilityChartFiltersSection(controller: controller, theme: theme),

        const SizedBox(height: 6),

        Expanded(
          child: UtilityChartTabBody(
            controller: controller,
            isActive: isActive,
            selectedScada: selectedScada,
            selectedBoxId: selectedBoxId,
            selectedBoxDeviceId: selectedDevice,
            // Pass the controller's list directly: copying it here allocated a
            // new object every rebuild, so downstream identity checks could
            // never short-circuit. Gated so a previous category's devices are
            // never handed to the tabs.
            boxDeviceIds: catalogMatches
                ? catalog.boxDeviceIds
                : const <String>[],
          ),
        ),
      ],
    );
  }
}
