import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../utility_api/utility_api.dart';
import '../utility_models/response/minute_point.dart';

class _MinuteReq {
  final String key;
  final String? facId;
  final String? scadaId;
  final String? cate;
  final String? boxDeviceId;
  final List<String>? cateIds;

  const _MinuteReq({
    required this.key,
    this.facId,
    this.scadaId,
    this.cate,
    this.boxDeviceId,
    this.cateIds,
  });
}

class MinuteSeriesProvider extends ChangeNotifier {
  final UtilityApi api;

  /// Khoảng nghỉ sau khi một vòng polling hoàn tất.
  final Duration interval;

  /// Khoảng dữ liệu giữ lại trên biểu đồ.
  final Duration window;

  /// Timeout cho từng request.
  final Duration requestTimeout;

  /// Số request tối đa chạy song song trong một vòng.
  final int maxConcurrentRequests;

  MinuteSeriesProvider({
    required this.api,
    this.interval = const Duration(seconds: 30),
    this.window = const Duration(minutes: 60),
    this.requestTimeout = const Duration(seconds: 15),
    this.maxConcurrentRequests = 3,
  }) : assert(maxConcurrentRequests > 0);

  Timer? _timer;

  bool _polling = false;
  bool _tickRunning = false;
  bool _disposed = false;
  bool _notifyScheduled = false;

  /// Version riêng từng key để response cũ không ghi đè request mới.
  final Map<String, int> _versions = {};

  final Map<String, _MinuteReq> _reqs = {};
  final Map<String, List<MinutePointDto>> _rows = {};
  final Map<String, Object?> _errors = {};
  final Map<String, bool> _fetching = {};
  final Map<String, DateTime?> _lastTs = {};
  final Map<String, bool> _fetchedOnce = {};
  final Map<String, DateTime?> _lastOkAt = {};
  final Map<String, DateTime?> _lastErrAt = {};

  // ============================================================
  // GETTERS
  // ============================================================

  bool get polling => _polling;

  bool get tickRunning => _tickRunning;

  int get requestCount => _reqs.length;

  bool get hasRequests => _reqs.isNotEmpty;

  // ============================================================
  // KEY
  // ============================================================

  String buildKey({
    String? facId,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    List<String>? cateIds,
  }) {
    final ids = _normalizeCateIds(cateIds) ?? const <String>[];

    return 'fac=${_normalizeText(facId)}'
        '|scada=${_normalizeText(scadaId)}'
        '|cate=${_normalizeText(cate)}'
        '|dev=${_normalizeText(boxDeviceId)}'
        '|cateIds=${ids.join(',')}';
  }

  // ============================================================
  // REQUEST MANAGEMENT
  // ============================================================

  void upsertRequest({
    required String key,
    String? facId,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    List<String>? cateIds,
  }) {
    if (_disposed) return;

    final normalizedKey = key.trim();

    if (normalizedKey.isEmpty) {
      return;
    }

    final newRequest = _MinuteReq(
      key: normalizedKey,
      facId: _normalizeNullableText(facId),
      scadaId: _normalizeNullableText(scadaId),
      cate: _normalizeNullableText(cate),
      boxDeviceId: _normalizeNullableText(boxDeviceId),
      cateIds: _normalizeCateIds(cateIds),
    );

    final oldRequest = _reqs[normalizedKey];

    final changed =
        oldRequest == null ||
        oldRequest.facId != newRequest.facId ||
        oldRequest.scadaId != newRequest.scadaId ||
        oldRequest.cate != newRequest.cate ||
        oldRequest.boxDeviceId != newRequest.boxDeviceId ||
        !listEquals(oldRequest.cateIds, newRequest.cateIds);

    _reqs[normalizedKey] = newRequest;

    _rows.putIfAbsent(normalizedKey, () => const <MinutePointDto>[]);

    _errors.putIfAbsent(normalizedKey, () => null);
    _fetching.putIfAbsent(normalizedKey, () => false);
    _lastTs.putIfAbsent(normalizedKey, () => null);
    _fetchedOnce.putIfAbsent(normalizedKey, () => false);
    _lastOkAt.putIfAbsent(normalizedKey, () => null);
    _lastErrAt.putIfAbsent(normalizedKey, () => null);
    _versions.putIfAbsent(normalizedKey, () => 0);

    if (changed && oldRequest != null) {
      /*
       * Cùng key nhưng tham số đã đổi:
       * vô hiệu response cũ và reset dữ liệu của key.
       */
      _invalidateKey(normalizedKey);

      _rows[normalizedKey] = const <MinutePointDto>[];
      _errors[normalizedKey] = null;
      _fetching[normalizedKey] = false;
      _lastTs[normalizedKey] = null;
      _fetchedOnce[normalizedKey] = false;
      _lastOkAt[normalizedKey] = null;
      _lastErrAt[normalizedKey] = null;

      _safeNotify();
    }

    /*
     * Nếu polling đang chạy và đây là request mới,
     * gọi ngay thay vì chờ vòng tiếp theo.
     */
    if (_polling && changed && _hasRequired(newRequest)) {
      unawaited(fetchKeyNow(normalizedKey));
    }
  }

