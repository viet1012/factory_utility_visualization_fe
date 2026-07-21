import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';

class SignalHealthMatrixController extends ChangeNotifier {
  final UtilityDashboardOverviewApi api;

  SignalHealthMatrixController(this.api);

  // ============================================================
  // CONFIG
  // ============================================================

  static const Duration requestTimeout = Duration(seconds: 50);

  static const Duration refreshInterval = Duration(minutes: 5);

  // ============================================================
  // INTERNAL STATE
  // ============================================================

  Timer? _timer;

  bool _disposed = false;
  bool _polling = false;
  bool _notifyScheduled = false;

  bool loading = true;
  bool refreshing = false;
  bool fetching = false;

  Object? error;

  int _requestId = 0;

  List<Map<String, dynamic>> data = const <Map<String, dynamic>>[];

  Map<String, dynamic>? selected;

  DateTime? _lastSuccessAt;
  DateTime? _lastErrorAt;

  // ============================================================
  // GETTERS
  // ============================================================

  bool get polling => _polling;

  bool get hasData => data.isNotEmpty;

  DateTime? get lastSuccessAt => _lastSuccessAt;

  DateTime? get lastErrorAt => _lastErrorAt;

  // ============================================================
  // START / STOP POLLING
  // ============================================================

  void startPolling() {
    if (_disposed || _polling) {
      return;
    }

    _polling = true;
    _cancelTimer();

    /*
     * Gọi API ngay khi bắt đầu.
     */
    unawaited(_runPollingCycle());
  }

  void stopPolling() {
    _polling = false;
    _cancelTimer();
  }

