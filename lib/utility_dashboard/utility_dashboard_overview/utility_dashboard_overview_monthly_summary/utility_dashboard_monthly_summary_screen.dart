import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';
import '../utility_dashboard_overview_monthly/utility_overview_monthly_box.dart';

class MonthlySummaryScreen extends StatefulWidget {
  final String facId;
  final String month;

  const MonthlySummaryScreen({
    super.key,
    required this.facId,
    required this.month,
  });

  @override
  State<MonthlySummaryScreen> createState() => _MonthlySummaryScreenState();
}

class _MonthlySummaryScreenState extends State<MonthlySummaryScreen> {
  static const Duration _refreshInterval = Duration(seconds: 30);
  static const Duration _requestTimeout = Duration(seconds: 15);

  Timer? _refreshTimer;

  bool _loading = true;
  bool _loadingNow = false;
  bool _disposed = false;
  Object? _error;

  List<EnergyMonthlySummary> _items = const [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed) return;
      _load();
    });

    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted || _disposed) return;
      _load(silent: true);
    });
  }

  @override
  void didUpdateWidget(covariant MonthlySummaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.facId != widget.facId || oldWidget.month != widget.month) {
      setState(() {
        _loading = true;
        _error = null;
        _items = const [];
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _disposed) return;
        _load();
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_loadingNow || _disposed || !mounted) return;

    _loadingNow = true;

    if (!silent && _items.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final api = context.read<UtilityDashboardOverviewApi>();

      final raw = await api
          .getEnergyMonthlySummary(facId: widget.facId, month: widget.month)
          .timeout(_requestTimeout);

      final parsedItems = raw
          .whereType<Map<String, dynamic>>()
          .map(EnergyMonthlySummary.fromJson)
          .toList(growable: false);

      setState(() {
        _items = parsedItems;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || _disposed) return;

      setState(() {
        _error = e;
        _loading = false;
      });
    } finally {
      _loadingNow = false;
    }
  }

  String get monthLabel {
    final raw = widget.month;
    if (raw.length != 6) return raw;

    final year = raw.substring(0, 4);
    final m = int.tryParse(raw.substring(4, 6)) ?? 1;

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[m - 1]} $year';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xff22d3ee)),
      );
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Text(
          'Load monthly summary failed',
          style: TextStyle(color: Colors.redAccent),
        ),
      );
    }

    final electricity = _items
        .where((e) => e.cate.toUpperCase().contains('ELECTRIC'))
        .firstOrNull;

    final water = _items
        .where((e) => e.cate.toUpperCase().contains('WATER'))
        .firstOrNull;

    final air = _items
        .where((e) => e.cate.toUpperCase().contains('AIR'))
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xff020817),
        borderRadius: BorderRadius.circular(24),
        // border: Border.all(color: const Color(0xff06b6d4), width: 1.2),
      ),
      child: Column(
        children: [
          _Header(monthLabel: monthLabel),
          const SizedBox(height: 8),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (electricity != null)
                  Expanded(child: _ElectricCard(item: electricity)),
                if (electricity != null && (water != null || air != null))
                  const SizedBox(width: 6),

                if (water != null)
                  Expanded(
                    child: _UtilityMinMaxCard(
                      item: water,
                      title: 'WATER',
                      subtitle: monthSubtitle(water.month, isMtd: false),
                      color: const Color(0xff22d3ee),
                      icon: Icons.water_drop_rounded,
                    ),
                  ),
                if (water != null && air != null) const SizedBox(width: 6),

                if (air != null)
                  Expanded(
                    child: _UtilityMinMaxCard(
                      item: air,
                      title: 'AIR',
                      subtitle: monthSubtitle(air.month, isMtd: false),
                      color: const Color(0xffa855f7),
                      icon: Icons.air_rounded,
                    ),
                  ),
              ],
            ),
          ),

          // const SizedBox(height: 8),
          // const _Footer(),
        ],
      ),
    );
  }
}

final _numFmt = NumberFormat('#,##0');
final _moneyFmt = NumberFormat('#,##0');

String fmt(num? v) => v == null ? '--' : _numFmt.format(v);

String money(num? v) => v == null ? '--' : _moneyFmt.format(v);

String monthSubtitle(String month, {required bool isMtd}) {
  if (month.length != 6) return month;

  final year = month.substring(0, 4);
  final m = int.parse(month.substring(4, 6));

  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  return isMtd ? 'MTD ${months[m - 1]} $year' : 'AVG ${months[m - 1]} $year';
}

