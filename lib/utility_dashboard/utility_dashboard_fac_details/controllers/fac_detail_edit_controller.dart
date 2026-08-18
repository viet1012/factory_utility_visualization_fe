import 'package:flutter/material.dart';

import '../models/group_frame_types.dart';

class FacDetailEditController extends ChangeNotifier {
  bool _editMode = false;

  String? _editingBoxDeviceId;

  final Map<String, ArrowDirection> _localDirections = {};

  // ============================================================
  // GETTERS
  // ============================================================

  bool get editMode => _editMode;

  String? get editingBoxDeviceId => _editingBoxDeviceId;

  Map<String, ArrowDirection> get localDirections =>
      Map.unmodifiable(_localDirections);

  // ============================================================
  // EDIT MODE
  // ============================================================

  void toggleEditMode() {
    _editMode = !_editMode;

    if (!_editMode) {
      _editingBoxDeviceId = null;
    }

    notifyListeners();
  }

  // ============================================================
  // SELECT BOX
  // ============================================================

  void selectDevice(String? boxDeviceId) {
    final normalized = boxDeviceId?.trim();

    final next = normalized == null || normalized.isEmpty ? null : normalized;

    if (_editingBoxDeviceId == next) {
      return;
    }

    _editingBoxDeviceId = next;

    notifyListeners();
  }

  // ============================================================
  // AUTO SELECT
  //
  // Dùng khi:
  // - bật Edit
  // - đổi utility
  // - danh sách box thay đổi
  // ============================================================

  void ensureSelected(List<String> boxDeviceIds) {
    if (!_editMode) {
      return;
    }

    final validIds = boxDeviceIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    // Không còn box nào
    if (validIds.isEmpty) {
      if (_editingBoxDeviceId != null) {
        _editingBoxDeviceId = null;

        notifyListeners();
      }

      return;
    }

    final current = _editingBoxDeviceId;

    // Box đang chọn vẫn thuộc danh sách hiện tại
    if (current != null && validIds.contains(current)) {
      return;
    }

    // Box cũ không còn hợp lệ
    // -> chọn box đầu tiên
    _editingBoxDeviceId = validIds.first;

    notifyListeners();
  }

  // ============================================================
  // DIRECTION
  // ============================================================

  void setLocalDirection(String boxDeviceId, ArrowDirection direction) {
    final normalized = boxDeviceId.trim();

    if (normalized.isEmpty) {
      return;
    }

    final current = _localDirections[normalized];

    if (current == direction) {
      return;
    }

    _localDirections[normalized] = direction;

    notifyListeners();
  }

  // ============================================================
  // CLEAR SELECTION
  // ============================================================

  void clearSelection() {
    if (_editingBoxDeviceId == null) {
      return;
    }

    _editingBoxDeviceId = null;

    notifyListeners();
  }

  // ============================================================
  // RESET
  // ============================================================

  void reset() {
    final hasState =
        _editMode || _editingBoxDeviceId != null || _localDirections.isNotEmpty;

    if (!hasState) {
      return;
    }

    _editMode = false;

    _editingBoxDeviceId = null;

    _localDirections.clear();

    notifyListeners();
  }
}
