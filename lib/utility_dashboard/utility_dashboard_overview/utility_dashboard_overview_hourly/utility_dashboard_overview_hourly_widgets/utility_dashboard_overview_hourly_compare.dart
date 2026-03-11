import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../chart_theme.dart';
import '../../utility_dashboard_api/utility_dashboard_overview_api.dart';

class _HourlyCompareDto {
  final int scaleHour; // 1..24
  final double? today;
  final double? yesterday;

  _HourlyCompareDto({
    required this.scaleHour,
    required this.today,
    required this.yesterday,
  });

  factory _HourlyCompareDto.fromJson(Map<String, dynamic> json) {
    final h = json['scaleHour'];
    final t = json['today'];
    final y = json['yesterday'];

    double? toD(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return _HourlyCompareDto(
      scaleHour: (h is num) ? h.toInt() : int.tryParse(h.toString()) ?? 0,
      today: toD(t),
      yesterday: toD(y),
    );
  }
}

class _LinePoint {
  final int hour; // 1..24
  final double y;

  _LinePoint(this.hour, this.y);
}

class UtilityDashboardOverviewHourlyCompare extends StatefulWidget {
  final String facId;
  final int hours;

  /// UI
  final String title;
  final ChartTheme theme; // ✅ NEW

  const UtilityDashboardOverviewHourlyCompare({
    super.key,
    required this.facId,
    required this.theme,
    this.hours = 48,
    this.title = 'Hourly Compare',
  });

