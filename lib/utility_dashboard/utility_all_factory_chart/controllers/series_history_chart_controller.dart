import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../shared/state/safe_change_notifier.dart';
import '../../utility_catalog/api/signal_history_repository.dart';
import '../../utility_catalog/models/signal_history_models.dart';
import '../models/series_history_response.dart';

// ============================================================
// STATE
// ============================================================

/// Du lieu cua mot box cho mot cua so thoi gian.
class SeriesBoxData<T> {
  /// Dinh danh cua so luc tai (range / thang): doi tag thi du lieu cu khong
  /// con dung loai.
  final String tag;
  final HistoryWindow window;

  /// Theo plcAddress.
  final Map<String, T> signals;

  const SeriesBoxData({
    required this.tag,
    required this.window,
    required this.signals,
  });
}

/// Trang thai bat bien cua mot box: moi thay doi tao object moi de
/// Selector o UI so sanh bang identical.
class SeriesBoxState<T> {
  final SeriesBoxData<T>? data;
  final Object? error;
  final bool loading;

  /// Lan goi API gan nhat thanh cong / loi (suc khoe polling).
  final DateTime? lastOkAt;
  final DateTime? lastErrAt;

  const SeriesBoxState({
    this.data,
    this.error,
    this.loading = false,
    this.lastOkAt,
    this.lastErrAt,
  });

  /// Dang tai lai trong khi van con chart cu (doi range / poll).
  bool get refreshing => loading && data != null;

  SeriesBoxState<T> copyWith({
    SeriesBoxData<T>? data,
    bool clearData = false,
    Object? error,
    bool clearError = false,
    bool? loading,
    DateTime? lastOkAt,
    DateTime? lastErrAt,
  }) {
    return SeriesBoxState<T>(
      data: clearData ? null : (data ?? this.data),
      error: clearError ? null : (error ?? this.error),
      loading: loading ?? this.loading,
      lastOkAt: lastOkAt ?? this.lastOkAt,
      lastErrAt: lastErrAt ?? this.lastErrAt,
    );
  }
}

// ============================================================
// BATCH
// ============================================================

/// Mot request `/series/history`: nhieu box cung danh sach PLC hop.
class SeriesRequestBatch {
  final List<String> boxes;

  /// Hop PLC cua moi box trong lo (gui len API).
  final List<String> plcs;

  /// box -> PLC can lay cho box do trong lo nay (de loc response).
  final Map<String, Set<String>> wanted;

  const SeriesRequestBatch({
    required this.boxes,
    required this.plcs,
    required this.wanted,
  });

  int get signalCount =>
      wanted.values.fold<int>(0, (sum, plcs) => sum + plcs.length);
}

/// Chia (box -> PLC) thanh cac lo: moi lo <= [maxBoxes] box va <=
/// [maxSignals] cap (box, plc). Box co > [maxSignals] PLC duoc tach thanh
/// nhieu lo rieng. Giu thu tu box / PLC dau vao.
List<SeriesRequestBatch> planSeriesBatches(
  Map<String, List<String>> plcsByBox, {
  int maxBoxes = 30,
  int maxSignals = 300,
}) {
  assert(maxBoxes > 0 && maxSignals > 0);

  final batches = <SeriesRequestBatch>[];
  var current = <String, List<String>>{};
  var currentSignals = 0;

  void flush() {
    if (current.isEmpty) return;

    final plcs = <String>{
      for (final list in current.values) ...list,
    }.toList()..sort();

    batches.add(
      SeriesRequestBatch(
        boxes: List<String>.unmodifiable(current.keys),
        plcs: List<String>.unmodifiable(plcs),
        wanted: {
          for (final MapEntry(key: box, value: list) in current.entries)
            box: list.toSet(),
        },
      ),
    );

    current = <String, List<String>>{};
    currentSignals = 0;
  }

  for (final MapEntry(key: box, value: plcs) in plcsByBox.entries) {
    if (plcs.isEmpty) continue;

    // Box qua lon: moi phan mot lo rieng.
    if (plcs.length > maxSignals) {
      flush();
      for (var start = 0; start < plcs.length; start += maxSignals) {
        current[box] = plcs.sublist(
          start,
          math.min(start + maxSignals, plcs.length),
        );
        flush();
      }
      continue;
    }

    if (current.length >= maxBoxes ||
        currentSignals + plcs.length > maxSignals) {
      flush();
    }

    current[box] = plcs;
    currentSignals += plcs.length;
  }

  flush();
  return batches;
}

// ============================================================
// CONTROLLER
// ============================================================

class _CacheEntry<T> {
  final DateTime createdAt;
  final SeriesBoxData<T> data;

  const _CacheEntry({required this.createdAt, required this.data});

