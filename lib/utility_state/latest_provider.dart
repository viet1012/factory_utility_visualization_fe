import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utility_api/utility_api.dart';
import '../utility_models/response/latest_record.dart';

class LatestProvider extends ChangeNotifier {
  final UtilityApi api;
  final Duration interval;

  LatestProvider({
    required this.api,
    this.interval = const Duration(seconds: 30),
  });

  Timer? _timer;

  // cache theo "key filter" => list record
  final Map<String, List<LatestRecordDto>> _cache = {};

  // error theo key
  final Map<String, Object?> _errors = {};

  // last updated theo key
  final Map<String, DateTime?> _lastUpdated = {};

  // ✅ lock theo key (không chặn nhau giữa A/B/C)
  final Map<String, bool> _inFlight = {};

  // ===== Lưu request theo key để polling tự động =====
  final Map<String, _Req> _reqs = {};

  /// tạo key unique theo filter của box
  String buildKey({
    String? facId,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    List<String>? cateIds,
  }) {
    final cateIdsCsv =
        (cateIds ?? []).map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          ..sort();

    return [
      (facId ?? '').trim(),
      (scadaId ?? '').trim(),
      (cate ?? '').trim(),
      (boxDeviceId ?? '').trim(),
      cateIdsCsv.join(','),
    ].join('|');
  }

  List<LatestRecordDto> getRows(String key) => _cache[key] ?? const [];

  Object? getError(String key) => _errors[key];

  DateTime? getLastUpdated(String key) => _lastUpdated[key];

  /// register một key để provider biết cần fetch key đó
  void registerKey(String key) {
    _cache.putIfAbsent(key, () => const []);
    _errors.putIfAbsent(key, () => null);
    _lastUpdated.putIfAbsent(key, () => null);
    _inFlight.putIfAbsent(key, () => false);
  }

  /// upsert request theo key (để polling tự động)
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

  /// remove key (khi widget dispose / filter đổi và muốn dọn)
  void removeKey(String key) {
    _reqs.remove(key);
    _cache.remove(key);
    _errors.remove(key);
    _lastUpdated.remove(key);
    _inFlight.remove(key);
    notifyListeners();
  }

  /// fetch 1 key cụ thể
  /// - notify = true: widget gọi trực tiếp để hiển thị ngay
  /// - notify = false: polling gọi nhiều key, sẽ notify 1 lần sau
  Future<void> fetchKey({
    required String key,
    String? facId,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    List<String>? cateIds,
    bool notify = true,
  }) async {
    // ✅ lock theo key để tránh spam cùng key, nhưng không chặn key khác
    if (_inFlight[key] == true) return;
    _inFlight[key] = true;

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
      if (notify) notifyListeners();
    } catch (e) {
      _errors[key] = e;
      if (notify) notifyListeners();
    } finally {
      _inFlight[key] = false;
    }
  }

  /// tick tất cả key đã register (dựa trên _reqs)
  Future<void> _tickAllWithReqs() async {
    if (_reqs.isEmpty) return;

    // ✅ chạy song song để A/B/C cập nhật cùng lúc
    final futures = <Future<void>>[];

    for (final entry in _reqs.entries) {
      final key = entry.key;
      final r = entry.value;

      futures.add(
        fetchKey(
          key: key,
          facId: r.facId,
          scadaId: r.scadaId,
          cate: r.cate,
          boxDeviceId: r.boxDeviceId,
          cateIds: r.cateIds,
          notify: false, // ✅ polling: notify 1 lần sau
        ),
      );
    }

    await Future.wait(futures);

    // ✅ notify 1 lần cho cả batch
    notifyListeners();
  }

  /// start polling cho toàn app
  void startPolling() {
    _timer?.cancel();

    // ✅ tick ngay lập tức
    unawaited(_tickAllWithReqs());

    _timer = Timer.periodic(interval, (_) {
      unawaited(_tickAllWithReqs());
    });
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
  final String? facId;
  final String? scadaId;
  final String? cate;
  final String? boxDeviceId;
  final List<String>? cateIds;

  _Req({this.facId, this.scadaId, this.cate, this.boxDeviceId, this.cateIds});
}
