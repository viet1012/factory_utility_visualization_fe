class TreeSeriesResponse {
  final String fac;
  final String bucket; // DAY / HOUR
  final DateTime from;
  final DateTime to;
  final List<CateGroup> cates;

  TreeSeriesResponse({
    required this.fac,
    required this.bucket,
    required this.from,
    required this.to,
    required this.cates,
  });

  factory TreeSeriesResponse.fromJson(Map<String, dynamic> j) {
    return TreeSeriesResponse(
      fac: (j['fac'] ?? '').toString(),
      bucket: (j['bucket'] ?? '').toString(),
      from: DateTime.parse(j['from'].toString()),
      to: DateTime.parse(j['to'].toString()),
      cates: (j['cates'] as List? ?? [])
          .map((e) => CateGroup.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  /// helper: l?y dúng signal theo box + plc
  SignalNode? findSignal({
    required String boxDeviceId,
    required String plcAddress,
  }) {
    for (final cg in cates) {
      for (final bg in cg.boxDevices) {
        if (bg.boxDeviceId != boxDeviceId) continue;
        for (final s in bg.signals) {
          if (s.plcAddress == plcAddress) return s;
        }
      }
    }
    return null;
  }
}

class CateGroup {
  final String cate;
  final List<BoxDeviceGroup> boxDevices;

  CateGroup({required this.cate, required this.boxDevices});

  factory CateGroup.fromJson(Map<String, dynamic> j) {
    return CateGroup(
      cate: (j['cate'] ?? '').toString(),
      boxDevices: (j['boxDevices'] as List? ?? [])
          .map(
            (e) => BoxDeviceGroup.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}

class BoxDeviceGroup {
  final String boxDeviceId;
  final List<SignalNode> signals;

  BoxDeviceGroup({required this.boxDeviceId, required this.signals});

  factory BoxDeviceGroup.fromJson(Map<String, dynamic> j) {
    return BoxDeviceGroup(
      boxDeviceId: (j['boxDeviceId'] ?? '').toString(),
      signals: (j['signals'] as List? ?? [])
          .map((e) => SignalNode.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class SignalNode {
  final String plcAddress;
  final String? nameVi;
  final String? nameEn;
  final String? unit;
  final String? scadaId;
  final List<TreePoint> points;

  SignalNode({
    required this.plcAddress,
    required this.points,
    this.nameVi,
    this.nameEn,
    this.unit,
    this.scadaId,
  });

  factory SignalNode.fromJson(Map<String, dynamic> j) {
    return SignalNode(
      plcAddress: (j['plcAddress'] ?? '').toString(),
      nameVi: j['nameVi']?.toString(),
      nameEn: j['nameEn']?.toString(),
      unit: j['unit']?.toString(),
      scadaId: j['scadaId']?.toString(),
      points: (j['points'] as List? ?? [])
          .map((e) => TreePoint.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class TreePoint {
  final DateTime ts;
  final double value;

  TreePoint({required this.ts, required this.value});

  factory TreePoint.fromJson(Map<String, dynamic> j) {
    return TreePoint(
      ts: DateTime.parse(j['ts'].toString()),
      value: (j['value'] as num).toDouble(),
    );
  }
}
