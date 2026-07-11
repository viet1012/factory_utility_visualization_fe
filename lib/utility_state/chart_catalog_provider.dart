import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utility_api/utility_api.dart';
import '../utility_models/response/chart_catalog_item.dart';

class SignalChartConfig {
  final String boxDeviceId;
  final String plcAddress;

  final String? cateId;
  final List<String>? cateIds;

  final String? groupLabel;

  final String? nameEn;
  final String? nameVi;
  final String? unit;

  const SignalChartConfig({
    required this.boxDeviceId,
    required this.plcAddress,
    this.cateId,
    this.cateIds,
    this.groupLabel,
    this.nameEn,
    this.nameVi,
    this.unit,
  });
}

class _CatalogCacheEntry {
  final DateTime createdAt;
  final List<ChartCatalogItem> items;

  const _CatalogCacheEntry({required this.createdAt, required this.items});

  bool isExpired(Duration ttl) {
    return DateTime.now().difference(createdAt) > ttl;
  }
}

class ChartCatalogProvider extends ChangeNotifier {
  final UtilityApi api;

  ChartCatalogProvider(this.api);

  static const Duration _cacheTtl = Duration(minutes: 5);

  bool _disposed = false;
  bool _loading = false;
  Object? _error;

  int _requestToken = 0;

  List<ChartCatalogItem> _allItems = const [];

  List<String> _scadaIds = const [];
  List<String> _boxIds = const [];
  List<String> _boxDeviceIds = const [];
  List<SignalChartConfig> _charts = const [];

  String? _selectedScadaId;
  String? _selectedBoxId;
  String? _selectedBoxDeviceId;

  final Map<String, _CatalogCacheEntry> _cache = {};
  final Map<String, Future<List<ChartCatalogItem>>> _inFlight = {};

  bool get loading => _loading;

  Object? get error => _error;

  List<String> get scadaIds => _scadaIds;

  List<String> get boxIds => _boxIds;

  List<String> get boxDeviceIds => _boxDeviceIds;

  List<SignalChartConfig> get charts => _charts;

  String? get selectedScadaId => _selectedScadaId;

  String? get selectedBoxId => _selectedBoxId;

  String? get selectedBoxDeviceId => _selectedBoxDeviceId;

