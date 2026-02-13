import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utility_models/response/latest_record.dart';
import '../utility_models/utility_facade_service.dart';

class FacLatestDetailProvider extends ChangeNotifier {
  final UtilityFacadeService svc;
  final String facId;

  FacLatestDetailProvider({required this.svc, required this.facId});

  List<LatestRecordDto> rows = [];
  bool loading = false;
  Object? error;
  DateTime? lastUpdated;

  Timer? _timer;

  Future<void> fetch({bool silent = false}) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final r = await svc.getLatestByFac(facId);
      rows = r;
      lastUpdated = DateTime.now();
      error = null;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void startPolling([Duration interval = const Duration(seconds: 10)]) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => fetch(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
