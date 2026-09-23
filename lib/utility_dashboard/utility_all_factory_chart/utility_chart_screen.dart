import 'dart:async';

import 'package:factory_utility_visualization/utility_dashboard/utility_all_factory_chart/controllers/utility_chart_controller.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_all_factory_chart/widgets/utility_chart_content.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/utility_chart_catalog_controller.dart';
import '../shared/polling/polling_coordinator.dart';
import '../shared/polling/polling_scope.dart';
import 'tabs/utility_chart_view.dart';
import '../utility_dashboard_common/chart_theme.dart';
import 'widgets/utility_chart_background.dart';

class UtilityChartScreen extends StatefulWidget {
  final bool isCurrentScreen;

  const UtilityChartScreen({super.key, this.isCurrentScreen = true});

  @override
  State<UtilityChartScreen> createState() => _UtilityChartScreenState();
}

class _UtilityChartScreenState extends State<UtilityChartScreen>
    with WidgetsBindingObserver {
  late final UtilityChartController controller;
  late final PollingCoordinator _pollingCoordinator;
  late final ValueNotifier<bool> _animationEnabledNotifier;

  Timer? _resumeAnimationTimer;

  bool _appActive = true;
  bool _isScrolling = false;
  bool _disposed = false;
  bool _controllerInitialized = false;
  bool _networkReady = false;
  bool _activating = false;
  bool _activationPending = false;

  bool get _animationEnabled {
    return !_disposed && _appActive && widget.isCurrentScreen && !_isScrolling;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _pollingCoordinator = context.read<PollingCoordinator>();
    controller = UtilityChartController(
      catalog: context.read<UtilityChartCatalogController>(),
    );
    controller.addListener(_syncMinutePolling);
    _animationEnabledNotifier = ValueNotifier<bool>(_animationEnabled);

    _syncMinutePolling();

    _scheduleActivation();
  }

  void _syncMinutePolling() {
    final shouldPoll =
        widget.isCurrentScreen &&
        controller.selectedView == UtilityChartView.minutes;

    if (shouldPoll) {
      _pollingCoordinator.activateScope(PollingScope.chartsMinutes);
    } else {
      _pollingCoordinator.deactivateScope(PollingScope.chartsMinutes);
    }
  }

  void _scheduleActivation() {
    if (_disposed ||
        !widget.isCurrentScreen ||
        _activating ||
        _activationPending) {
      return;
    }

    _activationPending = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activationPending = false;

      if (!mounted || _disposed || !widget.isCurrentScreen) return;

      unawaited(_activateCharts());
    });
  }

  Future<void> _activateCharts() async {
    if (_disposed || !widget.isCurrentScreen || _activating) return;

    _activating = true;

    try {
      if (_controllerInitialized) {
        // Re-entry: only hit the network when the cached catalog has expired.
        await controller.refreshIfStale();
      } else {
        _controllerInitialized = true;
        await controller.initialize();
      }
    } finally {
      _activating = false;

      if (!_disposed && mounted && widget.isCurrentScreen) {
        setState(() {
          _networkReady = true;
        });
      }
    }
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

    _appActive = nextActive;
    _syncAnimationEnabled();
  }

  /*
   * Không cần setState trong didUpdateWidget.
   *
   * Khi isCurrentScreen thay đổi, Flutter tự gọi build lại rồi.
   * Gọi setState ở đây sẽ tạo thêm một frame rebuild không cần thiết.
   */
  @override
  void didUpdateWidget(covariant UtilityChartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isCurrentScreen != widget.isCurrentScreen) {
      _syncMinutePolling();

      if (widget.isCurrentScreen) {
        _scheduleActivation();
      } else {
        _networkReady = false;
      }
    }

    if (!widget.isCurrentScreen) {
      _resumeAnimationTimer?.cancel();

      if (_isScrolling) {
        _isScrolling = false;
      }
    }

    _syncAnimationEnabled();
  }

  // ============================================================
  // SCROLL PERFORMANCE
  // ============================================================

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_disposed || !mounted) {
      return false;
    }

    if (notification is ScrollStartNotification) {
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

    _isScrolling = true;
    _syncAnimationEnabled();
  }

  void _scheduleResumeAnimation() {
    _resumeAnimationTimer?.cancel();

    _resumeAnimationTimer = Timer(const Duration(milliseconds: 180), () {
      if (_disposed || !mounted || !_isScrolling) {
        return;
      }

      _isScrolling = false;
      _syncAnimationEnabled();
    });
  }

  void _syncAnimationEnabled() {
    final enabled = _animationEnabled;
    if (_animationEnabledNotifier.value != enabled) {
      _animationEnabledNotifier.value = enabled;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: ValueListenableBuilder<bool>(
        valueListenable: _animationEnabledNotifier,
        child: RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _UtilityContentLayer(
              controller: controller,
              isActive: widget.isCurrentScreen && _networkReady,
            ),
          ),
        ),
        builder: (context, animationEnabled, content) {
          return TickerMode(
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
                      child: UtilityChartBackground(
                        controller: controller,
                        animated: animationEnabled,
                      ),
                    ),
                    content!,
                  ],
                ),
              ),
            ),
          );
        },
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

    _animationEnabledNotifier.dispose();
    _pollingCoordinator.deactivateScope(PollingScope.chartsMinutes);
    controller.removeListener(_syncMinutePolling);
    controller.dispose();

    super.dispose();
  }
}

// ============================================================
// CONTENT
// ============================================================

/// Subscribes to the controller and rebuilds the chart content.
///
/// Kept as a separate widget so the rebuild stays below the background layer
/// and the animation [TickerMode], which must not rebuild on controller data.
class _UtilityContentLayer extends StatelessWidget {
  final UtilityChartController controller;
  final bool isActive;

  const _UtilityContentLayer({
    required this.controller,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final theme = ChartThemes.byCate(controller.selectedCate);

        return UtilityChartContent(
          controller: controller,
          theme: theme,
          isActive: isActive,
        );
      },
    );
  }
}
