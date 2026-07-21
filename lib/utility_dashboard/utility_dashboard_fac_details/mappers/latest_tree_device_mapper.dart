import '../../utility_dashboard_overview/'
    'utility_dashboard_overview_models/latest_tree_response.dart';
import '../models/fac_device_view_data.dart';

class LatestTreeDeviceMapper {
  const LatestTreeDeviceMapper._();

  static Map<String, FacDeviceViewData> mapFacility(
    LatestFacilityDto? facility,
  ) {
    final result = <String, FacDeviceViewData>{};

    if (facility == null) {
      return result;
    }

    for (final category in facility.categories) {
      for (final scada in category.scadas) {
        for (final box in scada.boxes) {
          for (final device in box.devices) {
            final boxDeviceId = device.boxDeviceId.trim();

            if (boxDeviceId.isEmpty) {
              continue;
            }

            final viewData = result.putIfAbsent(
              boxDeviceId,
              () => FacDeviceViewData(boxDeviceId: boxDeviceId),
            );

            _addNonEmpty(viewData.categories, category.cate);

            _addNonEmpty(viewData.scadaIds, scada.scadaId);

            viewData.signals.addAll(device.signals);
          }
        }
      }
    }

    for (final device in result.values) {
      device.signals.sort(_compareSignals);
    }

    return result;
  }

  static List<String> sortedDeviceIds(Map<String, FacDeviceViewData> devices) {
    return devices.keys.toList()..sort(_compareText);
  }

  static DateTime? latestRecordedAt(Iterable<FacDeviceViewData> devices) {
    DateTime? latest;

    for (final device in devices) {
      for (final signal in device.signals) {
        final time = _parseDateTime(signal.recordedAt);

        if (time == null) continue;

        if (latest == null || time.isAfter(latest)) {
          latest = time;
        }
      }
    }

    return latest;
  }

  static void _addNonEmpty(Set<String> target, Object? value) {
    final text = value?.toString().trim() ?? '';

    if (text.isNotEmpty) {
      target.add(text);
    }
  }

  static int _compareSignals(LatestSignalDto first, LatestSignalDto second) {
    final nameCompare = _compareText(_signalName(first), _signalName(second));

    if (nameCompare != 0) {
      return nameCompare;
    }

    return _compareText(first.plcAddress, second.plcAddress);
  }

  static String _signalName(LatestSignalDto signal) {
    final nameEn = signal.nameEn.trim();

    if (nameEn.isNotEmpty) {
      return nameEn;
    }

    return signal.plcAddress.trim();
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }

  static int _compareText(String first, String second) {
    return first.trim().toLowerCase().compareTo(second.trim().toLowerCase());
  }
}
