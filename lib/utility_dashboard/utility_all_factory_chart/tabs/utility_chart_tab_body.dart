import 'package:flutter/material.dart';

import '../tabs/utility_daily_tab.dart';
import '../tabs/utility_minutes_tab.dart';
import '../utility_all_factories_controller.dart';

class UtilityChartTabBody extends StatelessWidget {
  final UtilityAllFactoriesController controller;

  final String? selectedScada;
  final String? selectedBoxId;
  final String? selectedBoxDeviceId;

  final List<String> boxDeviceIds;

  const UtilityChartTabBody({
    super.key,
    required this.controller,
    required this.selectedScada,
    required this.selectedBoxId,
    required this.selectedBoxDeviceId,
    required this.boxDeviceIds,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBoxLabel =
        selectedBoxDeviceId ?? selectedBoxId ?? 'Not configured';

    return IndexedStack(
      index: controller.selectedView.index,
      children: [
        UtilityMinutesTab(
          facId: controller.selectedFac,
          cate: controller.selectedCate,
          scadaId: selectedScada,
          selectedBox: selectedBoxLabel,
          importantOnly: controller.importantOnly,
        ),

        UtilityDailyTab(
          facId: controller.selectedFac,
          cate: controller.selectedCate,
          scadaId: selectedScada,
          boxId: selectedBoxId,
          selectedBoxDeviceId: selectedBoxDeviceId,
          boxDeviceIds: boxDeviceIds,
        ),
      ],
    );
  }
}
