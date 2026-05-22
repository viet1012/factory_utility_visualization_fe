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
  final String cate;

  const MonthlyUtilityUsagePanel({
    super.key,
    required this.fac,
    this.title = 'Monthly Usage',
    this.nameEn = 'Total Energy Consumption',
    this.cate = 'Electricity',
  });

  ChartTheme get theme => ChartThemes.getThemeByCate(cate);

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
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220).withOpacity(0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: t.line.withOpacity(0.10),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.34),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            _MonthlyUsageHeader(
              subtitle: '${_monthName(now.month)} ${now.year}',
              theme: t,
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
      ),
    );
  }
}

class _MonthlyUsageHeader extends StatelessWidget {
  final String subtitle;
  final ChartTheme theme;

  const _MonthlyUsageHeader({required this.subtitle, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.line.withOpacity(0.10),
            Colors.white.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: theme.line.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: theme.line.withOpacity(0.28)),
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              size: 15,
              color: theme.line,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.48),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
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
  static const Duration _requestTimeout = Duration(seconds: 15);

  List<MonthlyUtilityUsage> _items = const [];
  bool _loading = true;
  bool _loadingNow = false;
  Object? _error;
  Timer? _timer;

  double get _maxValue {
    if (_items.isEmpty) return 0;
    return _items.map((e) => e.usedValue).reduce((a, b) => a > b ? a : b);
  }

  String get _unit {
    for (final item in _items) {
      final u = item.unit.trim();
      if (u.isNotEmpty) return u;
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _load();

    // Monthly data không cần refresh quá dày.
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted && !_loadingNow) {
        _load(silent: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant MonthlyUtilityUsageList oldWidget) {
    super.didUpdateWidget(oldWidget);

    final changed =
        oldWidget.fac != widget.fac ||
        oldWidget.year != widget.year ||
        oldWidget.month != widget.month ||
        oldWidget.nameEn != widget.nameEn;

    if (!changed) return;

    setState(() {
      _items = const [];
      _loading = true;
      _error = null;
    });

    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_loadingNow || !mounted) return;

    _loadingNow = true;

    if (!silent && _items.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await widget.api
          .getMonthlyUtilityUsage(
            facId: widget.fac,
            year: widget.year,
            month: widget.month,
            nameEn: widget.nameEn,
          )
          .timeout(_requestTimeout);

      final sorted = [...data]
        ..sort((a, b) => b.usedValue.compareTo(a.usedValue));

      if (!mounted) return;

      if (!_dataChanged(sorted) && _error == null && !_loading) return;

      setState(() {
        _items = sorted;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e;
        _loading = false;

        // Giữ data cũ để panel không bị trắng khi API lỗi.
      });
    } finally {
      _loadingNow = false;
    }
  }

  bool _dataChanged(List<MonthlyUtilityUsage> next) {
    if (next.length != _items.length) return true;

    for (var i = 0; i < next.length; i++) {
      final a = _items[i];
      final b = next[i];

      if (a.boxId != b.boxId ||
          a.boxDeviceId != b.boxDeviceId ||
          a.unit != b.unit ||
          a.usedValue != b.usedValue) {
        return true;
      }
    }

    return false;
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

    return Column(
      children: [
        _UsageMetaRow(count: _items.length, unit: _unit, theme: widget.theme),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            physics: const BouncingScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = _items[index];

              return _UsageRow(
                rank: index + 1,
                item: item,
                maxValue: _maxValue,
                color: widget.theme.line,
                accent: widget.theme.accent,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UsageMetaRow extends StatelessWidget {
  final int count;
  final String unit;
  final ChartTheme theme;

  const _UsageMetaRow({
    required this.count,
    required this.unit,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Text(
            '$count meters',
            style: TextStyle(
              color: Colors.white.withOpacity(0.44),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          if (unit.isNotEmpty)
            Text(
              unit,
              style: TextStyle(
                color: theme.line.withOpacity(0.90),
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
        ],
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  final int rank;
  final MonthlyUtilityUsage item;
  final double maxValue;
  final Color color;
  final Color accent;

  const _UsageRow({
    required this.rank,
    required this.item,
    required this.maxValue,
    required this.color,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final percent = maxValue <= 0 ? 0.0 : item.usedValue / maxValue;
    final unit = item.unit.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Column(
        children: [
          ////////////////////////////////////////////////////////////
          /// TOP ROW
          ////////////////////////////////////////////////////////////
          Row(
            children: [
              _RankBadge(rank: rank, color: color),

              const SizedBox(width: 8),

              ////////////////////////////////////////////////////////////
              /// LABEL
              ////////////////////////////////////////////////////////////
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w900),
                ),
              ),

              const SizedBox(width: 8),

              ////////////////////////////////////////////////////////////
              /// VALUE
              ////////////////////////////////////////////////////////////
              Text(
                _formatUsage(item.usedValue),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          ////////////////////////////////////////////////////////////
          /// BAR
          ////////////////////////////////////////////////////////////
          _UsageBar(percent: percent, color: color),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  final Color color;

  const _RankBadge({required this.rank, required this.color});

  @override
  Widget build(BuildContext context) {
    final highlight = rank <= 3;

    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlight
            ? color.withOpacity(0.14)
            : Colors.white.withOpacity(0.05),

        borderRadius: BorderRadius.circular(6),

        border: Border.all(
          color: highlight
              ? color.withOpacity(0.35)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          color: highlight ? color : Colors.white.withOpacity(0.45),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  final double percent;
  final Color color;

  const _UsageBar({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    final value = percent.clamp(0.015, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          Container(
            height: 7,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.075)),
          ),
          FractionallySizedBox(
            widthFactor: value,
            child: Container(
              height: 7,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.95), color.withOpacity(0.65)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatUsage(double value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }

  if (value >= 1000) {
    return value.toStringAsFixed(0);
  }

  if (value >= 10) {
    return value.toStringAsFixed(1);
  }

  return value.toStringAsFixed(2);
}
