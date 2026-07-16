import 'package:flutter/material.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import 'utility_glass_tab_row.dart';

class UtilityChartFilters extends StatelessWidget {
  final bool expanded;

  final List<String> cateTabs;
  final List<String> facTabs;
  final List<String> scadaTabs;
  final List<String> boxIdTabs;
  final List<String> boxDeviceTabs;

  final bool loadingScadas;
  final bool loadingBoxes;

  final int selectedCateIndex;
  final int selectedFacIndex;
  final int selectedScadaIndex;
  final int selectedBoxIdIndex;
  final int selectedBoxDeviceIndex;

  final bool selectedAllDevices;

  final ValueChanged<int> onCateChanged;
  final ValueChanged<int> onFacChanged;
  final ValueChanged<int> onScadaChanged;
  final ValueChanged<int> onBoxIdChanged;
  final ValueChanged<int> onBoxDeviceChanged;

  final VoidCallback onAllDevicesSelected;

  final ChartTheme theme;

  const UtilityChartFilters({
    super.key,
    required this.expanded,
    required this.cateTabs,
    required this.facTabs,
    required this.scadaTabs,
    required this.boxIdTabs,
    required this.boxDeviceTabs,
    required this.loadingScadas,
    required this.loadingBoxes,
    required this.selectedCateIndex,
    required this.selectedFacIndex,
    required this.selectedScadaIndex,
    required this.selectedBoxIdIndex,
    required this.selectedBoxDeviceIndex,
    required this.selectedAllDevices,
    required this.onCateChanged,
    required this.onFacChanged,
    required this.onScadaChanged,
    required this.onBoxIdChanged,
    required this.onBoxDeviceChanged,
    required this.onAllDevicesSelected,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: expanded
          ? Column(
              children: [
                _PrimaryFilters(
                  cateTabs: cateTabs,
                  facTabs: facTabs,
                  selectedCateIndex: selectedCateIndex,
                  selectedFacIndex: selectedFacIndex,
                  onCateChanged: onCateChanged,
                  onFacChanged: onFacChanged,
                  theme: theme,
                ),

                const SizedBox(height: 10),

                UtilityFilterSection(
                  title: 'SCADA',
                  icon: Icons.hub_rounded,
                  child: UtilityAsyncFilterContent(
                    loading: loadingScadas,
                    loadingText: 'Loading SCADA channels',
                    empty: scadaTabs.isEmpty,
                    emptyText: 'No SCADA channel configured',
                    theme: theme,
                    child: UtilityGlassTabRow(
                      labels: scadaTabs,
                      selectedIndex: selectedScadaIndex,
                      onSelect: onScadaChanged,
                      theme: theme,
                    ),
                  ),
                ),

                if (!loadingScadas && scadaTabs.isNotEmpty) ...[
                  const SizedBox(height: 8),

                  UtilityFilterSection(
                    title: 'BOX GROUP',
                    icon: Icons.inventory_2_outlined,
                    child: UtilityAsyncFilterContent(
                      loading: loadingBoxes,
                      loadingText: 'Loading box groups',
                      empty: boxIdTabs.isEmpty,
                      emptyText: 'No box group available',
                      theme: theme,
                      child: UtilityGlassTabRow(
                        labels: boxIdTabs,
                        selectedIndex: selectedBoxIdIndex,
                        onSelect: onBoxIdChanged,
                        theme: theme,
                      ),
                    ),
                  ),
                ],

                if (_canShowDevices) ...[
                  const SizedBox(height: 8),

                  UtilityFilterSection(
                    title: 'DEVICE',
                    icon: Icons.memory_rounded,
                    child: UtilityAsyncFilterContent(
                      loading: false,
                      loadingText: 'Loading devices',
                      empty: boxDeviceTabs.isEmpty,
                      emptyText: 'No device available',
                      theme: theme,
                      child: UtilityGlassTabRow(
                        labels: boxDeviceTabs,
                        selectedIndex: selectedAllDevices
                            ? -1
                            : selectedBoxDeviceIndex,
                        onSelect: onBoxDeviceChanged,
                        theme: theme,
                        showAllChip: true,
                        allChipSelected: selectedAllDevices,
                        onAllTap: onAllDevicesSelected,
                      ),
                    ),
                  ),
                ],
              ],
            )
          : const SizedBox.shrink(),
    );
  }

  bool get _canShowDevices {
    return !loadingScadas &&
        !loadingBoxes &&
        scadaTabs.isNotEmpty &&
        boxIdTabs.isNotEmpty;
  }
}

class _PrimaryFilters extends StatelessWidget {
  final List<String> cateTabs;
  final List<String> facTabs;

  final int selectedCateIndex;
  final int selectedFacIndex;

  final ValueChanged<int> onCateChanged;
  final ValueChanged<int> onFacChanged;

  final ChartTheme theme;

  const _PrimaryFilters({
    required this.cateTabs,
    required this.facTabs,
    required this.selectedCateIndex,
    required this.selectedFacIndex,
    required this.onCateChanged,
    required this.onFacChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: UtilityGlassTabRow(
            labels: cateTabs,
            selectedIndex: selectedCateIndex,
            onSelect: onCateChanged,
            theme: theme,
          ),
        ),

        const SizedBox(width: 12),

        UtilityGlassTabRow(
          labels: facTabs,
          selectedIndex: selectedFacIndex,
          onSelect: onFacChanged,
          alignRight: true,
          theme: theme,
        ),
      ],
    );
  }
}

class UtilityFilterSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const UtilityFilterSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          height: 38,
          child: Row(
            children: [
              Icon(icon, size: 16, color: Colors.white.withOpacity(.48)),

              const SizedBox(width: 7),

              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.58),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(child: child),
      ],
    );
  }
}

class UtilityAsyncFilterContent extends StatelessWidget {
  final bool loading;
  final String loadingText;

  final bool empty;
  final String emptyText;

  final ChartTheme theme;
  final Widget child;

  const UtilityAsyncFilterContent({
    super.key,
    required this.loading,
    required this.loadingText,
    required this.empty,
    required this.emptyText,
    required this.theme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content;

    if (loading) {
      content = _FilterLoadingPill(
        key: ValueKey<String>('loading-$loadingText'),
        text: loadingText,
        theme: theme,
      );
    } else if (empty) {
      content = _FilterEmptyHint(
        key: ValueKey<String>('empty-$emptyText'),
        text: emptyText,
      );
    } else {
      content = KeyedSubtree(
        key: const ValueKey<String>('filter-tabs'),
        child: child,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: content,
    );
  }
}

class _FilterLoadingPill extends StatelessWidget {
  final String text;
  final ChartTheme theme;

  const _FilterLoadingPill({
    super.key,
    required this.text,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.line.withOpacity(.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.line.withOpacity(.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: theme.line),
          ),

          const SizedBox(width: 9),

          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(.72),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterEmptyHint extends StatelessWidget {
  final String text;

  const _FilterEmptyHint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.025),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: Colors.white.withOpacity(.38),
          ),

          const SizedBox(width: 8),

          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(.46),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
