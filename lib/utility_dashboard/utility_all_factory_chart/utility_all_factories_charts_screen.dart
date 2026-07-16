import 'package:factory_utility_visualization/utility_dashboard/utility_all_factory_chart/utility_all_factories_controller.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_all_factory_chart/widgets/utility_all_factories_content.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_state/chart_catalog_provider.dart';
import '../utility_dashboard_common/chart_theme.dart';
import '../utility_dashboard_overview/utility_dashboard_overview_painter/utility_industrial_motion_background.dart';

class UtilityAllFactoriesChartsScreen extends StatefulWidget {
  const UtilityAllFactoriesChartsScreen({super.key});

  @override
  State<UtilityAllFactoriesChartsScreen> createState() =>
      _UtilityAllFactoriesChartsScreenState();
}

class _UtilityAllFactoriesChartsScreenState
    extends State<UtilityAllFactoriesChartsScreen> {
  late final UtilityAllFactoriesController controller;

  @override
  void initState() {
    super.initState();

    controller = UtilityAllFactoriesController(
      catalog: context.read<ChartCatalogProvider>(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.initialize();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final theme = ChartThemes.byCate(controller.selectedCate);

        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A0E27), Color(0xFF020B16)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: UtilityIndustrialMotionBackground(
                        cate: controller.selectedCate,
                        color: theme.line,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: UtilityAllFactoriesContent(
                      controller: controller,
                      theme: theme,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
