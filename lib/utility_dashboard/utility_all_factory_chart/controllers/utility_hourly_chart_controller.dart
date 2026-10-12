import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../api/utility_chart_api.dart';
import '../models/series_history_response.dart';
import '../models/utility_hourly_models.dart';

/// Loi 400 cua backend, [message] lay nguyen van tu response.
class HourlyRequestException implements Exception {
  final String message;

  const HourlyRequestException(this.message);

  @override
  String toString() => message;
}

/// Du lieu da chuan hoa cua mot box cho mot range.
class HourlyBoxData {
  final UtilityHourlyRange range;
  final HourlyWindow window;
  final bool isSnapshot;

  /// Theo plcAddress.
  final Map<String, HourlySignalSeries> signals;

  const HourlyBoxData({
    required this.range,
    required this.window,
    required this.isSnapshot,
    required this.signals,
  });

  /// Gop [base] (phan da co trong cache) voi cac response vua tai
  /// (moi response la mot lo <= 50 PLC).
  factory HourlyBoxData.merge({
    required UtilityHourlyRange range,
    required HourlyWindow window,
    required Map<String, HourlySignalSeries> base,
    required List<SeriesHistoryResponse> responses,
  }) {
    final signals = Map<String, HourlySignalSeries>.of(base);
    var isSnapshot = base.values.any((series) => series.isSnapshot);

    for (final response in responses) {
      if (response.isSnapshot) isSnapshot = true;

      for (final dto in response.signals) {
        final plc = dto.plcAddress.trim();
        if (plc.isEmpty) continue;

        signals[plc] = HourlySignalSeries.fromDto(
          dto,
          isSnapshot: response.isSnapshot,
          windowTo: window.to,
        );
      }
    }

    return HourlyBoxData(
      range: range,
      window: window,
      isSnapshot: isSnapshot,
      signals: Map<String, HourlySignalSeries>.unmodifiable(signals),
    );
  }
}

/// Trang thai bat bien cua mot box: moi thay doi tao object moi de
/// Selector o UI so sanh bang identical.
class HourlyBoxState {
  final HourlyBoxData? data;
  final Object? error;
  final bool loading;

  const HourlyBoxState({this.data, this.error, this.loading = false});

  static const initial = HourlyBoxState();

  /// Dang tai lai trong khi van con chart cu (doi range / poll).
  bool get refreshing => loading && data != null;

  HourlyBoxState copyWith({
    HourlyBoxData? data,
    bool clearData = false,
    Object? error,
    bool clearError = false,
    bool? loading,
  }) {
    return HourlyBoxState(
      data: clearData ? null : (data ?? this.data),
      error: clearError ? null : (error ?? this.error),
      loading: loading ?? this.loading,
    );
  }
}

class _HourlyCacheEntry {
  final DateTime createdAt;
  final HourlyBoxData data;

  const _HourlyCacheEntry({required this.createdAt, required this.data});

  bool isFresh(Duration ttl) => DateTime.now().difference(createdAt) <= ttl;
}

/// Ke hoach tai cua mot box trong mot lan [UtilityHourlyChartController.load].
class _BoxPlan {
  final String box;
  final List<String> plcs;
  final String cacheKey;

  /// Signal lay duoc tu cache (doi Important: chi tai phan con thieu).
  final Map<String, HourlySignalSeries> base;

  /// Thoi diem tao cua phan cache cu nhat dung trong [base]: ban gop het han
  /// cung luc voi phan cu nhat.
  final DateTime? baseCreatedAt;

  /// Cac lo PLC can goi API, moi lo <= [UtilityHourlyChartController.maxPlcsPerRequest].
  final List<List<String>> chunks;

  final List<SeriesHistoryResponse> responses = [];
  int pending;
  bool failed = false;

  _BoxPlan({
    required this.box,
    required this.plcs,
    required this.cacheKey,
    required this.base,
    required this.baseCreatedAt,
    required this.chunks,
  }) : pending = chunks.length;
}

