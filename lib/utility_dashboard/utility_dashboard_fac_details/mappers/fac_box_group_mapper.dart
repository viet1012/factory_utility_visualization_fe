import '../models/fac_box_view_data.dart';
import '../models/fac_device_view_data.dart';

class FacBoxGroupMapper {
  const FacBoxGroupMapper._();

  static Map<String, FacBoxViewData> groupDevices(
    Map<String, FacDeviceViewData> devicesById,
  ) {
    final result = <String, FacBoxViewData>{};

    for (final entry in devicesById.entries) {
      final boxDeviceId = entry.key.trim();
      final device = entry.value;

      final boxId = device.primaryBoxId?.trim() ?? '';

      if (boxId.isEmpty) {
        continue;
      }

      // Dùng Box ID làm key chính.
      final group = result.putIfAbsent(
        boxId,
        () => FacBoxViewData(key: boxId, boxId: boxId),
      );

      if (boxDeviceId.isNotEmpty) {
        group.boxDeviceIds.add(boxDeviceId);
      }

      group.categories.addAll(device.categories);
      group.scadaIds.addAll(device.scadaIds);
      group.signals.addAll(device.signals);
    }

    for (final group in result.values) {
      group.signals.sort((a, b) {
        final plcCompare = (a.plcAddress ?? '').trim().toLowerCase().compareTo(
          (b.plcAddress ?? '').trim().toLowerCase(),
        );

        if (plcCompare != 0) {
          return plcCompare;
        }

        return (a.nameEn ?? '').trim().toLowerCase().compareTo(
          (b.nameEn ?? '').trim().toLowerCase(),
        );
      });
    }

    return Map<String, FacBoxViewData>.unmodifiable(result);
  }

  static List<String> sortedKeys(Map<String, FacBoxViewData> groups) {
    final keys = groups.keys.toList();

    keys.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return List<String>.unmodifiable(keys);
  }
}
