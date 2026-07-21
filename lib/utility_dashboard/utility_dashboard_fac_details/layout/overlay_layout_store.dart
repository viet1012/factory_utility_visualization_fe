import 'package:flutter/material.dart';

import '../../../utility_models/utility_facade_service.dart';
import '../models/group_frame_types.dart';

class OverlayGroupItem {
  final Offset pos01;
  final String direction;
  final String? color;

  const OverlayGroupItem({
    required this.pos01,
    required this.direction,
    this.color,
  });
}

class OverlayGroupLayoutStore extends ChangeNotifier {
  final UtilityFacadeService svc;

  OverlayGroupLayoutStore(this.svc);

  final Map<String, Map<String, Offset>> _groupLayouts = {};
  final Map<String, Map<String, ArrowDirection>> _groupDirections = {};
  final Map<String, Map<String, Color>> _groupColors = {};

  final Map<String, int> _loadVersions = {};

  bool _loading = false;
  bool _disposed = false;

  bool get loading => _loading;

  Map<String, Offset> groupLayoutOf(String facId) {
    return Map<String, Offset>.unmodifiable(
      _groupLayouts[facId] ?? const <String, Offset>{},
    );
  }

  Map<String, ArrowDirection> groupDirectionOf(String facId) {
    return Map<String, ArrowDirection>.unmodifiable(
      _groupDirections[facId] ?? const <String, ArrowDirection>{},
    );
  }

  Map<String, Color> groupColorOf(String facId) {
    return Map<String, Color>.unmodifiable(
      _groupColors[facId] ?? const <String, Color>{},
    );
  }

  Offset? positionOf({required String facId, required String boxDeviceId}) {
    return _groupLayouts[facId]?[boxDeviceId];
  }

  ArrowDirection directionOf({
    required String facId,
    required String boxDeviceId,
  }) {
    return _groupDirections[facId]?[boxDeviceId] ?? ArrowDirection.right;
  }

  Color? colorOf({required String facId, required String boxDeviceId}) {
    return _groupColors[facId]?[boxDeviceId];
  }

  Future<void> loadGroups(String facId) async {
    final normalizedFacId = facId.trim();

    if (normalizedFacId.isEmpty || _disposed) {
      return;
    }

    final version = (_loadVersions[normalizedFacId] ?? 0) + 1;

    _loadVersions[normalizedFacId] = version;

    _loading = true;
    _safeNotify();

    try {
      final response = await svc.getOverlayGroups(normalizedFacId);

      if (_disposed) return;

      // Bỏ kết quả request cũ nếu đã có request mới hơn.
      if (_loadVersions[normalizedFacId] != version) {
        return;
      }

      final positions = <String, Offset>{};
      final directions = <String, ArrowDirection>{};
      final colors = <String, Color>{};

      response.forEach((boxDeviceId, item) {
        final deviceId = boxDeviceId.trim();

        if (deviceId.isEmpty) {
          return;
        }

        positions[deviceId] = item.pos01;

        directions[deviceId] = _parseDirection(item.direction);

        final parsedColor = _tryParseHexColor(item.color);

        if (parsedColor != null) {
          colors[deviceId] = parsedColor;
        }
      });

      _groupLayouts[normalizedFacId] = positions;
      _groupDirections[normalizedFacId] = directions;
      _groupColors[normalizedFacId] = colors;
    } catch (error, stackTrace) {
      debugPrint(
        '[OverlayGroupLayoutStore] loadGroups error: '
        'fac=$normalizedFacId error=$error',
      );

      debugPrintStack(stackTrace: stackTrace);

      _groupLayouts.putIfAbsent(normalizedFacId, () => <String, Offset>{});

      _groupDirections.putIfAbsent(
        normalizedFacId,
        () => <String, ArrowDirection>{},
      );

      _groupColors.putIfAbsent(normalizedFacId, () => <String, Color>{});
    } finally {
      if (!_disposed && _loadVersions[normalizedFacId] == version) {
        _loading = false;
        _safeNotify();
      }
    }
  }

