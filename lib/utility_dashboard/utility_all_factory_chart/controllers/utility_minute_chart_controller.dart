import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../../shared/state/safe_change_notifier.dart';
import '../api/utility_chart_api.dart';
import '../models/minute_point.dart';

class _MinuteReq {
  final String key;
  final String? facId;
  final String? scadaId;
  final String? boxDeviceId;

  const _MinuteReq({
    required this.key,
    this.facId,
    this.scadaId,
    this.boxDeviceId,
  });
}

class UtilityMinuteChartController extends ChangeNotifier
    with SafeChangeNotifier {
  final UtilityChartApi api;

  /// Khoảng dữ liệu giữ lại trên biểu đồ.
  final Duration window;

  /// Timeout cho từng request.
  final Duration requestTimeout;

  /// Số request tối đa chạy song song trong một vòng.
  final int maxConcurrentRequests;

  UtilityMinuteChartController({
    required this.api,
    this.window = const Duration(minutes: 60),
    this.requestTimeout = const Duration(seconds: 15),
    this.maxConcurrentRequests = 3,
  }) : assert(maxConcurrentRequests > 0);

  bool _tickRunning = false;
  bool _disposed = false;

  /// Version riêng từng key để response cũ không ghi đè request mới.
  final Map<String, int> _versions = {};

  final Map<String, _MinuteReq> _reqs = {};
  final Map<String, List<MinutePointDto>> _rows = {};
  final Map<String, Object?> _errors = {};
  final Map<String, bool> _fetching = {};
  /*
   * _lastTs = BUCKET ts cua diem moi nhat dang giu trong _rows (khong phai
   * sampleRecordedAt). Day la chu y co chu dich, khong duoc doi sang
   * sampleRecordedAt.
   *
   * No dieu khien dung hai thu:
   *
   * 1. Chon che do fetch trong _tickAll: null => _fetchFullWindow,
   *    nguoc lai => _fetchIncremental.
   *
   * 2. Moc bat dau cua request incremental:
   *       from = _lastTs - 1 phut   (overlap), to = now
   *
   * Vi sao phai giu bucket ts:
   *
   * - Backend nhan [from, to) theo moc bucket. Bucket ts luon <= sample time
   *   thuc cua no, nen from tinh tu bucket ts luon som hon hoac bang from
   *   tinh tu sampleRecordedAt => khong bao gio bo sot bucket. Neu doi sang
   *   sampleRecordedAt (vd 11:15:46), from = 11:14:46 se roi vao giua bucket
   *   11:14 va co the lam backend bo bucket do.
   *
   * - Overlap 1 phut duoc thiet ke de fetch lai chinh bucket cuoi cung, vi
   *   bucket dang chay co the duoc backend cap nhat lai gia tri. _mergeRows
   *   dedupe theo _rowKey (cung dua tren bucket ts), nen diem fetch lai se
   *   thay the dung diem cu thay vi tao diem trung.
   *
   * Khong co bang chung nao cho thay hanh vi hien tai sai, nen giu nguyen.
   */
  final Map<String, DateTime?> _lastTs = {};
  final Map<String, bool> _fetchedOnce = {};
  final Map<String, DateTime?> _lastOkAt = {};
  final Map<String, DateTime?> _lastErrAt = {};

  /// Request dang chay theo key; huy khi key bi bo / doi request.
  final Map<String, CancelToken> _cancelTokens = {};

  // ============================================================
  // KEY
  // ===============================================  =============

  String buildKey({String? facId, String? scadaId, String? boxDeviceId}) {
    return 'fac=${_normalizeText(facId)}'
        '|scada=${_normalizeText(scadaId)}'
        '|dev=${_normalizeText(boxDeviceId)}';
  }

  // ============================================================
  // REQUEST MANAGEMENT
  // ============================================================

  void upsertRequest({
    required String key,
    String? facId,
    String? scadaId,
    String? boxDeviceId,
  }) {
    if (_disposed) return;

    final normalizedKey = key.trim();

    if (normalizedKey.isEmpty) return;

    final newRequest = _MinuteReq(
      key: normalizedKey,
      facId: _normalizeNullableText(facId),
      scadaId: _normalizeNullableText(scadaId),
      boxDeviceId: _normalizeNullableText(boxDeviceId),
    );

    final oldRequest = _reqs[normalizedKey];

    final changed =
        oldRequest == null ||
        oldRequest.facId != newRequest.facId ||
        oldRequest.scadaId != newRequest.scadaId ||
        oldRequest.boxDeviceId != newRequest.boxDeviceId;

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
      _invalidateKey(normalizedKey);
      _cancelRequest(normalizedKey, 'request changed');

      _rows[normalizedKey] = const <MinutePointDto>[];
      _errors[normalizedKey] = null;
      _fetching[normalizedKey] = false;
      _lastTs[normalizedKey] = null;
      _fetchedOnce[normalizedKey] = false;
      _lastOkAt[normalizedKey] = null;
      _lastErrAt[normalizedKey] = null;

      safeNotify();
    }
  }

  void removeKey(String key) {
    if (_disposed) return;

    final normalizedKey = key.trim();

    if (normalizedKey.isEmpty) return;

    _invalidateKey(normalizedKey);
    _cancelRequest(normalizedKey, 'key removed');

    _reqs.remove(normalizedKey);
    _rows.remove(normalizedKey);
    _errors.remove(normalizedKey);
    _fetching.remove(normalizedKey);
    _lastTs.remove(normalizedKey);
    _fetchedOnce.remove(normalizedKey);
    _lastOkAt.remove(normalizedKey);
    _lastErrAt.remove(normalizedKey);
    _versions.remove(normalizedKey);

    safeNotify();
  }

  /// Bo moi request khong thuoc [keys] (lua chon fac/cate/box/device hien
  /// tai), de [poll] chi lam moi device dang hien thi. Request dang chay cua
  /// cac key bi bo duoc huy.
  void retainOnly(Set<String> keys) {
    if (_disposed) return;

    final keep = keys.map((key) => key.trim()).toSet();
    final stale = _reqs.keys
        .where((key) => !keep.contains(key))
        .toList(growable: false);

    for (final key in stale) {
      removeKey(key);
    }
  }

  // ============================================================
  // DATA GETTERS
  // ============================================================

  List<MinutePointDto> getRowsForPlc(String key, String plcAddress) {
    final address = plcAddress.trim();

    if (address.isEmpty) {
      return const <MinutePointDto>[];
    }

    final allRows = _rows[key] ?? const <MinutePointDto>[];

    return List<MinutePointDto>.unmodifiable(
      allRows.where((item) => item.plcAddress.trim() == address),
    );
  }

  Object? getError(String key) => _errors[key];

  bool hasFetchedOnce(String key) {
    return _fetchedOnce[key] == true;
  }

  DateTime? lastOkAt(String key) => _lastOkAt[key];

  DateTime? lastErrAt(String key) => _lastErrAt[key];

  Future<void> poll() {
    return _tickAll();
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

  // ============================================================
  // TICK
  // ============================================================

  Future<void> _tickAll() async {
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

            if (last == null || isEmpty) {
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

      safeNotify();
      return;
    }

    final version = _currentVersion(key);

    _fetching[key] = true;
    _errors[key] = null;

    safeNotify();

    final cancelToken = _startRequest(key);

    try {
      final to = DateTime.now();
      final from = to.subtract(window);

      final result = await _withTimeout(
        api.getSeriesMinute(
          from: from,
          to: to,
          boxDeviceId: request.boxDeviceId!.trim(),
          cancelToken: cancelToken,
        ),
        cancelToken,
      );

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
      // Huy chu dong (key bi bo / doi request): khong phai loi.
      if (error is DioException && CancelToken.isCancel(error)) return;

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
      _finishRequest(key, cancelToken);
      _clearFetching(key);

      if (_isValidKeyRequest(key, version)) {
        safeNotify();
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

    safeNotify();

    final cancelToken = _startRequest(key);

    try {
      /*
       * Lùi một phút để tránh mất dữ liệu do lệch thời gian
       * hoặc dữ liệu được insert trễ.
       */
      final from = lastTimestamp.subtract(const Duration(minutes: 1));

      final to = DateTime.now();

      final result = await _withTimeout(
        api.getSeriesMinute(
          from: from,
          to: to,
          boxDeviceId: request.boxDeviceId!.trim(),
          cancelToken: cancelToken,
        ),
        cancelToken,
      );

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
      // Huy chu dong (key bi bo / doi request): khong phai loi.
      if (error is DioException && CancelToken.isCancel(error)) return;

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
      _finishRequest(key, cancelToken);
      _clearFetching(key);

      if (_isValidKeyRequest(key, version)) {
        safeNotify();
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

  /// Dedupe key cua mot diem: dua tren BUCKET ts, khong phai sampleRecordedAt.
  ///
  /// Mot bucket co the duoc backend tra ve lai voi sample khac (va do do
  /// sampleRecordedAt khac) khi phut do van dang chay. Khoa theo bucket ts
  /// dam bao lan tra ve sau THAY THE diem cu thay vi them mot diem trung
  /// tren cung mot moc X.
  String _rowKey(MinutePointDto item) {
    return '${item.ts.millisecondsSinceEpoch}'
        '|${item.boxDeviceId.trim()}'
        '|${item.plcAddress.trim()}'
        '|${(item.cateId ?? '').trim()}';
  }

  int _sortRows(MinutePointDto first, MinutePointDto second) {
    final timestampCompare = first.ts.compareTo(second.ts);

    if (timestampCompare != 0) {
      return timestampCompare;
    }

    final plcCompare = first.plcAddress.compareTo(second.plcAddress);

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
  // CANCELLATION
  // ============================================================

  CancelToken _startRequest(String key) {
    _cancelRequest(key, 'superseded');

    final token = CancelToken();
    _cancelTokens[key] = token;
    return token;
  }

  void _finishRequest(String key, CancelToken token) {
    if (identical(_cancelTokens[key], token)) {
      _cancelTokens.remove(key);
    }
  }

  void _cancelRequest(String key, String reason) {
    final token = _cancelTokens.remove(key);
    if (token != null && !token.isCancelled) token.cancel(reason);
  }

  /// Timeout cung huy request that, khong de no chay toi receiveTimeout.
  Future<T> _withTimeout<T>(Future<T> request, CancelToken cancelToken) {
    return request.timeout(
      requestTimeout,
      onTimeout: () {
        cancelToken.cancel('timeout');
        throw TimeoutException('Minute request timed out', requestTimeout);
      },
    );
  }

  // ============================================================
  // VERSION CONTROL
  // ============================================================

  /// Clears the in-flight marker for [key] unconditionally.
  ///
  /// Cleanup must never be gated on the request version: if a key was
  /// invalidated mid-flight and the marker stayed true, every later poll for
  /// that key would early-return and the series would freeze permanently.
  ///
  /// Uses containsKey so a key removed by removeKey/clear is not resurrected.
  void _clearFetching(String key) {
    if (_fetching.containsKey(key)) {
      _fetching[key] = false;
    }
  }

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

  bool _hasRequired(_MinuteReq request) {
    return (request.boxDeviceId ?? '').trim().isNotEmpty;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    for (final key in _versions.keys.toList()) {
      _invalidateKey(key);
    }
    for (final key in _cancelTokens.keys.toList()) {
      _cancelRequest(key, 'disposed');
    }

    super.dispose();
  }
}
