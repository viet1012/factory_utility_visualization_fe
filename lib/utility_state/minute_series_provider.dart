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
  final Duration interval;
  final Duration window;
  final Duration requestTimeout;

  MinuteSeriesProvider({
    required this.api,
    this.interval = const Duration(seconds: 30),
    this.window = const Duration(minutes: 60),
    this.requestTimeout = const Duration(seconds: 15),
  });

  Timer? _timer;
  bool _polling = false;
  bool _tickRunning = false;
  bool _disposed = false;

  final Map<String, _MinuteReq> _reqs = {};
  final Map<String, List<MinutePointDto>> _rows = {};
  final Map<String, Object?> _errors = {};
  final Map<String, bool> _fetching = {};
  final Map<String, DateTime?> _lastTs = {};
  final Map<String, bool> _fetchedOnce = {};
  final Map<String, DateTime?> _lastOkAt = {};
  final Map<String, DateTime?> _lastErrAt = {};

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

    return 'fac=${(facId ?? '').trim()}'
        '|scada=${(scadaId ?? '').trim()}'
        '|cate=${(cate ?? '').trim()}'
        '|dev=${(boxDeviceId ?? '').trim()}'
        '|cateIds=${ids.join(',')}';
  }

  List<String>? _normCateIds(List<String>? src) {
    if (src == null) return null;

    final out = src.map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
      ..sort();

    return out.isEmpty ? null : out;
  }

  bool _hasRequired(_MinuteReq r) {
    return (r.boxDeviceId ?? '').trim().isNotEmpty;
  }

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
      cateIds: _normCateIds(cateIds),
    );

    _rows.putIfAbsent(key, () => const []);
    _errors.putIfAbsent(key, () => null);
    _fetching.putIfAbsent(key, () => false);
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

    _safeNotify();
  }

  List<MinutePointDto> getRows(String key) => _rows[key] ?? const [];

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

  void startPolling() {
    if (_polling || _disposed) return;

    _polling = true;
    _timer?.cancel();

    _timer = Timer.periodic(interval, (_) {
      _tickAll();
    });
  }

  void stopPolling() {
    _polling = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> fetchKeyNow(String key) async {
    final r = _reqs[key];
    if (r == null || !_hasRequired(r)) return;

    await _fetchFullWindow(r);
  }

  Future<void> _tickAll() async {
    if (_disposed || !_polling || _tickRunning || _reqs.isEmpty) return;

    _tickRunning = true;

    try {
      final tasks = <Future<void>>[];

      for (final r in List<_MinuteReq>.from(_reqs.values)) {
        if (!_hasRequired(r)) continue;
        if (_fetching[r.key] == true) continue;

        final last = _lastTs[r.key];
        final isEmpty = _rows[r.key]?.isEmpty ?? true;

        if (last == null || isEmpty) {
          tasks.add(_fetchFullWindow(r));
        } else {
          tasks.add(_fetchIncremental(r));
        }
      }

      await Future.wait(tasks);
    } finally {
      _tickRunning = false;
    }
  }

  Future<void> _fetchFullWindow(_MinuteReq r) async {
    if (_disposed || _fetching[r.key] == true) return;

    if (!_hasRequired(r)) {
      _rows[r.key] = const [];
      _errors[r.key] = null;
      _lastTs[r.key] = null;
      _safeNotify();
      return;
    }

    _fetching[r.key] = true;
    _errors[r.key] = null;
    _safeNotify();

    try {
      final to = DateTime.now();
      final from = to.subtract(window);

      final rows = await api
          .getSeriesMinute(
            from: from,
            to: to,
            boxDeviceId: r.boxDeviceId!.trim(),
            plcAddress: null,
            cateIds: _normCateIds(r.cateIds),
          )
          .timeout(requestTimeout);

      rows.sort(_sortRows);

      _rows[r.key] = rows;
      _lastTs[r.key] = rows.isNotEmpty ? rows.last.ts : null;

      _trimToWindow(r.key);

      _errors[r.key] = null;
      _fetchedOnce[r.key] = true;
      _lastOkAt[r.key] = DateTime.now();
    } catch (e) {
      _errors[r.key] = e;
      _fetchedOnce[r.key] = true;
      _lastErrAt[r.key] = DateTime.now();

      // Giữ rows cũ, không clear data.
    } finally {
      _fetching[r.key] = false;
      _safeNotify();
    }
  }

  Future<void> _fetchIncremental(_MinuteReq r) async {
    if (_disposed || _fetching[r.key] == true) return;
    if (!_hasRequired(r)) return;

    final last = _lastTs[r.key];
    if (last == null) return;

    _fetching[r.key] = true;
    _safeNotify();

    try {
      final from = last.subtract(const Duration(minutes: 1));
      final to = DateTime.now();

      final newRows = await api
          .getSeriesMinute(
            from: from,
            to: to,
            boxDeviceId: r.boxDeviceId!.trim(),
            plcAddress: null,
            cateIds: _normCateIds(r.cateIds),
          )
          .timeout(requestTimeout);

      if (newRows.isNotEmpty) {
        newRows.sort(_sortRows);

        final merged = _mergeRows(
          current: _rows[r.key] ?? const [],
          incoming: newRows,
        );

        _rows[r.key] = merged;
        _lastTs[r.key] = merged.isNotEmpty ? merged.last.ts : _lastTs[r.key];

        _trimToWindow(r.key);
      }

      _errors[r.key] = null;
      _fetchedOnce[r.key] = true;
      _lastOkAt[r.key] = DateTime.now();
    } catch (e) {
      _errors[r.key] = e;
      _fetchedOnce[r.key] = true;
      _lastErrAt[r.key] = DateTime.now();

      // Giữ rows cũ, không clear data.
    } finally {
      _fetching[r.key] = false;
      _safeNotify();
    }
  }

  List<MinutePointDto> _mergeRows({
    required List<MinutePointDto> current,
    required List<MinutePointDto> incoming,
  }) {
    final merged = List<MinutePointDto>.from(current);
    final exists = <String>{};

    for (final e in merged) {
      exists.add(_rowKey(e));
    }

    for (final e in incoming) {
      final key = _rowKey(e);
      if (exists.add(key)) {
        merged.add(e);
      }
    }

    merged.sort(_sortRows);

    return merged;
  }

  String _rowKey(MinutePointDto e) {
    return '${e.ts.millisecondsSinceEpoch}|${(e.plcAddress ?? '').trim()}';
  }

  int _sortRows(MinutePointDto a, MinutePointDto b) {
    final c = a.ts.compareTo(b.ts);
    if (c != 0) return c;

    return (a.plcAddress ?? '').compareTo(b.plcAddress ?? '');
  }

  void _trimToWindow(String key) {
    final cur = _rows[key];
    if (cur == null || cur.isEmpty) return;

    final cutoff = DateTime.now().subtract(window);

    final trimmed = cur.where((e) => !e.ts.isBefore(cutoff)).toList();

    if (trimmed.length != cur.length) {
      _rows[key] = trimmed;
      _lastTs[key] = trimmed.isNotEmpty ? trimmed.last.ts : null;
    }
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}
