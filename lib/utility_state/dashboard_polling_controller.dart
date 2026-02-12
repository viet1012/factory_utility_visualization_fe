import 'dart:async';

import 'package:flutter/foundation.dart';

class DashboardPollingController extends ChangeNotifier {
  final Duration interval;
  Timer? _timer;

  DashboardPollingController({required this.interval});

  bool get isRunning => _timer != null;

  void start({
    required Future<void> Function() onTick,
    bool runImmediately = true,
  }) {
    stop();

    if (runImmediately) {
      // chạy ngay lần đầu
      unawaited(onTick());
    }

    _timer = Timer.periodic(interval, (_) {
      unawaited(onTick());
    });

    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
