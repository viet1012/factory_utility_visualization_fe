import 'package:flutter/material.dart';

import '../tabs/utility_daily_tab.dart';
import '../tabs/utility_minutes_tab.dart';
import '../controllers/utility_chart_controller.dart';
import 'utility_chart_view.dart';

class UtilityChartTabBody extends StatelessWidget {
  final UtilityChartController controller;
  final bool isActive;

  /// SCADA đang chọn, ví dụ A1.
  final String? selectedScada;

  /// BOX GROUP đang chọn, ví dụ DB-03.
  final String? selectedBoxId;

  /// DEVICE đang chọn.
  ///
  /// null hoặc rỗng nghĩa là đang chọn ALL.
  /// Ví dụ:
  /// DB-03_ES35-SW
  /// DB-03_MFM384
  final String? selectedBoxDeviceId;

  /// Danh sách toàn bộ device thuộc BOX GROUP hiện tại.
  final List<String> boxDeviceIds;

  const UtilityChartTabBody({
    super.key,
    required this.controller,
    required this.isActive,
    required this.selectedScada,
    required this.selectedBoxId,
    required this.selectedBoxDeviceId,
    required this.boxDeviceIds,
  });

  String get _selectedDevice {
    final device = selectedBoxDeviceId?.trim();

    /*
     * Khi người dùng bấm ALL:
     * selectedBoxDeviceId thường null hoặc rỗng.
     *
     * Phải trả về ALL, tuyệt đối không lấy selectedBoxId.
     */
    if (device == null || device.isEmpty) {
      return 'ALL';
    }

    return device;
  }

  @override
  Widget build(BuildContext context) {
    final minutesVisible = controller.selectedView == UtilityChartView.minutes;

    // IndexedStack keeps both tabs mounted so switching is instant and chart
    // state survives. TickerMode makes sure the hidden tab cannot keep a
    // ticker running, so preserved state never turns into background CPU.
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

            /// Phải truyền ALL hoặc device thật.
            /// Không truyền selectedBoxId = DB-03.
            selectedBox: _selectedDevice,

            importantOnly: controller.importantOnly,
          ),
        ),

        TickerMode(
          enabled: !minutesVisible,
          child: UtilityDailyTab(
            isActive: isActive && !minutesVisible,
            facId: controller.selectedFac,
            cate: controller.selectedCate,
            scadaId: selectedScada,

            /// Daily vẫn có thể dùng BOX GROUP.
            boxId: selectedBoxId,

            selectedBoxDeviceId: selectedBoxDeviceId,
            boxDeviceIds: boxDeviceIds,
          ),
        ),
      ],
    );
  }
}
