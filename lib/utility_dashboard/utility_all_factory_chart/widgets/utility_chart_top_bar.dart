import 'package:flutter/material.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import 'utility_glass_tab_row.dart';

class UtilityChartTopBar extends StatelessWidget {
  final bool filtersExpanded;

  final String selectedCate;
  final String selectedFac;
  final String? selectedScada;
  final String? selectedBox;

  final List<String> viewTabs;
  final int selectedViewIndex;
  final ValueChanged<int> onViewChanged;

  final bool importantOnly;
  final ValueChanged<bool> onImportantChanged;

  final VoidCallback onToggleFilters;

  final bool showImportantSwitch;
  final bool importantEnabled;
  final bool refreshing;

  final ChartTheme theme;

  const UtilityChartTopBar({
    super.key,
    required this.filtersExpanded,
    required this.selectedCate,
    required this.selectedFac,
    required this.selectedScada,
    required this.selectedBox,
    required this.viewTabs,
    required this.selectedViewIndex,
    required this.onViewChanged,
    required this.importantOnly,
    required this.onImportantChanged,
    required this.onToggleFilters,
    required this.showImportantSwitch,
    required this.importantEnabled,
    required this.refreshing,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CollapseToggle(
          expanded: filtersExpanded,
          onTap: onToggleFilters,
          theme: theme,
        ),

        const SizedBox(width: 12),

        UtilityGlassTabRow(
          labels: viewTabs,
          selectedIndex: selectedViewIndex,
          onSelect: onViewChanged,
          theme: theme,
        ),

        if (!filtersExpanded) ...[
          const SizedBox(width: 14),
          Expanded(
            child: _SelectedFilterSummary(
              selectedCate: selectedCate,
              selectedFac: selectedFac,
              selectedScada: selectedScada,
              selectedBox: selectedBox,
            ),
          ),
        ] else
          const Spacer(),

        if (refreshing) ...[
          _CatalogSyncBadge(color: theme.line),
          const SizedBox(width: 10),
        ],

        if (showImportantSwitch)
          _ImportantSwitch(
            value: importantOnly,
            enabled: importantEnabled,
            onChanged: onImportantChanged,
            theme: theme,
          ),
      ],
    );
  }
}

class _SelectedFilterSummary extends StatelessWidget {
  final String selectedCate;
  final String selectedFac;
  final String? selectedScada;
  final String? selectedBox;

  const _SelectedFilterSummary({
    required this.selectedCate,
    required this.selectedFac,
    required this.selectedScada,
    required this.selectedBox,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      'Cate: $selectedCate'
      '   •   Fac: $selectedFac'
      '   •   SCADA: ${selectedScada ?? "-"}'
      '   •   Box: ${selectedBox ?? "-"}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white.withOpacity(.68),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CollapseToggle extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;
  final ChartTheme theme;

  const _CollapseToggle({
    required this.expanded,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: expanded
                  ? theme.line.withOpacity(.30)
                  : Colors.white.withOpacity(.14),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedRotation(
                duration: const Duration(milliseconds: 160),
                turns: expanded ? 0 : .5,
                child: Icon(
                  Icons.expand_less_rounded,
                  color: Colors.white.withOpacity(.85),
                  size: 18,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                expanded ? 'Hide Tabs' : 'Show Tabs',
                style: TextStyle(
                  color: Colors.white.withOpacity(.88),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogSyncBadge extends StatelessWidget {
  final Color color;

  const _CatalogSyncBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(.20)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(.10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 13,
              child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              'Syncing',
              style: TextStyle(
                color: Colors.white.withOpacity(.74),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportantSwitch extends StatelessWidget {
  final bool value;
  final bool enabled;

  final ValueChanged<bool> onChanged;

  final ChartTheme theme;

  const _ImportantSwitch({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = value
        ? theme.line.withOpacity(.30)
        : Colors.white.withOpacity(.14);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled ? 1 : .52,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        padding: const EdgeInsets.only(left: 10, right: 3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: activeColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.star_rounded : Icons.star_border_rounded,
              size: 17,
              color: value ? theme.line : Colors.white54,
            ),

            const SizedBox(width: 7),

            Text(
              'Important',
              style: TextStyle(
                color: Colors.white.withOpacity(enabled ? .88 : .55),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),

            Transform.scale(
              scale: .76,
              child: Switch(
                value: value,
                activeColor: theme.line,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
