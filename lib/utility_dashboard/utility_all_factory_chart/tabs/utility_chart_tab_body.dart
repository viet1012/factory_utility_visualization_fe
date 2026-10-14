import 'package:flutter/material.dart';

import '../tabs/utility_daily_tab.dart';
import '../tabs/utility_hourly_tab.dart';
import '../tabs/utility_minutes_tab.dart';
import '../controllers/utility_chart_controller.dart';
import 'utility_chart_view.dart';

class UtilityChartTabBody extends StatelessWidget {
  final UtilityChartController controller;
  final bool isActive;

  /// SCADA đang chọn, ví dụ A1.
  final String? selectedScada;

  /// DEVICE đang chọn.
  ///
  /// null hoặc rỗng nghĩa là đang chọn ALL.
  /// Ví dụ:
  /// DB-03_ES35-SW
  /// DB-03_MFM384
  final String? selectedBoxDeviceId;

  const UtilityChartTabBody({
    super.key,
    required this.controller,
    required this.isActive,
    required this.selectedScada,
    required this.selectedBoxDeviceId,
  });

  String get _selectedDevice {
    final device = selectedBoxDeviceId?.trim();

    /*
     * Khi người dùng bấm ALL:
     * selectedBoxDeviceId thường null hoặc rỗng.
     *
     * Phải trả về ALL, tuyệt đối không lấy BOX GROUP.
     */
    if (device == null || device.isEmpty) {
      return 'ALL';
    }

    return device;
  }

  @override
  Widget build(BuildContext context) {
    final minutesVisible = controller.selectedView == UtilityChartView.minutes;
    final hoursVisible = controller.selectedView == UtilityChartView.hours;
    final dailyVisible = controller.selectedView == UtilityChartView.daily;

    // IndexedStack keeps every tab mounted so switching is instant and chart
    // state survives. TickerMode makes sure a hidden tab cannot keep a
    // ticker running, so preserved state never turns into background CPU.
    // Children must follow the declaration order of UtilityChartView.
    //
    // Ca 3 tab: ALL hoac device that (khong phai BOX GROUP); danh sach signal
    // lay tu catalog.
    return IndexedStack(
      index: controller.selectedView.index,
      children: [
        TickerMode(
          enabled: minutesVisible,
          child: UtilityMinutesTab(
            isActive: isActive && minutesVisible,
            facId: controller.selectedFac,
            cate: controller.selectedCate,
            scadaId: selectedScada,
            selectedBox: _selectedDevice,
            importantOnly: controller.importantOnly,
          ),
        ),

        TickerMode(
          enabled: hoursVisible,
          child: UtilityHourlyTab(
            isActive: isActive && hoursVisible,
            facId: controller.selectedFac,
            cate: controller.selectedCate,
            scadaId: selectedScada,
            selectedBox: _selectedDevice,
            importantOnly: controller.importantOnly,
          ),
        ),

        TickerMode(
          enabled: dailyVisible,
          child: UtilityDailyTab(
            isActive: isActive && dailyVisible,
            facId: controller.selectedFac,
            cate: controller.selectedCate,
            scadaId: selectedScada,
            selectedBox: _selectedDevice,
            importantOnly: controller.importantOnly,
          ),
        ),
      ],
    );
  }
}
