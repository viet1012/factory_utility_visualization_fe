import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Widget trang thai tai dung chung cho Overview (SUMMARY, o FAC A/B/C):
/// skeleton shimmer, goi y khi tai cham, badge "dang cap nhat" / "cap nhat
/// loi", the loi co nut thu lai.

const String kSlowLoadingText =
    'Aggregating monthly data, first load may take a while…';

/// Sau bao lau thi hien [kSlowLoadingText].
const Duration kSlowLoadingAfter = Duration(seconds: 5);

// ============================================================
// SKELETON
// ============================================================

/// Vet sang chay ngang qua cac [SkeletonBox] ben trong [child].
class SkeletonShimmer extends StatefulWidget {
  final Widget child;

  const SkeletonShimmer({super.key, required this.child});

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final t = _controller.value * 3 - 1; // -1 -> 2
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white.withValues(alpha: .06),
                Colors.white.withValues(alpha: .16),
                Colors.white.withValues(alpha: .06),
              ],
              stops: [
                (t - .3).clamp(0.0, 1.0),
                t.clamp(0.0, 1.0),
                (t + .3).clamp(0.0, 1.0),
              ],
            ).createShader(rect),
            child: child,
          );
        },
      ),
    );
  }
}

/// Khoi xam bo goc (dat trong [SkeletonShimmer]).
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ============================================================
// SLOW HINT
// ============================================================

/// Rong luc dau; sau [kSlowLoadingAfter] hien dong chu nho [kSlowLoadingText].
/// Timer gan voi vong doi widget (mount = bat dau tai).
class SlowLoadingHint extends StatefulWidget {
  final TextAlign textAlign;

  const SlowLoadingHint({super.key, this.textAlign = TextAlign.center});

  @override
  State<SlowLoadingHint> createState() => _SlowLoadingHintState();
}

class _SlowLoadingHintState extends State<SlowLoadingHint> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(kSlowLoadingAfter, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: Text(
        kSlowLoadingText,
        textAlign: widget.textAlign,
        maxLines: 2,
        overflow: TextOverflow.fade,
        style: TextStyle(
          color: Colors.white.withValues(alpha: .6),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ============================================================
// STALE BADGE
// ============================================================

/// Badge nho canh tieu de khi dang hien so cu:
/// - [refreshing]: cham xanh nhap nhay, tooltip "Updating…";
/// - [failed]: icon canh bao vang, tooltip kem gio cap nhat cuoi.
/// Ca hai false: khong chiem cho.
class StaleDataBadge extends StatelessWidget {
  final bool refreshing;
  final bool failed;
  final DateTime? lastUpdatedAt;
  final double size;

  const StaleDataBadge({
    super.key,
    required this.refreshing,
    required this.failed,
    required this.lastUpdatedAt,
    this.size = 13,
  });

  static final DateFormat _timeFormat = DateFormat('HH:mm');

  static String failedMessage(DateTime? lastUpdatedAt) {
    final at = lastUpdatedAt;
    return at == null
        ? 'Update failed, showing previous data'
        : 'Update failed, showing data as of ${_timeFormat.format(at)}';
  }

  @override
  Widget build(BuildContext context) {
    if (refreshing) {
      return Tooltip(
        message: 'Updating…',
        child: SizedBox.square(
          dimension: size,
          child: const Center(child: _PulsingDot()),
        ),
      );
    }

    if (failed) {
      return Tooltip(
        message: failedMessage(lastUpdatedAt),
        child: Icon(
          Icons.warning_amber_rounded,
          size: size,
          color: const Color(0xfffbbf24),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: .35, end: 1).animate(_controller),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xff22d3ee),
        ),
      ),
    );
  }
}

// ============================================================
// ERROR
// ============================================================

/// Noi dung loi gon trong khung the: icon + "Failed to load data" + nut
/// "Retry". Dat trong khung co san kich thuoc (khong tu dat kich thuoc).
class InlineLoadError extends StatelessWidget {
  final VoidCallback? onRetry;

  /// Dang thu lai: nut bi khoa, hien vong quay.
  final bool retrying;

  const InlineLoadError({super.key, this.onRetry, this.retrying = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 22,
              color: Colors.white.withValues(alpha: .55),
            ),
            const SizedBox(height: 6),
            Text(
              'Failed to load data',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .84),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: retrying ? null : onRetry,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xff22d3ee),
                visualDensity: VisualDensity.compact,
              ),
              icon: retrying
                  ? const SizedBox.square(
                      dimension: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.6),
                    )
                  : const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
