import 'package:flutter/material.dart';

class UtilityOverviewFilter {
  final String cate;
  final String factory;
  final String period;

  const UtilityOverviewFilter({
    required this.cate,
    required this.factory,
    required this.period,
  });

  UtilityOverviewFilter copyWith({
    String? cate,
    String? factory,
    String? period,
  }) {
    return UtilityOverviewFilter(
      cate: cate ?? this.cate,
      factory: factory ?? this.factory,
      period: period ?? this.period,
    );
  }
}

class UtilityOverviewTopHeader extends StatelessWidget {
  final UtilityOverviewFilter filter;

  final ValueChanged<String> onCateChanged;
  final ValueChanged<String> onFactoryChanged;
  final ValueChanged<String> onPeriodChanged;

  const UtilityOverviewTopHeader({
    super.key,
    required this.filter,
    required this.onCateChanged,
    required this.onFactoryChanged,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          _FilterBox(
            icon: Icons.bolt_rounded,
            title: 'Utility',
            value: filter.cate,
            color: Colors.amberAccent,
            items: const ['Electricity', 'Water', 'Compressed Air'],
            onChanged: onCateChanged,
          ),
          const SizedBox(width: 12),
          _FilterBox(
            icon: Icons.factory_rounded,
            title: 'Factory',
            value: filter.factory,
            color: Colors.white70,
            items: const ['All Factory', 'FAC A', 'FAC B', 'FAC C'],
            onChanged: onFactoryChanged,
          ),
          const SizedBox(width: 12),
          _FilterBox(
            icon: Icons.calendar_month_rounded,
            title: 'Period',
            value: filter.period,
            color: Colors.cyanAccent,
            items: const ['Today', 'Yesterday', 'This Week', 'This Month'],
            onChanged: onPeriodChanged,
          ),
          const Spacer(),
          _DateBox(),
        ],
      ),
    );
  }
}

class _FilterBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _FilterBox({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: const Color(0xFF071827),
      elevation: 12,
      onSelected: onChanged,
      itemBuilder: (_) {
        return items.map((e) {
          final selected = e == value;

          return PopupMenuItem<String>(
            value: e,
            child: Row(
              children: [
                if (selected)
                  Icon(Icons.check_rounded, color: color, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(
                  e,
                  style: TextStyle(
                    color: selected ? color : Colors.white.withOpacity(.82),
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        width: 164,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF071827),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(.12)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.52),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withOpacity(.65),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF071827),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: const [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                color: Colors.white70,
                size: 15,
              ),
              SizedBox(width: 8),
              Text(
                'Jun 12, 2026',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
            ],
          ),
          SizedBox(height: 3),
          Text(
            '● LIVE   •   Updated: 10:30:00',
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
