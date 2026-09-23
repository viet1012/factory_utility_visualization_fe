import 'package:flutter/material.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../controllers/utility_chart_controller.dart';
import 'utility_industrial_motion_background.dart';

/// Industrial motion background for the chart screen.
///
/// Deliberately subscribes to the controller directly and rebuilds **only**
/// when `selectedCate` changes, so the (expensive) background is untouched by
/// catalog loads, view switches, filter edits and polling updates.
class UtilityChartBackground extends StatefulWidget {
  final UtilityChartController controller;
  final bool animated;

  const UtilityChartBackground({
    super.key,
    required this.controller,
    required this.animated,
  });

  @override
  State<UtilityChartBackground> createState() => _UtilityChartBackgroundState();
}

class _UtilityChartBackgroundState extends State<UtilityChartBackground> {
  late String _category;

  @override
  void initState() {
    super.initState();

    _category = widget.controller.selectedCate;

    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant UtilityChartBackground oldWidget) {
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
