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

  List<UtilityDailyPoint> _electricity = const <UtilityDailyPoint>[];

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

  List<UtilityDailyPoint> get electricity => _electricity;

  List<UtilityDailyPoint> get water => _water;

  List<UtilityDailyPoint> get air => _air;

  bool get hasData {
    return _electricity.isNotEmpty || _water.isNotEmpty || _air.isNotEmpty;
  }

  bool get hasValidParams {
    final currentFac = _facId;
    final currentMonth = _month;

    if (currentFac == null || currentFac.trim().isEmpty) {
      return false;
    }

    if (currentMonth == null) {
      return false;
    }

    return _isValidMonth(currentMonth);
  }

  // ============================================================
  // START
  // ============================================================

  Future<void> start({required String facId, required String month}) async {
    if (_disposed) return;

    final normalizedFac = _normalizeFac(facId);
    final normalizedMonth = _normalizeMonth(month);

    final changed = normalizedFac != _facId || normalizedMonth != _month;

    /*
     * Khi start lại, luôn hủy lịch polling cũ.
     * Polling mới chỉ được tạo sau khi request hiện tại hoàn tất.
     */
    _stopPolling();

    if (changed) {
      /*
       * Request cũ nếu còn chạy sẽ không được phép cập nhật state.
       */
      _invalidateCurrentRequest();

      _facId = normalizedFac;
      _month = normalizedMonth;

      _electricity = const <UtilityDailyPoint>[];
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

    /*
     * Polling hoặc refresh thủ công không được chạy chồng.
     *
     * force chỉ dùng khi đổi facility/tháng, vì request cũ đã được
     * invalidate bằng request token.
     */
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
      /*
       * Silent refresh giữ nguyên dữ liệu cũ trên màn hình.
       */
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

      /*
       * Luôn tạo list mới để Selector/Consumer nhận ra dữ liệu đổi.
       */
      _electricity = List<UtilityDailyPoint>.unmodifiable(response.electricity);

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

    /*
     * Người dùng vừa refresh thủ công thì đếm lại chu kỳ 1 giờ
     * từ thời điểm refresh hoàn tất.
     */
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

      /*
         * Request hoàn tất rồi mới bắt đầu đếm tiếp 1 giờ.
         */
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

    _electricity = const <UtilityDailyPoint>[];
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

    /*
     * Chỉ lưu error, không xóa dữ liệu cũ.
     * Vì vậy silent refresh lỗi thì biểu đồ vẫn còn dữ liệu.
     */
    _error = error;

    debugPrint('$tag $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  String _normalizeFac(String facId) {
    final normalized = facId.trim();

    /*
     * Có thể đổi thành KVH nếu màn hình của bạn cho phép fac rỗng.
     */
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
