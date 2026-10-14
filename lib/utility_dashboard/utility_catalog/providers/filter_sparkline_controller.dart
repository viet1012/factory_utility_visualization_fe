import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../shared/state/safe_change_notifier.dart';
import '../api/signal_history_repository.dart';
import '../models/signal_history_models.dart';

/// Mot device can sparkline: key device + id cac signal cua no.
class SparklineDeviceRequest {
  final String deviceKey;
  final List<String> signalIds;

  const SparklineDeviceRequest({
    required this.deviceKey,
    required this.signalIds,
  });
}

enum SparklineLoadState { loading, ready, error }

/// Lich su 1h cho bang Filter results: sparkline, kind va nguong cua tung
/// signal. Chi tai cho cac device co dong DANG NAM TRONG KHUNG NHIN cua bang
/// ([syncVisible], bang tu goi theo vi tri cuon, da debounce).
///
/// - 1 request / device (`series/history`, bucket=auto -> 1m, ~60 diem);
/// - toi da [maxConcurrent] request cung luc, phan con lai xep hang;
/// - device ra khoi khung nhin ma request chua xong: huy (CancelToken);
/// - ket qua cache theo device [refreshInterval]; cuon len xuong khong tai
///   lai. Device dang hien duoc lam moi khi cache qua [refreshInterval]:
///   view dang ky task PollingCoordinator goi [refreshStale] (scope SCADA
///   TABLE, nen tu dung khi tab an / bi che).
class FilterSparklineController extends ChangeNotifier with SafeChangeNotifier {
  final SignalHistoryRepository repository;

  FilterSparklineController({required this.repository});

  static const Duration window = Duration(hours: 1);

  /// Chu ky lam moi sparkline va TTL cua cache theo device.
  static const Duration refreshInterval = Duration(minutes: 5);

  static const Duration requestTimeout = Duration(seconds: 15);
  static const int maxConcurrent = 4;

  /// Device vua loi: cho toi luc nay moi thu lai (bang nhip kiem tra cua
  /// task lam moi).
  static const Duration _retryDelay = Duration(seconds: 30);

  bool _disposed = false;

  final Map<String, _DeviceEntry> _entries = <String, _DeviceEntry>{};
  final Map<String, SignalHistorySeries> _seriesById =
      <String, SignalHistorySeries>{};

  final Map<String, SparklineDeviceRequest> _visible =
      <String, SparklineDeviceRequest>{};

  final Queue<SparklineDeviceRequest> _queue = Queue<SparklineDeviceRequest>();
  final Map<String, CancelToken> _inFlight = <String, CancelToken>{};

  /// Tong so request da gui (log debug, de do muc tai).
  int _requestCount = 0;

  // ============================================================
  // READ
  // ============================================================

  SignalHistorySeries? seriesFor(String signalId) => _seriesById[signalId];

  SparklineLoadState? stateOf(String deviceKey) => _entries[deviceKey]?.state;

  // ============================================================
  // SYNC
  // ============================================================

  /// [devices]: cac device co it nhat mot dong trong khung nhin hien tai.
  void syncVisible(List<SparklineDeviceRequest> devices) {
    if (_disposed) return;

    final nextVisible = <String, SparklineDeviceRequest>{
      for (final device in devices) device.deviceKey: device,
    };

    // Ra khoi khung nhin: huy request dang chay, bo khoi hang doi.
    for (final key in _inFlight.keys.toList()) {
      if (!nextVisible.containsKey(key)) {
        _inFlight.remove(key)?.cancel('scrolled out of view');

        // Chua co ket qua nao -> bo trang thai "dang tai".
        if (_entries[key]?.state == SparklineLoadState.loading) {
          _entries.remove(key);
        }
      }
    }
    _queue.removeWhere((item) => !nextVisible.containsKey(item.deviceKey));

    _visible
      ..clear()
      ..addAll(nextVisible);

    _evict();
    _enqueueStale();
  }

  /// Task lam moi cua view: tai lai cac device dang hien da qua han. Chay
  /// ngay khi bang hien lai (doi tab / bo che) thay vi doi nhip ke tiep.
  Future<void> refreshStale() async {
    if (_disposed) return;
    _enqueueStale();
  }

  /// Dua vao hang doi cac device dang hien chua co cache / cache da cu.
  void _enqueueStale() {
    final now = DateTime.now();
    var changed = false;

    for (final device in _visible.values) {
      if (!_needsLoad(device, now)) continue;

      _queue.add(device);

      // Chi hien "dang tai" khi chua co gi de ve; lam moi thi giu cai cu.
      final entry = _entries[device.deviceKey];
      if (entry == null || entry.state == SparklineLoadState.error) {
        _entries[device.deviceKey] = _DeviceEntry.loading(device.signalIds);
        changed = true;
      }
    }

    _pump();

    if (changed) safeNotify();
  }

