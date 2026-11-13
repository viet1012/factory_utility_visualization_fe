import 'package:flutter/material.dart';

import '../shared/formatters/period_basis_formatter.dart';
import 'electric_consumption/electric_consumption_screen.dart';
import 'electricity/electricity_screen.dart';

/// Nhom tien ich tren thanh tab con: Electricity (2 goc nhin) | Water.
enum MonitoringGroup {
  electricity('Electricity', Icons.bolt_rounded),
  water('Water', Icons.water_drop_outlined);

  const MonitoringGroup(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Thu tu enum = thu tu tren thanh tab va index cua IndexedStack.
enum MonitoringSubTab {
  electricity(
    'Live',
    Icons.timeline_rounded,
    MonitoringGroup.electricity,
    'Live power usage · day / week / month',
  ),
  electricConsumption(
    'Bill period',
    Icons.receipt_long_outlined,
    MonitoringGroup.electricity,
    'Daily consumption & cost per bill period '
        '(${PeriodBasisFormatter.billPeriodSpanText}), '
        'as in the F2 Excel report',
  ),
  waterCheck(
    'Water',
    Icons.water_drop_outlined,
    MonitoringGroup.water,
    'Water facility check',
  );

  const MonitoringSubTab(this.label, this.icon, this.group, this.hint);

  final String label;
  final IconData icon;
  final MonitoringGroup group;

  /// Tooltip khi re chuot.
  final String hint;
}

/// Tab MONITORING: Electricity (Live | Bill period) | Water. Polling scope
/// cua tung sub-tab do dashboard bat / tat qua [onChanged].
///
/// Live / Bill period: thanh tab con la mot hang rieng phia tren.
/// Water check: thanh tab con nam cung hang tieu de cua man (truyen vao
/// [waterCheckBuilder]).
class MonitoringScreen extends StatelessWidget {
  final MonitoringSubTab selected;
  final ValueChanged<MonitoringSubTab> onChanged;
  final ElectricityScreen electricity;
  final ElectricConsumptionScreen electricConsumption;

  /// [subTabs]: thanh tab con dat trong header Water check (null khi an).
  final Widget Function(Widget? subTabs) waterCheckBuilder;

  /// WATER CHECK full screen: an thanh sub-tab.
  final bool hideSubTabBar;

  const MonitoringScreen({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.electricity,
    required this.electricConsumption,
    required this.waterCheckBuilder,
    this.hideSubTabBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final subTabs = hideSubTabBar
        ? null
        : MonitoringSubTabBar(selected: selected, onChanged: onChanged);

    Widget withTabRow(Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (subTabs != null) ...[
          Align(alignment: Alignment.centerLeft, child: subTabs),
          const SizedBox(height: 8),
        ],
        Expanded(child: child),
      ],
    );

    return IndexedStack(
      index: selected.index,
      children: [
        for (final tab in MonitoringSubTab.values)
          // IndexedStack khong tat ticker cua sub-tab an.
          TickerMode(
            enabled: tab == selected,
            child: switch (tab) {
              MonitoringSubTab.electricity => withTabRow(electricity),
              MonitoringSubTab.electricConsumption => withTabRow(
                electricConsumption,
              ),
              MonitoringSubTab.waterCheck => waterCheckBuilder(subTabs),
            },
          ),
      ],
    );
  }
}

/// `⚡ ELECTRICITY [Live] [Bill period] │ [💧 Water]`: tab gom theo nhom
/// tien ich trong mot khung bo tron, gon (cao 30) de dat chung hang tieu de
/// cua Water check.
///
/// Nhom co nhieu tab hien nhan nhom (bam vao chon tab dau cua nhom); nhom
/// mot tab chi hien nut cua tab do (kem icon nhom).
class MonitoringSubTabBar extends StatelessWidget {
  final MonitoringSubTab selected;
  final ValueChanged<MonitoringSubTab> onChanged;

  const MonitoringSubTabBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const Color _track = Color(0xFF0B1A2B);
  static const Color _border = Color(0xFF1C3550);

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    for (final group in MonitoringGroup.values) {
      final tabs = [
        for (final tab in MonitoringSubTab.values)
          if (tab.group == group) tab,
      ];
      if (tabs.isEmpty) continue;

      if (children.isNotEmpty) {
        children.add(
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: _border,
          ),
        );
      }

      final groupActive = selected.group == group;
      if (tabs.length > 1) {
        children.add(
          _GroupLabel(
            group: group,
            active: groupActive,
            onTap: groupActive ? null : () => onChanged(tabs.first),
          ),
        );
      }
      for (final tab in tabs) {
        children.add(
          _SubTabPill(
            tab: tab,
            // Nhom mot tab: nut mang icon nhom thay cho nhan nhom.
            showIcon: tabs.length == 1,
            selected: tab == selected,
            onTap: () => onChanged(tab),
          ),
        );
      }
    }

    return Container(
      height: 30,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _track,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final MonitoringGroup group;
  final bool active;
  final VoidCallback? onTap;

  const _GroupLabel({
    required this.group,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? _SubTabPill.accent : _SubTabPill.dim;

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 6, 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(group.icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              group.label.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubTabPill extends StatelessWidget {
  final MonitoringSubTab tab;
  final bool showIcon;
  final bool selected;
  final VoidCallback onTap;

  const _SubTabPill({
    required this.tab,
    required this.showIcon,
    required this.selected,
    required this.onTap,
  });

  static const Color accent = Color(0xFF00CFFF);
  static const Color dim = Color(0xFF8DA2B8);
  static const Color _selectedBg = Color(0xFF1F4E79);
  static const Color _text = Color(0xFFE6EEF7);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tab.hint,
      waitDuration: const Duration(milliseconds: 500),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected ? _selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: .45)
                : Colors.transparent,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: selected ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    showIcon ? tab.group.icon : tab.icon,
                    size: 15,
                    color: selected ? accent : dim,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tab.label,
                    style: TextStyle(
                      color: selected ? _text : dim,
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
