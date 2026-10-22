import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../shared/state/safe_change_notifier.dart';
import '../api/water_check_api.dart';
import '../models/water_check_models.dart';

/// Du lieu cua tab WATER CHECK. Loi tai lai giu du lieu cu (UI hien banner).
class WaterCheckController extends ChangeNotifier with SafeChangeNotifier {
  final WaterCheckApi api;

  WaterCheckController({required this.api});

  WaterCheckResponse? _data;
  Object? _error;
  bool _loading = false;
  bool _disposed = false;
  CancelToken? _cancelToken;

  WaterCheckResponse? get data => _data;
  Object? get error => _error;
  bool get loading => _loading;
  bool get hasData => _data != null;

  /// Action cua PollingCoordinator: nem lai loi de khong tinh la lan chay
  /// thanh cong.
  Future<void> refresh() async {
    if (_disposed) return;

    _cancelToken?.cancel();
    final token = _cancelToken = CancelToken();

    _loading = true;
    safeNotify();

    try {
      final next = await api.fetch(cancelToken: token);
      if (_disposed || token.isCancelled) return;

      _logPoll(_data, next);
      _data = next;
      _error = null;
    } catch (error) {
      if (_disposed || token.isCancelled) return;

      _error = error;
      rethrow;
    } finally {
      if (!_disposed && identical(token, _cancelToken)) {
        _loading = false;
        safeNotify();
      }
    }
  }

  /// "[WATER] poll HH:mm:ss · signals N · changed M": M = diem do moi hoac
  /// doi value / rawValue / status / recordedAt so voi lan truoc.
  static void _logPoll(WaterCheckResponse? prev, WaterCheckResponse next) {
    if (!kDebugMode) return;

    String fingerprint(WaterSignal s) =>
        '${s.value}|${s.rawValue}|${s.status.code}|${s.recordedAt}';

    final before = <String, String>{
      if (prev != null)
        for (final fac in prev.facilities)
          for (final s in fac.signals)
            waterSignalKey(fac.facId, s.boxDeviceId, s.plcAddress):
                fingerprint(s),
    };

    var total = 0;
    var changed = 0;
    for (final fac in next.facilities) {
      for (final s in fac.signals) {
        total++;
        final key = waterSignalKey(fac.facId, s.boxDeviceId, s.plcAddress);
        if (before[key] != fingerprint(s)) changed++;
      }
    }

    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    debugPrint(
      '[WATER] poll ${two(now.hour)}:${two(now.minute)}:${two(now.second)} '
      '· signals $total · changed $changed',
    );
  }

  /// Nut Retry: loi da hien tren UI, khong nem tiep.
  Future<void> retry() async {
    try {
      await refresh();
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelToken?.cancel();
    super.dispose();
  }
}