  Future<void> setGroupPos({
    required String facId,
    required String boxDeviceId,
    required Offset pos01,
    required ArrowDirection direction,
    Color? color,
  }) async {
    final normalizedFacId = facId.trim();
    final normalizedDeviceId = boxDeviceId.trim();

    if (normalizedFacId.isEmpty || normalizedDeviceId.isEmpty || _disposed) {
      return;
    }

    // Đánh dấu mọi load cũ không còn được phép ghi đè local state.
    _invalidatePendingLoad(normalizedFacId);

    final positions = _groupLayouts.putIfAbsent(
      normalizedFacId,
      () => <String, Offset>{},
    );

    final directions = _groupDirections.putIfAbsent(
      normalizedFacId,
      () => <String, ArrowDirection>{},
    );

    final colors = _groupColors.putIfAbsent(
      normalizedFacId,
      () => <String, Color>{},
    );

    final previousPosition = positions[normalizedDeviceId];

    final previousDirection = directions[normalizedDeviceId];

    final previousColor = colors[normalizedDeviceId];

    // Nếu caller không truyền color thì giữ màu hiện tại.
    final effectiveColor = color ?? previousColor;

    positions[normalizedDeviceId] = _clampPosition(pos01);

    directions[normalizedDeviceId] = direction;

    if (effectiveColor != null) {
      colors[normalizedDeviceId] = effectiveColor;
    }

    _safeNotify();

    try {
      await svc.setOverlayGroupPos(
        facId: normalizedFacId,
        boxDeviceId: normalizedDeviceId,
        pos01: positions[normalizedDeviceId]!,
        direction: direction,
        color: effectiveColor == null ? null : _toHex(effectiveColor),
      );
    } catch (error, stackTrace) {
      // Rollback local state nếu API lưu thất bại.
      if (previousPosition == null) {
        positions.remove(normalizedDeviceId);
      } else {
        positions[normalizedDeviceId] = previousPosition;
      }

      if (previousDirection == null) {
        directions.remove(normalizedDeviceId);
      } else {
        directions[normalizedDeviceId] = previousDirection;
      }

      if (previousColor == null) {
        colors.remove(normalizedDeviceId);
      } else {
        colors[normalizedDeviceId] = previousColor;
      }

      _safeNotify();

      debugPrint(
        '[OverlayGroupLayoutStore] setGroupPos error: '
        'fac=$normalizedFacId '
        'device=$normalizedDeviceId '
        'error=$error',
      );

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> setGroupColor({
    required String facId,
    required String boxDeviceId,
    required Color color,
  }) async {
    final normalizedFacId = facId.trim();
    final normalizedDeviceId = boxDeviceId.trim();

    if (normalizedFacId.isEmpty || normalizedDeviceId.isEmpty || _disposed) {
      return;
    }

    _invalidatePendingLoad(normalizedFacId);

    final positions = _groupLayouts.putIfAbsent(
      normalizedFacId,
      () => <String, Offset>{},
    );

    final directions = _groupDirections.putIfAbsent(
      normalizedFacId,
      () => <String, ArrowDirection>{},
    );

    final colors = _groupColors.putIfAbsent(
      normalizedFacId,
      () => <String, Color>{},
    );

    final previousColor = colors[normalizedDeviceId];

    final position = positions[normalizedDeviceId] ?? const Offset(0.2, 0.2);

    final direction = directions[normalizedDeviceId] ?? ArrowDirection.right;

    // Đảm bảo position và direction cũng có trong local state.
    positions[normalizedDeviceId] = position;
    directions[normalizedDeviceId] = direction;
    colors[normalizedDeviceId] = color;

    _safeNotify();

    try {
      await svc.setOverlayGroupPos(
        facId: normalizedFacId,
        boxDeviceId: normalizedDeviceId,
        pos01: position,
        direction: direction,
        color: _toHex(color),
      );
    } catch (error, stackTrace) {
      if (previousColor == null) {
        colors.remove(normalizedDeviceId);
      } else {
        colors[normalizedDeviceId] = previousColor;
      }

      _safeNotify();

      debugPrint(
        '[OverlayGroupLayoutStore] setGroupColor error: '
        'fac=$normalizedFacId '
        'device=$normalizedDeviceId '
        'error=$error',
      );

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _invalidatePendingLoad(String facId) {
    _loadVersions[facId] = (_loadVersions[facId] ?? 0) + 1;

    if (_loading) {
      _loading = false;
    }
  }

  Offset _clampPosition(Offset position) {
    return Offset(position.dx.clamp(0.0, 1.0), position.dy.clamp(0.0, 1.0));
  }

  ArrowDirection _parseDirection(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
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

  Color? _tryParseHexColor(String? value) {
    final text = value?.trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    try {
      var raw = text.replaceFirst('#', '');

      if (raw.length == 6) {
        raw = 'FF$raw';
      }

      if (raw.length != 8) {
        return null;
      }

      return Color(int.parse(raw, radix: 16));
    } catch (error) {
      debugPrint(
        '[OverlayGroupLayoutStore] invalid color: '
        '$value error=$error',
      );

      return null;
    }
  }

  String _toHex(Color color) {
    final alpha = color.alpha.toRadixString(16).padLeft(2, '0');

    final red = color.red.toRadixString(16).padLeft(2, '0');

    final green = color.green.toRadixString(16).padLeft(2, '0');

    final blue = color.blue.toRadixString(16).padLeft(2, '0');

    return '#$alpha$red$green$blue'.toUpperCase();
  }

  void _safeNotify() {
    if (_disposed) return;

    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
