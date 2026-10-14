import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// notifyListeners an toan cho controller co the duoc goi trong build phase
/// (vd bind / sync tu didUpdateWidget): dang build thi hoan sang sau frame,
/// nhieu lan goi trong cung frame chi notify mot lan. Bo qua sau dispose.
mixin SafeChangeNotifier on ChangeNotifier {
  bool _safeNotifyDisposed = false;
  bool _notifyScheduled = false;

  void safeNotify() {
    if (_safeNotifyDisposed) return;

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
      if (_safeNotifyDisposed) return;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _safeNotifyDisposed = true;
    super.dispose();
  }
}
