import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utility_api/utility_api.dart';
import '../utility_models/response/minute_point.dart';

class _MinuteReq {
  final String key;

  final String? facId;
  final String? scadaId;
  final String? cate;

  final String? boxDeviceId;
  final String? plcAddress;
  final List<String>? cateIds;

  _MinuteReq({
    required this.key,
    this.facId,
    this.scadaId,
    this.cate,
    this.boxDeviceId,
    this.plcAddress,
    this.cateIds,
  });
}

class MinuteSeriesProvider extends ChangeNotifier {
  final UtilityApi api;
  final Duration interval;
  final Duration window;

  MinuteSeriesProvider({
    required this.api,
    this.interval = const Duration(seconds: 30),
    this.window = const Duration(minutes: 60),
  });

  Timer? _timer;
  bool _polling = false;

  // requests registry
  final Map<String, _MinuteReq> _reqs = {};

  // cache by key
  final Map<String, List<MinutePointDto>> _rows = {};
  final Map<String, Object?> _errors = {};
  final Map<String, bool> _fetching = {};
  final Map<String, DateTime?> _lastTs = {}; // incremental cursor

  // ✅ NEW: lifecycle state
  final Map<String, bool> _fetchedOnce = {};
  final Map<String, DateTime?> _lastOkAt = {};
  final Map<String, DateTime?> _lastErrAt = {};

  // ===== key builder =====
  String buildKey({
    String? facId,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    String? plcAddress,
    List<String>? cateIds,
  }) {
    final ids =
        (cateIds ?? []).map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          ..sort();

    return 'fac=${(facId ?? "").trim()}'
        '|scada=${(scadaId ?? "").trim()}'
        '|cate=${(cate ?? "").trim()}'
        '|dev=${(boxDeviceId ?? "").trim()}'
        '|addr=${(plcAddress ?? "").trim()}'
        '|cateIds=${ids.join(",")}';
  }

  List<String>? _normCateIds(List<String>? src) {
    if (src == null) return null;
    final out = src.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (out.isEmpty) return null;
    out.sort();
    return out;
  }

  bool _hasRequired(_MinuteReq r) {
    final dev = (r.boxDeviceId ?? '').trim();
    final addr = (r.plcAddress ?? '').trim();
    return dev.isNotEmpty && addr.isNotEmpty;
  }

  void upsertRequest({
    required String key,
    String? facId,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    String? plcAddress,
    List<String>? cateIds,
  }) {
    _reqs[key] = _MinuteReq(
      key: key,
      facId: facId,
      scadaId: scadaId,
      cate: cate,
      boxDeviceId: boxDeviceId,
      plcAddress: plcAddress,
      cateIds: cateIds,
    );

    // ✅ ensure maps exist (avoid null logic in UI)
    _rows.putIfAbsent(key, () => const []);
    _fetching.putIfAbsent(key, () => false);
    _errors.putIfAbsent(key, () => null);
    _lastTs.putIfAbsent(key, () => null);

    _fetchedOnce.putIfAbsent(key, () => false);
    _lastOkAt.putIfAbsent(key, () => null);
    _lastErrAt.putIfAbsent(key, () => null);
  }

  void removeKey(String key) {
    _reqs.remove(key);
    _rows.remove(key);
    _errors.remove(key);
    _fetching.remove(key);
    _lastTs.remove(key);

    _fetchedOnce.remove(key);
    _lastOkAt.remove(key);
    _lastErrAt.remove(key);

    notifyListeners();
  }

  // ===== exposed getters =====
  List<MinutePointDto> getRows(String key) => _rows[key] ?? const [];

  Object? getError(String key) => _errors[key];

  bool isFetching(String key) => _fetching[key] == true;

  // ✅ NEW getters for UI status
  bool hasFetchedOnce(String key) => _fetchedOnce[key] == true;

  DateTime? lastOkAt(String key) => _lastOkAt[key];

  DateTime? lastErrAt(String key) => _lastErrAt[key];

