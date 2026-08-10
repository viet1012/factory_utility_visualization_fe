import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';
import '../utility_dashboard_overview_models/utility_daily_dashboard_response.dart';

class UtilityDailyDashboardProvider extends ChangeNotifier {
  final UtilityDashboardOverviewApi api;

  UtilityDailyDashboardProvider(this.api);

  static const Duration pollInterval = Duration(hours: 1);
  static const Duration requestTimeout = Duration(seconds: 30);

  Timer? _pollTimer;

  bool _notifyScheduled = false;
  bool _loading = false;
  bool _refreshing = false;
  bool _fetching = false;
  bool _disposed = false;

  Object? _error;

  int _requestToken = 0;

  String? _facId;
  String? _month;

  List<UtilityDailyElectricityPoint> _electricity =
      const <UtilityDailyElectricityPoint>[];

  List<UtilityDailyPoint> _water = const <UtilityDailyPoint>[];

  List<UtilityDailyPoint> _air = const <UtilityDailyPoint>[];

  // ============================================================
  // GETTERS
  // ============================================================

  bool get loading => _loading;

  bool get refreshing => _refreshing;

  bool get fetching => _fetching;

  Object? get error => _error;

  String? get facId => _facId;

  String? get month => _month;

  List<UtilityDailyElectricityPoint> get electricity => _electricity;

  List<UtilityDailyPoint> get water => _water;

  List<UtilityDailyPoint> get air => _air;

  bool get hasData =>
      _electricity.isNotEmpty || _water.isNotEmpty || _air.isNotEmpty;

  bool get hasValidParams {
    final fac = _facId;
    final month = _month;

    if (fac == null || fac.trim().isEmpty) {
      return false;
    }

    if (month == null) {
      return false;
    }

    return _isValidMonth(month);
  }

  // ============================================================
  // START
  // ============================================================

  Future<void> start({required String facId, required String month}) async {
    if (_disposed) return;

    final normalizedFac = _normalizeFac(facId);
    final normalizedMonth = _normalizeMonth(month);

    final changed = normalizedFac != _facId || normalizedMonth != _month;

    _stopPolling();

    if (changed) {
      _invalidateCurrentRequest();

      _facId = normalizedFac;
      _month = normalizedMonth;

      _electricity = const <UtilityDailyElectricityPoint>[];

      _water = const <UtilityDailyPoint>[];

      _air = const <UtilityDailyPoint>[];

      _error = null;

      _fetching = false;
      _loading = true;
      _refreshing = false;

      _safeNotifyListeners();
    } else {
      _facId = normalizedFac;
      _month = normalizedMonth;
    }

    await load(silent: !changed && hasData, force: changed);

    if (_disposed) return;

    _scheduleNextPoll();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> load({bool silent = false, bool force = false}) async {
    if (_disposed) return;

    if (_fetching && !force) {
      return;
    }

    if (!hasValidParams) {
      _fetching = false;
      _loading = false;
      _refreshing = false;

      _error = 'Missing facId or invalid month format yyyyMM';

      _safeNotifyListeners();
      return;
    }

    final requestFacId = _facId!;
    final requestMonth = _month!;

    final token = ++_requestToken;

    _fetching = true;
    _error = null;

    if (silent && hasData) {
      _refreshing = true;
      _loading = false;
    } else {
      _loading = true;
      _refreshing = false;
    }

    _safeNotifyListeners();

    try {
      final response = await api
          .getDailyDashboard(facId: requestFacId, month: requestMonth)
          .timeout(requestTimeout);

      if (!_isValidRequest(token)) {
        return;
      }

      _electricity = List<UtilityDailyElectricityPoint>.unmodifiable(
        response.electricity,
      );

      _water = List<UtilityDailyPoint>.unmodifiable(response.water);

      _air = List<UtilityDailyPoint>.unmodifiable(response.air);

      _error = null;
    } on TimeoutException catch (error, stackTrace) {
      _handleError(token, error, stackTrace, '[DAILY DASHBOARD TIMEOUT]');
    } on DioException catch (error, stackTrace) {
      _handleError(
        token,
        error,
        stackTrace,
        '[DAILY DASHBOARD DIO ${error.type}]',
      );
    } catch (error, stackTrace) {
      _handleError(token, error, stackTrace, '[DAILY DASHBOARD ERROR]');
    } finally {
      if (_isValidRequest(token)) {
        _fetching = false;
        _loading = false;
        _refreshing = false;

        _safeNotifyListeners();
      }
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> refresh() async {
    if (_disposed || _fetching) {
      return;
    }

    _stopPolling();

    await load(silent: hasData, force: false);

    if (_disposed) return;

    _scheduleNextPoll();
  }

  // ============================================================
  // POLLING
  // ============================================================

  void _scheduleNextPoll() {
    if (_disposed || !hasValidParams) {
      return;
    }

    _stopPolling();

    _pollTimer = Timer(pollInterval, () async {
      if (_disposed) return;

      await load(silent: true, force: false);

      if (_disposed) return;

      _scheduleNextPoll();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // ============================================================
  // CLEAR
  // ============================================================

  void clear() {
    if (_disposed) return;

    _invalidateCurrentRequest();
    _stopPolling();

    _facId = null;
    _month = null;

    _electricity = const <UtilityDailyElectricityPoint>[];

    _water = const <UtilityDailyPoint>[];

    _air = const <UtilityDailyPoint>[];

    _error = null;

    _fetching = false;
    _loading = false;
    _refreshing = false;

    _safeNotifyListeners();
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _handleError(
    int token,
    Object error,
    StackTrace stackTrace,
    String tag,
  ) {
    if (!_isValidRequest(token)) {
      return;
    }

    _error = error;

    debugPrint('$tag $error');

    debugPrintStack(stackTrace: stackTrace);
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  String _normalizeFac(String facId) {
    final normalized = facId.trim();

    return normalized.isEmpty ? 'KVH' : normalized;
  }

  String _normalizeMonth(String month) {
    final normalized = month.trim();

    if (!_isValidMonth(normalized)) {
      throw ArgumentError.value(
        month,
        'month',
        'Month must use yyyyMM format, '
            'for example 202608',
      );
    }

    return normalized;
  }

  bool _isValidMonth(String value) {
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return false;
    }

    final monthNumber = int.tryParse(value.substring(4, 6));

    return monthNumber != null && monthNumber >= 1 && monthNumber <= 12;
  }

  // ============================================================
  // REQUEST TOKEN
  // ============================================================

  void _invalidateCurrentRequest() {
    _requestToken++;
  }

  bool _isValidRequest(int token) {
    return !_disposed && token == _requestToken;
  }

  // ============================================================
  // NOTIFY
  // ============================================================

  void _safeNotifyListeners() {
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

    if (_notifyScheduled) {
      return;
    }

    _notifyScheduled = true;

    binding.addPostFrameCallback((_) {
      _notifyScheduled = false;

      if (_disposed) return;

      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;

    _invalidateCurrentRequest();
    _stopPolling();

    super.dispose();
  }
}
