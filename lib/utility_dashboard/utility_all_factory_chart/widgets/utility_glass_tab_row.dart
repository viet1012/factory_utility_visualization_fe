import 'package:flutter/material.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_overview/utility_dashboard_overview_widgets/scada_tab_button.dart';

class UtilityGlassTabRow extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool alignRight;
  final ChartTheme theme;

  final bool showAllChip;
  final bool allChipSelected;
  final VoidCallback? onAllTap;

  const UtilityGlassTabRow({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
    required this.theme,
    this.alignRight = false,
    this.showAllChip = false,
    this.allChipSelected = false,
    this.onAllTap,
  });

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ScadaTabButton(
      label: label,
      selected: selected,
      onTap: onTap,
      color: theme.line,
      minWidth: label.length <= 4 ? 66 : 92,
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (showAllChip)
        _buildChip(
          label: 'ALL',
          selected: allChipSelected,
          onTap: onAllTap ?? () {},
        ),
      for (var index = 0; index < labels.length; index++)
        _buildChip(
          label: labels[index],
          selected: index == selectedIndex,
          onTap: () => onSelect(index),
        ),
    ];

    final tabs = Wrap(spacing: 8, runSpacing: 8, children: children);

    return alignRight
        ? Align(alignment: Alignment.topRight, child: tabs)
        : tabs;
  }
}
