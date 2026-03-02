import 'package:flutter/foundation.dart';

import '../utility_api/utility_api.dart';
import '../utility_models/response/tree_series_response.dart';

class TreeSeriesProvider extends ChangeNotifier {
  final UtilityApi api;

  TreeSeriesProvider(this.api);

  final Map<String, _Entry> _map = {};

  String buildKey({
    required String fac,
    required String boxDeviceId,
    required String plcAddress,
    String? range,
    int? year,
    int? month,
  }) => [
    fac.trim(),
    boxDeviceId.trim(),
    plcAddress.trim(),
    (range ?? '').trim(),
    (year?.toString() ?? ''),
    (month?.toString() ?? ''),
  ].join('|');

  _Entry _entry(String key) => _map.putIfAbsent(key, () => _Entry());

  bool isLoading(String key) => _map[key]?.loading ?? false;

  Object? errorOf(String key) => _map[key]?.error;

  TreeSeriesResponse? dataOf(String key) => _map[key]?.data;

  List<TreePoint> pointsOf(String key) {
    final e = _map[key];
    if (e?.data == null) return [];
    final parts = key.split('|');
    final box = parts[1];
    final plc = parts[2];
    final sig = e!.data!.findSignal(boxDeviceId: box, plcAddress: plc);
    final pts = sig?.points ?? [];
    final sorted = [...pts]..sort((a, b) => a.ts.compareTo(b.ts));
    return sorted;
  }

  Future<void> load({
    required String fac,
    required String boxDeviceId,
    required String plcAddress,
    String? range,
    int? year,
    int? month,
    bool force = false,
  }) async {
    final key = buildKey(
      fac: fac,
      boxDeviceId: boxDeviceId,
      plcAddress: plcAddress,
      range: range,
      year: year,
      month: month,
    );

    final e = _entry(key);
    if (!force && e.data != null) return;

    e.loading = true;
    e.error = null;
    notifyListeners();

    try {
      final res = await api.getTreeSeries(
        fac: fac,
        boxDeviceId: boxDeviceId,
        plcAddress: plcAddress,
        range: range,
        year: year,
        month: month,
      );

      e.data = res;
      e.loading = false;
      e.error = null;
      notifyListeners();
    } catch (err) {
      e.loading = false;
      e.error = err;
      notifyListeners();
    }
  }
}

class _Entry {
  bool loading = false;
  Object? error;
  TreeSeriesResponse? data;
}
