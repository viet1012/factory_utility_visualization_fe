import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../api/signal_health_history_api.dart';
import '../models/signal_health_history_models.dart';

/// State holder for HISTORY mode.
///
/// Deliberately NOT registered with the PollingCoordinator: historical data is
/// fetched only on explicit demand — when HISTORY first becomes active, when
/// the filter changes, and when the user hits Refresh. Realtime polling stays
/// entirely with [SignalHealthMatrixController] for CURRENT mode.
class SignalHealthHistoryController extends ChangeNotifier {
  final SignalHealthHistoryApi api;

  SignalHealthHistoryController(this.api)
    : _filter = SignalHealthHistoryFilter.last24Hours();

  // ============================================================
  // CONFIG
  // ============================================================

  static const Duration requestTimeout = Duration(seconds: 50);

  // ============================================================
  // INTERNAL STATE
  // ============================================================

  bool _disposed = false;
  bool _notifyScheduled = false;

  int _requestId = 0;

  SignalHealthHistoryFilter _filter;

  List<SignalHealthHistoryBucket> _buckets =
      const <SignalHealthHistoryBucket>[];

  bool _loading = false;
  bool _refreshing = false;
  bool _fetching = false;

  Object? _error;

  DateTime? _lastLoadedAt;

  /// Filter whose data is currently held in [buckets]. Used to decide whether
  /// an activation needs a fetch or can reuse what is already loaded.
  SignalHealthHistoryFilter? _loadedFilter;

  String? _selectedBoxDeviceId;

  /// Level card selection. Null = all levels.
  SignalHealthAlertLevel? _selectedLevel;

  /// Description bar selection (groupKey). Null = all descriptions.
  String? _selectedDescriptionKey;

  /// Debounce for rapid filter changes, so dragging through dropdowns or
  /// presets issues one request instead of several overlapping ones.
  static const Duration filterDebounce = Duration(milliseconds: 300);

  Timer? _filterDebounceTimer;

  // ============================================================
  // GETTERS
  // ============================================================

  SignalHealthHistoryFilter get filter => _filter;

  List<SignalHealthHistoryBucket> get buckets => _buckets;

  bool get loading => _loading;

  bool get refreshing => _refreshing;

  bool get hasData => _buckets.isNotEmpty;

  Object? get error => _error;

  DateTime? get lastLoadedAt => _lastLoadedAt;

  String? get selectedBoxDeviceId => _selectedBoxDeviceId;

  SignalHealthAlertLevel? get selectedLevel => _selectedLevel;

  String? get selectedDescriptionKey => _selectedDescriptionKey;

  /// True while a debounced filter change is waiting to fire.
  bool get filterPending => _filterDebounceTimer?.isActive ?? false;

  /// True when no successful load has happened for the current filter yet.
  bool get needsLoad => _loadedFilter != _filter;

  // ============================================================
  // ACTIVATION
  // ============================================================

  /// Called when HISTORY mode becomes active.
  ///
  /// Loads only when the current filter has never been fetched, so switching
  /// CURRENT -> HISTORY -> CURRENT -> HISTORY does not re-hit the API.
  Future<void> ensureLoaded() async {
    if (_disposed || _fetching) return;

    if (!needsLoad) return;

    await load();
  }

  // ============================================================
  // FILTERS
  // ============================================================

  /// Replaces the filter and schedules a debounced reload.
  ///
  /// The filter state updates immediately so the UI stays responsive, but the
  /// request waits [filterDebounce]. Changing several dropdowns in quick
  /// succession therefore issues ONE request for the final filter instead of
  /// one overlapping request per change.
  void applyFilter(SignalHealthHistoryFilter next) {
    if (_disposed) return;

    if (next == _filter) return;

    _filter = next;

    /*
     * Selection duoc giu lai qua lan doi filter; neu device khong con trong
     * ket qua moi thi _reconcileSelection se tu bo chon sau khi load xong.
     */
    _filterDebounceTimer?.cancel();

    _filterDebounceTimer = Timer(filterDebounce, () {
      if (_disposed) return;

      // Filter could have been fetched by a refresh during the debounce.
      if (!needsLoad) {
        _safeNotify();
        return;
      }

      unawaited(load(silent: hasData));
    });

    _safeNotify();
  }

  /// Manual refresh: always re-fetches, even when the filter is unchanged.
  ///
  /// Cancels any pending debounce so the user's explicit action wins and no
  /// duplicate request follows it.
  Future<void> refresh() async {
    if (_disposed || _fetching) return;

    _filterDebounceTimer?.cancel();

    await load(silent: hasData);
  }

  Future<void> retry() => refresh();

  // ============================================================
  // SELECTION
  // ============================================================

  void selectDevice(String? boxDeviceId) {
    if (_disposed) return;

    final next = boxDeviceId?.trim();

    final normalized = (next == null || next.isEmpty) ? null : next;

    if (normalized == _selectedBoxDeviceId) return;

    _selectedBoxDeviceId = normalized;

    _safeNotify();
  }

