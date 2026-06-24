import 'package:flutter/foundation.dart';

import '../utility_api/utility_api.dart';
import '../utility_models/f2_utility_scada_channel.dart';

class SignalChartConfig {
  final String boxDeviceId;
  final String plcAddress;

  final String? cateId;
  final List<String>? cateIds;

  final String? groupLabel;

  final String? nameEn;
  final String? nameVi;
  final String? unit;

  const SignalChartConfig({
    required this.boxDeviceId,
    required this.plcAddress,
    this.cateId,
    this.cateIds,
    this.groupLabel,
    this.nameEn,
    this.nameVi,
    this.unit,
  });
}

class ChartCatalogProvider extends ChangeNotifier {
  final UtilityApi api;

  ChartCatalogProvider(this.api);

  bool loading = false;
  Object? error;

  List<String> facs = [];
  List<String> cates = const ['Electricity', 'Water', 'Compressed Air'];

  List<String> scadaIds = [];
  List<String> boxIds = [];
  List<String> boxDeviceIds = [];
  List<SignalChartConfig> charts = [];

  List<ScadaChannelDto> _channels = [];

  String? _selectedScadaId;
  String? _selectedBoxId;

  String? get selectedScadaId => _selectedScadaId;

  String? get selectedBoxId => _selectedBoxId;

