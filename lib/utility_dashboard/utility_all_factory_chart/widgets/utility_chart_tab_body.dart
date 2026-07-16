import 'package:factory_utility_visualization/utility_dashboard/utility_all_factory_chart/tabs/utility_minutes_tab.dart';
import 'package:flutter/material.dart';

import '../tabs/utility_daily_tab.dart';
import '../utility_all_factories_controller.dart';

class UtilityChartTabBody extends StatelessWidget {
  final UtilityAllFactoriesController controller;
  final String? selectedScada;
  final String selectedBox;

  const UtilityChartTabBody({
    super.key,
    required this.controller,
    required this.selectedScada,
    required this.selectedBox,
  });

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: controller.selectedView.index,
      children: [
        UtilityMinutesTab(
          facId: controller.selectedFac,
          cate: controller.selectedCate,
          scadaId: selectedScada,
          selectedBox: selectedBox,
          importantOnly: controller.importantOnly,
        ),
        UtilityDailyTab(
          facId: controller.selectedFac,
          cate: controller.selectedCate,
          scadaId: selectedScada,
          selectedBox: selectedBox,
          importantOnly: controller.importantOnly,
        ),
      ],
    );
  }
}
