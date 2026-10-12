import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../api/signal_history_repository.dart';
import '../models/signal_history_models.dart';
import 'filter_sparkline_controller.dart';
import 'signal_history_controller.dart';

enum FilterChartLoadState { loading, ready, error }

/// Che do Chart cua Filter results: lich su cua MOI device khop filter
/// (toi da [maxDevices]) cho range dang chon.
///
/// - 1h: dung lai cache cua [FilterSparklineController]; chi tai device thieu.
/// - Range khac: 1 request series/history moi device (bucket theo
///   HistoryRange.requestBucket, cua so theo HistoryRange.windowEndingAt),
///   toi da [maxConcurrent] song song, timeout [requestTimeout].
/// - Cache theo (device, range) [cacheTtl]: doi range qua lai trong khoang
///   nay khong tai lai. Device dang hien lien tuc duoc lam moi moi
///   [FilterSparklineController.refreshInterval].
/// - Doi range / filter / ve Table: huy request khong con can (CancelToken).
/// - Device loi chi danh dau loi rieng no, khong lam hong ca nhom.
class FilterChartController extends ChangeNotifier {
  final SignalHistoryRepository repository;
  final FilterSparklineController sparklines;

  FilterChartController({required this.repository, required this.sparklines});

  static const int maxDevices = 30;
  static const int maxConcurrent = 4;
  static const Duration requestTimeout = Duration(seconds: 15);
  static const Duration cacheTtl = Duration(seconds: 60);

  static const Duration _refreshCheck = Duration(seconds: 30);

  bool _disposed = false;
  bool _notifyScheduled = false;

  CatalogDetailViewMode _viewMode = CatalogDetailViewMode.table;
  HistoryRange _range = HistoryRange.h1;

  /// Range cuoi cung da tai xong cho tap device hien tai (de giu chart cu,
  /// lam mo, trong luc tai range moi).
  HistoryRange? _shownRange;

  Map<String, SparklineDeviceRequest> _devices =
      <String, SparklineDeviceRequest>{};

  /// Cac (device, range) dang hien lien tuc tu lan sync truoc.
  final Set<String> _activeKeys = <String>{};

  final Map<String, _Entry> _entries = <String, _Entry>{};
  final Queue<_Job> _queue = Queue<_Job>();
  final Map<String, CancelToken> _inFlight = <String, CancelToken>{};

  Timer? _refreshTimer;
  int _requestCount = 0;

  // ============================================================
  // READ
  // ============================================================

  CatalogDetailViewMode get viewMode => _viewMode;

  HistoryRange get range => _range;

  /// Range de VE: range dang chon neu da tai xong, nguoc lai range truoc do
  /// (chart cu lam mo) hoac range dang chon neu chua tung tai.
  HistoryRange get displayRange {
    if (_shownRange == null || _isComplete(_range)) return _range;
    return _shownRange!;
  }

  /// Dang tai range moi trong khi van hien chart cua range cu.
  bool get switching => displayRange != _range;

  /// Con request / hang doi cho range dang chon.
  bool get loading => !_isComplete(_range);

  SignalHistorySeries? seriesFor(String deviceKey, String signalId) {
    return _entries[_key(deviceKey, displayRange)]?.series[signalId];
  }

  FilterChartLoadState? stateOf(String deviceKey) {
    return _entries[_key(deviceKey, displayRange)]?.state;
  }

  // ============================================================
  // VIEW STATE
  // ============================================================

  void setViewMode(CatalogDetailViewMode mode) {
    if (_disposed || mode == _viewMode) return;

    _viewMode = mode;

    if (mode == CatalogDetailViewMode.table) {
      // Ve Table: huy moi request chart, dung lam moi.
      _cancelWhere((_) => true);
      _queue.clear();
      _activeKeys.clear();
      _stopTimer();
    } else {
      _enqueue();
      _ensureTimer();
    }

    _safeNotify();
  }

  void setRange(HistoryRange range) {
    if (_disposed || range == _range) return;

    if (_isComplete(_range)) _shownRange = _range;

    _range = range;

    // Request cua range cu khong con can.
    _cancelWhere((key) => !key.endsWith('#${range.name}'));
    _queue.removeWhere((job) => job.range != range);
    _activeKeys.clear();

    _enqueue();
    _safeNotify();
  }

  // ============================================================
  // SYNC
  // ============================================================

  /// [devices]: moi device khop filter (da gioi han <= [maxDevices]).
  void sync(List<SparklineDeviceRequest> devices) {
    if (_disposed) return;

    _devices = {for (final device in devices) device.deviceKey: device};

    // Device khong con khop filter: huy request, bo khoi hang doi.
    _cancelWhere((key) => !_devices.containsKey(_deviceOf(key)));
    _queue.removeWhere((job) => !_devices.containsKey(job.device.deviceKey));

    _activeKeys.removeWhere((key) => !_devices.containsKey(_deviceOf(key)));

    _enqueue();
    _ensureTimer();
  }

  void _enqueue() {
    if (_viewMode != CatalogDetailViewMode.chart) return;

    final now = DateTime.now();
    var changed = false;

    for (final device in _devices.values) {
      final key = _key(device.deviceKey, _range);

      if (_inFlight.containsKey(key)) continue;
      if (_queue.any((job) => job.key == key)) continue;

      final entry = _entries[key];

      // 1h: lay tu cache sparkline neu du moi signal cua device.
      if (_range == HistoryRange.h1 &&
          (entry == null || entry.state != FilterChartLoadState.ready)) {
        final cached = _fromSparklines(device);
        if (cached != null) {
          _entries[key] = cached;
          _activeKeys.add(key);
          changed = true;
          continue;
        }
      }

      if (!_needsLoad(key, device, entry, now)) {
        _activeKeys.add(key);
        continue;
      }

      _queue.add(_Job(device, _range));

      if (entry == null || entry.state == FilterChartLoadState.error) {
        _entries[key] = _Entry.loading(device.signalIds);
        changed = true;
      }
    }

    _pump();

    if (changed) _safeNotify();
  }

  _Entry? _fromSparklines(SparklineDeviceRequest device) {
    final series = <String, SignalHistorySeries>{};

    for (final id in device.signalIds) {
      final item = sparklines.seriesFor(id);
      if (item == null) return null;
      series[id] = item;
    }

    return _Entry(
      state: FilterChartLoadState.ready,
      signalIds: device.signalIds,
      series: series,
      fetchedAt: DateTime.now(),
    );
  }

  bool _needsLoad(
    String key,
    SparklineDeviceRequest device,
    _Entry? entry,
    DateTime now,
  ) {
    if (entry == null) return true;
    if (!listEquals(entry.signalIds, device.signalIds)) return true;
    if (entry.state == FilterChartLoadState.loading) return true;

    final retryAfter = entry.retryAfter;
    if (retryAfter != null && now.isBefore(retryAfter)) return false;

    final fetchedAt = entry.fetchedAt;
    if (fetchedAt == null) return true;

    final age = now.difference(fetchedAt);

    // Dang hien lien tuc: lam moi theo chu ky dai. Quay lai sau khi doi
    // range / filter: dung cache trong [cacheTtl].
    return _activeKeys.contains(key)
        ? age >= FilterSparklineController.refreshInterval
        : age >= cacheTtl;
  }

  void _pump() {
    while (_inFlight.length < maxConcurrent && _queue.isNotEmpty) {
      final job = _queue.removeFirst();

      if (job.range != _range || !_devices.containsKey(job.device.deviceKey)) {
        continue;
      }

      unawaited(_fetch(job));
    }
  }

  Future<void> _fetch(_Job job) async {
    final key = job.key;
    final token = CancelToken();
    _inFlight[key] = token;

    final window = job.range.windowEndingAt(DateTime.now());

    _requestCount++;
    if (kDebugMode) {
      debugPrint(
        '[FILTER CHART] request #$_requestCount device=${job.device.deviceKey} '
        'range=${job.range.label} bucket=${job.range.requestBucket}',
      );
    }

    try {
      final result = await repository
          .fetchHistory(
            signalIds: job.device.signalIds,
            from: window.from,
            to: window.to,
            bucket: job.range.requestBucket,
            cancelToken: token,
          )
          .timeout(requestTimeout);

      if (_disposed || !identical(_inFlight[key], token)) return;

      _entries[key] = _Entry(
        state: FilterChartLoadState.ready,
        signalIds: job.device.signalIds,
        series: {for (final series in result.series) series.signalId: series},
        fetchedAt: DateTime.now(),
      );
    } catch (error) {
      if (_disposed || !identical(_inFlight[key], token)) return;

      if (error is TimeoutException) token.cancel('timeout');

      final previous = _entries[key];
      final keepOld =
          previous != null &&
          previous.state == FilterChartLoadState.ready &&
          previous.series.isNotEmpty;

      // Lam moi loi: giu chart cu. Lan dau loi: danh dau loi rieng device.
      _entries[key] = _Entry(
        state: keepOld ? FilterChartLoadState.ready : FilterChartLoadState.error,
        signalIds: job.device.signalIds,
        series: keepOld ? previous.series : const <String, SignalHistorySeries>{},
        fetchedAt: keepOld ? previous.fetchedAt : null,
        retryAfter: DateTime.now().add(_refreshCheck),
      );

      debugPrint('[FILTER CHART ERROR] device=${job.device.deviceKey} error=$error');
    } finally {
      if (!_disposed && identical(_inFlight[key], token)) {
        _inFlight.remove(key);
        _activeKeys.add(key);

        if (job.range == _range && _isComplete(_range)) {
          _shownRange = _range;
        }

        _safeNotify();
        _pump();
      }
    }
  }

  bool _isComplete(HistoryRange range) {
    for (final device in _devices.values) {
      final key = _key(device.deviceKey, range);

      if (_inFlight.containsKey(key)) return false;
      if (_queue.any((job) => job.key == key)) return false;

      final state = _entries[key]?.state;
      if (state == null || state == FilterChartLoadState.loading) return false;
    }

    return true;
  }

  void _cancelWhere(bool Function(String key) test) {
    for (final key in _inFlight.keys.toList()) {
      if (!test(key)) continue;

      _inFlight.remove(key)?.cancel('no longer needed');

      if (_entries[key]?.state == FilterChartLoadState.loading) {
        _entries.remove(key);
      }
    }
  }

  void _ensureTimer() {
    if (_viewMode != CatalogDetailViewMode.chart || _devices.isEmpty) {
      _stopTimer();
      return;
    }

    _refreshTimer ??= Timer.periodic(_refreshCheck, (_) {
      if (_disposed) return;
      _evict();
      _enqueue();
    });
  }

  void _stopTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Bo cache het han cua (device, range) khong con dang hien.
  void _evict() {
    final now = DateTime.now();

    _entries.removeWhere((key, entry) {
      if (_inFlight.containsKey(key) || _activeKeys.contains(key)) {
        return false;
      }

      final fetchedAt = entry.fetchedAt;
      return fetchedAt == null || now.difference(fetchedAt) >= cacheTtl;
    });
  }

  static String _key(String deviceKey, HistoryRange range) {
    return '$deviceKey#${range.name}';
  }

  /// deviceKey cua khoa cache (cat o '#' cuoi, ten range khong chua '#').
  static String _deviceOf(String key) {
    return key.substring(0, key.lastIndexOf('#'));
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

    if (_notifyScheduled) return;
    _notifyScheduled = true;

    binding.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (_disposed) return;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _stopTimer();

    for (final token in _inFlight.values) {
      token.cancel('disposed');
    }
    _inFlight.clear();
    _queue.clear();

    super.dispose();
  }
}

class _Job {
  final SparklineDeviceRequest device;
  final HistoryRange range;

  const _Job(this.device, this.range);

  String get key => '${device.deviceKey}#${range.name}';
}

class _Entry {
  final FilterChartLoadState state;
  final List<String> signalIds;
  final Map<String, SignalHistorySeries> series;
  final DateTime? fetchedAt;
  final DateTime? retryAfter;

  const _Entry({
    required this.state,
    required this.signalIds,
    required this.series,
    this.fetchedAt,
    this.retryAfter,
  });

  const _Entry.loading(this.signalIds)
    : state = FilterChartLoadState.loading,
      series = const <String, SignalHistorySeries>{},
      fetchedAt = null,
      retryAfter = null;
}