  void removeKey(String key) {
    if (_disposed) return;

    final normalizedKey = key.trim();

    if (normalizedKey.isEmpty) return;

    _invalidateKey(normalizedKey);

    _reqs.remove(normalizedKey);
    _rows.remove(normalizedKey);
    _errors.remove(normalizedKey);
    _fetching.remove(normalizedKey);
    _lastTs.remove(normalizedKey);
    _fetchedOnce.remove(normalizedKey);
    _lastOkAt.remove(normalizedKey);
    _lastErrAt.remove(normalizedKey);
    _versions.remove(normalizedKey);

    _safeNotify();
  }

  void clear() {
    if (_disposed) return;

    for (final key in _reqs.keys.toList(growable: false)) {
      _invalidateKey(key);
    }

    _reqs.clear();
    _rows.clear();
    _errors.clear();
    _fetching.clear();
    _lastTs.clear();
    _fetchedOnce.clear();
    _lastOkAt.clear();
    _lastErrAt.clear();
    _versions.clear();

    _safeNotify();
  }

  // ============================================================
  // DATA GETTERS
  // ============================================================

  List<MinutePointDto> getRows(String key) {
    return _rows[key] ?? const <MinutePointDto>[];
  }

  List<MinutePointDto> getRowsForPlc(String key, String plcAddress) {
    final address = plcAddress.trim();

    if (address.isEmpty) {
      return const <MinutePointDto>[];
    }

    final allRows = _rows[key] ?? const <MinutePointDto>[];

    return List<MinutePointDto>.unmodifiable(
      allRows.where((item) => (item.plcAddress ?? '').trim() == address),
    );
  }

  Object? getError(String key) => _errors[key];

  bool isFetching(String key) {
    return _fetching[key] == true;
  }

  bool hasFetchedOnce(String key) {
    return _fetchedOnce[key] == true;
  }

  DateTime? lastOkAt(String key) => _lastOkAt[key];

  DateTime? lastErrAt(String key) => _lastErrAt[key];

  // ============================================================
  // POLLING
  // ============================================================

  void startPolling() {
    if (_disposed || _polling) {
      return;
    }

    _polling = true;
    _stopTimer();

    /*
     * Gọi ngay vòng đầu tiên.
     */
    unawaited(_runPollingCycle());
  }

  void stopPolling() {
    _polling = false;
    _stopTimer();
  }

