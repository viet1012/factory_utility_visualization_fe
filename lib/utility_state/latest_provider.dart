import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utility_api/utility_api.dart';
import '../utility_models/response/latest_record.dart';

class LatestProvider extends ChangeNotifier {
  final UtilityApi api;
  final Duration interval;

  LatestProvider({
    required this.api,
    this.interval = const Duration(seconds: 2),
  });

  Timer? _timer;
  bool _fetching = false;

  // cache theo "key filter" => list record
  final Map<String, List<LatestRecordDto>> _cache = {};

  // error theo key
  final Map<String, Object?> _errors = {};

  // last updated theo key
  final Map<String, DateTime?> _lastUpdated = {};

  /// tạo key unique theo filter của box
  String buildKey({
    String? facId,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    List<String>? cateIds,
  }) {
    final cateIdsCsv = (cateIds ?? [])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(',');
    return [
      facId?.trim() ?? '',
      scadaId?.trim() ?? '',
      cate?.trim() ?? '',
      boxDeviceId?.trim() ?? '',
      cateIdsCsv,
    ].join('|');
  }

  List<LatestRecordDto> getRows(String key) => _cache[key] ?? const [];

  Object? getError(String key) => _errors[key];

  DateTime? getLastUpdated(String key) => _lastUpdated[key];

  /// start polling cho toàn app (1 timer chung)
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _tickAll());
    _tickAll(); // gọi ngay
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// register một key để provider biết cần fetch key đó
  void registerKey(String key) {
    _cache.putIfAbsent(key, () => const []);
    _errors.putIfAbsent(key, () => null);
    _lastUpdated.putIfAbsent(key, () => null);
  }

  /// fetch 1 key cụ thể
  Future<void> fetchKey({
    required String key,
    String? facId,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    List<String>? cateIds,
  }) async {
    if (_fetching) return;
    _fetching = true;

    try {
      final data = await api.getLatest(
        facId: facId,
        scadaId: scadaId,
        cate: cate,
        boxDeviceId: boxDeviceId,
        cateIds: cateIds,
      );

      _cache[key] = data;
      _errors[key] = null;
      _lastUpdated[key] = DateTime.now();
      notifyListeners();
    } catch (e) {
      _errors[key] = e;
      notifyListeners();
    } finally {
      _fetching = false;
    }
  }

  /// tick tất cả key đã register
  Future<void> _tickAll() async {
    // loop từng key để fetch (tuỳ bạn muốn song song hay tuần tự)
    // ở đây tuần tự để tránh spam request
    for (final entry in _cache.entries) {
      final key = entry.key;

      // parse key lại -> không cần (vì ta sẽ fetch bằng widget gọi trực tiếp)
      // Provider không biết filter của từng key nếu không lưu.
      // => giải pháp đơn giản: Widget sẽ gọi fetchKey() khi init và khi đổi filter.
      // Provider tickAll chỉ notify UI? Không. => ta cần lưu "request builder" theo key.
    }
  }

  // ===== Lưu request theo key để polling tự động =====
  final Map<String, _Req> _reqs = {};

  void upsertRequest({
    required String key,
    String? facId,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    List<String>? cateIds,
  }) {
    _reqs[key] = _Req(
      facId: facId,
      scadaId: scadaId,
      cate: cate,
      boxDeviceId: boxDeviceId,
      cateIds: cateIds,
    );
    registerKey(key);
  }

  Future<void> _tickAllWithReqs() async {
    for (final e in _reqs.entries) {
      final key = e.key;
      final r = e.value;

      await fetchKey(
        key: key,
        facId: r.facId,
        scadaId: r.scadaId,
        cate: r.cate,
        boxDeviceId: r.boxDeviceId,
        cateIds: r.cateIds,
      );
    }
  }

  // override start để dùng reqs
  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _tickAllWithReqs());
    _tickAllWithReqs();
  }

  void removeKey(String key) {
    _reqs.remove(key);
    _cache.remove(key);
    _errors.remove(key);
    _lastUpdated.remove(key);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

class _Req {
  final String? facId;
  final String? scadaId;
  final String? cate;
  final String? boxDeviceId;
  final List<String>? cateIds;

  _Req({this.facId, this.scadaId, this.cate, this.boxDeviceId, this.cateIds});
}
