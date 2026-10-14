import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../shared/download/file_download.dart';
import '../api/signal_health_api.dart';

class SignalHealthMatrixController extends ChangeNotifier {
  final SignalHealthApi api;

  SignalHealthMatrixController(this.api);

  // ============================================================
  // CONFIG
  // ============================================================

  static const Duration requestTimeout = Duration(seconds: 50);

  // ============================================================
  // INTERNAL STATE
  // ============================================================

  bool _disposed = false;
  bool _notifyScheduled = false;

  bool loading = true;
  bool refreshing = false;
  bool fetching = false;

  Object? error;

  /*
   * Export là thao tác độc lập.
   *
   * Không dùng chung loading/refreshing để tránh việc export làm
   * ẩn hoặc reset dữ liệu Signal Health đang hiển thị.
   */
  bool exporting = false;

  int _requestId = 0;

  List<Map<String, dynamic>> data = const <Map<String, dynamic>>[];

  // ============================================================
  // GETTERS
  // ============================================================

  bool get hasData => data.isNotEmpty;

  // ============================================================
  // FETCH
  // ============================================================

  Future<List<Map<String, dynamic>>> _fetchMatrix() {
    return api.getSignalHealthMatrix().timeout(requestTimeout);
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> load({bool silent = false}) async {
    if (_disposed) {
      return;
    }

    if (fetching) {
      return;
    }

    final hasOldData = data.isNotEmpty;

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

      error = null;
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

    await load(silent: hasData);
  }

  // ============================================================
  // EXPORT
  // ============================================================

  /// Downloads the Signal Health Excel export.
  ///
  /// Independent of [loading]/[refreshing]: a failed or in-flight export never
  /// hides the matrix data that is already on screen.
  ///
  /// Returns true when the file was handed to the browser.
  Future<bool> exportExcel() async {
    // Chặn double-click: chỉ cho phép một export tại một thời điểm.
    if (_disposed || exporting) {
      return false;
    }

    exporting = true;
    _safeNotify();

    try {
      final file = await api.getSignalHealthExport().timeout(requestTimeout);

      if (_disposed) {
        return false;
      }

      downloadBytes(
        bytes: file.bytes,
        filename: file.filename,
        mimeType: SignalHealthApi.xlsxMimeType,
      );

      return true;
    } catch (error, stackTrace) {
      if (_disposed) {
        return false;
      }

      debugPrint('SignalHealthMatrixController.exportExcel error: $error');
      debugPrintStack(stackTrace: stackTrace);

      return false;
    } finally {
      exporting = false;
      _safeNotify();
    }
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

    super.dispose();
  }
}
