import 'package:flutter/foundation.dart';

import '../utility_api/utility_api.dart';

class SignalChartConfig {
  final String boxDeviceId;
  final String plcAddress;
  final String? cateId;
  final List<String>? cateIds;

  const SignalChartConfig({
    required this.boxDeviceId,
    required this.plcAddress,
    this.cateId,
    this.cateIds,
  });
}

class ChartCatalogProvider extends ChangeNotifier {
  final UtilityApi api;

  ChartCatalogProvider(this.api);

  bool loading = false;
  Object? error;

  List<String> facs = [];
  List<String> cates = const ['Electricity', 'Water', 'Compressed Air'];

  List<String> boxDeviceIds = [];
  List<SignalChartConfig> charts = [];

  Future<void> loadFacs() async {
    // TODO: implement if needed
  }

  Future<void> loadBoxes({required String facId, required String cate}) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final channels = await api.getChannels(facId: facId, cate: cate);

      debugPrint('=== /channels facId=$facId cate=$cate');
      debugPrint('channels.length=${channels.length}');

      for (final c in channels.take(20)) {
        debugPrint('  - boxDeviceId=${c.boxDeviceId}  scadaId=${c.scadaId}');
      }

      final set = <String>{};
      for (final c in channels) {
        final v = c.boxDeviceId.trim();
        if (v.isNotEmpty) {
          set.add(v);
        }
      }

      boxDeviceIds = set.toList()..sort();
      charts = [];

      debugPrint('boxDeviceIds (${boxDeviceIds.length}):');
      for (final b in boxDeviceIds) {
        debugPrint('  • $b');
      }
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
        importantOnly: importantOnly,
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
                  cateId: cateId.isEmpty ? null : cateId,
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
