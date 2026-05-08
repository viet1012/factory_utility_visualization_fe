import 'package:flutter/foundation.dart';

import '../utility_api/utility_api.dart';
import '../utility_models/f2_utility_scada_channel.dart';

class SignalChartConfig {
  final String boxDeviceId;
  final String plcAddress;
  final String? cateId;
  final List<String>? cateIds;

  /// dùng khi xem ALL devices trong 1 BoxId
  final String? groupLabel;

  const SignalChartConfig({
    required this.boxDeviceId,
    required this.plcAddress,
    this.cateId,
    this.cateIds,
    this.groupLabel,
  });

  SignalChartConfig copyWith({
    String? boxDeviceId,
    String? plcAddress,
    String? cateId,
    List<String>? cateIds,
    String? groupLabel,
  }) {
    return SignalChartConfig(
      boxDeviceId: boxDeviceId ?? this.boxDeviceId,
      plcAddress: plcAddress ?? this.plcAddress,
      cateId: cateId ?? this.cateId,
      cateIds: cateIds ?? this.cateIds,
      groupLabel: groupLabel ?? this.groupLabel,
    );
  }
}

class ChartCatalogProvider extends ChangeNotifier {
  final UtilityApi api;

  ChartCatalogProvider(this.api);

  bool loading = false;
  Object? error;

  List<String> facs = [];
  List<String> cates = const ['Electricity', 'Water', 'Compressed Air'];

  List<String> boxIds = [];
  List<String> boxDeviceIds = [];
  List<SignalChartConfig> charts = [];

  List<ScadaChannelDto> _channels = [];
  String? _selectedBoxId;

  String? get selectedBoxId => _selectedBoxId;

  Future<void> loadFacs() async {
    // TODO: implement if needed
  }

  Future<void> loadBoxes({required String facId, required String cate}) async {
    loading = true;
    error = null;
    charts = [];
    boxIds = [];
    boxDeviceIds = [];
    _selectedBoxId = null;
    notifyListeners();

    try {
      final channels = await api.getChannels(facId: facId, cate: cate);
      _channels = channels;

      final boxIdSet = <String>{};
      for (final c in channels) {
        final v = c.boxId.trim();
        if (v.isNotEmpty) {
          boxIdSet.add(v);
        }
      }

      boxIds = boxIdSet.toList()..sort();

      if (boxIds.isNotEmpty) {
        _selectedBoxId = boxIds.first;
        _refreshBoxDeviceIdsForSelectedBox();
      } else {
        _selectedBoxId = null;
        boxDeviceIds = [];
      }
    } catch (e) {
      error = e;
      _channels = [];
      boxIds = [];
      boxDeviceIds = [];
      _selectedBoxId = null;
      charts = [];
      debugPrint('loadBoxes error=$e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void selectBoxId(String boxId) {
    final next = boxId.trim();
    if (next.isEmpty) return;

    _selectedBoxId = next;
    _refreshBoxDeviceIdsForSelectedBox();
    charts = [];
    notifyListeners();
  }

  void _refreshBoxDeviceIdsForSelectedBox() {
    final selected = _selectedBoxId;
    if (selected == null || selected.isEmpty) {
      boxDeviceIds = [];
      return;
    }

    final deviceSet = <String>{};
    for (final c in _channels) {
      if (c.boxId.trim() != selected) continue;

      final v = c.boxDeviceId.trim();
      if (v.isNotEmpty) {
        deviceSet.add(v);
      }
    }

    boxDeviceIds = deviceSet.toList()..sort();
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
    int importantOnly = 0,
  }) async {
    loading = true;
    error = null;
    charts = [];
    notifyListeners();

    try {
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
    ////////////////////////////////////////////////////////////
    /// API + FILTER SLAVE
    ////////////////////////////////////////////////////////////
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
            groupLabel: addGroupLabel ? boxDeviceId : null,
          );
        })
        .whereType<SignalChartConfig>()
        .toList()
      ..sort((a, b) => a.plcAddress.compareTo(b.plcAddress));
  }
}
