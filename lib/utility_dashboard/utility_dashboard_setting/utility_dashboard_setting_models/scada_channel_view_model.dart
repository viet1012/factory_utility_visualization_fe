import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/utility_dashboard_setting_models/utility_scada_channel.dart';
import 'package:flutter/material.dart';

import '../utility_scada_channel_api.dart';

/// ViewModel quản lý state, filtering, và business logic
/// Giúp tách biệt logic từ UI, dễ test
class ScadaChannelViewModel extends ChangeNotifier {
  final UtilityScadaChannelApi api;

  // State
  List<UtilityScadaChannel> _items = [];
  List<UtilityScadaChannel> _filteredItems = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String _searchKeyword = '';

  // Getters
  List<UtilityScadaChannel> get items => _items;

  List<UtilityScadaChannel> get filteredItems => _filteredItems;

  bool get loading => _loading;

  bool get submitting => _submitting;

  String? get error => _error;

  String get searchKeyword => _searchKeyword;

  int get totalCount => _items.length;

  int get filteredCount => _filteredItems.length;

  ScadaChannelViewModel({required this.api});

  // ============ LOADING & FILTERING ============
  Future<void> loadData() async {
    _setLoading(true);
    _setError(null);

    try {
      _items = await api.getAll();
      _applyFilterInternal();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      rethrow;
    }
  }

  void setSearchKeyword(String keyword) {
    _searchKeyword = keyword.trim().toLowerCase();
    _applyFilterInternal();
  }

  void _applyFilterInternal() {
    if (_searchKeyword.isEmpty) {
      _filteredItems = _items;
    } else {
      _filteredItems = _items.where((item) {
        final values = [
          item.id?.toString() ?? '',
          item.scadaId ?? '',
          item.cate ?? '',
          item.boxDeviceId ?? '',
          item.boxId ?? '',
        ];
        return values.any((v) => v.toLowerCase().contains(_searchKeyword));
      }).toList();
    }
    notifyListeners();
  }

  // ============ CREATE ============
  Future<void> createItem(UtilityScadaChannel item) async {
    _setSubmitting(true);

    try {
      final created = await api.create(item);
      _items.insert(0, created);
      _applyFilterInternal();
      _setSubmitting(false);
    } catch (e) {
      _setSubmitting(false);
      rethrow;
    }
  }

  // ============ UPDATE ============
  Future<void> updateItem(int id, UtilityScadaChannel item) async {
    _setSubmitting(true);

    try {
      final updated = await api.update(id, item);
      final index = _items.indexWhere((e) => e.id == id);
      if (index != -1) {
        _items[index] = updated;
      }
      _applyFilterInternal();
      _setSubmitting(false);
    } catch (e) {
      _setSubmitting(false);
      rethrow;
    }
  }

  // ============ PRIVATE HELPERS ============
  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void _setSubmitting(bool value) {
    _submitting = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
