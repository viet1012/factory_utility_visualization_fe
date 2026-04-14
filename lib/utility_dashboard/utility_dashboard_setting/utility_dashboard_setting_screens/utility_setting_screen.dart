import 'package:flutter/material.dart';

import '../utility_para_api.dart';
import '../utility_scada_api.dart';
import '../utility_scada_channel_api.dart';
import 'utility_para_screen.dart';
import 'utility_scada_channel_screen.dart';
import 'utility_scada_screen.dart';

class TabSpec {
  final String label;
  final IconData icon;
  final Widget child;
  final String? badge;

  const TabSpec({
    required this.label,
    required this.icon,
    required this.child,
    this.badge,
  });

  TabSpec copyWith({
    String? label,
    IconData? icon,
    Widget? child,
    String? badge,
  }) {
    return TabSpec(
      label: label ?? this.label,
      icon: icon ?? this.icon,
      child: child ?? this.child,
      badge: badge,
    );
  }
}

class UtilityScadaSettingScreen extends StatefulWidget {
  final UtilityScadaApi scadaApi;
  final UtilityScadaChannelApi channelApi;
  final UtilityParaApi paraApi;

  const UtilityScadaSettingScreen({
    super.key,
    required this.scadaApi,
    required this.channelApi,
    required this.paraApi,
  });

  @override
  State<UtilityScadaSettingScreen> createState() =>
      _UtilityScadaSettingScreenState();
}

class _UtilityScadaSettingScreenState extends State<UtilityScadaSettingScreen>
    with SingleTickerProviderStateMixin {
  static const _tabBarBg = Color(0xFF0B0D12);
  static const _active = Colors.white;
  static const _inactive = Colors.white54;
  static const _accent = Color(0xFF1F6FEB);
  static const _badge = Color(0xFF3FB950);

  late final TabController _controller;
  late List<TabSpec> _tabs;

  int get _currentIndex => _controller.index;

  @override
  void initState() {
    super.initState();

    _tabs = [
      TabSpec(
        label: 'SCADA',
        icon: Icons.settings_rounded,
        child: UtilityScadaScreen(api: widget.scadaApi),
      ),
      TabSpec(
        label: 'CHANNEL',
        icon: Icons.cable_rounded,
        child: UtilityScadaChannelScreen(
          api: widget.channelApi,
          scadaApi: widget.scadaApi,
        ),
      ),
      TabSpec(
        label: 'PARA',
        icon: Icons.tune_rounded,
        child: UtilityParaTreeScreen(
          api: widget.paraApi,
          scadaChannelApi: widget.channelApi,
        ),
      ),
    ];

    _controller = TabController(length: _tabs.length, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateBadge(int index, String? badge) {
    if (index < 0 || index >= _tabs.length) return;
    setState(() {
      _tabs[index] = _tabs[index].copyWith(badge: badge);
    });
  }

  void updateScadaBadge(String? badge) => _updateBadge(0, badge);

  void updateChannelBadge(String? badge) => _updateBadge(1, badge);

  void updateParaBadge(String? badge) => _updateBadge(2, badge);

  void goToTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      _controller.animateTo(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_tabs.length, (index) {
                final tab = _tabs[index];
                final selected = index == _currentIndex;

                return Padding(
                  padding: EdgeInsets.only(
                    right: index == _tabs.length - 1 ? 0 : 8,
                  ),
                  child: _TabChip(
                    label: tab.label,
                    icon: tab.icon,
                    badge: tab.badge,
                    selected: selected,
                    activeColor: _active,
                    inactiveColor: _inactive,
                    accentColor: _accent,
                    badgeColor: _badge,
                    onTap: () => _controller.animateTo(index),
                  ),
                );
              }),
            ),
          ),
        ),
        Container(height: 1, color: Colors.white.withOpacity(0.08)),
        Expanded(
          child: TabBarView(
            controller: _controller,
            physics: const BouncingScrollPhysics(),
            children: _tabs.map((e) => e.child).toList(),
          ),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? badge;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final Color accentColor;
  final Color badgeColor;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.accentColor,
    required this.badgeColor,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? activeColor : inactiveColor;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accentColor.withOpacity(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? accentColor.withOpacity(0.36)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            if (badge != null && badge!.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
