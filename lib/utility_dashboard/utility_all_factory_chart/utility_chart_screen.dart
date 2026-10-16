import 'dart:async';

import 'package:factory_utility_visualization/utility_dashboard/utility_all_factory_chart/controllers/utility_chart_controller.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_all_factory_chart/widgets/utility_chart_content.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../shared/widgets/feed_status_banner.dart';
import 'controllers/series_history_chart_controller.dart';
import 'controllers/utility_chart_catalog_controller.dart';
import 'controllers/utility_daily_chart_controller.dart';
import 'controllers/utility_hourly_chart_controller.dart';
import 'controllers/utility_minute_chart_controller.dart';
import '../shared/polling/polling_coordinator.dart';
import '../shared/polling/polling_scope.dart';
import 'tabs/utility_chart_view.dart';
import '../utility_dashboard_common/chart_theme.dart';
import 'widgets/utility_chart_background.dart';

class UtilityChartScreen extends StatefulWidget {
  final bool isCurrentScreen;

  /// Yeu cau mo mot signal tu tab khac (WATER CHECK › Open in Charts).
  final ValueListenable<ChartFocusRequest?>? focusRequest;

  const UtilityChartScreen({
    super.key,
    this.isCurrentScreen = true,
    this.focusRequest,
  });

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
    controller.addListener(_syncViewPolling);
    widget.focusRequest?.addListener(_handleFocusRequest);
    _animationEnabledNotifier = ValueNotifier<bool>(_animationEnabled);

    _syncViewPolling();

    _scheduleActivation();
  }

  void _handleFocusRequest() {
    final request = widget.focusRequest?.value;
    if (request == null || _disposed) return;

    unawaited(controller.focusSignal(request));
  }

  /// Polling scope cua tung tab; tab khong co polling (Daily) thi khong co.
  static const Map<UtilityChartView, PollingScope> _viewScopes = {
    UtilityChartView.minutes: PollingScope.chartsMinutes,
    UtilityChartView.hours: PollingScope.chartsHourly,
  };

  /// Chi bat scope cua tab dang xem (khi screen dang hien), tat moi scope khac.
  void _syncViewPolling() {
    final activeScope = widget.isCurrentScreen
        ? _viewScopes[controller.selectedView]
        : null;

    for (final scope in _viewScopes.values) {
      if (scope == activeScope) {
        _pollingCoordinator.activateScope(scope);
      } else {
        _pollingCoordinator.deactivateScope(scope);
      }
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

    if (oldWidget.focusRequest != widget.focusRequest) {
      oldWidget.focusRequest?.removeListener(_handleFocusRequest);
      widget.focusRequest?.addListener(_handleFocusRequest);
    }

    if (oldWidget.isCurrentScreen != widget.isCurrentScreen) {
      _syncViewPolling();

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
    for (final scope in _viewScopes.values) {
      _pollingCoordinator.deactivateScope(scope);
    }
    widget.focusRequest?.removeListener(_handleFocusRequest);
    controller.removeListener(_syncViewPolling);
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
          statusBanner: _FeedStatusLayer(view: controller.selectedView),
        );
      },
    );
  }
}

// ============================================================
// FEED STATUS BANNER
// ============================================================

/// Banner chung cua tab dang xem: FEED_DELAYED (cam) hoac moi box
/// FETCH_FAILED (do). Tu an khi trang thai ve ok (lan tai sau co mau moi).
class _FeedStatusLayer extends StatelessWidget {
  final UtilityChartView view;

  const _FeedStatusLayer({required this.view});

  static final DateFormat _timeFormat = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    return switch (view) {
      UtilityChartView.minutes => _select<UtilityMinuteChartController>(),
      UtilityChartView.hours => _select<UtilityHourlyChartController>(),
      UtilityChartView.daily => _select<UtilityDailyChartController>(),
    };
  }

  Widget _select<C extends SeriesHistoryChartController<dynamic>>() {
    return Selector<C, SeriesFeedStatus>(
      selector: (_, controller) => controller.feedStatus,
      builder: (context, status, _) => _banner(status),
    );
  }

  Widget _banner(SeriesFeedStatus status) {
    final banner = switch (status.state) {
      SeriesFeedState.ok => null,
      SeriesFeedState.feedDelayed => _delayed(status),
      SeriesFeedState.unreachable => const FeedStatusBanner(
        icon: Icons.cloud_off_rounded,
        message: 'Cannot reach server · retrying',
        color: Colors.redAccent,
      ),
    };

    if (banner == null) return const SizedBox.shrink();

    return Padding(padding: const EdgeInsets.only(bottom: 6), child: banner);
  }

  Widget _delayed(SeriesFeedStatus status) {
    final since = status.lastSampleAt;
    final at = status.evaluatedAt ?? DateTime.now();

    final detail = since == null
        ? ''
        : ' · no new samples since ${_timeFormat.format(since)} '
              '(${at.difference(since).inMinutes} min)';

    return FeedStatusBanner(
      icon: Icons.hourglass_bottom_rounded,
      message: 'Data feed delayed$detail · showing last known values',
      color: Colors.orange,
    );
  }
}
