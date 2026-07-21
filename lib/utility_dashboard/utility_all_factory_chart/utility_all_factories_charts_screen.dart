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

  bool _appActive = true;

  bool get _animationEnabled {
    return _appActive && widget.isCurrentScreen;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    controller = UtilityAllFactoriesController(
      catalog: context.read<ChartCatalogProvider>(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      controller.initialize();
    });
  }

  @override
  void didUpdateWidget(covariant UtilityAllFactoriesChartsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isCurrentScreen != widget.isCurrentScreen) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;

    if (_appActive == active) {
      return;
    }

    setState(() {
      _appActive = active;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: _animationEnabled,
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
            _UtilityBackgroundLayer(
              controller: controller,
              animated: _animationEnabled,
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: _UtilityContentLayer(controller: controller),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// BACKGROUND
// Chỉ rebuild khi category thay đổi.
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
    final next = widget.controller.selectedCate;

    if (next == _category) {
      return;
    }

    setState(() {
      _category = next;
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChartThemes.byCate(_category);

    return Positioned.fill(
      child: UtilityIndustrialMotionBackground(
        key: ValueKey('utility-background-$_category'),
        cate: _category,
        color: theme.line,
        animated: widget.animated,
      ),
    );
  }
}

// ============================================================
// CONTENT
// Chỉ content rebuild khi controller thay đổi.
// ============================================================

class _UtilityContentLayer extends StatelessWidget {
  final UtilityAllFactoriesController controller;

  const _UtilityContentLayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final category = controller.selectedCate;

        final theme = ChartThemes.byCate(category);

        return RepaintBoundary(
          child: UtilityAllFactoriesContent(
            controller: controller,
            theme: theme,
          ),
        );
      },
    );
  }
}
