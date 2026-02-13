import 'package:flutter/material.dart';

import '../../../utility_models/utility_facade_service.dart';

class OverlayLayoutStore extends ChangeNotifier {
  final UtilityFacadeService svc;

  OverlayLayoutStore(this.svc);

  final Map<String, Map<String, Offset>> _layouts = {};

  bool _loading = false;

  bool get loading => _loading;

  Map<String, Offset> layoutOf(String facId) => _layouts[facId] ?? {};

  // LOAD FROM DB
  Future<void> load(String facId) async {
    _loading = true;
    notifyListeners();

    final res = await svc.getOverlay(facId);
    print("OVERLAY RESULT: $res");
    _layouts[facId] = {for (final e in res) e.plcAddress: Offset(e.x, e.y)};

    _loading = false;
    notifyListeners();
  }

  // UPSERT + UPDATE UI
  Future<void> setPos({
    required String facId,
    required String boxDeviceId,
    required String plcAddress,
    required Offset pos01,
  }) async {
    final m = _layouts.putIfAbsent(facId, () => {});
    m[plcAddress] = pos01;
    notifyListeners();

    await svc.upsertOverlay(
      facId: facId,
      boxDeviceId: boxDeviceId,
      plcAddress: plcAddress,
      x: pos01.dx,
      y: pos01.dy,
    );
  }
}
