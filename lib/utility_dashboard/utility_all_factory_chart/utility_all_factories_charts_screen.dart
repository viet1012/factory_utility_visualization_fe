import 'dart:async';

import 'package:factory_utility_visualization/utility_dashboard/utility_all_factory_chart/utility_all_factories_controller.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_all_factory_chart/widgets/utility_all_factories_content.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_state/chart_catalog_provider.dart';
import '../utility_dashboard_common/chart_theme.dart';
import '../utility_dashboard_overview/utility_dashboard_overview_painter/utility_industrial_motion_background.dart';

class UtilityAllFactoriesChartsScreen extends StatefulWidget {
  final bool isCurrentScreen;

  const UtilityAllFactoriesChartsScreen({
    super.key,
    this.isCurrentScreen = true,
  });

  @override
  State<UtilityAllFactoriesChartsScreen> createState() =>
      _UtilityAllFactoriesChartsScreenState();
}

class _UtilityAllFactoriesChartsScreenState
    extends State<UtilityAllFactoriesChartsScreen>
    with WidgetsBindingObserver {
  late final UtilityAllFactoriesController controller;

  Timer? _resumeAnimationTimer;

  bool _appActive = true;
  bool _isScrolling = false;
  bool _disposed = false;

  bool get _animationEnabled {
    return !_disposed && _appActive && widget.isCurrentScreen && !_isScrolling;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    controller = UtilityAllFactoriesController(
      catalog: context.read<ChartCatalogProvider>(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed) return;

      controller.initialize();
    });
  }

  // ============================================================
  // APP LIFECYCLE
  // ============================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final nextActive = state == AppLifecycleState.resumed;

    if (_appActive == nextActive || !mounted) {
      return;
    }

    setState(() {
      _appActive = nextActive;
    });
  }

  /*
   * Không cần setState trong didUpdateWidget.
   *
   * Khi isCurrentScreen thay đổi, Flutter tự gọi build lại rồi.
   * Gọi setState ở đây sẽ tạo thêm một frame rebuild không cần thiết.
   */
  @override
  void didUpdateWidget(covariant UtilityAllFactoriesChartsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isCurrentScreen) {
      _resumeAnimationTimer?.cancel();

      if (_isScrolling) {
        _isScrolling = false;
      }
    }
  }

  // ============================================================
  // SCROLL PERFORMANCE
  // ============================================================

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_disposed || !mounted) {
      return false;
    }

    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      _pauseAnimationForScroll();
    } else if (notification is ScrollEndNotification) {
      _scheduleResumeAnimation();
    }

    return false;
  }

  void _pauseAnimationForScroll() {
    _resumeAnimationTimer?.cancel();

    if (_isScrolling) {
      return;
    }

    setState(() {
      _isScrolling = true;
    });
  }

  void _scheduleResumeAnimation() {
    _resumeAnimationTimer?.cancel();

    _resumeAnimationTimer = Timer(const Duration(milliseconds: 180), () {
      if (_disposed || !mounted || !_isScrolling) {
        return;
      }

      setState(() {
        _isScrolling = false;
      });
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final animationEnabled = _animationEnabled;

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: TickerMode(
        enabled: animationEnabled,
        child: RepaintBoundary(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A0E27), Color(0xFF020B16)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: _UtilityBackgroundLayer(
                    controller: controller,
                    animated: animationEnabled,
                  ),
                ),

                RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _UtilityContentLayer(controller: controller),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _disposed = true;

    _resumeAnimationTimer?.cancel();
    _resumeAnimationTimer = null;

    WidgetsBinding.instance.removeObserver(this);

    controller.dispose();

    super.dispose();
  }
}

// ============================================================
// BACKGROUND
// Chỉ cập nhật khi category hoặc trạng thái animated thay đổi.
// ============================================================
class _UtilityBackgroundLayer extends StatefulWidget {
  final UtilityAllFactoriesController controller;
  final bool animated;

  const _UtilityBackgroundLayer({
    required this.controller,
    required this.animated,
  });

  @override
  State<_UtilityBackgroundLayer> createState() =>
      _UtilityBackgroundLayerState();
}

class _UtilityBackgroundLayerState extends State<_UtilityBackgroundLayer> {
  late String _category;

  @override
  void initState() {
    super.initState();

    _category = widget.controller.selectedCate;

    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _UtilityBackgroundLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);

      _category = widget.controller.selectedCate;

      widget.controller.addListener(_handleControllerChanged);
    }
  }

  void _handleControllerChanged() {
    final nextCategory = widget.controller.selectedCate;

    if (!mounted || nextCategory == _category) {
      return;
    }

    setState(() {
      _category = nextCategory;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChartThemes.byCate(_category);

    return IgnorePointer(
      child: UtilityIndustrialMotionBackground(
        key: ValueKey('utility-background-$_category'),
        cate: _category,
        color: theme.line,
        animated: widget.animated,
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);

    super.dispose();
  }
}
// ============================================================
// CONTENT
// ============================================================

class _UtilityContentLayer extends StatelessWidget {
  final UtilityAllFactoriesController controller;

  const _UtilityContentLayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final category = controller.selectedCate;
        final theme = ChartThemes.byCate(category);

        return UtilityAllFactoriesContent(controller: controller, theme: theme);
      },
    );
  }
}