  Future<void> _runPollingCycle() async {
    if (_disposed || !_polling) {
      return;
    }

    await _tickAll();

    if (_disposed || !_polling) {
      return;
    }

    /*
     * Chỉ bắt đầu đếm interval sau khi vòng request hoàn tất.
     */
    _timer = Timer(interval, () {
      unawaited(_runPollingCycle());
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // ============================================================
  // MANUAL REFRESH
  // ============================================================

  Future<void> fetchKeyNow(String key) async {
    if (_disposed) return;

    final request = _reqs[key];

    if (request == null || !_hasRequired(request)) {
      return;
    }

    if (_fetching[key] == true) {
      return;
    }

    await _fetchFullWindow(request);
  }

  Future<void> refreshKey(String key) {
    return fetchKeyNow(key);
  }

  Future<void> refreshAll() async {
    if (_disposed || _tickRunning) {
      return;
    }

    final wasPolling = _polling;

    _stopTimer();

    await _tickAll(forceFullWindow: true);

    if (_disposed) return;

    if (wasPolling && _polling) {
      _timer = Timer(interval, () {
        unawaited(_runPollingCycle());
      });
    }
  }

  // ============================================================
  // TICK
  // ============================================================

  Future<void> _tickAll({bool forceFullWindow = false}) async {
    if (_disposed || _tickRunning || _reqs.isEmpty) {
      return;
    }

    _tickRunning = true;

    try {
      final requests = List<_MinuteReq>.from(
        _reqs.values,
      ).where(_hasRequired).toList(growable: false);

      if (requests.isEmpty) {
        return;
      }

      /*
       * Chia thành từng batch để tránh gọi quá nhiều API cùng lúc.
       */
      for (
        var start = 0;
        start < requests.length;
        start += maxConcurrentRequests
      ) {
        if (_disposed) break;

        final end = math.min(start + maxConcurrentRequests, requests.length);

        final batch = requests.sublist(start, end);

        await Future.wait(
          batch.map((request) async {
            if (_disposed) return;

            if (!_reqs.containsKey(request.key)) {
              return;
            }

            if (_fetching[request.key] == true) {
              return;
            }

            final last = _lastTs[request.key];

            final isEmpty = _rows[request.key]?.isEmpty ?? true;

            if (forceFullWindow || last == null || isEmpty) {
              await _fetchFullWindow(request);
            } else {
              await _fetchIncremental(request);
            }
          }),
        );
      }
    } finally {
      _tickRunning = false;
    }
  }

  // ============================================================
  // FULL WINDOW
  // ============================================================

  Future<void> _fetchFullWindow(_MinuteReq request) async {
    final key = request.key;

    if (_disposed || !_reqs.containsKey(key) || _fetching[key] == true) {
      return;
    }

    if (!_hasRequired(request)) {
      _rows[key] = const <MinutePointDto>[];
      _errors[key] = null;
      _lastTs[key] = null;
      _fetchedOnce[key] = true;

      _safeNotify();
      return;
    }

    final version = _currentVersion(key);

    _fetching[key] = true;
    _errors[key] = null;

    _safeNotify();

    try {
      final to = DateTime.now();
      final from = to.subtract(window);

      final result = await api
          .getSeriesMinute(
            from: from,
            to: to,
            boxDeviceId: request.boxDeviceId!.trim(),
            plcAddress: null,
            cateIds: request.cateIds,
          )
          .timeout(requestTimeout);

      if (!_isValidKeyRequest(key, version)) {
        return;
      }

      final sorted = List<MinutePointDto>.from(result)..sort(_sortRows);

      _rows[key] = List<MinutePointDto>.unmodifiable(sorted);

      _lastTs[key] = sorted.isNotEmpty ? sorted.last.ts : null;

      _trimToWindow(key);

      _errors[key] = null;
      _fetchedOnce[key] = true;
      _lastOkAt[key] = DateTime.now();
    } catch (error, stackTrace) {
      if (!_isValidKeyRequest(key, version)) {
        return;
      }

      _errors[key] = error;
      _fetchedOnce[key] = true;
      _lastErrAt[key] = DateTime.now();

      debugPrint(
        '[MINUTE FULL WINDOW ERROR] '
        'key=$key error=$error',
      );

      debugPrintStack(stackTrace: stackTrace);

      /*
       * Không xóa rows cũ khi request lỗi.
       */
    } finally {
      if (_isValidKeyRequest(key, version)) {
        _fetching[key] = false;
        _safeNotify();
      }
    }
  }

  // ============================================================
  // INCREMENTAL
  // ============================================================

  Future<void> _fetchIncremental(_MinuteReq request) async {
    final key = request.key;

    if (_disposed ||
        !_reqs.containsKey(key) ||
        _fetching[key] == true ||
        !_hasRequired(request)) {
      return;
    }

    final lastTimestamp = _lastTs[key];

    if (lastTimestamp == null) {
      await _fetchFullWindow(request);
      return;
    }

    final version = _currentVersion(key);

    _fetching[key] = true;
    _errors[key] = null;

    _safeNotify();

    try {
      /*
       * Lùi một phút để tránh mất dữ liệu do lệch thời gian
       * hoặc dữ liệu được insert trễ.
       */
      final from = lastTimestamp.subtract(const Duration(minutes: 1));

      final to = DateTime.now();

      final result = await api
          .getSeriesMinute(
            from: from,
            to: to,
            boxDeviceId: request.boxDeviceId!.trim(),
            plcAddress: null,
            cateIds: request.cateIds,
          )
          .timeout(requestTimeout);

      if (!_isValidKeyRequest(key, version)) {
        return;
      }

      if (result.isNotEmpty) {
        final incoming = List<MinutePointDto>.from(result)..sort(_sortRows);

        final merged = _mergeRows(
          current: _rows[key] ?? const <MinutePointDto>[],
          incoming: incoming,
        );

        _rows[key] = List<MinutePointDto>.unmodifiable(merged);

        _lastTs[key] = merged.isNotEmpty ? merged.last.ts : lastTimestamp;

        _trimToWindow(key);
      }

      _errors[key] = null;
      _fetchedOnce[key] = true;
      _lastOkAt[key] = DateTime.now();
    } catch (error, stackTrace) {
      if (!_isValidKeyRequest(key, version)) {
        return;
      }

      _errors[key] = error;
      _fetchedOnce[key] = true;
      _lastErrAt[key] = DateTime.now();

      debugPrint(
        '[MINUTE INCREMENTAL ERROR] '
        'key=$key error=$error',
      );

      debugPrintStack(stackTrace: stackTrace);

      /*
       * Giữ dữ liệu cũ khi refresh lỗi.
       */
    } finally {
      if (_isValidKeyRequest(key, version)) {
        _fetching[key] = false;
        _safeNotify();
      }
    }
  }

  // ============================================================
  // MERGE / SORT / TRIM
  // ============================================================

  List<MinutePointDto> _mergeRows({
    required List<MinutePointDto> current,
    required List<MinutePointDto> incoming,
  }) {
    /*
     * Dùng Map để incoming có thể thay thế điểm cũ
     * nếu cùng timestamp + PLC nhưng giá trị backend cập nhật lại.
     */
    final merged = <String, MinutePointDto>{};

    for (final item in current) {
      merged[_rowKey(item)] = item;
    }

    for (final item in incoming) {
      merged[_rowKey(item)] = item;
    }

    final result = merged.values.toList()..sort(_sortRows);

    return result;
  }

  String _rowKey(MinutePointDto item) {
    return '${item.ts.millisecondsSinceEpoch}'
        '|${(item.boxDeviceId ?? '').trim()}'
        '|${(item.plcAddress ?? '').trim()}'
        '|${(item.cateId ?? '').trim()}';
  }

  int _sortRows(MinutePointDto first, MinutePointDto second) {
    final timestampCompare = first.ts.compareTo(second.ts);

    if (timestampCompare != 0) {
      return timestampCompare;
    }

    final plcCompare = (first.plcAddress ?? '').compareTo(
      second.plcAddress ?? '',
    );

    if (plcCompare != 0) {
      return plcCompare;
    }

    return (first.cateId ?? '').compareTo(second.cateId ?? '');
  }

  void _trimToWindow(String key) {
    final current = _rows[key];

    if (current == null || current.isEmpty) {
      return;
    }

    final cutoff = DateTime.now().subtract(window);

    final trimmed = current
        .where((item) => !item.ts.isBefore(cutoff))
        .toList(growable: false);

    if (trimmed.length == current.length) {
      return;
    }

    _rows[key] = List<MinutePointDto>.unmodifiable(trimmed);

    _lastTs[key] = trimmed.isNotEmpty ? trimmed.last.ts : null;
  }

  // ============================================================
  // VERSION CONTROL
  // ============================================================

  int _currentVersion(String key) {
    return _versions[key] ?? 0;
  }

  void _invalidateKey(String key) {
    _versions[key] = _currentVersion(key) + 1;
  }

  bool _isValidKeyRequest(String key, int version) {
    return !_disposed &&
        _reqs.containsKey(key) &&
        _currentVersion(key) == version;
  }

  // ============================================================
  // NORMALIZE
  // ============================================================

  String _normalizeText(String? value) {
    return value?.trim() ?? '';
  }

  String? _normalizeNullableText(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  List<String>? _normalizeCateIds(List<String>? source) {
    if (source == null || source.isEmpty) {
      return null;
    }

    final result =
        source
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return result.isEmpty ? null : List<String>.unmodifiable(result);
  }

  bool _hasRequired(_MinuteReq request) {
    return (request.boxDeviceId ?? '').trim().isNotEmpty;
  }

  // ============================================================
  // SAFE NOTIFY
  // ============================================================

  void _safeNotify() {
    if (_disposed) return;

    final binding = WidgetsBinding.instance;
    final phase = binding.schedulerPhase;

    final isBuilding =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;

    if (!isBuilding) {
      notifyListeners();
      return;
    }

    if (_notifyScheduled) {
      return;
    }

    _notifyScheduled = true;

    binding.addPostFrameCallback((_) {
      _notifyScheduled = false;

      if (_disposed) return;

      notifyListeners();
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _polling = false;

    _stopTimer();

    for (final key in _versions.keys.toList()) {
      _invalidateKey(key);
    }

    super.dispose();
  }
}
