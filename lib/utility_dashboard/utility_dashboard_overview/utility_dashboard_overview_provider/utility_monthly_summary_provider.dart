import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';
import '../utility_dashboard_overview_monthly/utility_overview_monthly_box.dart';

class UtilityMonthlySummaryProvider extends ChangeNotifier {
  final UtilityDashboardOverviewApi api;

  UtilityMonthlySummaryProvider(this.api);

  // ============================================================
  // CONFIG
  // ============================================================

  static const Duration pollInterval = Duration(hours: 6);

  static const Duration requestTimeout = Duration(seconds: 45);

  static const Duration forceRefreshTimeout = Duration(seconds: 120);

  // ============================================================
  // INTERNAL STATE
  // ============================================================

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

  List<EnergyMonthlySummary> _rows = const <EnergyMonthlySummary>[];

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

  bool get hasValidParams {
    final currentFac = _facId;
    final currentMonth = _month;

    return currentFac != null &&
        currentFac.trim().isNotEmpty &&
        currentMonth != null &&
        _isValidMonth(currentMonth);
  }

  EnergyMonthlySummary? get electricity {
    return _findByCate('ELECTRIC');
  }

  EnergyMonthlySummary? get water {
    return _findByCate('WATER');
  }

  EnergyMonthlySummary? get air {
    return _findByCate('AIR') ?? _findByCate('COMPRESSED');
  }

  // ============================================================
  // START
  // ============================================================

  Future<void> start({required String facId, required String month}) async {
    if (_disposed) return;

    final normalizedFac = _normalizeFac(facId);
    final normalizedMonth = _normalizeMonth(month);

    final changed = normalizedFac != _facId || normalizedMonth != _month;

    // Hủy lịch polling cũ trước khi load.
    _stopPolling();

    if (changed) {
      // Response cũ nếu trả về sau sẽ không được cập nhật state.
      _invalidateCurrentRequest();

      _facId = normalizedFac;
      _month = normalizedMonth;

      _rows = const <EnergyMonthlySummary>[];

      _error = null;

      _fetching = false;
      _loading = true;
      _refreshing = false;
      _forceRefreshing = false;

      _safeNotify();
    } else {
      _facId = normalizedFac;
      _month = normalizedMonth;
    }

    await load(silent: !changed && hasData, force: changed);

    if (_disposed) return;

    _scheduleNextPoll();
  }

  // ============================================================
  // NORMAL GET
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

      _safeNotify();
      return;
    }

    final requestFac = _facId!;
    final requestMonth = _month!;

    final token = ++_requestToken;

    _fetching = true;
    _error = null;

    if (silent && hasData) {
      // Giữ UI cũ khi polling.
      _refreshing = true;
      _loading = false;
    } else {
      _loading = true;
      _refreshing = false;
    }

    _safeNotify();

    try {
      final data = await api
          .getMonthlySummary(facId: requestFac, month: requestMonth)
          .timeout(requestTimeout);

      if (!_isValid(token)) {
        return;
      }

      // Tạo list mới để Selector nhận ra dữ liệu thay đổi.
      _rows = List<EnergyMonthlySummary>.unmodifiable(data);

      _error = null;
    } on TimeoutException catch (error, stackTrace) {
      _handleError(
        token: token,
        error: error,
        stackTrace: stackTrace,
        tag: '[MONTHLY GET TIMEOUT]',
      );
    } on DioException catch (error, stackTrace) {
      _handleError(
        token: token,
        error: error,
        stackTrace: stackTrace,
        tag: '[MONTHLY GET DIO ${error.type}]',
      );
    } catch (error, stackTrace) {
      _handleError(
        token: token,
        error: error,
        stackTrace: stackTrace,
        tag: '[MONTHLY GET ERROR]',
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
  // NORMAL REFRESH
  // ============================================================

  Future<void> refresh() async {
    if (_disposed || _fetching || _forceRefreshing) {
      return;
    }

    // Người dùng refresh thì đếm lại chu kỳ 6 giờ.
    _stopPolling();

    await load(silent: hasData, force: false);

    if (_disposed) return;

    _scheduleNextPoll();
  }

  // ============================================================
  // FORCE REFRESH BACKEND CACHE
  // ============================================================

  Future<bool> forceRefresh() async {
    if (_disposed || _fetching || _forceRefreshing) {
      return false;
    }

    if (!hasValidParams) {
      return false;
    }

    final requestFac = _facId!;
    final requestMonth = _month!;

    final token = ++_requestToken;

    _stopPolling();

    _fetching = true;
    _forceRefreshing = true;
    _refreshing = hasData;
    _loading = !hasData;
    _error = null;

    _safeNotify();

    try {
      final data = await api
          .forceRefreshMonthlySummary(facId: requestFac, month: requestMonth)
          .timeout(forceRefreshTimeout);

      if (!_isValid(token)) {
        return false;
      }

      _rows = List<EnergyMonthlySummary>.unmodifiable(data);

      _error = null;

      return true;
    } on TimeoutException catch (error, stackTrace) {
      _handleError(
        token: token,
        error: error,
        stackTrace: stackTrace,
        tag: '[MONTHLY FORCE REFRESH TIMEOUT]',
      );

      return false;
    } on DioException catch (error, stackTrace) {
      _handleError(
        token: token,
        error: error,
        stackTrace: stackTrace,
        tag: '[MONTHLY FORCE REFRESH DIO ${error.type}]',
      );

      return false;
    } catch (error, stackTrace) {
      _handleError(
        token: token,
        error: error,
        stackTrace: stackTrace,
        tag: '[MONTHLY FORCE REFRESH ERROR]',
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
          _scheduleNextPoll();
        }
      }
    }
  }

  // ============================================================
  // RETRY
  // ============================================================

  Future<void> retry() async {
    if (_disposed || _fetching || _forceRefreshing) {
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

      // Request hoàn tất rồi mới đếm tiếp 6 giờ.
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

    _rows = const <EnergyMonthlySummary>[];

    _error = null;

    _fetching = false;
    _loading = false;
    _refreshing = false;
    _forceRefreshing = false;

    _safeNotify();
  }

  // ============================================================
  // CATEGORY HELPERS
  // ============================================================

  EnergyMonthlySummary? _findByCate(String keyword) {
    final normalizedKeyword = keyword.trim().toUpperCase();

    for (final item in _rows) {
      final category = item.cate.trim().toUpperCase();

      if (category.contains(normalizedKeyword)) {
        return item;
      }
    }

    return null;
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _handleError({
    required int token,
    required Object error,
    required StackTrace stackTrace,
    required String tag,
  }) {
    if (!_isValid(token)) {
      return;
    }

    // Không xóa rows cũ nếu refresh lỗi.
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
        'Month must use yyyyMM format, for example 202607',
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

  bool _isValid(int token) {
    return !_disposed && token == _requestToken;
  }

  // ============================================================
  // SAFE NOTIFY
  // ============================================================

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

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _disposed = true;

    _invalidateCurrentRequest();
    _stopPolling();

    super.dispose();
  }
}
