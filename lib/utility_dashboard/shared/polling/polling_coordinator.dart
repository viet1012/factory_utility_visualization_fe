import 'polling_scope.dart';
import 'polling_task.dart';

/// Coordinates generic async polling callbacks by lifecycle scope.
class PollingCoordinator {
  final Map<String, PollingTask> _tasks = <String, PollingTask>{};
  final Set<PollingScope> _activeScopes = <PollingScope>{};

  bool _disposed = false;

  bool get isDisposed => _disposed;

  /// Registers a task without starting it.
  ///
  /// Task IDs are unique for the lifetime of this coordinator.
  void register({
    required String id,
    required PollingScope scope,
    required Duration interval,
    required PollingAction action,
    bool runImmediately = false,
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
    );
    task.setEffectivelyActive(isScopeActive(scope));
    _tasks[id] = task;
  }

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

  /// Whether [scope] and every parent scope are explicitly active.
  bool isScopeActive(PollingScope scope) =>
      scope.selfAndAncestors.every(_activeScopes.contains);

  PollingTask _task(String id) {
    final task = _tasks[id];
    if (task == null) {
      throw StateError('No polling task is registered with id "$id".');
    }
    return task;
  }

  void _reevaluateTasks() {
    for (final task in _tasks.values) {
      task.setEffectivelyActive(isScopeActive(task.scope));
    }
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
  }
}
