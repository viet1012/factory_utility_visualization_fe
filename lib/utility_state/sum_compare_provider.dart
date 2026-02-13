import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utility_api/utility_api.dart';
import '../utility_models/response/sum_compare_item.dart';

class SumCompareProvider extends ChangeNotifier {
  final UtilityApi api;
  final Duration interval;

  SumCompareProvider({
    required this.api,
    this.interval = const Duration(seconds: 30),
  });

  Timer? _timer;
  bool _fetching = false;

  List<SumCompareItem> _rows = const [];
  Object? _error;
  DateTime? _lastUpdated;

  List<SumCompareItem> get rows => _rows;

  Object? get error => _error;

  DateTime? get lastUpdated => _lastUpdated;

  bool get isLoading => _rows.isEmpty && _error == null;

  // filter hiện tại (nếu bạn muốn đổi facId/scadaId...)
  String by = 'cate';
  String? facId, scadaId, cate, boxDeviceId;
  List<String>? deviceIds, cateIds, nameEns;

  Future<void> fetchNow() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final data = await api.sumCompare(
        by: by,
        facId: facId,
        scadaId: scadaId,
        cate: cate,
        boxDeviceId: boxDeviceId,
        deviceIds: deviceIds,
        cateIds: cateIds,
        nameEns: nameEns,
      );
      _rows = data;
      _error = null;
      _lastUpdated = DateTime.now();
      notifyListeners();
    } catch (e) {
      _error = e;
      notifyListeners();
    } finally {
      _fetching = false;
    }
  }

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => fetchNow());
    fetchNow();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void setFilter({
    String? by,
    String? facId,
    String? scadaId,
    String? cate,
    String? boxDeviceId,
    List<String>? deviceIds,
    List<String>? cateIds,

    // ✅ NEW
    List<String>? nameEns,
  }) {
    this.by = by ?? this.by;
    this.facId = facId;
    this.scadaId = scadaId;
    this.cate = cate;
    this.boxDeviceId = boxDeviceId;
    this.deviceIds = deviceIds;
    this.cateIds = cateIds;
    this.nameEns = nameEns;

    fetchNow();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
