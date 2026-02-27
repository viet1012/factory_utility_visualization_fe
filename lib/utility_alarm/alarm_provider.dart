// lib/utility_state/alarm_provider.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'alarm_api.dart';
import 'alarm_event.dart';

class AlarmProvider extends ChangeNotifier {
  final AlarmApi api;
  final Duration interval;

  AlarmProvider({
    required this.api,
    this.interval = const Duration(seconds: 15),
  });

  Timer? _timer;

  bool _loading = false;
  Object? _error;
  List<AlarmEvent> _items = const [];

  // filters
  String? facId;
  String? cate;
  bool? acked; // null = all
  String q = '';

  bool get loading => _loading;

  Object? get error => _error;

  List<AlarmEvent> get items => _items;

  int get alarmCount =>
      _items.where((e) => !e.acked && e.severity == AlarmSeverity.alarm).length;

  int get warningCount => _items
      .where((e) => !e.acked && e.severity == AlarmSeverity.warning)
      .length;

  int get offlineCount => _items
      .where((e) => !e.acked && e.severity == AlarmSeverity.offline)
      .length;

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => fetch());
    fetch();
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  Future<void> fetch() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await api.fetchAlarms(
        facId: facId,
        cate: cate,
        acked: acked,
        q: q,
      );
      _items = res;
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setFilters({String? facId, String? cate, bool? acked, String? q}) {
    this.facId = facId;
    this.cate = cate;
    this.acked = acked;
    if (q != null) this.q = q;
    fetch();
  }

  Future<void> ack(String id) async {
    await api.ackAlarm(id, ackBy: 'operator');

    // optimistic update UI
    _items = _items
        .map(
          (e) => e.id == id
              ? e.copyWith(
                  acked: true,
                  ackBy: 'operator',
                  ackAt: DateTime.now(),
                )
              : e,
        )
        .toList();
    notifyListeners();
  }
}
