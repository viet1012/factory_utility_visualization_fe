import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utility_api/utility_api.dart';
import '../utility_models/response/hour_point.dart';

class HourlySeriesProvider extends ChangeNotifier {
  final UtilityApi api;
  final Duration interval;

  HourlySeriesProvider({
    required this.api,
    this.interval = const Duration(seconds: 30),
  });

  Timer? _timer;

  final Map<String, List<HourPointDto>> _cache = {};
  final Map<String, Object?> _errors = {};
  final Map<String, DateTime?> _lastUpdated = {};
  final Map<String, bool> _inFlight = {};
  final Map<String, _Req> _reqs = {};
  final Set<String> _fetchedOnce = {};

  String buildKey({
    required DateTime fromTs,
    required DateTime toTs,
    String? fac,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    required String plcAddress,
    String? cateId,
    List<String>? cateIds,
  }) {
    final ids =
        (cateIds ?? []).map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          ..sort();

    return [
      fromTs.toIso8601String(),
      toTs.toIso8601String(),
      (fac ?? '').trim(),
      (scadaId ?? '').trim(),
      (cate ?? '').trim(),
      (boxDeviceId ?? '').trim(),
      plcAddress.trim(),
      (cateId ?? '').trim(),
      ids.join(','),
    ].join('|');
  }

  List<HourPointDto> getRows(String key) => _cache[key] ?? const [];

  Object? getError(String key) => _errors[key];

  DateTime? getLastUpdated(String key) => _lastUpdated[key];

  bool hasFetchedOnce(String key) => _fetchedOnce.contains(key);

  void registerKey(String key) {
    _cache.putIfAbsent(key, () => const []);
    _errors.putIfAbsent(key, () => null);
    _lastUpdated.putIfAbsent(key, () => null);
    _inFlight.putIfAbsent(key, () => false);
  }

  void upsertRequest({
    required String key,
    required DateTime fromTs,
    required DateTime toTs,

    String? fac,
    String? scadaId,
    String? cate,
    String? boxDeviceId,

    required String plcAddress,
    String? cateId,
    List<String>? cateIds,
  }) {
    _reqs[key] = _Req(
      fromTs: fromTs,
      toTs: toTs,
      fac: fac,
      scadaId: scadaId,
      cate: cate,
      boxDeviceId: boxDeviceId,
      plcAddress: plcAddress,
      cateId: cateId,
      cateIds: cateIds,
    );
    registerKey(key);
  }

  Future<void> fetchKey({
    required String key,
    required _Req r,
    bool notify = true,
  }) async {
    if (_inFlight[key] == true) return;
    _inFlight[key] = true;

    try {
      final data = await api.seriesHourly(
        fromTs: r.fromTs,
        toTs: r.toTs,
        fac: r.fac,
        scadaId: r.scadaId,
        cate: r.cate,
        boxDeviceId: r.boxDeviceId,
        plcAddress: r.plcAddress,
        cateId: r.cateId,
        cateIds: r.cateIds,
      );

      _cache[key] = data;
      _errors[key] = null;
      _lastUpdated[key] = DateTime.now();
      _fetchedOnce.add(key);

      if (notify) notifyListeners();
    } catch (e) {
      _errors[key] = e;
      _fetchedOnce.add(key);
      if (notify) notifyListeners();
    } finally {
      _inFlight[key] = false;
    }
  }

  Future<void> fetchKeyNow(String key) async {
    final r = _reqs[key];
    if (r == null) return;
    await fetchKey(key: key, r: r, notify: true);
  }

  Future<void> _tickAll() async {
    if (_reqs.isEmpty) return;

    final futures = <Future<void>>[];
    for (final entry in _reqs.entries) {
      futures.add(fetchKey(key: entry.key, r: entry.value, notify: false));
    }
    await Future.wait(futures);
    notifyListeners();
  }

  void startPolling() {
    _timer?.cancel();
    // tick ngay
    unawaited(_tickAll());

    _timer = Timer.periodic(interval, (_) => unawaited(_tickAll()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

class _Req {
  final DateTime fromTs;
  final DateTime toTs;

  final String? fac;
  final String? scadaId;
  final String? cate;
  final String? boxDeviceId;

  final String plcAddress;
  final String? cateId;
  final List<String>? cateIds;

  _Req({
    required this.fromTs,
    required this.toTs,
    this.fac,
    this.scadaId,
    this.cate,
    this.boxDeviceId,
    required this.plcAddress,
    this.cateId,
    this.cateIds,
  });
}