/// Lich su theo gio (bucket=1h) qua GET /api/utility/series/history.
///
/// Moi box device gui plcAddress = PLC cua cac signal catalog dang hien thi
/// (sau filter Important); box > [maxPlcsPerRequest] PLC chia nhieu request
/// roi gop. Toi da [maxConcurrentRequests] request song song; cache
/// [cacheTtl] theo (box, range, danh sach PLC da sort). Khong dung
/// /api/utility/series/hourly (cong gia tri cua moi signal theo gio nen ra so
/// sai).
class UtilityHourlyChartController extends ChangeNotifier {
  static const int maxPlcsPerRequest = 50;

  final UtilityChartApi api;
  final Duration requestTimeout;
  final Duration cacheTtl;
  final int maxConcurrentRequests;

  UtilityHourlyChartController({
    required this.api,
    this.requestTimeout = const Duration(seconds: 15),
    this.cacheTtl = const Duration(seconds: 60),
    this.maxConcurrentRequests = 4,
  }) : assert(maxConcurrentRequests > 0);

  bool _disposed = false;
  bool _notifyScheduled = false;

  UtilityHourlyRange _range = UtilityHourlyRange.today;

  /// Lan load gan nhat: box -> PLC da sort. Dung cho poll / retry.
  Map<String, List<String>> _request = const <String, List<String>>{};

  final Map<String, HourlyBoxState> _boxes = {};
  final Map<String, _HourlyCacheEntry> _cache = {};

  /// Moi request mot token de timeout chi huy dung request do.
  final Set<CancelToken> _inFlight = {};

  /// Tang moi lan load / cancel: response cua lan cu bi bo qua.
  int _generation = 0;

  // ============================================================
  // GETTERS
  // ============================================================

  UtilityHourlyRange get range => _range;

  List<String> get boxDeviceIds => _request.keys.toList(growable: false);

  HourlyBoxState boxState(String boxDeviceId) {
    return _boxes[boxDeviceId.trim()] ?? HourlyBoxState.initial;
  }

  bool get fetching => _boxes.values.any((state) => state.loading);

  // ============================================================
  // COMMANDS
  // ============================================================

  /// Chi doi state; tab se goi [load] khi thay signature doi.
  void changeRange(UtilityHourlyRange range) {
    if (_disposed || _range == range) return;

    _range = range;
    _safeNotify();
  }

  /// Tai du lieu o range hien tai cho [plcsByBox] (box -> PLC dang hien thi).
  ///
  /// - Box khong co PLC nao: khong goi request.
  /// - Cache dung khoa (box, range, PLC) con han: khong goi API.
  /// - Khong [forceRefresh]: PLC da co trong cache con han cua cung
  ///   (box, range) duoc dung lai, chi tai phan con thieu.
  /// - Box dang co chart (range cu / poll) giu chart, chi bat `loading`.
  /// - Request dang chay cua lan truoc bi huy.
  Future<void> load({
    required Map<String, List<String>> plcsByBox,
    bool forceRefresh = false,
  }) async {
    if (_disposed) return;

    final request = _normalizeRequest(plcsByBox);

    _cancelInFlight();
    final generation = ++_generation;

    _request = request;
    _boxes.removeWhere((key, _) => !request.containsKey(key));
    _cache.removeWhere((_, entry) => !entry.isFresh(cacheTtl));

    if (request.isEmpty) {
      _safeNotify();
      return;
    }

    final range = _range;
    final window = range.windowAt(DateTime.now());
    final plans = <_BoxPlan>[];

    for (final MapEntry(key: box, value: plcs) in request.entries) {
      final cacheKey = _cacheKey(box, range, plcs);
      final current = _boxes[box] ?? HourlyBoxState.initial;

      if (forceRefresh) {
        plans.add(_plan(box, plcs, cacheKey, plcs, const {}, null));
        _boxes[box] = current.copyWith(loading: true, clearError: true);
        continue;
      }

      final exact = _cache[cacheKey];
      if (exact != null) {
        _boxes[box] = HourlyBoxState(data: exact.data);
        continue;
      }

      final (:base, :oldest) = _cachedSignals(box, range, plcs);
      final missing = plcs
          .where((plc) => !base.containsKey(plc))
          .toList(growable: false);

      if (missing.isEmpty) {
        // Vd bat Important: tap PLC moi nam tron trong cache.
        final data = HourlyBoxData.merge(
          range: range,
          window: window,
          base: base,
          responses: const [],
        );
        _cache[cacheKey] = _HourlyCacheEntry(createdAt: oldest!, data: data);
        _boxes[box] = HourlyBoxState(data: data);
        continue;
      }

      plans.add(_plan(box, plcs, cacheKey, missing, base, oldest));
      _boxes[box] = current.copyWith(loading: true, clearError: true);
    }

    _safeNotify();

    if (plans.isEmpty) return;

    // Hang doi theo lo: gioi han song song tinh tren request, khong tren box.
    final jobs = <(_BoxPlan, List<String>)>[
      for (final plan in plans)
        for (final chunk in plan.chunks) (plan, chunk),
    ];

    var next = 0;

    Future<void> worker() async {
      while (next < jobs.length && generation == _generation) {
        final (plan, chunk) = jobs[next++];
        if (plan.failed) continue;
        await _fetchChunk(plan, chunk, range, window, generation);
      }
    }

    await Future.wait(
      List.generate(
        math.min(maxConcurrentRequests, jobs.length),
        (_) => worker(),
      ),
    );
  }

