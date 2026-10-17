import 'package:flutter/material.dart';

import 'electricity/electricity_screen.dart';

enum MonitoringSubTab {
  electricity('Electricity', Icons.bolt_rounded),
  waterCheck('Water check', Icons.water_drop_outlined);

  const MonitoringSubTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Tab MONITORING: sub-tab Electricity | Water check. Polling scope cua tung
/// sub-tab do dashboard bat / tat qua [onChanged].
///
/// Electricity: thanh tab con la mot hang rieng phia tren. Water check: thanh
/// tab con nam cung hang tieu de cua man (truyen vao [waterCheckBuilder]).
class MonitoringScreen extends StatelessWidget {
  final MonitoringSubTab selected;
  final ValueChanged<MonitoringSubTab> onChanged;
  final ElectricityScreen electricity;

  /// [subTabs]: thanh tab con dat trong header Water check (null khi an).
  final Widget Function(Widget? subTabs) waterCheckBuilder;

  /// WATER CHECK full screen: an thanh sub-tab.
  final bool hideSubTabBar;

  const MonitoringScreen({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.electricity,
    required this.waterCheckBuilder,
    this.hideSubTabBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final subTabs = hideSubTabBar
        ? null
        : MonitoringSubTabBar(selected: selected, onChanged: onChanged);

    return IndexedStack(
      index: selected.index,
      children: [
        for (final tab in MonitoringSubTab.values)
          // IndexedStack khong tat ticker cua sub-tab an.
          TickerMode(
            enabled: tab == selected,
            child: tab == MonitoringSubTab.electricity
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (subTabs != null) ...[
                        Align(alignment: Alignment.centerLeft, child: subTabs),
                        const SizedBox(height: 8),
                      ],
                      Expanded(child: electricity),
                    ],
                  )
                : waterCheckBuilder(subTabs),
          ),
      ],
    );
  }
}

/// Electricity | Water check, gon (cao 30) de dat chung hang tieu de.
class MonitoringSubTabBar extends StatelessWidget {
  final MonitoringSubTab selected;
  final ValueChanged<MonitoringSubTab> onChanged;

  const MonitoringSubTabBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tab in MonitoringSubTab.values)
          _SubTabButton(
            tab: tab,
            selected: tab == selected,
            onTap: () => onChanged(tab),
          ),
      ],
    );
  }
}

class _SubTabButton extends StatelessWidget {
  final MonitoringSubTab tab;
  final bool selected;
  final VoidCallback onTap;

  const _SubTabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00CFFF);
    final color = selected ? accent : const Color(0xFF8DA2B8);

    return InkWell(
      onTap: selected ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tab.icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              tab.label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
