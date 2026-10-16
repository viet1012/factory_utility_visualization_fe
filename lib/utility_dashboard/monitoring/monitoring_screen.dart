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
class MonitoringScreen extends StatelessWidget {
  final MonitoringSubTab selected;
  final ValueChanged<MonitoringSubTab> onChanged;
  final ElectricityScreen electricity;
  final Widget waterCheck;

  /// WATER CHECK full screen: an thanh sub-tab.
  final bool hideSubTabBar;

  const MonitoringScreen({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.electricity,
    required this.waterCheck,
    this.hideSubTabBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hideSubTabBar) ...[
          Row(
            children: [
              for (final tab in MonitoringSubTab.values)
                _SubTabButton(
                  tab: tab,
                  selected: tab == selected,
                  onTap: () => onChanged(tab),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: IndexedStack(
            index: selected.index,
            children: [
              for (final tab in MonitoringSubTab.values)
                // IndexedStack khong tat ticker cua sub-tab an.
                TickerMode(
                  enabled: tab == selected,
                  child: tab == MonitoringSubTab.electricity
                      ? electricity
                      : waterCheck,
                ),
            ],
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
