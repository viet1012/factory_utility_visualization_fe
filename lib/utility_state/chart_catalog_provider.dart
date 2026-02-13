import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utility_api/utility_api.dart';
import '../utility_dashboard/ultility_dashboard_chart/utility_minute_chart_screen.dart';

class ChartCatalogProvider extends ChangeNotifier {
  final UtilityApi api;

  ChartCatalogProvider(this.api);

  bool loading = false;
  Object? error;

  List<String> facs = [];
  List<String> cates = const [
    'Electricity',
    'Water',
    'Compressed Air',
  ]; // có thể API hoá sau

  List<String> boxDeviceIds = [];
  List<SignalChartConfig> charts = [];

  Future<void> loadFacs() async {
    // nếu bạn có /scadas trả fac list -> parse fac unique
    // Ở đây mình giả định bạn đã có api.getScadas()
  }

  Future<void> loadBoxes({required String facId, required String cate}) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final channels = await api.getChannels(facId: facId, cate: cate);
      final set = <String>{};
      for (final c in channels) {
        final v = c.boxDeviceId.trim();
        if (v.isNotEmpty) set.add(v);
      }
      boxDeviceIds = set.toList()..sort();

      // reset charts khi đổi fac/cate
      charts = [];
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadChartsForBox({
    required String facId,
    required String cate,
    required String boxDeviceId,
  }) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final ps = await api.getParams(
        facId: facId,
        cate: cate,
        boxDeviceId: boxDeviceId,
      );

      // build chart list (1 plcAddress = 1 chart)
      final out = <SignalChartConfig>[];
      final seen = <String>{};

      for (final p in ps) {
        final addr = p.plcAddress.trim();
        if (addr.isEmpty) continue;

        final key = '${boxDeviceId.trim()}|$addr';
        if (seen.add(key)) {
          out.add(
            SignalChartConfig(
              boxDeviceId: boxDeviceId.trim(),
              plcAddress: addr,
              cateIds: (p.cateId == null || p.cateId!.trim().isEmpty)
                  ? null
                  : [p.cateId!.trim()],
            ),
          );
        }
      }

      out.sort((a, b) => a.plcAddress.compareTo(b.plcAddress));
      charts = out;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
