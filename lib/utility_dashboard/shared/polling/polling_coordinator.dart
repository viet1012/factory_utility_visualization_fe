import 'package:flutter/foundation.dart';

import 'polling_scope.dart';
import 'polling_task.dart';

/// Coordinates generic async polling callbacks by lifecycle scope.
///
/// A scope is effective when it and every parent scope are explicitly
/// active, the coordinator is not [paused] (browser tab hidden) and none of
/// those scopes is suppressed (screen covered by another route).
///
/// [activity] ticks whenever the set of effective scopes may have changed, so
/// widgets that run their own refresh logic can follow the same gating. (The
/// coordinator itself is not a Listenable: it is exposed with Provider.value.)
class PollingCoordinator {
  final ValueNotifier<int> _activity = ValueNotifier<int>(0);

  final Map<String, PollingTask> _tasks = <String, PollingTask>{};
  final Set<PollingScope> _activeScopes = <PollingScope>{};
  final Set<PollingScope> _suppressedScopes = <PollingScope>{};

  bool _paused = false;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  ValueListenable<int> get activity => _activity;

  /// True while every task is held, e.g. the browser tab is hidden.
  bool get paused => _paused;

  /// Registers a task without starting it.
  ///
  /// Task IDs are unique for the lifetime of this coordinator.
  ///
  /// [catchUpOnly] defaults to true for intervals of one hour or more: on
  /// re-activation such tasks keep their schedule and only run at once when
  /// the last successful run is older than [interval].
  void register({
    required String id,
    required PollingScope scope,
    required Duration interval,
    required PollingAction action,
    bool runImmediately = false,
    bool? catchUpOnly,
  }) {
    _ensureNotDisposed();
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (_tasks.containsKey(id)) {
      throw StateError('A polling task with id "$id" is already registered.');
    }

    final task = PollingTask(
      id: id,
      scope: scope,
      interval: interval,
      action: action,
      runImmediately: runImmediately,
      catchUpOnly: catchUpOnly ?? interval >= const Duration(hours: 1),
    );
    task.setEffectivelyActive(isScopeActive(scope));
    _tasks[id] = task;
  }

  bool isRegistered(String id) => _tasks.containsKey(id);

  void start(String id) {
    if (_disposed) return;
    _task(id).start();
  }

  void stop(String id) {
    if (_disposed) return;
    _task(id).stop();
  }

  void unregister(String id) {
    if (_disposed) return;
    _tasks.remove(id)?.dispose();
  }

  void activateScope(PollingScope scope) {
    if (_disposed || !_activeScopes.add(scope)) return;
    _reevaluateTasks();
  }

  void deactivateScope(PollingScope scope) {
    if (_disposed || !_activeScopes.remove(scope)) return;
    _reevaluateTasks();
  }

  /// Holds every task (browser tab hidden). Resuming runs one round for the
  /// visible scopes, following each task's catch-up rule.
  void setPaused(bool paused) {
    if (_disposed || _paused == paused) return;

    _paused = paused;
    _reevaluateTasks(resumed: !paused);
  }

  /// Holds [scopes] (and their children) without forgetting that they are
  /// active, e.g. while another route covers the screen that owns them.
  void setSuppressed(Iterable<PollingScope> scopes, bool suppressed) {
    if (_disposed) return;

    var changed = false;
    for (final scope in scopes) {
      changed |= suppressed
          ? _suppressedScopes.add(scope)
          : _suppressedScopes.remove(scope);
    }

    if (changed) _reevaluateTasks(resumed: !suppressed);
  }

  /// Whether [scope] and every parent scope are explicitly active, not
  /// suppressed, and the coordinator is not paused.
  bool isScopeActive(PollingScope scope) =>
      !_paused &&
      scope.selfAndAncestors.every(
        (item) =>
            _activeScopes.contains(item) && !_suppressedScopes.contains(item),
      );

  PollingTask _task(String id) {
    final task = _tasks[id];
    if (task == null) {
      throw StateError('No polling task is registered with id "$id".');
    }
    return task;
  }

  void _reevaluateTasks({bool resumed = false}) {
    for (final task in _tasks.values) {
      task.setEffectivelyActive(isScopeActive(task.scope), resumed: resumed);
    }
    _activity.value++;
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('PollingCoordinator has been disposed.');
    }
  }

  void dispose() {
    if (_disposed) return;

    _disposed = true;
    for (final task in _tasks.values) {
      task.dispose();
    }
    _tasks.clear();
    _activeScopes.clear();
    _suppressedScopes.clear();
    _activity.dispose();
  }
}