class _Header extends StatelessWidget {
  final String monthLabel;

  const _Header({required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          const Icon(
            Icons.bar_chart_rounded,
            color: Color(0xffa5b4fc),
            size: 17,
          ),
          const SizedBox(width: 5),
          const Text(
            'SUMMARY',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            '(MONTHLY)',
            style: TextStyle(
              color: Color(0xff22d3ee),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(.12)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white70,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  monthLabel,
                  style: const TextStyle(
                    color: Color(0xff22d3ee),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ElectricCard extends StatelessWidget {
  final EnergyMonthlySummary item;

  const _ElectricCard({required this.item});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xffffcc33);
    final unit = item.unit.isEmpty ? 'kWh' : item.unit;

    return _SummaryCard(
      color: color,
      icon: Icons.bolt_rounded,
      title: 'ELECTRICITY',
      subtitle: monthSubtitle(item.month, isMtd: true),
      child: Column(
        children: [
          _MainValue(value: fmt(item.value), unit: unit, color: color),
          const SizedBox(height: 6),

          _InfoLine(
            icon: Icons.history_rounded,
            label: 'Prev',
            value: '${fmt(item.prevValue)} $unit',
            color: Colors.white70,
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  icon: Icons.monetization_on_outlined,
                  label: 'Cost',
                  value: money(item.currentCost),
                  color: color,
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: _InfoTile(
                  icon: Icons.history_rounded,
                  label: 'Prev',
                  value: money(item.previousCost),
                  color: color,
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _DeltaPill(delta: item.deltaPercent),
            ),
          ),
        ],
      ),
    );
  }
}

class _UtilityMinMaxCard extends StatelessWidget {
  final EnergyMonthlySummary item;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _UtilityMinMaxCard({
    required this.item,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final unit = item.unit.isEmpty ? 'm³' : item.unit;
    return _SummaryCard(
      color: color,
      icon: icon,
      title: title,
      subtitle: subtitle,
      child: Column(
        children: [
          _MainValue(value: item.avgValue.toString(), unit: unit, color: color),

          const SizedBox(height: 6),

          _InfoLine(
            icon: Icons.history_rounded,
            label: 'Prev Avg',
            value: '${fmt(item.prevAvgValue)} $unit',
            color: Colors.white70,
          ),

          const SizedBox(height: 5),

          Row(
            children: [
              Expanded(
                child: _SmallMetric(
                  icon: Icons.arrow_downward_rounded,
                  label: 'MIN',
                  value: item.minValue?.toString() ?? '--',
                  unit: unit,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _SmallMetric(
                  icon: Icons.waves_rounded,
                  label: 'AVG',
                  value: item.avgValue?.toString() ?? '--',
                  unit: unit,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _SmallMetric(
                  icon: Icons.arrow_upward_rounded,
                  label: 'MAX',
                  value: item.maxValue?.toString() ?? '--',
                  unit: unit,
                  color: color,
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _DeltaPill(delta: item.deltaPercent),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SummaryCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.75), width: .9),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.16),
            blurRadius: 16,
            spreadRadius: -9,
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(.16),
                    border: Border.all(color: color.withOpacity(.8)),
                  ),
                  child: Icon(icon, color: Colors.white, size: 17),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.68),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _MainValue extends StatelessWidget {
  final String value;
  final String unit;
  final Color color;

  const _MainValue({
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color.withOpacity(.9),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.18),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          // const SizedBox(width: 3),
          // Text(
          //   label,
          //   style: TextStyle(
          //     color: Colors.white.withOpacity(.56),
          //     fontSize: 14,
          //     fontWeight: FontWeight.w800,
          //   ),
          // ),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(.58),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _SmallMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 14),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          // Text(
          //   unit,
          //   maxLines: 1,
          //   overflow: TextOverflow.ellipsis,
          //   style: TextStyle(
          //     color: color.withOpacity(.8),
          //     fontSize: 14,
          //     fontWeight: FontWeight.w700,
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  final double? delta;

  const _DeltaPill({required this.delta});

  @override
  Widget build(BuildContext context) {
    final d = delta ?? 0;
    final isUp = d > 0;
    final color = isUp ? Colors.redAccent : Colors.lightGreenAccent;

    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.28)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 3),
          Text(
            '${d.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            'vs prev',
            style: TextStyle(
              color: Colors.white.withOpacity(.6),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
