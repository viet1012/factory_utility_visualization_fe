import 'package:flutter/foundation.dart';

import '../utility_scada_api.dart';
import 'utility_scada.dart';

class ScadaViewModel extends ChangeNotifier {
  final UtilityScadaApi api;

  ScadaViewModel({required this.api});

  bool _loading = false;
  bool _submitting = false;
  String? _error;
  String _searchKeyword = '';

  List<UtilityScada> _items = [];
  List<UtilityScada> _filteredItems = [];

  bool get loading => _loading;

  bool get submitting => _submitting;

  String? get error => _error;

  List<UtilityScada> get items => List.unmodifiable(_items);

  List<UtilityScada> get filteredItems => List.unmodifiable(_filteredItems);

  int get totalCount => _items.length;

  int get filteredCount => _filteredItems.length;

  Future<void> loadData() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await api.getAll();
      _items = result;
      _applyFilter();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setSearchKeyword(String value) {
    _searchKeyword = value.trim().toLowerCase();
    _applyFilter();
    notifyListeners();
  }

  Future<void> createItem(UtilityScada item) async {
    _submitting = true;
    _error = null;
    notifyListeners();

    try {
      final created = await api.create(item);
      _items = [created, ..._items];
      _applyFilter();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> updateItem(int id, UtilityScada item) async {
    _submitting = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await api.update(id, item);
      _items = _items.map((e) => e.id == id ? updated : e).toList();
      _applyFilter();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> deleteItem(int id) async {
    _submitting = true;
    _error = null;
    notifyListeners();

    try {
      await api.delete(id);
      _items = _items.where((e) => e.id != id).toList();
      _applyFilter();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  void _applyFilter() {
    if (_searchKeyword.isEmpty) {
      _filteredItems = List.from(_items);
      return;
    }

    _filteredItems = _items.where((item) {
      final values = [
        item.id?.toString() ?? '',
        item.scadaId ?? '',
        item.fac ?? '',
        item.plcIp ?? '',
        item.plcPort?.toString() ?? '',
        item.pcName ?? '',
        item.wlan ?? '',
        item.connected?.toString() ?? '',
        item.alert?.toString() ?? '',
        item.timeUpdate ?? '',
      ];

      return values.any(
        (value) => value.toLowerCase().contains(_searchKeyword),
      );
    }).toList();
  }
}
