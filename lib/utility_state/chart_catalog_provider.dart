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

  Future<void> loadBoxes1({required String facId, required String cate}) async {
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

  Future<void> loadBoxes({required String facId, required String cate}) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final channels = await api.getChannels(facId: facId, cate: cate);

      // ✅ 1) in số lượng channels + vài dòng sample
      debugPrint('=== /channels facId=$facId cate=$cate');
      debugPrint('channels.length=${channels.length}');
      for (final c in channels.take(20)) {
        debugPrint('  - boxDeviceId=${c.boxDeviceId}  scadaId=${c.scadaId} ');
      }

      // ✅ 2) build boxDeviceIds
      final set = <String>{};
      for (final c in channels) {
        final v = c.boxDeviceId.trim();
        if (v.isNotEmpty) set.add(v);
      }
      boxDeviceIds = set.toList()..sort();

      // ✅ 3) in danh sách BOX
      debugPrint('boxDeviceIds (${boxDeviceIds.length}):');
      for (final b in boxDeviceIds) {
        debugPrint('  • $b');
      }

      charts = [];
    } catch (e) {
      error = e;
      debugPrint('loadBoxes error=$e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadChartsForBox({
    required String facId,
    required String cate,
    required String boxDeviceId,
    int importantOnly = 0,
  }) async {
    loading = true;
    error = null;
    charts = [];
    notifyListeners();

    final box = boxDeviceId.trim();

    try {
      final ps = await api.getParams(
        facId: facId,
        cate: cate,
        boxDeviceId: box,
        importantOnly: importantOnly, // ✅ truyền xuống API
      );

      final seen = <String>{};

      charts =
          ps
              .map((p) {
                final addr = (p.plcAddress ?? '').trim();
                final cateId = (p.cateId ?? '').trim();

                if (addr.isEmpty) return null;

                final key = '$box|$addr';
                if (!seen.add(key)) return null;

                return SignalChartConfig(
                  boxDeviceId: box,
                  plcAddress: addr,
                  cateId: cateId.isEmpty ? null : cateId, // ✅ dùng single
                );
              })
              .whereType<SignalChartConfig>()
              .toList()
            ..sort((a, b) => a.plcAddress.compareTo(b.plcAddress));
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
