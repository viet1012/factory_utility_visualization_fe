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
  final List<String>? cateIds;

  _MinuteReq({
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
  final Duration interval;
  final Duration window;

  MinuteSeriesProvider({
    required this.api,
    this.interval = const Duration(seconds: 30),
    this.window = const Duration(minutes: 60),
  });

  Timer? _timer;
  bool _polling = false;

  // ===================== REGISTRY =====================

  final Map<String, _MinuteReq> _reqs = {};

  // cache by BOX key (rows gồm nhiều plcAddress)
  final Map<String, List<MinutePointDto>> _rows = {};
  final Map<String, Object?> _errors = {};
  final Map<String, bool> _fetching = {};
  final Map<String, DateTime?> _lastTs = {}; // cursor toàn box (max ts)

  // lifecycle state (y chang bản bạn)
  final Map<String, bool> _fetchedOnce = {};
  final Map<String, DateTime?> _lastOkAt = {};
  final Map<String, DateTime?> _lastErrAt = {};

  // ===================== KEY BUILDER (BOX KEY) =====================
  // ✅ NOTE: KHÔNG còn plcAddress trong key
  String buildKey({
    String? facId,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    List<String>? cateIds,
  }) {
    final ids =
        (cateIds ?? []).map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          ..sort();

    return 'fac=${(facId ?? "").trim()}'
        '|scada=${(scadaId ?? "").trim()}'
        '|cate=${(cate ?? "").trim()}'
        '|dev=${(boxDeviceId ?? "").trim()}'
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
    return dev.isNotEmpty; // ✅ chỉ cần boxDeviceId
  }

  // ===================== UPSERT =====================
  // ✅ upsert theo BOX key, plcAddress không còn nằm trong request
  void upsertRequest({
    required String key,
    String? facId,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    List<String>? cateIds,
  }) {
    _reqs[key] = _MinuteReq(
      key: key,
      facId: facId,
      scadaId: scadaId,
      cate: cate,
      boxDeviceId: boxDeviceId,
      cateIds: cateIds,
    );

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

  // ===================== GETTERS =====================

  /// ✅ all rows (nhiều plcAddress)
  List<MinutePointDto> getRows(String key) => _rows[key] ?? const [];

  /// ✅ rows theo plcAddress (UI panel dùng cái này)
  List<MinutePointDto> getRowsForPlc(String key, String plcAddress) {
    final addr = plcAddress.trim();
    if (addr.isEmpty) return const [];
    final all = _rows[key] ?? const [];
    return all.where((e) => (e.plcAddress ?? '').trim() == addr).toList();
  }

  Object? getError(String key) => _errors[key];

  bool isFetching(String key) => _fetching[key] == true;

  bool hasFetchedOnce(String key) => _fetchedOnce[key] == true;

  DateTime? lastOkAt(String key) => _lastOkAt[key];

  DateTime? lastErrAt(String key) => _lastErrAt[key];

  // ===================== POLLING CONTROL =====================

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

  // ===================== FETCH FULL WINDOW (1 API PER BOX) =====================
  Future<void> _fetchFullWindow(_MinuteReq r) async {
    if (_fetching[r.key] == true) return;

    if (!_hasRequired(r)) {
      _rows[r.key] = const [];
      _errors[r.key] = null;
      _lastTs[r.key] = null;

      notifyListeners();
      return;
    }

    _fetching[r.key] = true;
    _errors[r.key] = null;
    notifyListeners();

    try {
      final to = DateTime.now();
      final from = to.subtract(window);

      // ✅ IMPORTANT: plcAddress = null => backend trả ALL plcAddress của box
      final rows = await api.getSeriesMinute(
        from: from,
        to: to,
        boxDeviceId: r.boxDeviceId!.trim(),
        plcAddress: null,
        // ✅ CHỖ QUAN TRỌNG
        cateIds: _normCateIds(r.cateIds),
      );

      // sort ổn định: ts asc, plc asc
      rows.sort((a, b) {
        final c = a.ts.compareTo(b.ts);
        if (c != 0) return c;
        return (a.plcAddress ?? '').compareTo(b.plcAddress ?? '');
      });

      _rows[r.key] = rows;

      // cursor = max ts của toàn bộ rows
      _lastTs[r.key] = rows.isNotEmpty ? rows.last.ts : null;

      _trimToWindow(r.key);

      _errors[r.key] = null;

      _fetchedOnce[r.key] = true;
      _lastOkAt[r.key] = DateTime.now();
    } catch (e) {
      _errors[r.key] = e;

      _fetchedOnce[r.key] = true;
      _lastErrAt[r.key] = DateTime.now();
    } finally {
      _fetching[r.key] = false;
      notifyListeners();
    }
  }

  // ===================== FETCH INCREMENTAL (SAFE) =====================
  Future<void> _fetchIncremental(_MinuteReq r) async {
    if (_fetching[r.key] == true) return;
    if (!_hasRequired(r)) return;

    final last = _lastTs[r.key];
    if (last == null) return;

    _fetching[r.key] = true;
    notifyListeners();

    try {
      // ✅ “safe incremental”:
      // vì rows gồm nhiều plcAddress, dùng cursor chung có thể miss nếu signal nào đó update chậm.
      // nên lùi lại 1 phút để merge lại cho chắc (cost nhỏ).
      final from = last.subtract(const Duration(minutes: 1));
      final to = DateTime.now();

      final rows = await api.getSeriesMinute(
        from: from,
        to: to,
        boxDeviceId: r.boxDeviceId!.trim(),
        plcAddress: null,
        // ✅ ALL plcAddress
        cateIds: _normCateIds(r.cateIds),
      );

      if (rows.isNotEmpty) {
        rows.sort((a, b) {
          final c = a.ts.compareTo(b.ts);
          if (c != 0) return c;
          return (a.plcAddress ?? '').compareTo(b.plcAddress ?? '');
        });

        final cur = List<MinutePointDto>.from(_rows[r.key] ?? const []);

        // ✅ merge unique theo (ts + plcAddress)
        final existing = <String>{};
        for (final e in cur) {
          final k =
              '${e.ts.millisecondsSinceEpoch}|${(e.plcAddress ?? '').trim()}';
          existing.add(k);
        }

        for (final x in rows) {
          final k =
              '${x.ts.millisecondsSinceEpoch}|${(x.plcAddress ?? '').trim()}';
          if (!existing.contains(k)) {
            cur.add(x);
            existing.add(k);
          }
        }

        cur.sort((a, b) {
          final c = a.ts.compareTo(b.ts);
          if (c != 0) return c;
          return (a.plcAddress ?? '').compareTo(b.plcAddress ?? '');
        });

        _rows[r.key] = cur;
        _lastTs[r.key] = cur.isNotEmpty ? cur.last.ts : _lastTs[r.key];
        _trimToWindow(r.key);
      }

      _errors[r.key] = null;

      _fetchedOnce[r.key] = true;
      _lastOkAt[r.key] = DateTime.now();
    } catch (e) {
      _errors[r.key] = e;

      _fetchedOnce[r.key] = true;
      _lastErrAt[r.key] = DateTime.now();
    } finally {
      _fetching[r.key] = false;
      notifyListeners();
    }
  }

  // ===================== WINDOW TRIM =====================
  void _trimToWindow(String key) {
    final cur = _rows[key];
    if (cur == null || cur.isEmpty) return;

    final cutoff = DateTime.now().subtract(window);

    // vì cur đang sort theo ts asc
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
