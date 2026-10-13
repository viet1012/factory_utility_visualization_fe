import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Chi tao chart khi the da vao khung nhin lan dau; truoc do hien
/// [placeholder] (skeleton nhe, khong co Syncfusion).
///
/// GridView.builder van build the trong vung cacheExtent; gate nay chan phan
/// nang (chart) cua cac the do cho toi khi chung that su hien. Cac the cung
/// hien trong mot frame duoc mo dan, toi da [_RevealScheduler.perFrame] the
/// moi frame, de lan cuon / mo tab dau khong dung khung.
class LazyChartGate extends StatefulWidget {
  final Widget placeholder;
  final WidgetBuilder builder;

  const LazyChartGate({
    super.key,
    required this.placeholder,
    required this.builder,
  });

  @override
  State<LazyChartGate> createState() => _LazyChartGateState();
}

class _LazyChartGateState extends State<LazyChartGate> {
  bool _revealed = false;
  bool _queued = false;
  bool _checkScheduled = false;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_revealed) return;

    final position = Scrollable.maybeOf(context)?.position;
    if (identical(position, _position)) return;

    _position?.removeListener(_check);
    _position = position;
    _position?.addListener(_check);
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    _RevealScheduler.cancel(this);
    super.dispose();
  }

  void _scheduleCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      _check();
    });
  }

  void _check() {
    if (!mounted || _revealed || _queued) return;

    if (_isOnScreen()) {
      _queued = true;
      _RevealScheduler.request(this);
    }
  }

  bool _isOnScreen() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;

    final scrollable = Scrollable.maybeOf(context);
    // Khong nam trong vung cuon: luon hien.
    if (scrollable == null) return true;

    final viewport = scrollable.context.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return true;

    final rect = box.localToGlobal(Offset.zero) & box.size;
    final visible = viewport.localToGlobal(Offset.zero) & viewport.size;

    return rect.overlaps(visible);
  }

  void _reveal() {
    if (!mounted || _revealed) return;

    _position?.removeListener(_check);
    _position = null;

    setState(() => _revealed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_revealed) return widget.builder(context);

    _scheduleCheck();
    return widget.placeholder;
  }
}

/// Hang doi mo chart: moi frame mo toi da [perFrame] the.
abstract final class _RevealScheduler {
  static const int perFrame = 3;

  static final List<_LazyChartGateState> _queue = <_LazyChartGateState>[];
  static bool _frameScheduled = false;

  static void request(_LazyChartGateState gate) {
    _queue.add(gate);
    _schedule();
  }

  static void cancel(_LazyChartGateState gate) => _queue.remove(gate);

  static void _schedule() {
    if (_frameScheduled || _queue.isEmpty) return;
    _frameScheduled = true;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;

      for (var i = 0; i < perFrame && _queue.isNotEmpty; i++) {
        _queue.removeAt(0)._reveal();
      }

      if (_queue.isNotEmpty) {
        _schedule();
        SchedulerBinding.instance.scheduleFrame();
      }
    });
    SchedulerBinding.instance.scheduleFrame();
  }
}
