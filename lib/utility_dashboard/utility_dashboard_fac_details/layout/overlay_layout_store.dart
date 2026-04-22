import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_fac_details/layout/utility_fac_layout_screen.dart';
import 'package:flutter/material.dart';

import '../../../utility_models/utility_facade_service.dart';

class OverlayGroupItem {
  final Offset pos01;
  final String direction;
  final String? color;

  OverlayGroupItem({required this.pos01, required this.direction, this.color});
}

class OverlayGroupLayoutStore extends ChangeNotifier {
  final UtilityFacadeService svc;

  OverlayGroupLayoutStore(this.svc);

  final Map<String, Map<String, Offset>> _groupLayouts = {};
  final Map<String, Map<String, ArrowDirection>> _groupDirections = {};
  final Map<String, Map<String, Color>> _groupColors = {};

  bool _loading = false;

  bool get loading => _loading;

  Map<String, Offset> groupLayoutOf(String facId) => _groupLayouts[facId] ?? {};

  Map<String, ArrowDirection> groupDirectionOf(String facId) =>
      _groupDirections[facId] ?? {};

  Map<String, Color> groupColorOf(String facId) => _groupColors[facId] ?? {};

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

  Color _parseHexColor(String? hex) {
    if (hex == null || hex.trim().isEmpty) {
      return const Color(0x66000000);
    }

    final raw = hex.replaceFirst('#', '').trim();
    final normalized = raw.length == 6 ? 'FF$raw' : raw;

    return Color(int.parse(normalized, radix: 16));
  }

  String _toHex(Color color) {
    final a = color.alpha.toRadixString(16).padLeft(2, '0');
    final r = color.red.toRadixString(16).padLeft(2, '0');
    final g = color.green.toRadixString(16).padLeft(2, '0');
    final b = color.blue.toRadixString(16).padLeft(2, '0');
    return '#$a$r$g$b'.toUpperCase();
  }

  Future<void> loadGroups(String facId) async {
    _loading = true;
    notifyListeners();

    try {
      final res = await svc.getOverlayGroups(facId);

      _groupLayouts[facId] = {};
      _groupDirections[facId] = {};
      _groupColors[facId] = {};

      res.forEach((boxId, item) {
        _groupLayouts[facId]![boxId] = item.pos01;
        _groupDirections[facId]![boxId] = _parseDirection(item.direction);
        _groupColors[facId]![boxId] = _parseHexColor(item.color);
      });
    } catch (e) {
      debugPrint('[OverlayGroupLayoutStore] loadGroups fallback: $e');
      _groupLayouts.putIfAbsent(facId, () => {});
      _groupDirections.putIfAbsent(facId, () => {});
      _groupColors.putIfAbsent(facId, () => {});
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> setGroupPos({
    required String facId,
    required String boxDeviceId,
    required Offset pos01,
    required ArrowDirection direction,
    Color? color,
  }) async {
    final facMap = _groupLayouts.putIfAbsent(facId, () => {});
    final dirMap = _groupDirections.putIfAbsent(facId, () => {});
    final colorMap = _groupColors.putIfAbsent(facId, () => {});

    facMap[boxDeviceId] = pos01;
    dirMap[boxDeviceId] = direction;

    if (color != null) {
      colorMap[boxDeviceId] = color;
    }

    notifyListeners();

    try {
      await svc.setOverlayGroupPos(
        facId: facId,
        boxDeviceId: boxDeviceId,
        pos01: pos01,
        direction: direction,
        color: color != null ? _toHex(color) : null,
      );
    } catch (e) {
      debugPrint('[OverlayGroupLayoutStore] setGroupPos fallback: $e');
    }
  }

  Future<void> setGroupColor({
    required String facId,
    required String boxDeviceId,
    required Color color,
  }) async {
    final facMap = _groupLayouts.putIfAbsent(facId, () => {});
    final dirMap = _groupDirections.putIfAbsent(facId, () => {});
    final colorMap = _groupColors.putIfAbsent(facId, () => {});

    final pos01 = facMap[boxDeviceId] ?? const Offset(0.2, 0.2);
    final direction = dirMap[boxDeviceId] ?? ArrowDirection.right;

    colorMap[boxDeviceId] = color;
    notifyListeners();

    try {
      await svc.setOverlayGroupPos(
        facId: facId,
        boxDeviceId: boxDeviceId,
        pos01: pos01,
        direction: direction,
        color: _toHex(color),
      );
    } catch (e) {
      debugPrint('[OverlayGroupLayoutStore] setGroupColor fallback: $e');
    }
  }
}
