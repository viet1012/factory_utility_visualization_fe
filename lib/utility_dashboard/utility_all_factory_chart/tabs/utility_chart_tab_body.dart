import 'package:flutter/material.dart';

import '../tabs/utility_daily_tab.dart';
import '../tabs/utility_minutes_tab.dart';
import '../utility_all_factories_controller.dart';

class UtilityChartTabBody extends StatelessWidget {
  final UtilityAllFactoriesController controller;

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
    required this.selectedScada,
    required this.selectedBoxId,
    required this.selectedBoxDeviceId,
    required this.boxDeviceIds,
  });

  String _resolveSelectedDevice() {
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
    final selectedDevice = _resolveSelectedDevice();

    debugPrint(
      '[CHART TAB BODY] '
      'boxGroup=$selectedBoxId, '
      'selectedDevice=$selectedDevice, '
      'devices=$boxDeviceIds',
    );

    return IndexedStack(
      index: controller.selectedView.index,
      children: [
        UtilityMinutesTab(
          facId: controller.selectedFac,
          cate: controller.selectedCate,
          scadaId: selectedScada,

          /// Phải truyền ALL hoặc device thật.
          /// Không truyền selectedBoxId = DB-03.
          selectedBox: selectedDevice,

          importantOnly: controller.importantOnly,
        ),

        UtilityDailyTab(
          facId: controller.selectedFac,
          cate: controller.selectedCate,
          scadaId: selectedScada,

          /// Daily vẫn có thể dùng BOX GROUP.
          boxId: selectedBoxId,

          selectedBoxDeviceId: selectedBoxDeviceId,
          boxDeviceIds: boxDeviceIds,
        ),
      ],
    );
  }
}
