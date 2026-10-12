import '../models/latest_tree_response.dart';
import '../models/signal_history_models.dart';

/// Mot signal trong cay latest, kem boxDeviceId de goi API theo device.
class LatestSignalRef {
  final String boxDeviceId;
  final LatestSignalDto signal;

  const LatestSignalRef({required this.boxDeviceId, required this.signal});
}

/// Index signal cua cay latest theo id cua buildSignalHistoryId, de API
/// repository lay boxDeviceId / plcAddress / ten / unit.
Map<String, LatestSignalRef> indexLatestSignals(List<LatestFacilityDto> tree) {
  final index = <String, LatestSignalRef>{};

  for (final facility in tree) {
    for (final category in facility.categories) {
      for (final scada in category.scadas) {
        for (final box in scada.boxes) {
          for (final device in box.devices) {
            for (final signal in device.signals) {
              final id = buildSignalHistoryId(
                fac: facility.fac,
                cate: category.cate,
                scadaId: scada.scadaId,
                boxId: box.boxId,
                boxDeviceId: device.boxDeviceId,
                plcAddress: signal.plcAddress,
              );

              index[id] = LatestSignalRef(
                boxDeviceId: device.boxDeviceId,
                signal: signal,
              );
            }
          }
        }
      }
    }
  }

  return index;
}
