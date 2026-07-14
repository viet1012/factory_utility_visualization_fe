import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';
import '../utility_dashboard_overview_models/utility_minute_dashboard_response.dart';

class UtilityMinuteDashboardProvider extends ChangeNotifier {
  final UtilityDashboardOverviewApi api;

  UtilityMinuteDashboardProvider(this.api);

  static const Duration pollInterval = Duration(seconds: 50);

  static const Duration requestTimeout = Duration(seconds: 15);

  Timer? _pollTimer;

  bool _loading = false;
  bool _refreshing = false;
  bool _fetching = false;
  bool _disposed = false;

  Object? _error;

  int _requestToken = 0;

  String? _facId;
  int _minutes = 60;

  List<OverviewMinutePointDto> _electricity = const [];
  List<OverviewMinutePointDto> _water = const [];
  List<OverviewMinutePointDto> _air = const [];

  bool get loading => _loading;

  bool get refreshing => _refreshing;

  bool get fetching => _fetching;

  Object? get error => _error;

  String? get facId => _facId;

  int get minutes => _minutes;

  List<OverviewMinutePointDto> get electricity => _electricity;

  List<OverviewMinutePointDto> get water => _water;

  List<OverviewMinutePointDto> get air => _air;

  bool get hasData =>
      _electricity.isNotEmpty || _water.isNotEmpty || _air.isNotEmpty;

  bool get hasValidParams {
    final fac = _facId;

    return fac != null && fac.trim().isNotEmpty && _minutes > 0;
  }

  Future<void> start({required String facId, int minutes = 60}) async {
    if (_disposed) return;

    final normalizedFac = facId.trim();

    final normalizedMinutes = minutes <= 0 ? 60 : minutes.clamp(1, 24 * 60);

    final changed = normalizedFac != _facId || normalizedMinutes != _minutes;

    _facId = normalizedFac;
    _minutes = normalizedMinutes;

    _pollTimer?.cancel();

    if (changed) {
      /*
       * Vô hiệu hóa request cũ nếu FAC/minutes đổi
       * trong lúc request đó vẫn đang chạy.
       */
      _requestToken++;

      _electricity = const [];
      _water = const [];
      _air = const [];

      _error = null;
      _loading = true;
      _refreshing = false;
      _fetching = false;

      _safeNotifyListeners();
    }

    await load(force: changed);

    if (_disposed) return;

    _pollTimer = Timer.periodic(pollInterval, (_) {
      unawaited(load(silent: true));
    });
  }

  Future<void> load({bool silent = false, bool force = false}) async {
    if (_disposed) return;

    /*
     * Polling không tạo request trùng.
     * Khi đổi FAC thì force=true vẫn được phép chạy request mới.
     */
    if (_fetching && !force) return;

    if (!hasValidParams) {
      _loading = false;
      _refreshing = false;
      _fetching = false;

      _error = 'Missing facId or invalid minutes';

      _safeNotifyListeners();
      return;
    }

    final requestFac = _facId!;
    final requestMinutes = _minutes;

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
          .getMinuteDashboard(facId: requestFac, minutes: requestMinutes)
          .timeout(requestTimeout);

      if (!_isValidRequest(token)) return;

      _electricity = response.electricity;
      _water = response.water;
      _air = response.air;

      _error = null;
    } on TimeoutException catch (error, stackTrace) {
      _handleError(token, error, stackTrace, '[MINUTE DASHBOARD TIMEOUT]');
    } on DioException catch (error, stackTrace) {
      _handleError(
        token,
        error,
        stackTrace,
        '[MINUTE DASHBOARD DIO ${error.type}]',
      );
    } catch (error, stackTrace) {
      _handleError(token, error, stackTrace, '[MINUTE DASHBOARD ERROR]');
    } finally {
      if (_isValidRequest(token)) {
        _fetching = false;
        _loading = false;
        _refreshing = false;

        _safeNotifyListeners();
      }
    }
  }

  Future<void> refresh() {
    return load(silent: hasData, force: false);
  }

  void clear() {
    _requestToken++;

    _pollTimer?.cancel();
    _pollTimer = null;

    _electricity = const [];
    _water = const [];
    _air = const [];

    _error = null;
    _loading = false;
    _refreshing = false;
    _fetching = false;

    _safeNotifyListeners();
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

  bool _isValidRequest(int token) {
    return !_disposed && token == _requestToken;
  }

  void _safeNotifyListeners() {
    if (_disposed) return;

    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestToken++;

    _pollTimer?.cancel();
    _pollTimer = null;

    super.dispose();
  }
}
