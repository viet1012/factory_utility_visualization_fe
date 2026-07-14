import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

import '../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';
import '../utility_dashboard_overview_monthly/utility_overview_monthly_box.dart';

class UtilityMonthlySummaryProvider extends ChangeNotifier {
  final UtilityDashboardOverviewApi api;

  UtilityMonthlySummaryProvider(this.api);

  static const Duration pollInterval = Duration(hours: 6);

  Timer? _pollTimer;
  bool _notifyScheduled = false;

  bool _disposed = false;
  bool _fetching = false;

  bool _loading = false;
  bool _refreshing = false;
  bool _forceRefreshing = false;

  Object? _error;

  String? _facId;
  String? _month;

  int _requestToken = 0;

  List<EnergyMonthlySummary> _rows = const [];

  // ============================================================
  // GETTERS
  // ============================================================

  bool get loading => _loading;

  bool get refreshing => _refreshing;

  bool get forceRefreshing => _forceRefreshing;

  bool get fetching => _fetching;

  Object? get error => _error;

  String? get facId => _facId;

  String? get month => _month;

  List<EnergyMonthlySummary> get rows => _rows;

  bool get hasData => _rows.isNotEmpty;

  EnergyMonthlySummary? get electricity => _findByCate('ELECTRIC');

  EnergyMonthlySummary? get water => _findByCate('WATER');

  EnergyMonthlySummary? get air =>
      _findByCate('AIR') ?? _findByCate('COMPRESSED');

  // ============================================================
  // START / POLLING
  // ============================================================

  Future<void> start({required String facId, required String month}) async {
    if (_disposed) return;

    final normalizedFac = _normalizeFac(facId);

    final normalizedMonth = _normalizeMonth(month);

    final changed = normalizedFac != _facId || normalizedMonth != _month;

    _facId = normalizedFac;
    _month = normalizedMonth;

    _restartPollingTimerAfterLoad();

    if (changed) {
      _invalidateCurrentRequest();

      _rows = const [];
      _error = null;

      _loading = true;
      _refreshing = false;
      _forceRefreshing = false;
      _fetching = false;

      _safeNotify();
    }

    await load(force: changed);

    if (_disposed) return;

    _startPollingTimer();
  }

