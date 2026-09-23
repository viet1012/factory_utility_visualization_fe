import 'package:flutter/foundation.dart';

import '../api/utility_latest_api.dart';
import '../models/latest_tree_response.dart';

class LatestProvider extends ChangeNotifier {
  final UtilityLatestApi api;

  LatestProvider({required this.api});

  bool _disposed = false;
  bool _loading = false;

  /*
   * Tree va Facility dung guard rieng, de mot request tree dang
   * chay khong lam bo qua tick cua Facility Detail va nguoc lai.
   */
  bool _treeRefreshing = false;
  bool _facilityRefreshing = false;

  /*
   * Moi lifecycle co bo dem rieng. Request cu tra ve sau se bi bo qua,
   * khong ghi de ket qua cua request moi hon trong cung lifecycle.
   *
   * Tree va Facility khong dung chung token, vi hai lifecycle nay
   * duoc phep chay dong thoi.
   */
  int _treeRequestToken = 0;
  int _facilityRequestToken = 0;

  /*
   * Tach error theo lifecycle: mot loi cua Facility khong duoc
   * ghi de loi cua Tree/SCADA va nguoc lai.
   */
  Object? _treeError;
  Object? _facilityError;

  List<LatestFacilityDto> _items = const [];

  String? _activeFac;
  String? _activeCate;

  bool get loading => _loading;

  bool get refreshing => _treeRefreshing;

  bool get facilityRefreshing => _facilityRefreshing;

  /// Loi cua lifecycle Tree/SCADA. Giu nguyen ten cho cac caller hien tai.
  Object? get error => _treeError;

  /// Loi cua lifecycle Facility Detail, tach rieng khoi [error].
  Object? get facilityError => _facilityError;

  bool get hasData => _items.isNotEmpty;

  List<LatestFacilityDto> get items => _items;

  String? get activeFac => _activeFac;

  String? get activeCate => _activeCate;

  int _dataVersion = 0;

  int get dataVersion => _dataVersion;

  DateTime? _lastRefreshAt;

  /// Thoi diem response tree/SCADA moi nhat duoc apply thanh cong.
  DateTime? get lastRefreshAt => _lastRefreshAt;

  // ============================================================
  // INITIAL LOAD
  // ============================================================

  Future<void> loadInitial() async {
    if (_loading || _items.isNotEmpty || _disposed) {
      return;
    }

    final token = ++_treeRequestToken;

    _loading = true;
    _treeError = null;
    _safeNotify();

    try {
      final result = await api.getLatestTree();

      if (!_isCurrentTreeRequest(token)) return;

      _items = List<LatestFacilityDto>.unmodifiable(result);
      _dataVersion++;
      _lastRefreshAt = DateTime.now();
      _treeError = null;
    } catch (error, stackTrace) {
      if (!_isCurrentTreeRequest(token)) return;

      _treeError = error;

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

  /*
   * Request tree dang chay duoc chia se cho moi caller (nut Refresh va
   * PollingCoordinator). Caller den sau khong bi bo qua im lang ma se
   * await chung ket qua cua request dang chay.
   */
  Future<void>? _treeInFlight;

  Future<void> refreshAll() {
    if (_disposed || _loading) {
      return Future<void>.value();
    }

    final inFlight = _treeInFlight;

    if (inFlight != null) {
      return inFlight;
    }

    final request = _runRefreshAll();

    _treeInFlight = request;

    return request.whenComplete(() {
      if (identical(_treeInFlight, request)) {
        _treeInFlight = null;
      }
    });
  }

  Future<void> _runRefreshAll() async {
    final token = ++_treeRequestToken;

    _treeRefreshing = true;
    _treeError = null;
    _safeNotify();

    try {
      final result = await api.getLatestTree();

      if (!_isCurrentTreeRequest(token)) return;
      _items = List<LatestFacilityDto>.unmodifiable(result);
      _dataVersion++;
      _lastRefreshAt = DateTime.now();
      _treeError = null;
    } catch (error, stackTrace) {
      if (!_isCurrentTreeRequest(token)) return;

      _treeError = error;

      debugPrint('[LATEST REFRESH ALL ERROR] $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (!_disposed) {
        _treeRefreshing = false;
        _safeNotify();
      }
    }
  }

  // ============================================================
  // REFRESH ONE FACILITY
  // ============================================================

  Future<void> refreshFacility(String facId, {bool silent = true}) async {
    if (_disposed || _facilityRefreshing) {
      return;
    }

    final fac = _normalize(facId);

    if (fac == null) {
      return;
    }

    final token = ++_facilityRequestToken;

    _facilityRefreshing = true;
    _facilityError = null;

    if (!silent || _items.isEmpty) {
      _safeNotify();
    }

    try {
      final result = await api.getLatestTree(facId: fac);

      if (!_isCurrentFacilityRequest(token)) return;

      _mergeFacility(fac: fac, incoming: result);

      _facilityError = null;
    } catch (error, stackTrace) {
      if (!_isCurrentFacilityRequest(token)) return;

      _facilityError = error;

      debugPrint(
        '[LATEST FACILITY REFRESH ERROR] '
        'fac=$fac error=$error',
      );

      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (!_disposed) {
        _facilityRefreshing = false;
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
    if (_disposed || _treeRefreshing) {
      return;
    }

    final fac = _activeFac;
    final cate = _activeCate;

    if (fac == null || cate == null) {
      return;
    }

    final token = ++_treeRequestToken;

    _treeRefreshing = true;
    _treeError = null;
    _safeNotify();

    try {
      final result = await api.getLatestTree(facId: fac, cate: cate);

      if (!_isCurrentTreeRequest(token)) return;

      _mergeCategory(fac: fac, cate: cate, incoming: result);

      _lastRefreshAt = DateTime.now();
      _treeError = null;
    } catch (error, stackTrace) {
      if (!_isCurrentTreeRequest(token)) return;

      _treeError = error;

      debugPrint(
        '[LATEST ACTIVE REFRESH ERROR] '
        'fac=$fac cate=$cate error=$error',
      );

      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (!_disposed) {
        _treeRefreshing = false;
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
      _dataVersion++;
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

  // ============================================================
  // REQUEST TOKEN
  // ============================================================

  bool _isCurrentTreeRequest(int token) {
    return !_disposed && token == _treeRequestToken;
  }

  bool _isCurrentFacilityRequest(int token) {
    return !_disposed && token == _facilityRequestToken;
  }

  void _safeNotify() {
    if (_disposed) return;

    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;

    // Vo hieu hoa moi request dang chay cua ca hai lifecycle.
    _treeRequestToken++;
    _facilityRequestToken++;

    super.dispose();
  }
}