  Future<void> _runPollingCycle() async {
    if (_disposed || !_polling) {
      return;
    }

    await load(silent: hasData);

    if (_disposed || !_polling) {
      return;
    }

    /*
     * Request hoàn tất rồi mới bắt đầu đếm 5 phút.
     */
    _timer = Timer(refreshInterval, () {
      unawaited(_runPollingCycle());
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // ============================================================
  // FETCH
  // ============================================================

  Future<List<Map<String, dynamic>>> _fetchMatrix() {
    return api.getSignalHealthMatrix().timeout(requestTimeout);
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> load({bool silent = false, bool force = false}) async {
    if (_disposed) {
      return;
    }

    if (fetching && !force) {
      return;
    }

    final hasOldData = data.isNotEmpty;

    final oldSelectedKey = _selectedKey(selected);

    final requestId = ++_requestId;

    fetching = true;
    error = null;

    if (silent && hasOldData) {
      loading = false;
      refreshing = true;
    } else {
      loading = true;
      refreshing = false;
    }

    _safeNotify();

    try {
      final response = await _fetchMatrix();

      if (!_isValidRequest(requestId)) {
        return;
      }

      final newData = response
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);

      data = List<Map<String, dynamic>>.unmodifiable(newData);

      selected = _findSelectedDevice(newData, oldSelectedKey);

      error = null;
      _lastSuccessAt = DateTime.now();
    } on TimeoutException catch (exception, stackTrace) {
      _handleError(
        requestId: requestId,
        exception: exception,
        stackTrace: stackTrace,
        tag: '[SIGNAL MATRIX TIMEOUT]',
      );
    } catch (exception, stackTrace) {
      _handleError(
        requestId: requestId,
        exception: exception,
        stackTrace: stackTrace,
        tag: '[SIGNAL MATRIX ERROR]',
      );
    } finally {
      if (_isValidRequest(requestId)) {
        fetching = false;
        loading = false;
        refreshing = false;

        _safeNotify();
      }
    }
  }

  // ============================================================
  // MANUAL REFRESH
  // ============================================================

  Future<void> refresh() async {
    if (_disposed || fetching) {
      return;
    }

    /*
     * Refresh thủ công thì tính lại chu kỳ 5 phút.
     */
    final shouldResumePolling = _polling;

    _cancelTimer();

    await load(silent: hasData);

    if (_disposed) {
      return;
    }

    if (shouldResumePolling && _polling) {
      _timer = Timer(refreshInterval, () {
        unawaited(_runPollingCycle());
      });
    }
  }

  Future<void> retry() {
    return refresh();
  }

  // ============================================================
  // SELECTION
  // ============================================================

  void select(Map<String, dynamic> item) {
    if (_disposed) {
      return;
    }

    final newKey = _selectedKey(item);
    final oldKey = _selectedKey(selected);

    if (newKey == oldKey) {
      return;
    }

    selected = item;
    _safeNotify();
  }

  String? _selectedKey(Map<String, dynamic>? item) {
    if (item == null) {
      return null;
    }

    final facility = item['fac']?.toString().trim() ?? '';

    final category = item['cate']?.toString().trim() ?? '';

    final scada = item['scadaId']?.toString().trim() ?? '';

    final boxDeviceId = item['boxDeviceId']?.toString().trim() ?? '';

    /*
     * Chỉ dùng boxDeviceId có thể bị trùng giữa nhiều FAC.
     */
    return '$facility|$category|$scada|$boxDeviceId';
  }

  Map<String, dynamic>? _findSelectedDevice(
    List<Map<String, dynamic>> newData,
    String? oldSelectedKey,
  ) {
    if (newData.isEmpty) {
      return null;
    }

    if (oldSelectedKey != null) {
      for (final row in newData) {
        if (_selectedKey(row) == oldSelectedKey) {
          return row;
        }
      }
    }

    return newData.first;
  }

  // ============================================================
  // KPI
  // ============================================================

  int get totalFac {
    return data
        .map((item) => item['fac']?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .length;
  }

  int get totalBoxDevice {
    return data
        .map((item) => item['boxDeviceId']?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .length;
  }

  int get totalRegister {
    return data.fold<int>(0, (sum, item) {
      return sum + _toInt(item['totalRegisters']);
    });
  }

  int get totalNgRegister {
    return data.fold<int>(0, (sum, item) {
      return sum + _toInt(item['ngRegisters']);
    });
  }

  int get totalOkRegister {
    final result = totalRegister - totalNgRegister;

    return result < 0 ? 0 : result;
  }

  int get ngDeviceCount {
    return data.where((item) {
      final status = item['status']?.toString().trim().toUpperCase();

      final ngRegisters = _toInt(item['ngRegisters']);

      return status == 'NG' || ngRegisters > 0;
    }).length;
  }

  int get okDeviceCount {
    final result = totalBoxDevice - ngDeviceCount;

    return result < 0 ? 0 : result;
  }

  static int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString().trim()) ?? 0;
  }

  // ============================================================
  // LAST UPDATED
  // ============================================================

  DateTime? get latestRecordedAt {
    DateTime? latest;

    for (final device in data) {
      final rawSignals = device['signals'];

      if (rawSignals is! List) {
        continue;
      }

      for (final rawSignal in rawSignals) {
        if (rawSignal is! Map) {
          continue;
        }

        final recordedAt = _parseDateTime(rawSignal['recordedAt']);

        if (recordedAt == null) {
          continue;
        }

        if (latest == null || recordedAt.isAfter(latest)) {
          latest = recordedAt;
        }
      }
    }

    return latest;
  }

  String get lastUpdated {
    final value = latestRecordedAt;

    if (value == null) {
      return '-';
    }

    final local = value.toLocal();

    String two(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${two(local.day)}/'
        '${two(local.month)}/'
        '${local.year} '
        '${two(local.hour)}:'
        '${two(local.minute)}:'
        '${two(local.second)}';
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _handleError({
    required int requestId,
    required Object exception,
    required StackTrace stackTrace,
    required String tag,
  }) {
    if (!_isValidRequest(requestId)) {
      return;
    }

    _lastErrorAt = DateTime.now();

    /*
     * Nếu đã có dữ liệu cũ thì giữ màn hình hiện tại.
     * Vẫn lưu error để UI có thể hiện warning nhỏ.
     */
    error = exception;

    debugPrint('$tag $exception');
    debugPrintStack(stackTrace: stackTrace);
  }

  bool _isValidRequest(int requestId) {
    return !_disposed && requestId == _requestId;
  }

  // ============================================================
  // CLEAR
  // ============================================================

  void clear() {
    if (_disposed) {
      return;
    }

    _requestId++;

    stopPolling();

    data = const <Map<String, dynamic>>[];
    selected = null;

    loading = false;
    refreshing = false;
    fetching = false;

    error = null;

    _lastSuccessAt = null;
    _lastErrorAt = null;

    _safeNotify();
  }

  // ============================================================
  // SAFE NOTIFY
  // ============================================================

  void _safeNotify() {
    if (_disposed) {
      return;
    }

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

      if (_disposed) {
        return;
      }

      notifyListeners();
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _requestId++;

    _polling = false;
    _cancelTimer();

    super.dispose();
  }
}
