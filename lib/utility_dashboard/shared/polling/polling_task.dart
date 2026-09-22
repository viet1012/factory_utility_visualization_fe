import 'dart:async';
import 'dart:developer' as developer;

import 'polling_scope.dart';

typedef PollingAction = Future<void> Function();

/// A polling definition and its private scheduling state.
///
/// Scheduling is controlled by the owning polling coordinator.
class PollingTask {
  PollingTask({
    required this.id,
    required this.scope,
    required this.interval,
    required this.action,
    required this.runImmediately,
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

  Timer? _timer;
  bool _started = false;
  bool _effectivelyActive = false;
  bool _running = false;
  bool _disposed = false;
  bool _resumeAfterCurrentAction = false;
  int _generation = 0;

  bool get isStarted => _started;
  bool get isRunning => _running;

  void start() {
    if (_disposed || _started) return;

    _started = true;
    if (_effectivelyActive) {
      _enterEligibleState();
    }
  }

  void stop() {
    if (!_started) return;

    _started = false;
    _suspend();
  }

  void setEffectivelyActive(bool active) {
    if (_disposed || _effectivelyActive == active) return;

    _effectivelyActive = active;
    if (!active) {
      _suspend();
    } else if (_started) {
      _enterEligibleState();
    }
  }

  void _enterEligibleState() {
    final generation = ++_generation;
    _timer?.cancel();
    _timer = null;

    if (_running) {
      _resumeAfterCurrentAction = true;
      return;
    }

    if (runImmediately) {
      unawaited(_run(generation));
    } else {
      _schedule(generation);
    }
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

  void _schedule(int generation) {
    if (!_isEligible(generation)) return;

    _timer = Timer(interval, () {
      _timer = null;
      unawaited(_run(generation));
    });
  }

  Future<void> _run(int generation) async {
    if (!_isEligible(generation) || _running) return;

    _running = true;
    try {
      await action();
    } catch (error, stackTrace) {
      developer.log(
        'Polling task "$id" failed.',
        name: 'PollingCoordinator',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _running = false;
    }

    if (_resumeAfterCurrentAction &&
        !_disposed &&
        _started &&
        _effectivelyActive) {
      _resumeAfterCurrentAction = false;
      if (runImmediately) {
        unawaited(_run(_generation));
      } else {
        _schedule(_generation);
      }
      return;
    }

    if (_isEligible(generation)) {
      _schedule(generation);
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