  /// Toggles the level-card filter.
  ///
  /// Narrowing the level can orphan the selected description/device, so both
  /// are cleared: the drill-down must never show data outside the active
  /// selection.
  void toggleLevel(SignalHealthAlertLevel level) {
    if (_disposed) return;

    _selectedLevel = _selectedLevel == level ? null : level;

    _selectedDescriptionKey = null;
    _selectedBoxDeviceId = null;

    _safeNotify();
  }

  /// Toggles the description-bar filter, narrowing the device chart to the
  /// devices affected by that description.
  void toggleDescription(String descriptionKey) {
    if (_disposed) return;

    final key = descriptionKey.trim();

    if (key.isEmpty) return;

    _selectedDescriptionKey = _selectedDescriptionKey == key ? null : key;

    // The previously selected device may not be affected by this description.
    _selectedBoxDeviceId = null;

    _safeNotify();
  }

  /// Clears level, description and device selection in one step.
  void clearSelection() {
    if (_disposed) return;

    if (_selectedLevel == null &&
        _selectedDescriptionKey == null &&
        _selectedBoxDeviceId == null) {
      return;
    }

    _selectedLevel = null;
    _selectedDescriptionKey = null;
    _selectedBoxDeviceId = null;

    _safeNotify();
  }

  // ============================================================
  // LOAD
  // ============================================================

  /// Fetches the hourly history for the active filter.
  ///
  /// [silent] keeps existing data and charts on screen while refreshing,
  /// mirroring how the matrix controller distinguishes loading vs refreshing.
  Future<void> load({bool silent = false}) async {
    if (_disposed) return;

    final requestedFilter = _filter;

    final requestId = ++_requestId;

    _fetching = true;
    _error = null;

    if (silent && hasData) {
      _loading = false;
      _refreshing = true;
    } else {
      _loading = true;
      _refreshing = false;
    }

    _safeNotify();

    try {
      final result = await api
          .getHourlyHistory(requestedFilter)
          .timeout(requestTimeout);

      if (!_isValidRequest(requestId)) return;

      _buckets = result;
      _loadedFilter = requestedFilter;
      _lastLoadedAt = DateTime.now();
      _error = null;

      _reconcileSelection();
    } on TimeoutException catch (exception, stackTrace) {
      _handleError(
        requestId: requestId,
        exception: exception,
        stackTrace: stackTrace,
        tag: '[SIGNAL HISTORY TIMEOUT]',
      );
    } catch (exception, stackTrace) {
      _handleError(
        requestId: requestId,
        exception: exception,
        stackTrace: stackTrace,
        tag: '[SIGNAL HISTORY ERROR]',
      );
    } finally {
      if (_isValidRequest(requestId)) {
        _fetching = false;
        _loading = false;
        _refreshing = false;

        _safeNotify();
      }
    }
  }

  /// Drops level / description / device selections that the new dataset no
  /// longer contains, so the charts and drill-down never filter on something
  /// invisible.
  void _reconcileSelection() {
    final levels = <SignalHealthAlertLevel>{};
    final descriptionKeys = <String>{};
    final deviceIds = <String>{};

    for (final bucket in _buckets) {
      for (final alert in bucket.alerts) {
        levels.add(alert.level);

        for (final description in alert.descriptions) {
          descriptionKeys.add(description.groupKey);

          for (final device in description.devices) {
            final id = device.boxDeviceId.trim();
            if (id.isNotEmpty) deviceIds.add(id);
          }
        }
      }
    }

    final level = _selectedLevel;

    if (level != null && !levels.contains(level)) {
      _selectedLevel = null;
    }

    final descriptionKey = _selectedDescriptionKey;

    if (descriptionKey != null && !descriptionKeys.contains(descriptionKey)) {
      _selectedDescriptionKey = null;
    }

    final device = _selectedBoxDeviceId;

    if (device != null && !deviceIds.contains(device)) {
      _selectedBoxDeviceId = null;
    }
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
    if (!_isValidRequest(requestId)) return;

    /*
     * Giu nguyen buckets cu de man hinh khong bi trang khi refresh loi.
     * _loadedFilter khong duoc cap nhat, nen lan activate sau se thu lai.
     */
    _error = exception;

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
    if (_disposed) return;

    _requestId++;

    _filterDebounceTimer?.cancel();

    _buckets = const <SignalHealthHistoryBucket>[];
    _loadedFilter = null;
    _selectedBoxDeviceId = null;
    _selectedLevel = null;
    _selectedDescriptionKey = null;

    _loading = false;
    _refreshing = false;
    _fetching = false;

    _error = null;
    _lastLoadedAt = null;

    _safeNotify();
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
    if (_disposed) return;

    _disposed = true;
    _requestId++;

    _filterDebounceTimer?.cancel();
    _filterDebounceTimer = null;

    super.dispose();
  }
}
