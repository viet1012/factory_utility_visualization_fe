import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/utility_dashboard_overview_api.dart';
import '../models/utility_hourly_dashboard_response.dart';

class UtilityHourlyDashboardProvider extends ChangeNotifier {
  final UtilityDashboardOverviewApi api;

  UtilityHourlyDashboardProvider(this.api);

  static const Duration requestTimeout = Duration(seconds: 15);

  bool _loading = false;
  bool _refreshing = false;
  bool _fetching = false;
  bool _disposed = false;

  Object? _error;

  int _requestToken = 0;

  String? _facId;
  int _hours = 48;
  String? _nameEn;

  List<HourlyEnergyPoint> _electricity = const [];
  List<HourlySensorPoint> _water = const [];
  List<HourlySensorPoint> _air = const [];

  bool get loading => _loading;

  bool get refreshing => _refreshing;

  bool get fetching => _fetching;

  Object? get error => _error;

  String? get facId => _facId;

  int get hours => _hours;

  List<HourlyEnergyPoint> get electricity => _electricity;

  List<HourlySensorPoint> get water => _water;

  List<HourlySensorPoint> get air => _air;

  bool get hasData =>
      _electricity.isNotEmpty || _water.isNotEmpty || _air.isNotEmpty;

  bool get hasValidParams => _facId != null && _facId!.isNotEmpty;

  void configure({
    required String facId,
    int hours = 48,
    String? nameEn,
  }) {
    if (_disposed) return;

    final normalizedFac = facId.trim();
    final normalizedHours = hours <= 0 ? 48 : hours.clamp(1, 168);

    final normalizedName = nameEn?.trim();

    final changed =
        normalizedFac != _facId ||
        normalizedHours != _hours ||
        normalizedName != _nameEn;

    _facId = normalizedFac;
    _hours = normalizedHours;
    _nameEn = normalizedName;

    if (changed) {
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
  }

  Future<void> load({bool silent = false}) async {
    if (_fetching || _disposed) return;

    if (!hasValidParams) {
      _loading = false;
      _refreshing = false;
      _error = 'Missing facId';

      _safeNotifyListeners();
      return;
    }

    final facId = _facId!;
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
          .getHourlyDashboard(facId: facId, hours: _hours, nameEn: _nameEn)
          .timeout(requestTimeout);

      if (!_isValidRequest(token)) return;

      _electricity = response.electricity;
      _water = response.water;
      _air = response.air;

      _error = null;
    } on TimeoutException catch (error, stackTrace) {
      _handleError(token, error, stackTrace, '[HOURLY DASHBOARD TIMEOUT]');
    } on DioException catch (error, stackTrace) {
      _handleError(
        token,
        error,
        stackTrace,
        '[HOURLY DASHBOARD DIO ${error.type}]',
      );
    } catch (error, stackTrace) {
      _handleError(token, error, stackTrace, '[HOURLY DASHBOARD ERROR]');
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
    return load(silent: hasData);
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

    super.dispose();
  }
}
