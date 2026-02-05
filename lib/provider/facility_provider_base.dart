import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/ApiService.dart';
import '../model/dashboard_response.dart';
import '../model/facility_filtered.dart';

abstract class FacilityProviderBase extends ChangeNotifier {
  FacilityProviderBase({ApiService? api, this.debugLog = false})
      : _api = api ?? ApiService();

  final ApiService _api;
  final bool debugLog;

  List<FacilityFiltered> _facilities = [];
  List<FacilityFiltered> _prevFacilities = []; // ✅ thêm prev snapshot

  bool _isLoading = false;

  Timer? _timer;
  bool _inFlight = false;
  Set<String> _plcSet = const {};

  List<FacilityFiltered> get facilities => _facilities;
  List<FacilityFiltered> get prevFacilities => _prevFacilities; // ✅ getter

  bool get isLoading => _isLoading;

  /// implement ở provider con
  Future<DashboardResponse> loadDashboard({
    required List<String> plcAddresses,
  });

  Future<void> fetchFacilities(List<String> plcAddresses) async {
    _plcSet = _normalizePlcSet(plcAddresses);

    if (_inFlight) return;
    _inFlight = true;

    _setLoading(true);
    try {
      final data = await loadDashboard(plcAddresses: _plcSet.toList());
      final nextFacilities = _filterFacilities(data, _plcSet);

      // ✅ chỉ cập nhật prev khi có data trước đó
      if (_facilities.isNotEmpty) {
        _prevFacilities = _facilities;
      }

      _facilities = nextFacilities;

      if (debugLog) _logFacilities(_facilities);

      // ✅ now/prev đổi -> notify
      notifyListeners();
    } catch (e, st) {
      debugPrint("⚠️ fetchFacilities error: $e");
      if (kDebugMode) debugPrintStack(stackTrace: st);
    } finally {
      _setLoading(false);
      _inFlight = false;
    }
  }

  void startAutoRefresh(
      List<String> plcAddresses, {
        Duration interval = const Duration(seconds: 60),
        bool runImmediately = true,
      }) {
    stopAutoRefresh();
    _plcSet = _normalizePlcSet(plcAddresses);

    if (runImmediately) {
      unawaited(fetchFacilities(_plcSet.toList()));
    }

    _timer = Timer.periodic(interval, (_) {
      unawaited(fetchFacilities(_plcSet.toList()));
    });
  }

  void stopAutoRefresh() {
    _timer?.cancel();
    _timer = null;
  }

  void updatePlcAddresses(List<String> plcAddresses) {
    _plcSet = _normalizePlcSet(plcAddresses);
    unawaited(fetchFacilities(_plcSet.toList()));
  }

  Set<String> _normalizePlcSet(List<String> plcAddresses) {
    return plcAddresses
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e.trim())
        .toSet();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  List<FacilityFiltered> _filterFacilities(
      DashboardResponse data,
      Set<String> plcSet,
      ) {
    if (plcSet.isEmpty) return [];

    return data.facilities
        .map((facility) {
      final filteredSignals =
      facility.signals.where((s) => plcSet.contains(s.plcAddress)).toList();

      if (filteredSignals.isEmpty) return null;

      return FacilityFiltered(
        fac: facility.fac,
        facName: facility.facName,
        signals: filteredSignals,
      );
    })
        .whereType<FacilityFiltered>()
        .toList();
  }

  void _logFacilities(List<FacilityFiltered> list) {
    for (final f in list) {
      debugPrint("---- Facility: ${f.fac} | ${f.facName} ----");
      for (final s in f.signals) {
        debugPrint(
          "  PLC: ${s.plcAddress}, Value: ${s.value}, Type: ${s.dataType}, Desc: ${s.description}",
        );
      }
    }
  }

  ApiService get api => _api;

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}