  void _startPollingTimer() {
    _pollTimer?.cancel();

    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (_disposed || _fetching || _forceRefreshing) {
        return;
      }

      unawaited(load(silent: true));
    });
  }

  void _restartPollingTimerAfterLoad() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // ============================================================
  // NORMAL GET
  // ============================================================

  Future<void> load({bool silent = false, bool force = false}) async {
    if (_disposed) return;

    if (_fetching && !force) {
      return;
    }

    final fac = _facId;
    final selectedMonth = _month;

    if (fac == null ||
        fac.isEmpty ||
        selectedMonth == null ||
        selectedMonth.isEmpty) {
      return;
    }

    final token = ++_requestToken;

    _fetching = true;
    _error = null;

    if (silent && hasData) {
      _refreshing = true;
    } else if (!hasData) {
      _loading = true;
    }

    _safeNotify();

    try {
      final data = await api.getMonthlySummary(
        facId: fac,
        month: selectedMonth,
      );

      if (!_isValid(token)) return;

      _rows = List<EnergyMonthlySummary>.unmodifiable(data);

      _error = null;
    } on TimeoutException catch (exception) {
      _handleError(token, exception, '[MONTHLY GET TIMEOUT]');
    } on DioException catch (exception) {
      _handleError(token, exception, '[MONTHLY GET DIO ${exception.type}]');
    } catch (exception, stackTrace) {
      _handleError(
        token,
        exception,
        '[MONTHLY GET ERROR]',
        stackTrace: stackTrace,
      );
    } finally {
      if (_isValid(token)) {
        _fetching = false;
        _loading = false;
        _refreshing = false;

        _safeNotify();
      }
    }
  }

  // ============================================================
  // FORCE REFRESH BACKEND CACHE
  // ============================================================

  Future<bool> forceRefresh() async {
    if (_disposed || _forceRefreshing || _fetching) {
      return false;
    }

    final fac = _facId;
    final selectedMonth = _month;

    if (fac == null ||
        fac.isEmpty ||
        selectedMonth == null ||
        selectedMonth.isEmpty) {
      return false;
    }

    final token = ++_requestToken;

    _pollTimer?.cancel();
    _pollTimer = null;

    _fetching = true;
    _forceRefreshing = true;
    _refreshing = hasData;
    _loading = !hasData;
    _error = null;

    _safeNotify();

    var success = false;

    try {
      final data = await api.forceRefreshMonthlySummary(
        facId: fac,
        month: selectedMonth,
      );

      if (!_isValid(token)) {
        return false;
      }

      _rows = List<EnergyMonthlySummary>.unmodifiable(data);

      _error = null;
      success = true;

      return true;
    } on TimeoutException catch (exception) {
      _handleError(token, exception, '[MONTHLY FORCE REFRESH TIMEOUT]');

      return false;
    } on DioException catch (exception) {
      _handleError(
        token,
        exception,
        '[MONTHLY FORCE REFRESH DIO ${exception.type}]',
      );

      return false;
    } catch (exception, stackTrace) {
      _handleError(
        token,
        exception,
        '[MONTHLY FORCE REFRESH ERROR]',
        stackTrace: stackTrace,
      );

      return false;
    } finally {
      if (_isValid(token)) {
        _fetching = false;
        _loading = false;
        _refreshing = false;
        _forceRefreshing = false;

        _safeNotify();

        if (!_disposed) {
          _startPollingTimer();
        }
      } else if (!success && !_disposed) {
        _startPollingTimer();
      }
    }
  }

  // ============================================================
  // RETRY
  // ============================================================

  Future<void> retry() {
    return load(force: true);
  }

  // ============================================================
  // CLEAR
  // ============================================================

  void clear() {
    if (_disposed) return;

    _invalidateCurrentRequest();

    _pollTimer?.cancel();
    _pollTimer = null;

    _facId = null;
    _month = null;

    _rows = const [];
    _error = null;

    _fetching = false;
    _loading = false;
    _refreshing = false;
    _forceRefreshing = false;

    _safeNotify();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  EnergyMonthlySummary? _findByCate(String keyword) {
    final normalizedKeyword = keyword.trim().toUpperCase();

    for (final item in _rows) {
      final cate = item.cate.trim().toUpperCase();

      if (cate.contains(normalizedKeyword)) {
        return item;
      }
    }

    return null;
  }

  void _handleError(
    int token,
    Object exception,
    String tag, {
    StackTrace? stackTrace,
  }) {
    if (!_isValid(token)) return;

    _error = exception;

    debugPrint('$tag $exception');

    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _normalizeFac(String facId) {
    final normalized = facId.trim();

    return normalized.isEmpty ? 'KVH' : normalized;
  }

  String _normalizeMonth(String month) {
    final normalized = month.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(normalized)) {
      throw ArgumentError.value(month, 'month', 'Month must use yyyyMM format');
    }

    final monthNumber = int.tryParse(normalized.substring(4, 6));

    if (monthNumber == null || monthNumber < 1 || monthNumber > 12) {
      throw ArgumentError.value(month, 'month', 'Invalid month value');
    }

    return normalized;
  }

  void _invalidateCurrentRequest() {
    _requestToken++;
  }

  bool _isValid(int token) {
    return !_disposed && token == _requestToken;
  }

  void _safeNotify() {
    if (_disposed) return;

    final binding = WidgetsBinding.instance;
    final phase = binding.schedulerPhase;

    final isBuilding =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;

    if (!isBuilding) {
      notifyListeners();
      return;
    }

    if (_notifyScheduled) return;

    _notifyScheduled = true;

    binding.addPostFrameCallback((_) {
      _notifyScheduled = false;

      if (_disposed) return;

      notifyListeners();
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _disposed = true;

    _invalidateCurrentRequest();

    _pollTimer?.cancel();
    _pollTimer = null;

    super.dispose();
  }
}