  Future<void> loadScadas({required String facId, required String cate}) async {
    loading = true;
    error = null;
    charts = [];
    scadaIds = [];
    boxIds = [];
    boxDeviceIds = [];
    _selectedScadaId = null;
    _selectedBoxId = null;
    notifyListeners();

    try {
      final channels = await api.getChannels(facId: facId, cate: cate);

      _channels = channels;

      final set = <String>{};

      for (final c in channels) {
        final v = c.scadaId.trim();
        if (v.isNotEmpty) {
          set.add(v);
        }
      }

      scadaIds = set.toList()..sort();

      if (scadaIds.isNotEmpty) {
        _selectedScadaId = scadaIds.first;
        _refreshBoxIdsForSelectedScada();
        _refreshBoxDeviceIdsForSelectedBox();
      }
    } catch (e) {
      error = e;
      _channels = [];
      scadaIds = [];
      boxIds = [];
      boxDeviceIds = [];
      charts = [];
      debugPrint('loadScadas error=$e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void selectScadaId(String scadaId) {
    final next = scadaId.trim();
    if (next.isEmpty) return;

    _selectedScadaId = next;
    _selectedBoxId = null;
    charts = [];

    _refreshBoxIdsForSelectedScada();

    if (boxIds.isNotEmpty) {
      _selectedBoxId = boxIds.first;
      _refreshBoxDeviceIdsForSelectedBox();
    } else {
      boxDeviceIds = [];
    }

    notifyListeners();
  }

  Future<void> loadBoxes({
    required String facId,
    required String cate,
    String? scadaId,
  }) async {
    if (_channels.isEmpty) {
      await loadScadas(facId: facId, cate: cate);
    }

    if (scadaId != null && scadaId.trim().isNotEmpty) {
      _selectedScadaId = scadaId.trim();
    }

    _refreshBoxIdsForSelectedScada();

    if (boxIds.isNotEmpty) {
      _selectedBoxId = boxIds.first;
      _refreshBoxDeviceIdsForSelectedBox();
    } else {
      _selectedBoxId = null;
      boxDeviceIds = [];
    }

    notifyListeners();
  }

  void selectBoxId(String boxId) {
    final next = boxId.trim();
    if (next.isEmpty) return;

    _selectedBoxId = next;
    _refreshBoxDeviceIdsForSelectedBox();
    charts = [];

    notifyListeners();
  }

  void _refreshBoxIdsForSelectedScada() {
    final scada = _selectedScadaId;

    if (scada == null || scada.isEmpty) {
      boxIds = [];
      return;
    }

    final set = <String>{};

    for (final c in _channels) {
      if (c.scadaId.trim() != scada) continue;

      final boxId = c.boxId.trim();
      if (boxId.isNotEmpty) {
        set.add(boxId);
      }
    }

    boxIds = set.toList()..sort();
  }

  void _refreshBoxDeviceIdsForSelectedBox() {
    final scada = _selectedScadaId;
    final box = _selectedBoxId;

    if (scada == null || scada.isEmpty || box == null || box.isEmpty) {
      boxDeviceIds = [];
      return;
    }

    final set = <String>{};

    for (final c in _channels) {
      if (c.scadaId.trim() != scada) continue;
      if (c.boxId.trim() != box) continue;

      final dev = c.boxDeviceId.trim();
      if (dev.isNotEmpty) {
        set.add(dev);
      }
    }

    boxDeviceIds = set.toList()..sort();
  }

  Future<void> loadChartsForBox({
    required String facId,
    required String cate,
    String? scadaId,
    required String boxDeviceId,
    int importantOnly = 0,
  }) async {
    loading = true;
    error = null;
    charts = [];
    notifyListeners();

    try {
      charts = await _buildChartsForSingleBox(
        facId: facId,
        cate: cate,
        boxDeviceId: boxDeviceId.trim(),
        importantOnly: importantOnly,
        addGroupLabel: false,
      );
    } catch (e) {
      error = e;
      debugPrint('loadChartsForBox error=$e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadChartsForBoxGroup({
    required String facId,
    required String cate,
    String? scadaId,
    int importantOnly = 0,
  }) async {
    loading = true;
    error = null;
    charts = [];
    notifyListeners();

    try {
      if (scadaId != null && scadaId.trim().isNotEmpty) {
        _selectedScadaId = scadaId.trim();
      }

      _refreshBoxDeviceIdsForSelectedBox();

      final boxes = List<String>.from(boxDeviceIds);

      if (boxes.isEmpty) {
        charts = [];
        return;
      }

      final results = await Future.wait(
        boxes.map(
          (box) => _buildChartsForSingleBox(
            facId: facId,
            cate: cate,
            boxDeviceId: box,
            importantOnly: importantOnly,
            addGroupLabel: true,
          ),
        ),
      );

      final merged = <SignalChartConfig>[for (final list in results) ...list];

      merged.sort((a, b) {
        final g = (a.groupLabel ?? '').compareTo(b.groupLabel ?? '');
        if (g != 0) return g;

        return a.plcAddress.compareTo(b.plcAddress);
      });

      charts = merged;
    } catch (e) {
      error = e;
      debugPrint('loadChartsForBoxGroup error=$e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<List<SignalChartConfig>> _buildChartsForSingleBox({
    required String facId,
    required String cate,
    required String boxDeviceId,
    required int importantOnly,
    required bool addGroupLabel,
  }) async {
    final ps =
        (await api.getParams(
          facId: facId,
          cate: cate,
          boxDeviceId: boxDeviceId,
          importantOnly: importantOnly,
        )).where((p) {
          final name = (p.nameEn ?? '').toString().toLowerCase();
          return !name.contains('slave');
        }).toList();

    final seen = <String>{};

    return ps
        .map((p) {
          final addr = (p.plcAddress ?? '').trim();
          final cateId = (p.cateId ?? '').trim();

          if (addr.isEmpty) return null;

          final key = '$boxDeviceId|$addr';

          if (!seen.add(key)) return null;

          return SignalChartConfig(
            boxDeviceId: boxDeviceId,
            plcAddress: addr,

            cateId: cateId.isEmpty ? null : cateId,
            cateIds: cateId.isEmpty ? null : [cateId],

            nameEn: p.nameEn,
            nameVi: p.nameVi,
            unit: p.unit,

            groupLabel: addGroupLabel ? boxDeviceId : null,
          );
        })
        .whereType<SignalChartConfig>()
        .toList()
      ..sort((a, b) => a.plcAddress.compareTo(b.plcAddress));
  }
}
