import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

import '../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';
import '../utility_dashboard_overview_models/utility_daily_dashboard_response.dart';

class UtilityDailyDashboardProvider extends ChangeNotifier {
  final UtilityDashboardOverviewApi api;

  UtilityDailyDashboardProvider(this.api);

  static const Duration pollInterval = Duration(hours: 1);

  static const Duration requestTimeout = Duration(seconds: 15);

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

  List<UtilityDailyPoint> _electricity = const [];
  List<UtilityDailyPoint> _water = const [];
  List<UtilityDailyPoint> _air = const [];

  bool get loading => _loading;

  bool get refreshing => _refreshing;

  bool get fetching => _fetching;

  Object? get error => _error;

  String? get facId => _facId;

  String? get month => _month;

  List<UtilityDailyPoint> get electricity => _electricity;

  List<UtilityDailyPoint> get water => _water;

  List<UtilityDailyPoint> get air => _air;

  bool get hasData =>
      _electricity.isNotEmpty || _water.isNotEmpty || _air.isNotEmpty;

  bool get hasValidParams {
    final fac = _facId;
    final month = _month;

    return fac != null &&
        fac.isNotEmpty &&
        month != null &&
        RegExp(r'^\d{6}$').hasMatch(month);
  }

  Future<void> start({required String facId, required String month}) async {
    final normalizedFac = facId.trim();
    final normalizedMonth = month.trim();

    final changed = normalizedFac != _facId || normalizedMonth != _month;

    _facId = normalizedFac;
    _month = normalizedMonth;

    _pollTimer?.cancel();

    if (changed) {
      _electricity = const [];
      _water = const [];
      _air = const [];
      _error = null;
      _loading = true;
      _refreshing = false;
      _safeNotifyListeners();
    }

    await load();

    if (_disposed) return;

    _pollTimer = Timer.periodic(pollInterval, (_) {
      unawaited(load(silent: true));
    });
  }

  Future<void> load({bool silent = false}) async {
    if (_fetching || _disposed) return;

    if (!hasValidParams) {
      _loading = false;
      _refreshing = false;
      _error = 'Missing facId or invalid month format yyyyMM';
      _safeNotifyListeners();
      return;
    }

    final facId = _facId!;
    final month = _month!;
    final token = ++_requestToken;

    _fetching = true;
    _error = null;

    if (silent && hasData) {
      _refreshing = true;
    } else {
      _loading = true;
    }

    _safeNotifyListeners();

    try {
      final response = await api
          .getDailyDashboard(facId: facId, month: month)
          .timeout(requestTimeout);

      if (!_isValidRequest(token)) return;

      _electricity = response.electricity;
      _water = response.water;
      _air = response.air;

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

  void _handleError(
    int token,
    Object error,
    StackTrace stackTrace,
    String tag,
  ) {
    if (!_isValidRequest(token)) return;

    _error = error;

    debugPrint('$tag $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  Future<void> refresh() {
    return load(silent: hasData);
  }

  void clear() {
    _requestToken++;

    _electricity = const [];
    _water = const [];
    _air = const [];

    _error = null;
    _loading = false;
    _refreshing = false;
    _fetching = false;

    _safeNotifyListeners();
  }

  bool _isValidRequest(int token) {
    return !_disposed && token == _requestToken;
  }

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

    if (_notifyScheduled) return;

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
    _requestToken++;

    _pollTimer?.cancel();

    super.dispose();
  }
}
