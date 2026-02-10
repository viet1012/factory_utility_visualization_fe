import 'package:flutter/material.dart';

class ScadaTabBar extends StatelessWidget {
  const ScadaTabBar();

  @override
  Widget build(BuildContext context) {
    final tabCtrl = DefaultTabController.of(context);

    return AnimatedBuilder(
      animation: tabCtrl,
      builder: (context, _) {
        final idx = tabCtrl.index;

        return Container(
          height: 52,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1729),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1B2A44)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: TabBar(
            splashFactory: NoSplash.splashFactory,
            overlayColor: const MaterialStatePropertyAll(Colors.transparent),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            padding: EdgeInsets.zero,
            labelPadding: EdgeInsets.zero,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1B2A44).withOpacity(0.95),
                  const Color(0xFF223A63).withOpacity(0.95),
                ],
              ),
              border: Border.all(color: const Color(0xFF2C4A7A)),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF9FB2D6),
            tabs: [
              _tabItem(active: idx == 0, icon: Icons.map_outlined, text: 'MAP'),
              _tabItem(
                active: idx == 1,
                icon: Icons.show_chart,
                text: 'MINI DASH',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabItem({
    required bool active,
    required IconData icon,
    required String text,
  }) {
    return Container(
      height: 40,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: active ? Colors.white : const Color(0xFF9FB2D6),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.6,
              color: active ? Colors.white : const Color(0xFF9FB2D6),
            ),
          ),
        ],
      ),
    );
  }
}