  // ===== polling control =====
  void startPolling() {
    if (_polling) return;
    _polling = true;
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _tickAll());
  }

  void stopPolling() {
    _polling = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> fetchKeyNow(String key) async {
    final r = _reqs[key];
    if (r == null) return;
    await _fetchFullWindow(r);
  }

  Future<void> _tickAll() async {
    if (_reqs.isEmpty) return;

    for (final r in _reqs.values) {
      if (!_hasRequired(r)) continue;

      final last = _lastTs[r.key];
      final curRowsEmpty = (_rows[r.key]?.isEmpty ?? true);

      if (last == null || curRowsEmpty) {
        await _fetchFullWindow(r);
      } else {
        await _fetchIncremental(r);
      }
    }
  }

  Future<void> _fetchFullWindow(_MinuteReq r) async {
    if (_fetching[r.key] == true) return;

    // ✅ missing required -> clear and mark fetchedOnce? (không)
    if (!_hasRequired(r)) {
      _rows[r.key] = const [];
      _errors[r.key] = null;
      _lastTs[r.key] = null;

      // không đánh fetchedOnce vì chưa gọi API thật
      notifyListeners();
      return;
    }

    _fetching[r.key] = true;
    _errors[r.key] = null;
    notifyListeners();

    try {
      final to = DateTime.now();
      final from = to.subtract(window);

      final rows = await api.getSeriesMinute(
        from: from,
        to: to,
        boxDeviceId: r.boxDeviceId!.trim(),
        plcAddress: r.plcAddress!.trim(),
        cateIds: _normCateIds(r.cateIds),
      );

      rows.sort((a, b) => a.ts.compareTo(b.ts));

      _rows[r.key] = rows;
      _lastTs[r.key] = rows.isNotEmpty ? rows.last.ts : null;
      _trimToWindow(r.key);

      _errors[r.key] = null;

      // ✅ NEW: mark success (kể cả rows rỗng)
      _fetchedOnce[r.key] = true;
      _lastOkAt[r.key] = DateTime.now();
    } catch (e) {
      _errors[r.key] = e;

      // ✅ NEW: mark error
      _fetchedOnce[r.key] = true;
      _lastErrAt[r.key] = DateTime.now();
    } finally {
      _fetching[r.key] = false;
      notifyListeners();
    }
  }

  Future<void> _fetchIncremental(_MinuteReq r) async {
    if (_fetching[r.key] == true) return;
    if (!_hasRequired(r)) return;

    final last = _lastTs[r.key];
    if (last == null) return;

    _fetching[r.key] = true;
    notifyListeners();

    try {
      final from = last.add(const Duration(seconds: 1));
      final to = DateTime.now();

      final rows = await api.getSeriesMinute(
        from: from,
        to: to,
        boxDeviceId: r.boxDeviceId!.trim(),
        plcAddress: r.plcAddress!.trim(),
        cateIds: _normCateIds(r.cateIds),
      );

      // merge
      if (rows.isNotEmpty) {
        rows.sort((a, b) => a.ts.compareTo(b.ts));

        final cur = List<MinutePointDto>.from(_rows[r.key] ?? const []);
        final existing = cur.map((e) => e.ts.millisecondsSinceEpoch).toSet();

        for (final x in rows) {
          final k = x.ts.millisecondsSinceEpoch;
          if (!existing.contains(k)) cur.add(x);
        }

        cur.sort((a, b) => a.ts.compareTo(b.ts));
        _rows[r.key] = cur;
        _lastTs[r.key] = cur.isNotEmpty ? cur.last.ts : _lastTs[r.key];
        _trimToWindow(r.key);
      }

      _errors[r.key] = null;

      // ✅ NEW: success tick (dù rows incremental rỗng vẫn là success)
      _fetchedOnce[r.key] = true;
      _lastOkAt[r.key] = DateTime.now();
    } catch (e) {
      _errors[r.key] = e;

      // ✅ NEW: error tick
      _fetchedOnce[r.key] = true;
      _lastErrAt[r.key] = DateTime.now();
    } finally {
      _fetching[r.key] = false;
      notifyListeners();
    }
  }

  void _trimToWindow(String key) {
    final cur = _rows[key];
    if (cur == null || cur.isEmpty) return;

    final cutoff = DateTime.now().subtract(window);
    while (cur.isNotEmpty && cur.first.ts.isBefore(cutoff)) {
      cur.removeAt(0);
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