  /// Polling 5 phut: lam moi lua chon hien tai, bo qua cache.
  Future<void> poll() async {
    if (_disposed || _request.isEmpty) return;

    await load(plcsByBox: _request, forceRefresh: true);
  }

  /// Retry: box loi khong co cache nen se goi lai, box khac dung cache.
  Future<void> retry() {
    return load(plcsByBox: _request);
  }

  /// Roi tab: huy request dang chay, box dang tai tro ve trang thai truoc do.
  void cancel() {
    if (_disposed) return;

    _cancelInFlight();
    _generation++;

    var changed = false;

    for (final entry in _boxes.entries.toList(growable: false)) {
      if (entry.value.loading) {
        _boxes[entry.key] = entry.value.copyWith(loading: false);
        changed = true;
      }
    }

    if (changed) _safeNotify();
  }

  // ============================================================
  // PLAN
  // ============================================================

  Map<String, List<String>> _normalizeRequest(
    Map<String, List<String>> plcsByBox,
  ) {
    final result = <String, List<String>>{};

    final boxes =
        plcsByBox.keys
            .map((box) => box.trim())
            .where((box) => box.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    for (final box in boxes) {
      final plcs =
          plcsByBox.entries
              .where((entry) => entry.key.trim() == box)
              .expand((entry) => entry.value)
              .map((plc) => plc.trim())
              .where((plc) => plc.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      // Danh sach rong: khong gui request cho device nay.
      if (plcs.isEmpty) continue;

      result[box] = List<String>.unmodifiable(plcs);
    }

    return Map<String, List<String>>.unmodifiable(result);
  }

  _BoxPlan _plan(
    String box,
    List<String> plcs,
    String cacheKey,
    List<String> toFetch,
    Map<String, HourlySignalSeries> base,
    DateTime? baseCreatedAt,
  ) {
    return _BoxPlan(
      box: box,
      plcs: plcs,
      cacheKey: cacheKey,
      base: base,
      baseCreatedAt: baseCreatedAt,
      chunks: [
        for (var start = 0; start < toFetch.length; start += maxPlcsPerRequest)
          toFetch.sublist(
            start,
            math.min(start + maxPlcsPerRequest, toFetch.length),
          ),
      ],
    );
  }

  /// Signal cua [plcs] co san trong cac cache con han cung (box, range).
  ({Map<String, HourlySignalSeries> base, DateTime? oldest}) _cachedSignals(
    String box,
    UtilityHourlyRange range,
    List<String> plcs,
  ) {
    final prefix = _cachePrefix(box, range);
    final wanted = plcs.toSet();
    final base = <String, HourlySignalSeries>{};
    DateTime? oldest;

    // Entry moi hon ghi de entry cu hon.
    final entries =
        _cache.entries
            .where((entry) => entry.key.startsWith(prefix))
            .map((entry) => entry.value)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final entry in entries) {
      var used = false;

      for (final MapEntry(key: plc, value: series)
          in entry.data.signals.entries) {
        if (!wanted.contains(plc)) continue;
        base[plc] = series;
        used = true;
      }

      if (used && (oldest == null || entry.createdAt.isBefore(oldest))) {
        oldest = entry.createdAt;
      }
    }

    return (base: base, oldest: oldest);
  }

  // ============================================================
  // FETCH
  // ============================================================

  Future<void> _fetchChunk(
    _BoxPlan plan,
    List<String> plcs,
    UtilityHourlyRange range,
    HourlyWindow window,
    int generation,
  ) async {
    final box = plan.box;
    final cancelToken = CancelToken();
    _inFlight.add(cancelToken);

    try {
      final response = await api
          .getSeriesHistory(
            boxDeviceId: box,
            plcAddresses: plcs,
            from: window.from,
            to: window.to,
            bucket: '1h',
            cancelToken: cancelToken,
          )
          .timeout(
            requestTimeout,
            onTimeout: () {
              cancelToken.cancel('timeout');
              throw TimeoutException(
                'Hourly request timed out',
                requestTimeout,
              );
            },
          );

      if (!_isCurrent(generation, box) || plan.failed) return;

      plan.responses.add(response);
      plan.pending--;

      if (plan.pending > 0) return;

      // Du cac lo: gop voi phan cache roi ghi mot lan.
      final data = HourlyBoxData.merge(
        range: range,
        window: window,
        base: plan.base,
        responses: plan.responses,
      );

      _cache[plan.cacheKey] = _HourlyCacheEntry(
        createdAt: plan.baseCreatedAt ?? DateTime.now(),
        data: data,
      );

      _boxes[box] = HourlyBoxState(data: data);
      _safeNotify();
    } catch (error, stackTrace) {
      // Huy chu dong (doi lua chon / range / roi tab): khong phai loi.
      // Timeout den day duoi dang TimeoutException nen van bao loi.
      if (error is DioException && CancelToken.isCancel(error)) return;

      if (!_isCurrent(generation, box) || plan.failed) return;

      // Mot lo loi -> ca box loi; cac lo con lai cua box duoc bo qua.
      plan.failed = true;

      debugPrint(
        '[HOURLY ERROR] box=$box range=${range.name} '
        'plcs=${plcs.length} error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);

      final current = _boxes[box] ?? HourlyBoxState.initial;

      // Chart cung range (poll loi) van giu; chart range cu thi bo.
      final keepData = current.data?.range == range;

      _boxes[box] = HourlyBoxState(
        data: keepData ? current.data : null,
        error: _mapError(error),
      );
      _safeNotify();
    } finally {
      _inFlight.remove(cancelToken);
    }
  }

  bool _isCurrent(int generation, String box) {
    return !_disposed && generation == _generation && _boxes.containsKey(box);
  }

  void _cancelInFlight() {
    for (final token in _inFlight.toList(growable: false)) {
      if (!token.isCancelled) token.cancel('superseded');
    }
    _inFlight.clear();
  }

  String _cachePrefix(String box, UtilityHourlyRange range) {
    return '$box|${range.name}|';
  }

  /// [plcs] da sort (xem [_normalizeRequest]).
  String _cacheKey(String box, UtilityHourlyRange range, List<String> plcs) {
    return '${_cachePrefix(box, range)}${plcs.join(',')}';
  }

  /// 400 -> HourlyRequestException kem message cua backend.
  static Object _mapError(Object error) {
    if (error is! DioException || error.response?.statusCode != 400) {
      return error;
    }

    final data = error.response?.data;
    String? message;

    if (data is Map) {
      message = (data['message'] ?? data['error'] ?? data['detail'])
          ?.toString();
    } else if (data is String) {
      message = data;
    }

    final text = message?.trim() ?? '';

    return HourlyRequestException(
      text.isEmpty ? 'Invalid hourly request (HTTP 400).' : text,
    );
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

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _generation++;
    _cancelInFlight();

    super.dispose();
  }
}
