import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/state/safe_change_notifier.dart';
import '../api/power_usage_api.dart';
import '../model/power_usage.dart';

/// MONITORING › Electricity. Doi toggle thi tai lai ngay (giu data cu, mo di);
/// polling 1 phut chi tai khi dang xem hom nay.
class PowerUsageController extends ChangeNotifier with SafeChangeNotifier {
  final PowerUsageApi _api;

  PowerUsageController({required PowerUsageApi api}) : _api = api;

  PowerUsageResponse? _data;
  String? _error;
  bool _loading = false;
  PowerPeriod _period = PowerPeriod.day;
  PowerUnit _unit = PowerUnit.kwh;
  DateTime _date = _today();

  /// true: [_date] luon theo ngay hien tai (qua nua dem tu sang ngay moi).
  bool _followToday = true;

  CancelToken? _cancelToken;
  int _requestSeq = 0;
  bool _disposed = false;

  PowerUsageResponse? get data => _data;
  String? get error => _error;
  bool get loading => _loading;
  bool get hasData => _data != null;
  PowerPeriod get period => _period;
  DateTime get date => _date;

  /// USD chi dung duoc khi backend tra total.usd.
  bool get usdAvailable => _data?.total.usd != null;

  PowerUnit get unit => usdAvailable ? _unit : PowerUnit.kwh;

  bool get isViewingToday => _sameDay(_date, _today());

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void setUnit(PowerUnit unit) {
    if (_unit == unit) return;
    _unit = unit;
    safeNotify();
  }

  Future<void> setPeriod(PowerPeriod period) {
    if (_period == period) return Future.value();
    _period = period;
    return load();
  }

  Future<void> setDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    _followToday = _sameDay(day, _today());
    if (_sameDay(_date, day)) return Future.value();
    _date = day;
    return load();
  }

  /// Task polling (scope electricity): chi lam moi khi dang xem hom nay hoac
  /// chua co data.
  Future<void> poll() {
    if (_followToday) _date = _today();
    if (hasData && !isViewingToday) return Future.value();
    return load();
  }

  Future<void> retry() => load();

  Future<void> load() async {
    if (_disposed) return;

    _cancelToken?.cancel();
    final cancelToken = _cancelToken = CancelToken();
    final seq = ++_requestSeq;

    _loading = true;
    safeNotify();

    try {
      final result = await _api.fetch(
        date: _date,
        period: _period,
        cancelToken: cancelToken,
      );
      if (_disposed || seq != _requestSeq) return;

      _data = result;
      _error = null;
    } catch (e) {
      if (_disposed || seq != _requestSeq || cancelToken.isCancelled) return;
      _error = e.toString();
    } finally {
      if (!_disposed && seq == _requestSeq) {
        _loading = false;
        safeNotify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelToken?.cancel();
    super.dispose();
  }
}
