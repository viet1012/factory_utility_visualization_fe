import 'dart:async';

import 'package:flutter/material.dart';

import '../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';

class SignalHealthMatrixController extends ChangeNotifier {
  final UtilityDashboardOverviewApi api;

  SignalHealthMatrixController(this.api);

  static const Duration requestTimeout = Duration(seconds: 50);
  static const Duration refreshInterval = Duration(minutes: 5);

  Timer? _timer;

  bool loading = true;
  bool refreshing = false;
  bool fetching = false;
  Object? error;

  int _requestId = 0;

  List<Map<String, dynamic>> data = [];
  Map<String, dynamic>? selected;

  void startPolling() {
    _timer?.cancel();

    load();

    _timer = Timer.periodic(refreshInterval, (_) {
      load(silent: true);
    });
  }

  Future<List<Map<String, dynamic>>> _fetchMatrix() {
    return api.getSignalHealthMatrix().timeout(requestTimeout);
  }

  Future<void> load({bool silent = false}) async {
    if (fetching) return;

    fetching = true;
    final requestId = ++_requestId;

    final hasOldData = data.isNotEmpty;
    final oldBoxDeviceId = selected?['boxDeviceId']?.toString();

    if (!silent && !hasOldData) {
      loading = true;
      error = null;
      notifyListeners();
    }

    if (silent && hasOldData) {
      refreshing = true;
    }

    try {
      final newData = await _fetchMatrix();

      if (requestId != _requestId) return;

      data = newData;
      selected = _findSelectedDevice(newData, oldBoxDeviceId);
      loading = false;
      refreshing = false;
      error = null;

      notifyListeners();
    } catch (e) {
      if (requestId != _requestId) return;

      loading = false;
      refreshing = false;

      if (data.isEmpty) {
        error = e;
        notifyListeners();
      } else {
        error = null;
        notifyListeners();
      }
    } finally {
      if (requestId == _requestId) {
        fetching = false;
      }
    }
  }

  void select(Map<String, dynamic> item) {
    selected = item;
    notifyListeners();
  }

  int get totalFac => data.map((e) => e['fac']).toSet().length;

  int get totalBoxDevice => data.length;

  int get totalRegister =>
      data.fold<int>(0, (sum, e) => sum + _toInt(e['totalRegisters']));

  int get totalNgRegister =>
      data.fold<int>(0, (sum, e) => sum + _toInt(e['ngRegisters']));

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Map<String, dynamic>? _findSelectedDevice(
    List<Map<String, dynamic>> newData,
    String? oldBoxDeviceId,
  ) {
    if (newData.isEmpty) return null;

    if (oldBoxDeviceId != null) {
      for (final row in newData) {
        if ('${row['boxDeviceId']}' == oldBoxDeviceId) {
          return row;
        }
      }
    }

    return newData.first;
  }

  String get lastUpdated {
    String latest = '-';

    for (final device in data) {
      for (final signal in device['signals'] ?? []) {
        final time = '${signal['recordedAt'] ?? ''}';
        if (time.isNotEmpty && (latest == '-' || time.compareTo(latest) > 0)) {
          latest = time;
        }
      }
    }

    return latest;
  }

  @override
  void dispose() {
    _requestId++;
    _timer?.cancel();
    super.dispose();
  }
}
