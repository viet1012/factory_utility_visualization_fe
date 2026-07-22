import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utility_api/utility_api.dart';
import '../utility_dashboard/utility_dashboard_overview/'
    'utility_dashboard_overview_models/latest_tree_response.dart';

class LatestProvider extends ChangeNotifier {
  final UtilityApi api;
  final Duration refreshInterval;

  LatestProvider({
    required this.api,
    this.refreshInterval = const Duration(minutes: 1),
  });

  Timer? _timer;

  bool _disposed = false;
  bool _loading = false;
  bool _refreshing = false;

  Object? _error;

  List<LatestFacilityDto> _items = const [];

  String? _activeFac;
  String? _activeCate;

  bool get loading => _loading;

  bool get refreshing => _refreshing;

  Object? get error => _error;

  bool get hasData => _items.isNotEmpty;

  List<LatestFacilityDto> get items => _items;

  String? get activeFac => _activeFac;

  String? get activeCate => _activeCate;

  int _dataVersion = 0;

  int get dataVersion => _dataVersion;

  // ============================================================
  // INITIAL LOAD
  // ============================================================

  Future<void> loadInitial() async {
    if (_loading || _items.isNotEmpty || _disposed) {
      return;
    }

    _loading = true;
    _error = null;
    _safeNotify();

    try {
      final result = await api.getLatestTree();

      if (_disposed) return;

      _items = List<LatestFacilityDto>.unmodifiable(result);
      _dataVersion++;
      _error = null;
    } catch (error, stackTrace) {
      if (_disposed) return;

      _error = error;

      debugPrint('[LATEST INITIAL ERROR] $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (!_disposed) {
        _loading = false;
        _safeNotify();
      }
    }
  }

  Future<void> load() {
    return loadInitial();
  }

  // ============================================================
  // GET FACILITY
  // ============================================================

  LatestFacilityDto? facilityOf(String? facId) {
    final normalizedFac = _normalize(facId);

    if (normalizedFac == null) {
      return null;
    }

    return _findFacility(_items, normalizedFac);
  }

  // ============================================================
  // ACTIVE TAB
  // ============================================================

  void setActiveTab({required String? fac, required String? cate}) {
    final normalizedFac = _normalize(fac);
    final normalizedCate = _normalize(cate);

    if (_sameNullable(_activeFac, normalizedFac) &&
        _sameNullable(_activeCate, normalizedCate)) {
      return;
    }

    _activeFac = normalizedFac;
    _activeCate = normalizedCate;
  }

  // ============================================================
  // REFRESH ALL
  // ============================================================

  Future<void> refreshAll() async {
    if (_disposed || _loading || _refreshing) {
      return;
    }

    _refreshing = true;
    _error = null;
    _safeNotify();

    try {
      final result = await api.getLatestTree();

      if (_disposed) return;
      _items = List<LatestFacilityDto>.unmodifiable(result);
      _dataVersion++;
      _error = null;
    } catch (error, stackTrace) {
      if (_disposed) return;

      _error = error;

      debugPrint('[LATEST REFRESH ALL ERROR] $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (!_disposed) {
        _refreshing = false;
        _safeNotify();
      }
    }
  }

  // ============================================================
  // REFRESH ONE FACILITY
  // ============================================================

  Future<void> refreshFacility(String facId, {bool silent = true}) async {
    if (_disposed || _refreshing) {
      return;
    }

    final fac = _normalize(facId);

    if (fac == null) {
      return;
    }

    _refreshing = true;
    _error = null;

    if (!silent || _items.isEmpty) {
      _safeNotify();
    }

    try {
      final result = await api.getLatestTree(facId: fac);

      if (_disposed) return;

      _mergeFacility(fac: fac, incoming: result);

      _error = null;
    } catch (error, stackTrace) {
      if (_disposed) return;

      _error = error;

      debugPrint(
        '[LATEST FACILITY REFRESH ERROR] '
        'fac=$fac error=$error',
      );

      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (!_disposed) {
        _refreshing = false;
        _safeNotify();
      }
    }
  }

