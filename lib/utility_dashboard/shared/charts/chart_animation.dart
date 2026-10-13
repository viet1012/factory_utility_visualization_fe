import 'package:flutter/widgets.dart';

/// Thoi gian animate o lan ve dau cua mot chart.
const int kFirstPaintAnimationMs = 300;

/// Chi animate o lan ve dau co du lieu; moi lan build sau (polling, doi
/// range, resize) tra 0 de Syncfusion ve thang, khong chay lai animation.
///
/// Giu mot instance trong State cua chart:
/// ```dart
/// final _animation = FirstPaintAnimation();
/// ...
/// animationDuration: _animation.duration(),
/// ```
class FirstPaintAnimation {
  bool _painted = false;
  bool _scheduled = false;

  /// [hasData] = false: chua tinh la lan ve dau (vd dang skeleton).
  double duration({bool hasData = true}) {
    if (_painted || !hasData) return 0;

    if (!_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _painted = true);
    }

    return kFirstPaintAnimationMs.toDouble();
  }
}
