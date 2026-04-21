import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_fac_details/layout/utility_fac_layout_screen.dart';
import 'package:flutter/material.dart';

import '../../../utility_models/utility_facade_service.dart';

class OverlayGroupLayoutStore extends ChangeNotifier {
  final UtilityFacadeService svc;

  OverlayGroupLayoutStore(this.svc);

  final Map<String, Map<String, Offset>> _groupLayouts = {};
  final Map<String, Map<String, ArrowDirection>> _groupDirections = {};

  bool _loading = false;

  bool get loading => _loading;

  Map<String, Offset> groupLayoutOf(String facId) => _groupLayouts[facId] ?? {};

  Map<String, ArrowDirection> groupDirectionOf(String facId) =>
      _groupDirections[facId] ?? {};

  ArrowDirection _parseDirection(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'left':
        return ArrowDirection.left;
      case 'up':
        return ArrowDirection.up;
      case 'down':
        return ArrowDirection.down;
      case 'right':
      default:
        return ArrowDirection.right;
    }
  }

  Future<void> loadGroups(String facId) async {
    _loading = true;
    notifyListeners();

    try {
      final res = await svc.getOverlayGroups(facId);

      _groupLayouts[facId] = {};
      _groupDirections[facId] = {};

      res.forEach((boxId, item) {
        _groupLayouts[facId]![boxId] = item.pos01;
        _groupDirections[facId]![boxId] = _parseDirection(item.direction);
      });
    } catch (e) {
      debugPrint('[OverlayGroupLayoutStore] loadGroups fallback: $e');
      _groupLayouts.putIfAbsent(facId, () => {});
      _groupDirections.putIfAbsent(facId, () => {});
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> setGroupPos({
    required String facId,
    required String boxDeviceId,
    required Offset pos01,
    required ArrowDirection direction,
  }) async {
    final facMap = _groupLayouts.putIfAbsent(facId, () => {});
    final dirMap = _groupDirections.putIfAbsent(facId, () => {});

    facMap[boxDeviceId] = pos01;
    dirMap[boxDeviceId] = direction;

    notifyListeners();

    try {
      await svc.setOverlayGroupPos(
        facId: facId,
        boxDeviceId: boxDeviceId,
        pos01: pos01,
        direction: direction,
      );
    } catch (e) {
      debugPrint('[OverlayGroupLayoutStore] setGroupPos fallback: $e');
    }
  }
}

class OverlayGroupItem {
  final Offset pos01;
  final String direction;

  OverlayGroupItem({required this.pos01, required this.direction});
}