  @override
  State<UtilityDashboardOverviewHourlyCompare> createState() =>
      _UtilityDashboardOverviewHourlyCompareState();
}

class _UtilityDashboardOverviewHourlyCompareState
    extends State<UtilityDashboardOverviewHourlyCompare> {
  List<_HourlyCompareDto> rows = [];
  bool loading = true;
  Object? error;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load(force: true);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void didUpdateWidget(
    covariant UtilityDashboardOverviewHourlyCompare oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.facId != widget.facId || oldWidget.hours != widget.hours;
    if (!changed) return;

    setState(() {
      loading = true;
      error = null;
      rows = [];
    });

    _load(force: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    if (widget.facId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Missing facId';
        rows = [];
      });
      return;
    }

    try {
      final api = context.read<UtilityDashboardOverviewApi>();

      final res = await api.getEnergyHourly(
        facId: widget.facId,
        hours: widget.hours,
      );

      final list =
          res
              .map((e) => _HourlyCompareDto.fromJson(e))
              .where((e) => e.scaleHour >= 1 && e.scaleHour <= 24)
              .toList()
            ..sort((a, b) => a.scaleHour.compareTo(b.scaleHour));

      if (!mounted) return;

      setState(() {
        rows = list;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nowStr = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final yStr = DateFormat(
      'dd/MM/yyyy',
    ).format(DateTime.now().subtract(const Duration(days: 1)));

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1324).withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryBar(
            loading: loading,
            error: error,
            rows: rows,
            theme: widget.theme, // ✅
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: _body(nowStr, yStr),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(String nowStr, String yStr) {
    if (loading && rows.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (error != null && rows.isEmpty) {
      return Center(
        child: Text(
          'API error:\n$error',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.85)),
        ),
      );
    }
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'No data',
          style: TextStyle(color: Colors.white.withOpacity(0.75)),
        ),
      );
    }

    final todayPts = <_LinePoint>[];
    final ydayPts = <_LinePoint>[];
    final areaPts = <_LinePoint>[]; // background grey (max of 2 lines)

    for (final r in rows) {
      if (r.today != null) todayPts.add(_LinePoint(r.scaleHour, r.today!));

      if (r.yesterday != null) {
        final p = _LinePoint(r.scaleHour, r.yesterday!);
        ydayPts.add(p);
        areaPts.add(p);
      } else if (r.today != null) {
        areaPts.add(_LinePoint(r.scaleHour, r.today!)); // fallback
      }
    }
    // y-axis safe
    final allY = <double>[
      ...todayPts.map((e) => e.y),
      ...ydayPts.map((e) => e.y),
    ];
    final maxY = allY.isEmpty ? 1.0 : allY.reduce((m, v) => v > m ? v : m);
    final safeMaxY = (maxY <= 0) ? 1.0 : maxY * 1.2;

    return SfCartesianChart(
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 1,
      plotAreaBorderColor: Colors.white.withOpacity(0.10),
      legend: Legend(
        isVisible: true,
        position: LegendPosition.top,
        overflowMode: LegendItemOverflowMode.wrap,
        textStyle: TextStyle(
          color: Colors.white.withOpacity(0.85),
          fontSize: 11,
        ),
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        header: '',
        canShowMarker: true,
        textStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      primaryXAxis: NumericAxis(
        minimum: 1,
        maximum: 24,
        interval: 1,
        majorGridLines: MajorGridLines(
          width: 1,
          color: widget.theme.fillBottom.withOpacity(0.12), // ✅ tone theo theme
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(0.10)),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.55),
          fontSize: 13,
        ),
      ),
      primaryYAxis: NumericAxis(
        minimum: 0,
        maximum: safeMaxY,
        majorGridLines: MajorGridLines(
          width: 1,
          color: widget.theme.fillBottom.withOpacity(0.12), // ✅
        ),
        title: AxisTitle(
          text: widget.theme.unit,
          alignment: ChartAlignment.center,
          textStyle: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(0.10)),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.55),
          fontSize: 13,
        ),
      ),

      series: <CartesianSeries<_LinePoint, num>>[
        // ✅ Yesterday = AREA
        AreaSeries<_LinePoint, num>(
          name: 'Previous',
          // ⭐ QUAN TRỌNG
          dataSource: areaPts,
          xValueMapper: (p, _) => p.hour,
          yValueMapper: (p, _) => p.y,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.theme.fillTop.withOpacity(0.45),
              widget.theme.fillBottom.withOpacity(0.05),
            ],
          ),
          borderColor: Colors.transparent,
        ),

        // ✅ Today = LINE
        LineSeries<_LinePoint, num>(
          name: 'Today',
          // ⭐ QUAN TRỌNG
          dataSource: todayPts,
          xValueMapper: (p, _) => p.hour,
          yValueMapper: (p, _) => p.y,
          width: 2.6,
          color: widget.theme.line,
          markerSettings: MarkerSettings(
            isVisible: true,
            width: 6,
            height: 6,
            borderWidth: 1,
            borderColor: widget.theme.line.withOpacity(0.9),
          ),
        ),
      ],
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final bool loading;
  final Object? error;
  final List<_HourlyCompareDto> rows;
  final ChartTheme theme;

  const _SummaryBar({
    required this.loading,
    required this.error,
    required this.rows,
    required this.theme,
  });

  @override
  @override
  Widget build(BuildContext context) {
    if (loading && rows.isEmpty) return _wrap('Loading...');
    if (error != null && rows.isEmpty) return _wrap('N/A');
    if (rows.isEmpty) return _wrap('No data');

    final nowScaleHour = DateTime.now().hour + 1;

    double sumToday = 0, sumYday = 0;

    for (final r in rows) {
      if (r.scaleHour <= nowScaleHour) {
        sumToday += r.today ?? 0.0;
        sumYday += r.yesterday ?? 0.0;
      }
    }

    final delta = sumToday - sumYday;
    final pct = (sumYday == 0) ? null : (delta / sumYday) * 100.0;

    final trendUp = delta >= 0;
    final trendColor = trendUp ? const Color(0xFFFF6B6B) : theme.line;

    final trendIcon = trendUp ? Icons.arrow_upward : Icons.arrow_downward;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(trendIcon, size: 14, color: trendColor),
          const SizedBox(width: 6),

          Text(
            'T ${sumToday.toStringAsFixed(1)} ${theme.unit}',
            style: TextStyle(
              color: theme.line,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),

          const SizedBox(width: 10),

          Text(
            'P ${sumYday.toStringAsFixed(1)} ${theme.unit}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),

          const Spacer(),

          Text(
            pct == null
                ? delta.toStringAsFixed(0)
                : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} '
                      '(${pct.toStringAsFixed(1)}%)',
            style: TextStyle(
              color: trendColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrap(String s) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.fillTop.withOpacity(0.25)), // ✅
      ),
      child: Text(
        s,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withOpacity(0.75),
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}
