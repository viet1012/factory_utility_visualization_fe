import 'package:factory_utility_visualization/utility_models/f2_utility_parameter_history.dart';
import 'package:factory_utility_visualization/utility_models/f2_utility_parameter_master.dart';
import 'package:factory_utility_visualization/utility_models/f2_utility_scada_box.dart';
import 'package:factory_utility_visualization/utility_models/f2_utility_scada_channel.dart';

import 'utility_repository.dart';

class UtilityFacadeService {
  final UtilityRepository repo;

  UtilityFacadeService(this.repo);

  Future<List<FacTree>> fetchFacTrees({DateTime? at, int seed = 1}) async {
    final boxes = await repo.fetchBoxes();
    final channels = await repo.fetchChannels();
    final masters = await repo.fetchMasters();
    final latest = await repo.fetchLatestHistories(at: at, seed: seed);

    String key(String d, String a) => '$d::$a';
    final latestMap = <String, UtilityParameterHistory>{
      for (final h in latest) key(h.boxDeviceId, h.plcAddress): h,
    };

    final channelsByScada = <String, List<UtilityScadaChannel>>{};
    for (final c in channels) {
      channelsByScada.putIfAbsent(c.scadaId, () => []).add(c);
    }

    final mastersByDevice = <String, List<UtilityParameterMaster>>{};
    for (final m in masters) {
      mastersByDevice.putIfAbsent(m.boxDeviceId, () => []).add(m);
    }

    final boxesByFac = <String, List<UtilityScadaBox>>{};
    for (final b in boxes) {
      boxesByFac.putIfAbsent(b.facName, () => []).add(b);
    }

    final facIds = boxesByFac.keys.toList()..sort();

    final out = <FacTree>[];
    for (final facId in facIds) {
      final facBoxes = boxesByFac[facId] ?? const [];
      final facName = facBoxes.isNotEmpty ? facBoxes.first.facName : facId;

      final boxTrees = <BoxTree>[];
      for (final b in facBoxes) {
        final cs = channelsByScada[b.scadaId] ?? const [];
        final devTrees = <DeviceTree>[];

        for (final c in cs) {
          final ms = mastersByDevice[c.boxDeviceId] ?? const [];
          final params = ms
              .map(
                (m) => ParamNode(
                  master: m,
                  latest: latestMap[key(m.boxDeviceId, m.plcAddress)],
                ),
              )
              .toList();

          devTrees.add(DeviceTree(channel: c, params: params));
        }

        boxTrees.add(BoxTree(box: b, devices: devTrees));
      }

      out.add(FacTree(facId: facId, facName: facName, boxes: boxTrees));
    }

    return out;
  }
}

/// ===== UI tree models =====

class FacTree {
  final String facId;
  final String facName;
  final List<BoxTree> boxes;

  const FacTree({
    required this.facId,
    required this.facName,
    required this.boxes,
  });
}

class BoxTree {
  final UtilityScadaBox box;
  final List<DeviceTree> devices;

  const BoxTree({required this.box, required this.devices});
}

class DeviceTree {
  final UtilityScadaChannel channel;
  final List<ParamNode> params;

  const DeviceTree({required this.channel, required this.params});
}

class ParamNode {
  final UtilityParameterMaster master;
  final UtilityParameterHistory? latest;

  const ParamNode({required this.master, required this.latest});
}
