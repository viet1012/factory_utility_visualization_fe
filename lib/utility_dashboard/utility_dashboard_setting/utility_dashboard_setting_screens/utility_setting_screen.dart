import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/utility_dashboard_setting_screens/utility_scada_channel_screen.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/utility_dashboard_setting_screens/utility_scada_screen.dart';
import 'package:flutter/material.dart';

import '../utility_para_api.dart';
import '../utility_scada_api.dart';
import '../utility_scada_channel_api.dart';
import 'utility_para_screen.dart';

class TabConfig {
  final String label;
  final IconData icon;
  final String? badge;

  const TabConfig({required this.label, required this.icon, this.badge});
}

class TabBarStyles {
  static const Color activeColor = Colors.white;
  static const Color inactiveColor = Colors.white54;
  static const Color indicatorColor = Color(0xFF1F6FEB);
  static const Color backgroundColor = Color(0xFF0D1117);
  static const Color accentColor = Color(0xFF3FB950);

  static const double tabHeight = 56;
  static const double indicatorHeight = 3;
  static const double borderRadius = 12;
  static const double iconSize = 20;
  static const double fontSize = 14;
  static const double horizontalPadding = 16;
  static const double verticalPadding = 12;

  static const Duration animationDuration = Duration(milliseconds: 300);
}

class ModernTabItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final String? badge;
  final VoidCallback onTap;

  const ModernTabItem({
    super.key,
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: TabBarStyles.animationDuration,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: TabBarStyles.horizontalPadding,
          vertical: TabBarStyles.verticalPadding,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? TabBarStyles.indicatorColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(TabBarStyles.borderRadius),
          border: Border.all(
            color: isActive
                ? TabBarStyles.indicatorColor.withOpacity(0.4)
                : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: TabBarStyles.iconSize,
              color: isActive
                  ? TabBarStyles.activeColor
                  : TabBarStyles.inactiveColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? TabBarStyles.activeColor
                    : TabBarStyles.inactiveColor,
                fontSize: TabBarStyles.fontSize,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TabBarStyles.accentColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
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
  late TabController _tabController;
  int _currentTabIndex = 0;

  late List<TabConfig> _tabs;

  @override
  void initState() {
    super.initState();
    _initTabs();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: 0,
    );
    _tabController.addListener(_onTabChanged);
  }

  void _initTabs() {
    _tabs = [
      const TabConfig(label: 'SCADA', icon: Icons.settings_rounded),
      const TabConfig(label: 'CHANNEL', icon: Icons.cable_rounded),
      const TabConfig(label: 'PARA', icon: Icons.tune_rounded),
    ];
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    }
  }

  void _updateBadge(int index, String? badge) {
    if (index < _tabs.length) {
      setState(() {
        _tabs[index] = TabConfig(
          label: _tabs[index].label,
          icon: _tabs[index].icon,
          badge: badge,
        );
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabBar(),
        Container(height: 1, color: Colors.white.withOpacity(0.08)),
        Expanded(child: _buildTabContent()),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TabBarStyles.horizontalPadding,
        vertical: 8,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(
            _tabs.length,
            (index) => ModernTabItem(
              label: _tabs[index].label,
              icon: _tabs[index].icon,
              badge: _tabs[index].badge,
              isActive: _currentTabIndex == index,
              onTap: () => _tabController.animateTo(index),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      physics: const BouncingScrollPhysics(),
      children: [_buildScadaTab(), _buildChannelTab(), _buildParaTab()],
    );
  }

  Widget _buildScadaTab() {
    return Container(
      color: Colors.transparent,
      child: UtilityScadaScreen(api: widget.scadaApi),
    );
  }

  Widget _buildChannelTab() {
    return Container(
      color: Colors.transparent,
      child: UtilityScadaChannelScreen(api: widget.channelApi),
    );
  }

  Widget _buildParaTab() {
    return Container(
      color: Colors.transparent,
      child: UtilityParaScreen(api: widget.paraApi),
    );
  }

  void updateScadaBadge(String? badge) => _updateBadge(0, badge);

  void updateChannelBadge(String? badge) => _updateBadge(1, badge);

  void updateParaBadge(String? badge) => _updateBadge(2, badge);

  void goToTab(int index) {
    if (index < _tabs.length) {
      _tabController.animateTo(index);
    }
  }
}

// class UtilityScadaSettingScreen extends StatefulWidget {
//   final UtilityScadaApi scadaApi;
//   final UtilityScadaChannelApi channelApi;
//
//   const UtilityScadaSettingScreen({
//     super.key,
//     required this.scadaApi,
//     required this.channelApi,
//   });
//
//   @override
//   State<UtilityScadaSettingScreen> createState() =>
//       _UtilityScadaSettingScreenState();
// }
//
// class _UtilityScadaSettingScreenState extends State<UtilityScadaSettingScreen>
//     with SingleTickerProviderStateMixin {
//   late TabController _tabController;
//
//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//   }
//
//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         /// ===== TAB HEADER =====
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//           child: TabBar(
//             controller: _tabController,
//             indicator: BoxDecoration(
//               color: Colors.blueAccent.withOpacity(0.2),
//               borderRadius: BorderRadius.circular(10),
//             ),
//             labelColor: Colors.white,
//             unselectedLabelColor: Colors.white54,
//             tabs: const [
//               Tab(text: 'SCADA'),
//               Tab(text: 'CHANNEL'),
//             ],
//           ),
//         ),
//
//         /// ===== CONTENT =====
//         Expanded(
//           child: TabBarView(
//             controller: _tabController,
//             children: [
//               UtilityScadaScreen(api: widget.scadaApi),
//               UtilityScadaChannelScreen(api: widget.channelApi),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }
