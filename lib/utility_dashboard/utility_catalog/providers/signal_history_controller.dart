import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../shared/state/safe_change_notifier.dart';
import '../api/signal_history_repository.dart';
import '../models/signal_history_models.dart';

enum CatalogDetailViewMode { table, chart }

/// Cach xep the o che do Chart: gop signal cung (code, unit) vao mot the,
/// hoac moi signal mot the gon.
enum CatalogChartLayout { merge, split }

/// State cua che do Chart trong panel chi tiet thiet bi.
///
/// Khong con reload theo LatestProvider.dataVersion. View (SignalChartView)
/// dang ky mot task PollingCoordinator goi [refresh] theo chu ky cua range
/// ([autoRefreshInterval]); task thuoc scope scadaTable nen chi chay khi
/// panel o Chart mode, tab SCADA TABLE dang hien va khong bi route khac che.
///
/// Trang thai tai (xem [initialLoading], [switching], [refreshing]):
/// - lan tai dau cua device, chua co gi de hien: skeleton;
/// - doi range: giu chart cu (lam mo) + progress bar, khong ve skeleton;
/// - polling / refresh cung range: tai ngam, chart giu nguyen.
class SignalHistoryController extends ChangeNotifier with SafeChangeNotifier {
  final SignalHistoryRepository repository;

  SignalHistoryController({required this.repository});

  /// Qua thoi gian nay ma chua co response: huy request, hien error state.
  static const Duration requestTimeout = Duration(seconds: 15);

  /// Chu ky tu lam moi cua chart theo range.
  static Duration autoRefreshInterval(HistoryRange range) {
    return switch (range) {
      HistoryRange.h1 => const Duration(minutes: 1),
      HistoryRange.h6 => const Duration(minutes: 2),
      HistoryRange.h24 || HistoryRange.d7 => const Duration(minutes: 5),
    };
  }

  /// Cache theo (device, range) trong phien: quay lai range da xem trong
  /// khoang nay thi hien ngay, roi lam moi ngam (stale-while-revalidate).
  static const Duration cacheTtl = Duration(seconds: 60);
  static const int _cacheCapacity = 24;

  bool _disposed = false;

  int _requestId = 0;

  /// Request dang chay (null = khong co). Doi device / range thi huy.
  CancelToken? _cancelToken;

  CatalogDetailViewMode _viewMode = CatalogDetailViewMode.table;

  /// Giu trong phien (controller song cung dashboard).
  CatalogChartLayout _chartLayout = CatalogChartLayout.merge;

  HistoryRange _range = HistoryRange.h1;

  // Target dang duoc view yeu cau.
  String? _deviceKey;
  List<String> _signalIds = const <String>[];

  /// Key (device + range + signals) cua data DANG HIEN THI.
  String? _displayedKey;

  List<SignalHistorySeries> _series = const <SignalHistorySeries>[];
  HistoryAggregation? _aggregation;

  /// Range cua data dang hien thi (null = chua co). Co the khac
  /// [range] trong luc dang doi range.
  HistoryRange? _displayedRange;

  Object? _error;

  final Map<String, _CacheEntry> _cache = <String, _CacheEntry>{};

  // ============================================================
  // GETTERS
  // ============================================================

  CatalogDetailViewMode get viewMode => _viewMode;

  CatalogChartLayout get chartLayout => _chartLayout;

  HistoryRange get range => _range;

  List<SignalHistorySeries> get series => _series;

  List<SignalHistorySeries>? _indexedSeries;
  Map<String, SignalHistorySeries> _seriesById = const {};

  /// Series cua mot signal trong [series] dang hien (null = khong co).
  /// Cho phep moi the chart chi lang nghe du lieu cua chinh no.
  SignalHistorySeries? seriesById(String signalId) {
    if (!identical(_indexedSeries, _series)) {
      _indexedSeries = _series;
      _seriesById = {for (final item in _series) item.signalId: item};
    }

    return _seriesById[signalId];
  }

  /// Cach gop diem cua [series] dang hien thi; null khi chua co ket qua.
  HistoryAggregation? get aggregation => _aggregation;

  /// Range cua [series] dang hien thi, quyet dinh kieu chart (line / cot).
  HistoryRange? get displayedRange => _displayedRange;

  Object? get error => _error;

  bool get hasData => _series.isNotEmpty;

  String? get deviceKey => _deviceKey;

  /// Co request dang chay.
  bool get fetching => _cancelToken != null;

  /// Data dang hien thi dung la cua device + range dang chon.
  bool get showingCurrent => _displayedKey != null && _displayedKey == _dataKey;

  /// Chua co gi de hien va dang tai: skeleton.
  bool get initialLoading => fetching && !hasData;

  /// Dang tai range moi, tam hien chart cua range truoc (lam mo).
  bool get switching => fetching && hasData && !showingCurrent;

  /// Dang lam moi ngam data cua chinh range dang hien.
  bool get refreshing => fetching && hasData && showingCurrent;

  // ============================================================
  // VIEW STATE
  // ============================================================

  void setViewMode(CatalogDetailViewMode mode) {
    if (_disposed || mode == _viewMode) return;

    _viewMode = mode;
    safeNotify();

    _loadIfNeeded();
  }

  /// Chi doi cach hien thi, khong tai lai du lieu.
  void setChartLayout(CatalogChartLayout layout) {
    if (_disposed || layout == _chartLayout) return;

    _chartLayout = layout;
    safeNotify();
  }

  void setRange(HistoryRange range) {
    if (_disposed) return;
    if (range == _range) return;

    _range = range;
    safeNotify();

    _loadIfNeeded();
  }

  // ============================================================
  // BINDING
  // ============================================================

  /// Goi tu view moi khi device dang chon (hoac tap signal) thay doi.
  void bind({required String deviceKey, required List<String> signalIds}) {
    if (_disposed) return;

    final sameDevice =
        deviceKey == _deviceKey && _sameIds(signalIds, _signalIds);

    if (sameDevice) return;

    _deviceKey = deviceKey;
    _signalIds = List<String>.unmodifiable(signalIds);

    _loadIfNeeded();
  }

  Future<void> retry() => _load();

  /// Lam moi ngam data dang hien (polling theo range). Request truoc chua
  /// xong thi bo qua luot nay, khong chay chong.
  Future<void> refresh() async {
    if (_disposed || _viewMode != CatalogDetailViewMode.chart) return;
    if (_dataKey == null) return;

    if (fetching) {
      if (kDebugMode) debugPrint('[SIGNAL HISTORY] skip refresh (in flight)');
      return;
    }

    await _load();
  }

  // ============================================================
  // LOAD
  // ============================================================

  String? get _dataKey {
    final device = _deviceKey;
    if (device == null) return null;

    return '$device#${_range.name}#${_signalIds.join(',')}';
  }

  void _loadIfNeeded() {
    if (_viewMode != CatalogDetailViewMode.chart) return;

    final key = _dataKey;
    if (key == null) return;

    // Da hien dung data nay va con moi: lam moi la viec cua [refresh].
    // Quay lai Chart sau mot luc (data cu hon chu ky) thi tai lai ngay.
    if (key == _displayedKey && !_isDisplayStale(key)) return;

    _load();
  }

  bool _isDisplayStale(String key) {
    final fetchedAt = _cache[key]?.fetchedAt;
    if (fetchedAt == null) return true;

    return DateTime.now().difference(fetchedAt) >= autoRefreshInterval(_range);
  }

  String get _rangeLabel => _range.label;

  HistoryWindow _resolveWindow() {
    // 7d can 00:00 cua 6 ngay truoc (xem HistoryRange.windowEndingAt).
    return _range.windowEndingAt(DateTime.now());
  }

  Future<void> _load() async {
    if (_disposed) return;

    final key = _dataKey;
    if (key == null) return;

    final ids = _signalIds;
    final window = _resolveWindow();
    final range = _range;
    final bucket = range.requestBucket;

    final requestId = ++_requestId;

    // Huy request cu (range / device truoc) de khong ton bang thong.
    _cancelToken?.cancel('superseded by request #$requestId');
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    _prepareDisplay(key);

    _error = null;
    safeNotify();

    if (ids.isEmpty) {
      _showResult(
        key,
        const SignalHistoryResult(
          series: <SignalHistorySeries>[],
          source: DataSource.api,
        ),
        range,
      );
      _finish(requestId);
      return;
    }

    final stopwatch = Stopwatch()..start();

    if (kDebugMode) {
      debugPrint(
        '[SIGNAL HISTORY] #$requestId start device=$_deviceKey '
        'range=$_rangeLabel bucket=$bucket signals=${ids.length}',
      );
    }

    try {
      final result = await repository
          .fetchHistory(
            signalIds: ids,
            from: window.from,
            to: window.to,
            bucket: bucket,
            cancelToken: cancelToken,
          )
          .timeout(requestTimeout);

      // Response cua device / range cu ve muon: bo qua.
      if (!_isCurrent(requestId)) return;

      _showResult(key, result, range);
      _cache[key] = _CacheEntry(result, range, DateTime.now());
      _trimCache();

      if (kDebugMode) {
        final points = result.series.fold<int>(
          0,
          (total, series) => total + series.points.length,
        );

        debugPrint(
          '[SIGNAL HISTORY] #$requestId done device=$_deviceKey '
          'range=$_rangeLabel source=${result.source.name} '
          'aggregation=${result.aggregation.name} '
          'bucket=${result.bucket?.inMinutes ?? '?'}m '
          'series=${result.series.length} points=$points '
          'elapsed=${stopwatch.elapsedMilliseconds}ms',
        );
      }
    } catch (error, stackTrace) {
      if (!_isCurrent(requestId)) return;

      if (error is TimeoutException) {
        cancelToken.cancel('timeout after ${requestTimeout.inSeconds}s');
      }

      _error = error;

      /*
       * Loi khi lam moi CUNG range: giu chart dang co + icon canh bao.
       * Loi khi doi sang range / device KHAC: khong de chart cua range cu
       * dung ten range moi -> xoa de UI hien error state + Retry.
       */
      if (!showingCurrent) _clearDisplay();

      debugPrint(
        '[SIGNAL HISTORY CHART ERROR] #$requestId device=$_deviceKey '
        'range=$_rangeLabel elapsed=${stopwatch.elapsedMilliseconds}ms '
        'error=$error',
      );
      if (error is! TimeoutException) {
        debugPrintStack(stackTrace: stackTrace);
      }
    } finally {
      _finish(requestId);
    }
  }

  /// Chuan bi noi dung hien thi truoc khi request chay.
  void _prepareDisplay(String key) {
    // Quay lai (device, range) da xem gan day: hien ngay ban cache.
    final cached = _cache[key];

    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) <= cacheTtl &&
        _displayedKey != key) {
      // Request nay van chay de lam moi ngam.
      _showResult(key, cached.result, cached.range);
      return;
    }

    // Doi device: khong bao gio hien data cua device truoc.
    if (_displayedKey != null && _deviceOf(_displayedKey!) != _deviceOf(key)) {
      _clearDisplay();
    }

    // Cung device, khac range: giu chart cu (view lam mo + progress bar).
  }

  void _showResult(
    String key,
    SignalHistoryResult result,
    HistoryRange? range,
  ) {
    _series = result.series;
    _aggregation = result.aggregation;
    _displayedRange = range;
    _displayedKey = key;
  }

  void _clearDisplay() {
    _series = const <SignalHistorySeries>[];
    _aggregation = null;
    _displayedRange = null;
    _displayedKey = null;
  }

  void _finish(int requestId) {
    if (!_isCurrent(requestId)) return;

    _cancelToken = null;
    safeNotify();
  }

  void _trimCache() {
    final now = DateTime.now();

    _cache.removeWhere(
      (_, entry) => now.difference(entry.fetchedAt) > cacheTtl,
    );

    while (_cache.length > _cacheCapacity) {
      _cache.remove(_cache.keys.first);
    }
  }

  static String _deviceOf(String key) => key.split('#').first;

  bool _isCurrent(int requestId) => !_disposed && requestId == _requestId;

  static bool _sameIds(List<String> first, List<String> second) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;

    for (var i = 0; i < first.length; i++) {
      if (first[i] != second[i]) return false;
    }

    return true;
  }

  @override
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _requestId++;

    _cancelToken?.cancel('disposed');
    _cancelToken = null;

    super.dispose();
  }
}

class _CacheEntry {
  final SignalHistoryResult result;
  final HistoryRange? range;
  final DateTime fetchedAt;

  const _CacheEntry(this.result, this.range, this.fetchedAt);
}