  bool isFresh(Duration ttl) => DateTime.now().difference(createdAt) <= ttl;
}

/// Ke hoach tai cua mot box trong mot lan [SeriesHistoryChartController.load].
class _BoxPlan<T> {
  final String box;
  final String cacheKey;

  /// Signal lay duoc tu cache (doi Important: chi tai phan con thieu).
  final Map<String, T> base;

  /// Thoi diem tao cua phan cache cu nhat dung trong [base]: ban gop het han
  /// cung luc voi phan cu nhat.
  final DateTime? baseCreatedAt;

  final Map<String, T> fetched = {};

  /// So lo chua xong co chua box nay.
  int pending = 0;
  bool failed = false;

  _BoxPlan({
    required this.box,
    required this.cacheKey,
    required this.base,
    required this.baseCreatedAt,
  });
}

/// Lich su theo bucket cho cac the cua tab Minutes / Hourly / Daily qua
/// [SignalHistoryRepository] (cache + dedupe dung chung voi SCADA TABLE).
///
/// Moi lan [load] gom moi box dang hien thi vao it request nhat co the:
/// mot request chua nhieu box (`boxDeviceId` CSV), chia lo khi > [maxBoxes]
/// box hoac > [maxSignals] signal. Toi da [maxConcurrentRequests] request
/// song song; cache [cacheTtl] theo (tag, box, danh sach PLC da sort).
///
/// Lop con quyet dinh cua so ([windowAt] / [windowTag]), [bucket] va cach
/// chuan hoa mot signal ([convert]).
abstract class SeriesHistoryChartController<T> extends ChangeNotifier
    with SafeChangeNotifier {
  final SignalHistoryRepository repository;
  final Duration requestTimeout;
  final Duration cacheTtl;
  final int maxConcurrentRequests;
  final int maxBoxes;
  final int maxSignals;

  SeriesHistoryChartController({
    required this.repository,
    this.requestTimeout = const Duration(seconds: 15),
    this.cacheTtl = const Duration(seconds: 60),
    this.maxConcurrentRequests = 4,
    this.maxBoxes = 30,
    this.maxSignals = 300,
  }) : assert(maxConcurrentRequests > 0);

  /// Tham so `bucket` gui len API.
  String get bucket;

  /// Dinh danh cua so hien tai (vd range); dung lam khoa cache.
  String get windowTag;

  HistoryWindow windowAt(DateTime now);

  T convert(
    SeriesHistorySignalDto dto,
    SeriesHistoryResponse response,
    HistoryWindow window,
  );

  /// Ten trong log debug.
  String get debugLabel;

  bool _disposed = false;

  /// Lan load gan nhat: box -> PLC da sort. Dung cho poll / retry.
  Map<String, List<String>> _request = const <String, List<String>>{};

  final Map<String, SeriesBoxState<T>> _boxes = {};
  final Map<String, _CacheEntry<T>> _cache = {};

  /// Moi request mot token de timeout chi huy dung request do.
  final Set<CancelToken> _inFlight = {};

  /// Tang moi lan load / cancel: response cua lan cu bi bo qua.
  int _generation = 0;

  // ============================================================
  // GETTERS
  // ============================================================

  List<String> get boxDeviceIds => _request.keys.toList(growable: false);

  SeriesBoxState<T> boxState(String boxDeviceId) {
    return _boxes[boxDeviceId.trim()] ?? SeriesBoxState<T>();
  }

  bool get fetching => _boxes.values.any((state) => state.loading);

  bool get hasData => _boxes.values.any((state) => state.data != null);

  // ============================================================
  // COMMANDS
  // ============================================================

  /// Tai du lieu cua so hien tai cho [plcsByBox] (box -> PLC dang hien thi).
  ///
  /// - Box khong co PLC nao: khong goi request.
  /// - Cache dung khoa (tag, box, PLC) con han: khong goi API.
  /// - Khong [forceRefresh]: PLC da co trong cache con han cua cung
  ///   (tag, box) duoc dung lai, chi tai phan con thieu.
  /// - Box dang co chart (cua so cu / poll) giu chart, chi bat `loading`.
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
      safeNotify();
      return;
    }

    final tag = windowTag;
    final window = windowAt(DateTime.now());

    final plans = <String, _BoxPlan<T>>{};
    final missingByBox = <String, List<String>>{};

    for (final MapEntry(key: box, value: plcs) in request.entries) {
      final cacheKey = _cacheKey(tag, box, plcs);
      final current = _boxes[box] ?? SeriesBoxState<T>();

      if (forceRefresh) {
        plans[box] = _BoxPlan<T>(
          box: box,
          cacheKey: cacheKey,
          base: const {},
          baseCreatedAt: null,
        );
        missingByBox[box] = plcs;
        _boxes[box] = current.copyWith(loading: true, clearError: true);
        continue;
      }

      final exact = _cache[cacheKey];
      if (exact != null) {
        _boxes[box] = current.copyWith(
          data: exact.data,
          clearError: true,
          loading: false,
        );
        continue;
      }

      final (:base, :oldest) = _cachedSignals(tag, box, plcs);
      final missing = plcs
          .where((plc) => !base.containsKey(plc))
          .toList(growable: false);

      if (missing.isEmpty) {
        // Vd bat Important: tap PLC moi nam tron trong cache.
        final data = SeriesBoxData<T>(
          tag: tag,
          window: window,
          signals: Map<String, T>.unmodifiable(base),
        );
        _cache[cacheKey] = _CacheEntry<T>(createdAt: oldest!, data: data);
        _boxes[box] = current.copyWith(
          data: data,
          clearError: true,
          loading: false,
        );
        continue;
      }

      plans[box] = _BoxPlan<T>(
        box: box,
        cacheKey: cacheKey,
        base: base,
        baseCreatedAt: oldest,
      );
      missingByBox[box] = missing;
      _boxes[box] = current.copyWith(loading: true, clearError: true);
    }

    safeNotify();

    if (plans.isEmpty) return;

    final batches = planSeriesBatches(
      missingByBox,
      maxBoxes: maxBoxes,
      maxSignals: maxSignals,
    );

    for (final batch in batches) {
      for (final box in batch.boxes) {
        plans[box]!.pending++;
      }
    }

    if (kDebugMode) {
      debugPrint(
        '[$debugLabel] load boxes=${missingByBox.length} '
        'signals=${batches.fold<int>(0, (n, b) => n + b.signalCount)} '
        'requests=${batches.length} force=$forceRefresh',
      );
    }

    var next = 0;

    Future<void> worker() async {
      while (next < batches.length && generation == _generation) {
        final batch = batches[next++];
        await _fetchBatch(batch, plans, tag, window, forceRefresh, generation);
      }
    }

    await Future.wait(
      List.generate(
        math.min(maxConcurrentRequests, batches.length),
        (_) => worker(),
      ),
    );
  }

  /// Polling: lam moi lua chon hien tai, bo qua cache.
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

    if (changed) safeNotify();
  }

  // ============================================================
  // PLAN
  // ============================================================

  Map<String, List<String>> _normalizeRequest(
    Map<String, List<String>> plcsByBox,
  ) {
    final merged = <String, Set<String>>{};

    for (final MapEntry(key: rawBox, value: rawPlcs) in plcsByBox.entries) {
      final box = rawBox.trim();
      if (box.isEmpty) continue;

      final plcs = merged.putIfAbsent(box, () => <String>{});
      for (final plc in rawPlcs) {
        final value = plc.trim();
        if (value.isNotEmpty) plcs.add(value);
      }
    }

    final boxes = merged.keys.toList()..sort();

    return Map<String, List<String>>.unmodifiable({
      for (final box in boxes)
        // Danh sach rong: khong gui request cho device nay.
        if (merged[box]!.isNotEmpty)
          box: List<String>.unmodifiable(merged[box]!.toList()..sort()),
    });
  }

  /// Signal cua [plcs] co san trong cac cache con han cung (tag, box).
  ({Map<String, T> base, DateTime? oldest}) _cachedSignals(
    String tag,
    String box,
    List<String> plcs,
  ) {
    final prefix = _cachePrefix(tag, box);
    final wanted = plcs.toSet();
    final base = <String, T>{};
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

  Future<void> _fetchBatch(
    SeriesRequestBatch batch,
    Map<String, _BoxPlan<T>> plans,
    String tag,
    HistoryWindow window,
    bool forceRefresh,
    int generation,
  ) async {
    final cancelToken = CancelToken();
    _inFlight.add(cancelToken);

    try {
      final response = await repository
          .fetchSeriesHistory(
            boxDeviceIds: batch.boxes,
            plcAddresses: batch.plcs,
            from: window.from,
            to: window.to,
            bucket: bucket,
            cacheTtl: cacheTtl,
            forceRefresh: forceRefresh,
            cancelToken: cancelToken,
          )
          .timeout(
            requestTimeout,
            onTimeout: () {
              cancelToken.cancel('timeout');
              throw TimeoutException(
                '$debugLabel request timed out',
                requestTimeout,
              );
            },
          );

      if (!_isCurrent(generation)) return;

      // PLC gui chung cho ca lo: chi nhan dung cap (box, plc) can, ghep
      // theo cap cua response (khong theo thu tu), khoa luu la box / PLC
      // nguyen van cua request (panel tra boxState(box).signals[plc]).
      var unmatched = 0;

      for (final dto in response.signals) {
        final target = _matchSignal(batch, dto);

        if (target == null) {
          unmatched++;
          continue;
        }

        final (box, plc) = target;
        final plan = plans[box];
        if (plan == null || plan.failed) continue;

        plan.fetched[plc] = convert(dto, response, window);
      }

      if (unmatched > 0 && kDebugMode) {
        debugPrint(
          '[$debugLabel] $unmatched/${response.signals.length} signal '
          'khong ghep duoc voi (box, plc) da gui; vd '
          'box="${response.signals.first.boxDeviceId}" '
          'plc="${response.signals.first.plcAddress}"',
        );
      }

      final now = DateTime.now();
      var changed = false;

      for (final box in batch.boxes) {
        final plan = plans[box]!;
        if (plan.failed || !_boxes.containsKey(box)) continue;

        plan.pending--;
        if (plan.pending > 0) continue;

        // Du cac lo: gop voi phan cache roi ghi mot lan.
        final data = SeriesBoxData<T>(
          tag: tag,
          window: window,
          signals: Map<String, T>.unmodifiable({
            ...plan.base,
            ...plan.fetched,
          }),
        );

        _cache[plan.cacheKey] = _CacheEntry<T>(
          createdAt: plan.baseCreatedAt ?? now,
          data: data,
        );

        final current = _boxes[box] ?? SeriesBoxState<T>();
        _boxes[box] = SeriesBoxState<T>(
          data: data,
          lastOkAt: now,
          lastErrAt: current.lastErrAt,
        );
        changed = true;
      }

      if (changed) safeNotify();
    } catch (error, stackTrace) {
      // Huy chu dong (doi lua chon / range / roi tab): khong phai loi.
      // Timeout den day duoi dang TimeoutException nen van bao loi.
      if (error is DioException && CancelToken.isCancel(error)) return;

      if (!_isCurrent(generation)) return;

      debugPrint(
        '[$debugLabel ERROR] boxes=${batch.boxes.join(',')} '
        'plcs=${batch.plcs.length} error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);

      final now = DateTime.now();

      // Mot lo loi -> moi box trong lo loi; cac lo con lai cua box bo qua.
      for (final box in batch.boxes) {
        final plan = plans[box]!;
        if (plan.failed || !_boxes.containsKey(box)) continue;

        plan.failed = true;

        final current = _boxes[box] ?? SeriesBoxState<T>();

        // Chart cung tag (poll loi) van giu; chart tag cu thi bo.
        final keepData = current.data?.tag == tag;

        _boxes[box] = SeriesBoxState<T>(
          data: keepData ? current.data : null,
          error: error,
          lastOkAt: current.lastOkAt,
          lastErrAt: now,
        );
      }

      safeNotify();
    } finally {
      _inFlight.remove(cancelToken);
    }
  }

  static String _norm(String value) => value.trim().toUpperCase();

  /// (box, plc) cua request ma [dto] thuoc ve, null = khong can.
  ///
  /// So khop theo cap (boxDeviceId, plcAddress) da chuan hoa (trim, khong
  /// phan biet hoa thuong) roi tra ve dung chuoi box / PLC cua request.
  /// Signal khong co boxDeviceId: chi nhan khi dung mot box trong lo can
  /// PLC do.
  (String, String)? _matchSignal(
    SeriesRequestBatch batch,
    SeriesHistorySignalDto dto,
  ) {
    final boxKey = _norm(dto.boxDeviceId);
    final plcKey = _norm(dto.plcAddress);
    if (plcKey.isEmpty) return null;

    (String, String)? found;

    for (final MapEntry(key: box, value: plcs) in batch.wanted.entries) {
      if (boxKey.isNotEmpty && _norm(box) != boxKey) continue;

      for (final plc in plcs) {
        if (_norm(plc) != plcKey) continue;

        // Thieu box o response ma nhieu box cung can PLC nay: khong doan.
        if (found != null) return null;
        found = (box, plc);
      }

      if (boxKey.isNotEmpty && found != null) return found;
    }

    return found;
  }

  bool _isCurrent(int generation) {
    return !_disposed && generation == _generation;
  }

  void _cancelInFlight() {
    for (final token in _inFlight.toList(growable: false)) {
      if (!token.isCancelled) token.cancel('superseded');
    }
    _inFlight.clear();
  }

  String _cachePrefix(String tag, String box) => '$tag|$box|';

  /// [plcs] da sort (xem [_normalizeRequest]).
  String _cacheKey(String tag, String box, List<String> plcs) {
    return '${_cachePrefix(tag, box)}${plcs.join(',')}';
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
