import 'dart:async';

import 'package:flutter/material.dart';

import '../../../utility_api/dio_client.dart';
import '../../utility_dashboard_common/chart_theme.dart';
import '../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';
import '../utility_dashboard_overview_widgets/chart_state_widgets.dart';

class MonthlyUtilityUsage {
  final String boxId;
  final String boxDeviceId;
  final String unit;
  final double usedValue;

  const MonthlyUtilityUsage({
    required this.boxId,
    required this.boxDeviceId,
    required this.unit,
    required this.usedValue,
  });

  factory MonthlyUtilityUsage.fromJson(Map<String, dynamic> json) {
    return MonthlyUtilityUsage(
      boxId: (json['boxId'] ?? '').toString(),
      boxDeviceId: (json['boxDeviceId'] ?? '').toString(),
      unit: (json['unit'] ?? '').toString(),
      usedValue: (json['usedValue'] as num?)?.toDouble() ?? 0,
    );
  }

  String get label => boxId.trim().isNotEmpty ? boxId.trim() : boxDeviceId;
}

class MonthlyUtilityUsagePanel extends StatelessWidget {
  final String fac;
  final String title;
  final String nameEn;

  const MonthlyUtilityUsagePanel({
    super.key,
    required this.fac,
    this.title = 'Utility Usage',
    this.nameEn = 'Total Energy Consumption',
  });

  ChartTheme get theme {
    final v = nameEn.toLowerCase();

    if (v.contains('water')) return ChartThemes.water;
    if (v.contains('air')) return ChartThemes.air;
    if (v.contains('gas')) return ChartThemes.gas;
    if (v.contains('steam')) return ChartThemes.steam;

    return ChartThemes.power;
  }

  String _monthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final t = theme;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.26),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 14,
                  color: t.line.withOpacity(0.72),
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: Text(
                    '${_monthName(now.month)} ${now.year} • Monthly Usage',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: MonthlyUtilityUsageList(
              fac: fac,
              year: now.year,
              month: now.month,
              nameEn: nameEn,
              theme: t,
              api: UtilityDashboardOverviewApi(DioClient.dio),
            ),
          ),
        ],
      ),
    );
  }
}

class MonthlyUtilityUsageList extends StatefulWidget {
  final String fac;
  final int year;
  final int month;
  final String nameEn;
  final ChartTheme theme;
  final UtilityDashboardOverviewApi api;

  const MonthlyUtilityUsageList({
    super.key,
    required this.fac,
    required this.year,
    required this.month,
    required this.nameEn,
    required this.theme,
    required this.api,
  });

  @override
  State<MonthlyUtilityUsageList> createState() =>
      _MonthlyUtilityUsageListState();
}

class _MonthlyUtilityUsageListState extends State<MonthlyUtilityUsageList> {
  List<MonthlyUtilityUsage> _items = const [];
  bool _loading = true;
  Object? _error;
  Timer? _timer;

  double get _maxValue {
    if (_items.isEmpty) return 0;
    return _items.map((e) => e.usedValue).reduce((a, b) => a > b ? a : b);
  }

  @override
  void initState() {
    super.initState();
    _load();

    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _load(silent: true),
    );
  }

  @override
  void didUpdateWidget(covariant MonthlyUtilityUsageList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.fac != widget.fac ||
        oldWidget.year != widget.year ||
        oldWidget.month != widget.month ||
        oldWidget.nameEn != widget.nameEn) {
      _load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await widget.api.getMonthlyUtilityUsage(
        facId: widget.fac,
        year: widget.year,
        month: widget.month,
        nameEn: widget.nameEn,
      );

      final sorted = [...data]
        ..sort((a, b) => b.usedValue.compareTo(a.usedValue));

      if (!mounted) return;

      setState(() {
        _items = sorted;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: widget.theme.line,
          strokeWidth: 2.4,
        ),
      );
    }

    if (_error != null && _items.isEmpty) {
      return ChartApiErrorState(color: widget.theme.line, onRetry: _load);
    }

    if (_items.isEmpty) {
      return const EmptyChartState(
        title: 'No Monthly Data',
        message: 'No utility consumption data found for this month.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
      physics: const BouncingScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final item = _items[index];

        return _UsageRow(
          item: item,
          maxValue: _maxValue,
          color: widget.theme.line,
          accent: widget.theme.accent,
        );
      },
    );
  }
}

class _UsageRow extends StatelessWidget {
  final MonthlyUtilityUsage item;
  final double maxValue;
  final Color color;
  final Color accent;

  const _UsageRow({
    required this.item,
    required this.maxValue,
    required this.color,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final percent = maxValue <= 0 ? 0.0 : item.usedValue / maxValue;
    final unit = item.unit.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: accent,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _UsageBar(percent: percent, color: color),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 96,
              child: Text(
                '${_formatUsage(item.usedValue)}${unit.isEmpty ? '' : ' $unit'}',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _UsageBar extends StatelessWidget {
  final double percent;
  final Color color;

  const _UsageBar({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          Container(height: 10, color: Colors.white.withOpacity(0.07)),
          FractionallySizedBox(
            widthFactor: percent.clamp(0.015, 1.0),
            child: Container(height: 10, color: color),
          ),
        ],
      ),
    );
  }
}

String _formatUsage(double value) {
  if (value >= 1000) {
    return value.toStringAsFixed(0);
  }

  if (value >= 10) {
    return value.toStringAsFixed(1);
  }

  return value.toStringAsFixed(2);
}