  bool _needsLoad(SparklineDeviceRequest device, DateTime now) {
    final key = device.deviceKey;

    if (_inFlight.containsKey(key)) return false;
    if (_queue.any((item) => item.deviceKey == key)) return false;

    final entry = _entries[key];
    if (entry == null) return true;
    if (!listEquals(entry.signalIds, device.signalIds)) return true;
    if (entry.state == SparklineLoadState.loading) return true;

    // Vua loi: cho toi nhip kiem tra sau, khong thu lai moi lan cuon.
    final retryAfter = entry.retryAfter;
    if (retryAfter != null && now.isBefore(retryAfter)) return false;

    final fetchedAt = entry.fetchedAt;
    return fetchedAt == null || now.difference(fetchedAt) >= refreshInterval;
  }

  void _pump() {
    while (_inFlight.length < maxConcurrent && _queue.isNotEmpty) {
      final device = _queue.removeFirst();
      if (!_visible.containsKey(device.deviceKey)) continue;

      unawaited(_fetch(device));
    }
  }

  Future<void> _fetch(SparklineDeviceRequest device) async {
    final key = device.deviceKey;
    final token = CancelToken();
    _inFlight[key] = token;

    final to = DateTime.now();
    final from = to.subtract(window);

    _requestCount++;
    if (kDebugMode) {
      debugPrint(
        '[FILTER SPARKLINE] request #$_requestCount device=$key '
        'signals=${device.signalIds.length} inFlight=${_inFlight.length}',
      );
    }

    try {
      final result = await repository
          .fetchHistory(
            signalIds: device.signalIds,
            from: from,
            to: to,
            cancelToken: token,
          )
          .timeout(requestTimeout);

      if (_disposed || !identical(_inFlight[key], token)) return;

      for (final series in result.series) {
        _seriesById[series.signalId] = series;
      }

      _entries[key] = _DeviceEntry(
        state: SparklineLoadState.ready,
        signalIds: device.signalIds,
        fetchedAt: DateTime.now(),
      );
    } catch (error) {
      if (_disposed || !identical(_inFlight[key], token)) return;

      if (error is TimeoutException) token.cancel('timeout');

      // Loi lam moi: giu sparkline cu. Thu lai o nhip kiem tra sau.
      _entries[key] = _DeviceEntry(
        state: _hasAnySeries(device)
            ? SparklineLoadState.ready
            : SparklineLoadState.error,
        signalIds: device.signalIds,
        fetchedAt: _hasAnySeries(device) ? _entries[key]?.fetchedAt : null,
        retryAfter: DateTime.now().add(_retryDelay),
      );

      debugPrint('[FILTER SPARKLINE ERROR] device=$key error=$error');
    } finally {
      if (!_disposed && identical(_inFlight[key], token)) {
        _inFlight.remove(key);
        safeNotify();
        _pump();
      }
    }
  }

  bool _hasAnySeries(SparklineDeviceRequest device) {
    return device.signalIds.any(_seriesById.containsKey);
  }

  /// Bo cache cua device khong con hien va da het han.
  void _evict() {
    final now = DateTime.now();

    final expired = <String>[
      for (final entry in _entries.entries)
        if (!_visible.containsKey(entry.key) &&
            !_inFlight.containsKey(entry.key) &&
            (entry.value.fetchedAt == null ||
                now.difference(entry.value.fetchedAt!) >= refreshInterval))
          entry.key,
    ];

    for (final key in expired) {
      final entry = _entries.remove(key);
      entry?.signalIds.forEach(_seriesById.remove);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    for (final token in _inFlight.values) {
      token.cancel('disposed');
    }
    _inFlight.clear();
    _queue.clear();

    super.dispose();
  }
}

class _DeviceEntry {
  final SparklineLoadState state;
  final List<String> signalIds;
  final DateTime? fetchedAt;

  /// Loi: khong thu lai truoc thoi diem nay.
  final DateTime? retryAfter;

  const _DeviceEntry({
    required this.state,
    required this.signalIds,
    this.fetchedAt,
    this.retryAfter,
  });

  const _DeviceEntry.loading(this.signalIds)
    : state = SparklineLoadState.loading,
      fetchedAt = null,
      retryAfter = null;
}
