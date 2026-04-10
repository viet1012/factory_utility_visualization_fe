import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/utility_dashboard_setting_models/utility_para.dart';
import 'package:flutter/foundation.dart';

import '../utility_para_api.dart';

class UtilityParaViewModel extends ChangeNotifier {
  final UtilityParaApi api;

  UtilityParaViewModel({required this.api});

  bool _loading = false;
  bool _submitting = false;
  String? _error;
  String _searchKeyword = '';

  List<UtilityPara> _items = [];
  List<UtilityPara> _filteredItems = [];

  bool get loading => _loading;

  bool get submitting => _submitting;

  String? get error => _error;

  List<UtilityPara> get items => List.unmodifiable(_items);

  List<UtilityPara> get filteredItems => List.unmodifiable(_filteredItems);

  int get totalCount => _items.length;

  int get filteredCount => _filteredItems.length;

  Future<void> load() async {
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

  void setSearch(String value) {
    _searchKeyword = value.trim().toLowerCase();
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    if (_searchKeyword.isEmpty) {
      _filteredItems = List.from(_items);
      return;
    }

    _filteredItems = _items.where((item) {
      final values = [
        item.id?.toString() ?? '',
        item.nameVi ?? '',
        item.nameEn ?? '',
        item.cateId ?? '',
        item.plcAddress ?? '',
        item.valueType ?? '',
        item.unit ?? '',
        item.isImportant?.toString() ?? '',
        item.isAlert?.toString() ?? '',
        item.minAlert?.toString() ?? '',
        item.maxAlert?.toString() ?? '',
      ];

      return values.any(
        (value) => value.toLowerCase().contains(_searchKeyword),
      );
    }).toList();
  }
}
