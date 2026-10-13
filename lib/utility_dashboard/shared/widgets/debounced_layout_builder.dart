import 'dart:async';

import 'package:flutter/widgets.dart';

/// Nhu [LayoutBuilder] nhung chi goi lai [builder] khi kich thuoc da dung yen
/// [delay] (mac dinh 150ms).
///
/// Trong luc keo cua so, widget con da build (grid + chart) duoc giu nguyen
/// instance nen Flutter chi layout / paint lai, khong build lai the hay tinh
/// lai truc; so cot va truc duoc tinh lai mot lan khi resize dung.
class DebouncedLayoutBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints)
  builder;
  final Duration delay;

  const DebouncedLayoutBuilder({
    super.key,
    required this.builder,
    this.delay = const Duration(milliseconds: 150),
  });

  @override
  State<DebouncedLayoutBuilder> createState() => _DebouncedLayoutBuilderState();
}

class _DebouncedLayoutBuilderState extends State<DebouncedLayoutBuilder> {
  BoxConstraints? _applied;
  BoxConstraints? _pending;
  Widget? _cached;
  Timer? _timer;

  @override
  void didUpdateWidget(covariant DebouncedLayoutBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cha build lai (data / filter doi): phai build lai noi dung.
    _cached = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _apply() {
    if (!mounted || _pending == null) return;

    setState(() {
      _applied = _pending;
      _pending = null;
      _cached = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final applied = _applied;

        if (applied == null) {
          _applied = constraints;
        } else if (constraints != applied) {
          if (constraints != _pending) {
            _pending = constraints;
            _timer?.cancel();
            _timer = Timer(widget.delay, _apply);
          }
        } else if (_pending != null) {
          // Quay ve dung kich thuoc cu truoc khi het delay.
          _pending = null;
          _timer?.cancel();
        }

        return _cached ??= widget.builder(context, _applied!);
      },
    );
  }
}
