import 'package:flutter/material.dart';

import '../models/group_frame_types.dart';

class FacDetailEditController extends ChangeNotifier {
  bool _editMode = false;
  String? _editingBoxDeviceId;

  final Map<String, ArrowDirection> _localDirections = {};

  bool get editMode => _editMode;

  String? get editingBoxDeviceId => _editingBoxDeviceId;

  Map<String, ArrowDirection> get localDirections =>
      Map.unmodifiable(_localDirections);

  void toggleEditMode() {
    _editMode = !_editMode;

    if (!_editMode) {
      _editingBoxDeviceId = null;
    }

    notifyListeners();
  }

  void selectDevice(String? boxDeviceId) {
    if (_editingBoxDeviceId == boxDeviceId) {
      return;
    }

    _editingBoxDeviceId = boxDeviceId;
    notifyListeners();
  }

  void ensureSelected(List<String> boxDeviceIds) {
    if (!_editMode) return;
    if (_editingBoxDeviceId != null) return;
    if (boxDeviceIds.isEmpty) return;

    _editingBoxDeviceId = boxDeviceIds.first;
    notifyListeners();
  }

  void setLocalDirection(String boxDeviceId, ArrowDirection direction) {
    _localDirections[boxDeviceId] = direction;
    notifyListeners();
  }

  void reset() {
    _editMode = false;
    _editingBoxDeviceId = null;
    _localDirections.clear();

    notifyListeners();
  }
}
