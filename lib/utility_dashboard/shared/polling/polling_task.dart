import 'dart:async';
import 'dart:developer' as developer;

import 'polling_scope.dart';

typedef PollingAction = Future<void> Function();

/// A polling definition and its private scheduling state.
///
/// Scheduling is controlled by the owning polling coordinator.
///
/// Schedule semantics:
/// - [start] after [stop] is a fresh start: the schedule is reset and
///   [runImmediately] decides whether the first run happens at once. Callers
///   use stop/start to force a reload after a source change (fac, month...).
/// - Losing and regaining eligibility (scope switch, hidden browser tab,
///   covered route) keeps the existing schedule instead of resetting it:
///   - [catchUpOnly] tasks run at once only when the last successful run is
///     older than [interval]; otherwise they wait for the remaining time.
///   - other tasks run at once when [runImmediately] is set or when the
///     coordinator resumes them (page shown again / route uncovered).
class PollingTask {
  PollingTask({
    required this.id,
    required this.scope,
    required this.interval,
    required this.action,
    required this.runImmediately,
    required this.catchUpOnly,
  }) {
    if (interval <= Duration.zero) {
      throw ArgumentError.value(interval, 'interval', 'Must be positive.');
    }
  }

  final String id;
  final PollingScope scope;
  final Duration interval;
  final PollingAction action;
  final bool runImmediately;
  final bool catchUpOnly;

  Timer? _timer;
  bool _started = false;
  bool _effectivelyActive = false;
  bool _running = false;
  bool _disposed = false;
  bool _resumeAfterCurrentAction = false;
  int _generation = 0;

  /// Next planned run; null until the task first becomes eligible after
  /// [start]. Survives suspension so re-activation keeps the old schedule.
  DateTime? _nextDueAt;

  /// Completion time of the last run whose action did not throw.
  DateTime? _lastSuccessAt;

  /// Bumped by [stop]: a run that started before a stop/start (source
  /// change) must not write its timestamps into the fresh schedule.
  int _scheduleEpoch = 0;

  bool get isStarted => _started;
  bool get isRunning => _running;
  DateTime? get lastSuccessAt => _lastSuccessAt;

  void start() {
    if (_disposed || _started) return;

    _started = true;
    if (_effectivelyActive) {
      _enterEligibleState(resumed: false);
    }
  }

  void stop() {
    if (!_started) return;

    _started = false;
    _suspend();

    // Fresh schedule on the next start().
    _scheduleEpoch++;
    _nextDueAt = null;
    _lastSuccessAt = null;
  }

  /// [resumed]: eligibility came back because the page became visible again
  /// or a covering route was popped, not because of a scope switch.
  void setEffectivelyActive(bool active, {bool resumed = false}) {
    if (_disposed || _effectivelyActive == active) return;

    _effectivelyActive = active;
    if (!active) {
      _suspend();
    } else if (_started) {
      _enterEligibleState(resumed: resumed);
    }
  }

  void _enterEligibleState({required bool resumed}) {
    final generation = ++_generation;
    _timer?.cancel();
    _timer = null;

    if (_running) {
      _resumeAfterCurrentAction = true;
      return;
    }

    final now = DateTime.now();
    final due = _dueAt(now, resumed: resumed);

    if (!due.isAfter(now)) {
      unawaited(_run(generation));
    } else {
      _scheduleAt(generation, due);
    }
  }

  DateTime _dueAt(DateTime now, {required bool resumed}) {
    final planned = _nextDueAt;

    // First eligibility after start().
    if (planned == null) {
      final first = runImmediately ? now : now.add(interval);
      _nextDueAt = first;
      return first;
    }

    if (catchUpOnly) {
      final lastSuccess = _lastSuccessAt;
      final overdueAt = lastSuccess?.add(interval);

      // Overdue by the last success (e.g. failed run since): run now.
      if (overdueAt != null && overdueAt.isBefore(planned)) return overdueAt;
      return planned;
    }

    if (runImmediately || resumed) return now;

    return planned;
  }

  void _suspend() {
    _generation++;
    _resumeAfterCurrentAction = false;
    _timer?.cancel();
    _timer = null;
  }

  bool _isEligible(int generation) =>
      !_disposed &&
      _started &&
      _effectivelyActive &&
      generation == _generation;

  void _scheduleAt(int generation, DateTime due) {
    if (!_isEligible(generation)) return;

    _nextDueAt = due;

    var delay = due.difference(DateTime.now());
    if (delay.isNegative) delay = Duration.zero;

    _timer = Timer(delay, () {
      _timer = null;
      unawaited(_run(generation));
    });
  }

  Future<void> _run(int generation) async {
    if (!_isEligible(generation) || _running) return;

    _running = true;
    final epoch = _scheduleEpoch;
    try {
      await action();
      if (epoch == _scheduleEpoch) _lastSuccessAt = DateTime.now();
    } catch (error, stackTrace) {
      developer.log(
        'Polling task "$id" failed.',
        name: 'PollingCoordinator',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _running = false;
      // The interval counts from the end of this run, success or not.
      if (epoch == _scheduleEpoch) {
        _nextDueAt = DateTime.now().add(interval);
      }
    }

    if (_resumeAfterCurrentAction &&
        !_disposed &&
        _started &&
        _effectivelyActive) {
      _resumeAfterCurrentAction = false;
      _enterEligibleState(resumed: false);
      return;
    }

    final next = _nextDueAt;
    if (_isEligible(generation) && next != null) {
      _scheduleAt(generation, next);
    }
  }

  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _started = false;
    _effectivelyActive = false;
    _suspend();
  }
}