  void _mergeFacility({
    required String fac,
    required List<LatestFacilityDto> incoming,
  }) {
    final incomingFacility = _findFacility(incoming, fac);

    final replacement =
        incomingFacility ?? LatestFacilityDto(fac: fac, categories: const []);

    final facilities = List<LatestFacilityDto>.from(_items);

    final facilityIndex = facilities.indexWhere(
      (item) => _sameText(item.fac, fac),
    );

    if (facilityIndex < 0) {
      facilities.add(replacement);
    } else {
      facilities[facilityIndex] = replacement;
    }

    facilities.sort((first, second) {
      return first.fac.toLowerCase().compareTo(second.fac.toLowerCase());
    });

    _items = List<LatestFacilityDto>.unmodifiable(facilities);
    _dataVersion++;
  }

  // ============================================================
  // REFRESH ACTIVE CATEGORY
  // ============================================================

  Future<void> refreshActiveTab() async {
    if (_disposed || _refreshing) {
      return;
    }

    final fac = _activeFac;
    final cate = _activeCate;

    if (fac == null || cate == null) {
      return;
    }

    _refreshing = true;
    _error = null;
    _safeNotify();

    try {
      final result = await api.getLatestTree(facId: fac, cate: cate);

      if (_disposed) return;

      _mergeCategory(fac: fac, cate: cate, incoming: result);

      _error = null;
    } catch (error, stackTrace) {
      if (_disposed) return;

      _error = error;

      debugPrint(
        '[LATEST ACTIVE REFRESH ERROR] '
        'fac=$fac cate=$cate error=$error',
      );

      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (!_disposed) {
        _refreshing = false;
        _safeNotify();
      }
    }
  }

  Future<void> refresh() {
    if (_activeFac != null && _activeCate != null) {
      return refreshActiveTab();
    }

    return refreshAll();
  }

  void _mergeCategory({
    required String fac,
    required String cate,
    required List<LatestFacilityDto> incoming,
  }) {
    final incomingFacility = _findFacility(incoming, fac);

    final incomingCategory = incomingFacility == null
        ? null
        : _findCategory(incomingFacility.categories, cate);

    final replacement =
        incomingCategory ?? LatestCategoryDto(cate: cate, scadas: const []);

    final facilities = List<LatestFacilityDto>.from(_items);

    final facilityIndex = facilities.indexWhere(
      (item) => _sameText(item.fac, fac),
    );

    if (facilityIndex < 0) {
      facilities.add(LatestFacilityDto(fac: fac, categories: [replacement]));

      _items = List<LatestFacilityDto>.unmodifiable(facilities);
      return;
    }

    final currentFacility = facilities[facilityIndex];

    final categories = List<LatestCategoryDto>.from(currentFacility.categories);

    final categoryIndex = categories.indexWhere(
      (item) => _sameText(item.cate, cate),
    );

    if (categoryIndex < 0) {
      categories.add(replacement);
    } else {
      categories[categoryIndex] = replacement;
    }

    facilities[facilityIndex] = LatestFacilityDto(
      fac: currentFacility.fac,
      categories: List<LatestCategoryDto>.unmodifiable(categories),
    );

    _items = List<LatestFacilityDto>.unmodifiable(facilities);
    _dataVersion++;
  }

  // ============================================================
  // POLLING
  // ============================================================

  void startPolling() {
    _timer?.cancel();

    _timer = Timer.periodic(refreshInterval, (_) {
      unawaited(refreshAll());
    });
  }

  void startFacilityPolling(
    String facId, {
    Duration interval = const Duration(seconds: 30),
  }) {
    _timer?.cancel();

    _timer = Timer.periodic(interval, (_) {
      unawaited(refreshFacility(facId, silent: true));
    });
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  LatestFacilityDto? _findFacility(
    List<LatestFacilityDto> facilities,
    String fac,
  ) {
    for (final facility in facilities) {
      if (_sameText(facility.fac, fac)) {
        return facility;
      }
    }

    return null;
  }

  LatestCategoryDto? _findCategory(
    List<LatestCategoryDto> categories,
    String cate,
  ) {
    for (final category in categories) {
      if (_sameText(category.cate, cate)) {
        return category;
      }
    }

    return null;
  }

  String? _normalize(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  bool _sameText(String first, String second) {
    return first.trim().toLowerCase() == second.trim().toLowerCase();
  }

  bool _sameNullable(String? first, String? second) {
    if (first == null && second == null) {
      return true;
    }

    if (first == null || second == null) {
      return false;
    }

    return _sameText(first, second);
  }

  void _safeNotify() {
    if (_disposed) return;

    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;

    stopPolling();

    super.dispose();
  }
}
