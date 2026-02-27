// import 'package:flutter/material.dart';
//
// import '../../../utility_models/utility_facade_service.dart';
//
// class OverlayLayoutStore extends ChangeNotifier {
//   final UtilityFacadeService svc;
//
//   OverlayLayoutStore(this.svc);
//
//   final Map<String, Map<String, Offset>> _layouts = {};
//
//   bool _loading = false;
//
//   bool get loading => _loading;
//
//   Map<String, Offset> layoutOf(String facId) => _layouts[facId] ?? {};
//
//   // LOAD FROM DB
//   Future<void> load(String facId) async {
//     _loading = true;
//     notifyListeners();
//
//     final res = await svc.getOverlay(facId);
//     print("OVERLAY RESULT: $res");
//     _layouts[facId] = {for (final e in res) e.plcAddress: Offset(e.x, e.y)};
//
//     _loading = false;
//     notifyListeners();
//   }
//
//   // UPSERT + UPDATE UI
//   Future<void> setPos({
//     required String facId,
//     required String boxDeviceId,
//     required String plcAddress,
//     required Offset pos01,
//   }) async {
//     final m = _layouts.putIfAbsent(facId, () => {});
//     m[plcAddress] = pos01;
//     notifyListeners();
//
//     await svc.upsertOverlay(
//       facId: facId,
//       boxDeviceId: boxDeviceId,
//       plcAddress: plcAddress,
//       x: pos01.dx,
//       y: pos01.dy,
//     );
//   }
// }

import 'package:flutter/material.dart';

import '../../../utility_models/utility_facade_service.dart';

/// Layout theo GROUP (boxDeviceId):
/// facId -> boxDeviceId -> Offset(0..1)
class OverlayGroupLayoutStore extends ChangeNotifier {
  final UtilityFacadeService svc;

  OverlayGroupLayoutStore(this.svc);

  final Map<String, Map<String, Offset>> _groupLayouts = {};
  bool _loading = false;

  bool get loading => _loading;

  Map<String, Offset> groupLayoutOf(String facId) => _groupLayouts[facId] ?? {};

  Future<void> loadGroups(String facId) async {
    _loading = true;
    notifyListeners();

    try {
      final res = await svc.getOverlayGroups(facId); // ✅ new API
      _groupLayouts[facId] = res;
    } catch (e) {
      // ✅ Backend chưa có cũng không sao: vẫn chạy
      debugPrint('[OverlayGroupLayoutStore] loadGroups fallback: $e');
      _groupLayouts.putIfAbsent(facId, () => {});
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> setGroupPos({
    required String facId,
    required String boxDeviceId,
    required Offset pos01,
  }) async {
    // optimistic update
    final facMap = _groupLayouts.putIfAbsent(facId, () => {});
    facMap[boxDeviceId] = pos01;
    notifyListeners();

    try {
      await svc.setOverlayGroupPos(
        facId: facId,
        boxDeviceId: boxDeviceId,
        pos01: pos01,
      );
    } catch (e) {
      // backend chưa có => vẫn ok, UI vẫn giữ pos
      debugPrint('[OverlayGroupLayoutStore] setGroupPos fallback: $e');
    }
  }
}
