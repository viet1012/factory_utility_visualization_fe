import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utility_models/response/tree_series_response.dart';
import '../utility_models/utility_facade_service.dart';

class TreeLatestProvider extends ChangeNotifier {
  final UtilityFacadeService svc;

  TreeLatestProvider(this.svc);

  final Map<String, _TreeState> _states = {};
  Timer? _timer;

  _TreeState _ensure(String key) =>
      _states.putIfAbsent(key, () => _TreeState());

  TreeSeriesResponse? dataOf(String key) => _states[key]?.data;

  Object? errorOf(String key) => _states[key]?.error;

  bool loadingOf(String key) => _states[key]?.loading ?? false;

  String buildKey({
    required List<String> facIds,
    required List<String> plcAddresses,
    String? boxDeviceId,
  }) {
    final f = [...facIds.map((e) => e.trim())]..removeWhere((e) => e.isEmpty);
    final p = [...plcAddresses.map((e) => e.trim())]
      ..removeWhere((e) => e.isEmpty);
    f.sort();
    p.sort();
    return 'fac=${f.join("|")}|plc=${p.join("|")}|box=${(boxDeviceId ?? "").trim()}';
  }

  Future<void> fetch({
    required String key,
    required List<String> facIds,
    required List<String> plcAddresses,
    String? boxDeviceId,
  }) async {
    final st = _ensure(key);
    st.loading = true;
    st.error = null;
    notifyListeners();

    try {
      final data = await svc.fetchLatestTree(
        facIds: facIds,
        plcAddresses: plcAddresses,
        boxDeviceId: boxDeviceId,
      );
      st.data = data;
      st.error = null;
    } catch (e) {
      st.error = e;
    } finally {
      st.loading = false;
      notifyListeners();
    }
  }

  void startAuto({
    required String key,
    required List<String> facIds,
    required List<String> plcAddresses,
    String? boxDeviceId,
    Duration interval = const Duration(seconds: 3),
  }) {
    _timer?.cancel();

    // fetch ngay
    fetch(
      key: key,
      facIds: facIds,
      plcAddresses: plcAddresses,
      boxDeviceId: boxDeviceId,
    );

    _timer = Timer.periodic(interval, (_) {
      fetch(
        key: key,
        facIds: facIds,
        plcAddresses: plcAddresses,
        boxDeviceId: boxDeviceId,
      );
    });
  }

  void stopAuto() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stopAuto();
    super.dispose();
  }
}

class _TreeState {
  TreeSeriesResponse? data;
  Object? error;
  bool loading = false;
}