  bool get hasData => _allItems.isNotEmpty;

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> loadCatalog({
    required String facId,
    required String cate,
    int importantOnly = 0,
    bool forceRefresh = false,
  }) async {
    final normalizedFac = _normalizeRequired(facId);
    final normalizedCate = _normalizeRequired(cate);
    final normalizedImportant = importantOnly == 1 ? 1 : 0;

    if (normalizedFac.isEmpty || normalizedCate.isEmpty) {
      _setError(ArgumentError('facId and cate are required.'));
      return;
    }

    final cacheKey = _buildCacheKey(
      facId: normalizedFac,
      cate: normalizedCate,
      importantOnly: normalizedImportant,
    );

    final token = ++_requestToken;

    final previousScada = _selectedScadaId;
    final previousBox = _selectedBoxId;
    final previousDevice = _selectedBoxDeviceId;

    _loading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      final items = await _getCatalogItems(
        cacheKey: cacheKey,
        facId: normalizedFac,
        cate: normalizedCate,
        importantOnly: normalizedImportant,
        forceRefresh: forceRefresh,
      );

      if (!_isCurrentRequest(token)) return;

      _allItems = items;

      _restoreSelections(
        previousScada: previousScada,
        previousBox: previousBox,
        previousDevice: previousDevice,
      );
    } catch (error, stackTrace) {
      if (!_isCurrentRequest(token)) return;

      _error = error;

      debugPrint('ChartCatalogProvider.loadCatalog error: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (_isCurrentRequest(token)) {
        _loading = false;
        _safeNotifyListeners();
      }
    }
  }

  Future<List<ChartCatalogItem>> _getCatalogItems({
    required String cacheKey,
    required String facId,
    required String cate,
    required int importantOnly,
    required bool forceRefresh,
  }) async {
    if (!forceRefresh) {
      final cached = _cache[cacheKey];

      if (cached != null && !cached.isExpired(_cacheTtl)) {
        return cached.items;
      }
    }

    final existingRequest = _inFlight[cacheKey];

    if (existingRequest != null) {
      return existingRequest;
    }

    final request = _fetchCatalog(
      facId: facId,
      cate: cate,
      importantOnly: importantOnly,
    );

    _inFlight[cacheKey] = request;

    try {
      final items = await request;

      _cache[cacheKey] = _CatalogCacheEntry(
        createdAt: DateTime.now(),
        items: items,
      );

      return items;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  Future<List<ChartCatalogItem>> _fetchCatalog({
    required String facId,
    required String cate,
    required int importantOnly,
  }) async {
    final response = await api.getChartCatalog(
      facId: facId,
      cate: cate,
      importantOnly: importantOnly,
    );

    final normalized = response.items
        .where(_isValidCatalogItem)
        .toList(growable: false);
    return List<ChartCatalogItem>.unmodifiable(normalized);
  }

  // ============================================================
  // SELECTION
  // ============================================================

  void selectScadaId(String value) {
    final next = value.trim();

    if (next.isEmpty) return;
    if (!_scadaIds.contains(next)) return;
    if (next == _selectedScadaId) return;

    _selectedScadaId = next;
    _selectedBoxId = null;
    _selectedBoxDeviceId = null;

    _rebuildBoxes();

    if (_boxIds.isNotEmpty) {
      _selectedBoxId = _boxIds.first;
    }

    _rebuildDevices();
    _rebuildCharts();

    _safeNotifyListeners();
  }

  void selectBoxId(String value) {
    final next = value.trim();

    if (next.isEmpty) return;
    if (!_boxIds.contains(next)) return;
    if (next == _selectedBoxId) return;

    _selectedBoxId = next;
    _selectedBoxDeviceId = null;

    _rebuildDevices();
    _rebuildCharts();

    _safeNotifyListeners();
  }

  void selectBoxDeviceId(String? value) {
    final next = _normalizeNullable(value);

    if (next != null && !_boxDeviceIds.contains(next)) {
      return;
    }

    if (next == _selectedBoxDeviceId) {
      return;
    }

    _selectedBoxDeviceId = next;
    _rebuildCharts();

    _safeNotifyListeners();
  }

  void selectAllDevices() {
    if (_selectedBoxDeviceId == null) return;

    _selectedBoxDeviceId = null;
    _rebuildCharts();

    _safeNotifyListeners();
  }

  void _restoreSelections({
    required String? previousScada,
    required String? previousBox,
    required String? previousDevice,
  }) {
    _rebuildScadas();

    _selectedScadaId =
        previousScada != null && _scadaIds.contains(previousScada)
        ? previousScada
        : _scadaIds.firstOrNull;

    _rebuildBoxes();

    _selectedBoxId = previousBox != null && _boxIds.contains(previousBox)
        ? previousBox
        : _boxIds.firstOrNull;

    _rebuildDevices();

    _selectedBoxDeviceId =
        previousDevice != null && _boxDeviceIds.contains(previousDevice)
        ? previousDevice
        : null;

    _rebuildCharts();
  }

  // ============================================================
  // LOCAL INDEXES
  // ============================================================

  void _rebuildScadas() {
    final values = <String>{};

    for (final item in _allItems) {
      if (item.scadaId.isNotEmpty) {
        values.add(item.scadaId);
      }
    }

    final result = values.toList()..sort();

    _scadaIds = List<String>.unmodifiable(result);
  }

  void _rebuildBoxes() {
    final selectedScada = _selectedScadaId;

    if (selectedScada == null) {
      _boxIds = const [];
      return;
    }

    final values = <String>{};

    for (final item in _allItems) {
      if (item.scadaId != selectedScada) continue;
      if (item.boxId.isEmpty) continue;

      values.add(item.boxId);
    }

    final result = values.toList()..sort();

    _boxIds = List<String>.unmodifiable(result);
  }

  void _rebuildDevices() {
    final selectedScada = _selectedScadaId;
    final selectedBox = _selectedBoxId;

    if (selectedScada == null || selectedBox == null) {
      _boxDeviceIds = const [];
      return;
    }

    final values = <String>{};

    for (final item in _allItems) {
      if (item.scadaId != selectedScada) continue;
      if (item.boxId != selectedBox) continue;
      if (item.boxDeviceId.isEmpty) continue;

      values.add(item.boxDeviceId);
    }

    final result = values.toList()..sort();

    _boxDeviceIds = List<String>.unmodifiable(result);
  }

  void _rebuildCharts() {
    final selectedScada = _selectedScadaId;
    final selectedBox = _selectedBoxId;
    final selectedDevice = _selectedBoxDeviceId;

    if (selectedScada == null || selectedBox == null) {
      _charts = const [];
      return;
    }

    final seen = <String>{};
    final result = <SignalChartConfig>[];

    for (final item in _allItems) {
      if (item.scadaId != selectedScada) continue;
      if (item.boxId != selectedBox) continue;

      if (selectedDevice != null && item.boxDeviceId != selectedDevice) {
        continue;
      }

      final nameEn = item.nameEn?.trim();

      if (nameEn != null && nameEn.toLowerCase().contains('slave')) {
        continue;
      }

      if (item.boxDeviceId.isEmpty || item.plcAddress.isEmpty) {
        continue;
      }

      final uniqueKey = '${item.boxDeviceId}|${item.plcAddress}';

      if (!seen.add(uniqueKey)) {
        continue;
      }

      final cateId = item.cateId;
      result.add(
        SignalChartConfig(
          boxDeviceId: item.boxDeviceId,
          plcAddress: item.plcAddress,
          cateId: cateId,
          cateIds: cateId == null ? null : List<String>.unmodifiable([cateId]),
          groupLabel: selectedDevice == null ? item.boxDeviceId : null,
          nameEn: item.nameEn,
          nameVi: item.nameVi,
          unit: item.unit,
        ),
      );
    }

    result.sort((a, b) {
      final deviceCompare = a.boxDeviceId.compareTo(b.boxDeviceId);

      if (deviceCompare != 0) {
        return deviceCompare;
      }

      return _comparePlcAddress(a.plcAddress, b.plcAddress);
    });

    _charts = List<SignalChartConfig>.unmodifiable(result);
  }

  // ============================================================
  // NORMALIZATION
  // ============================================================

  bool _isValidCatalogItem(ChartCatalogItem item) {
    return item.scadaId.isNotEmpty &&
        item.boxId.isNotEmpty &&
        item.boxDeviceId.isNotEmpty &&
        item.plcAddress.isNotEmpty;
  }

  String _normalizeRequired(String value) {
    return value.trim();
  }

  String? _normalizeNullable(String? value) {
    if (value == null) return null;

    final normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
  }

  String _buildCacheKey({
    required String facId,
    required String cate,
    required int importantOnly,
  }) {
    return '${facId.toLowerCase()}|'
        '${cate.toLowerCase()}|'
        '$importantOnly';
  }

  // D100 phải đứng trước D20 nếu sort text thường.
  int _comparePlcAddress(String first, String second) {
    final firstMatch = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(first);

    final secondMatch = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(second);

    if (firstMatch == null || secondMatch == null) {
      return first.compareTo(second);
    }

    final prefixCompare = firstMatch.group(1)!.compareTo(secondMatch.group(1)!);

    if (prefixCompare != 0) {
      return prefixCompare;
    }

    final firstNumber = int.tryParse(firstMatch.group(2)!) ?? 0;

    final secondNumber = int.tryParse(secondMatch.group(2)!) ?? 0;

    return firstNumber.compareTo(secondNumber);
  }

  // ============================================================
  // CACHE
  // ============================================================

  void clearCache() {
    _cache.clear();
  }

  void invalidateCache({
    required String facId,
    required String cate,
    required int importantOnly,
  }) {
    final key = _buildCacheKey(
      facId: facId.trim(),
      cate: cate.trim(),
      importantOnly: importantOnly == 1 ? 1 : 0,
    );

    _cache.remove(key);
  }

  Future<void> refresh({
    required String facId,
    required String cate,
    int importantOnly = 0,
  }) {
    return loadCatalog(
      facId: facId,
      cate: cate,
      importantOnly: importantOnly,
      forceRefresh: true,
    );
  }

  // ============================================================
  // INTERNAL STATE
  // ============================================================

  bool _isCurrentRequest(int token) {
    return !_disposed && token == _requestToken;
  }

  void _setError(Object error) {
    _error = error;
    _loading = false;
    _safeNotifyListeners();
  }

  void _safeNotifyListeners() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestToken++;
    _inFlight.clear();

    super.dispose();
  }
}

extension _FirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
