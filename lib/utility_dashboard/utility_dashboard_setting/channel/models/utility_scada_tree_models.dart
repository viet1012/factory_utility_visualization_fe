class UtilityScadaTreeFacRaw {
  final String fac;
  final String scadaId;
  final List<UtilityScadaTreeBoxRaw> boxes;

  const UtilityScadaTreeFacRaw({
    required this.fac,
    required this.scadaId,
    required this.boxes,
  });

  factory UtilityScadaTreeFacRaw.fromJson(Map<String, dynamic> json) {
    return UtilityScadaTreeFacRaw(
      fac: json['fac']?.toString() ?? '',
      scadaId: json['scadaId']?.toString() ?? '',
      boxes: (json['boxes'] as List? ?? [])
          .map(
            (e) =>
                UtilityScadaTreeBoxRaw.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
}

class UtilityScadaTreeBoxRaw {
  final String boxId;
  final List<UtilityScadaTreeDeviceRaw> devices;

  const UtilityScadaTreeBoxRaw({required this.boxId, required this.devices});

  factory UtilityScadaTreeBoxRaw.fromJson(Map<String, dynamic> json) {
    return UtilityScadaTreeBoxRaw(
      boxId: json['boxId']?.toString() ?? '',
      devices: (json['devices'] as List? ?? [])
          .map(
            (e) => UtilityScadaTreeDeviceRaw.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }
}

class UtilityScadaTreeDeviceRaw {
  final int? channelId;
  final String cate;
  final String boxDeviceId;

  const UtilityScadaTreeDeviceRaw({
    required this.channelId,
    required this.cate,
    required this.boxDeviceId,
  });

  factory UtilityScadaTreeDeviceRaw.fromJson(Map<String, dynamic> json) {
    return UtilityScadaTreeDeviceRaw(
      channelId: json['channelId'] as int?,
      cate: json['cate']?.toString() ?? '',
      boxDeviceId: json['boxDeviceId']?.toString() ?? '',
    );
  }
}

class FacTreeNode {
  final String fac;
  final List<ScadaTreeNode> scadas;

  const FacTreeNode({required this.fac, required this.scadas});
}

class ScadaTreeNode {
  final String scadaId;
  final List<BoxTreeNode> boxes;

  const ScadaTreeNode({required this.scadaId, required this.boxes});
}

class BoxTreeNode {
  final String boxId;
  final List<DeviceTreeNode> devices;

  const BoxTreeNode({required this.boxId, required this.devices});
}

class DeviceTreeNode {
  final int? channelId; // channelId = id
  final String cate;
  final String boxDeviceId;
  final String scadaId;
  final String boxId;

  const DeviceTreeNode({
    required this.channelId,
    required this.cate,
    required this.boxDeviceId,
    required this.scadaId,
    required this.boxId,
  });
}

List<FacTreeNode> regroupTree(List<UtilityScadaTreeFacRaw> raw) {
  final Map<String, List<UtilityScadaTreeFacRaw>> grouped = {};
  for (final item in raw) {
    grouped.putIfAbsent(item.fac, () => []).add(item);
  }
  return grouped.entries.map((entry) {
    return FacTreeNode(
      fac: entry.key,
      scadas: entry.value.map((scadaRaw) {
        return ScadaTreeNode(
          scadaId: scadaRaw.scadaId,
          boxes: scadaRaw.boxes.map((boxRaw) {
            return BoxTreeNode(
              boxId: boxRaw.boxId,
              devices: boxRaw.devices.map((d) {
                return DeviceTreeNode(
                  channelId: d.channelId,
                  cate: d.cate,
                  boxDeviceId: d.boxDeviceId,
                  scadaId: scadaRaw.scadaId,
                  boxId: boxRaw.boxId,
                );
              }).toList(),
            );
          }).toList(),
        );
      }).toList(),
    );
  }).toList();
}

int countDevices(List<FacTreeNode> items) {
  var count = 0;
  for (final fac in items) {
    for (final scada in fac.scadas) {
      for (final box in scada.boxes) {
        count += box.devices.length;
      }
    }
  }
  return count;
}
