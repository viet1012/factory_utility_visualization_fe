import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../chart_theme.dart';
import '../../data_health.dart';
import '../../utility_dashboard_api/utility_dashboard_overview_api.dart';
import '../../utility_dashboard_overview_widgets/health_indicator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DTOs
// ─────────────────────────────────────────────────────────────────────────────

class _HourlyCompareDto {
  final int scaleHour; // 0..23
  final double? today;
  final double? yesterday;
  final double? todayUsd;
  final double? yesterdayUsd;

  const _HourlyCompareDto({
    required this.scaleHour,
    required this.today,
    required this.yesterday,
    required this.todayUsd,
    required this.yesterdayUsd,
  });

  factory _HourlyCompareDto.fromJson(Map<String, dynamic> json) {
    double? toD(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    double? round2(dynamic v) {
      final val = toD(v);
      if (val == null) return null;
      return double.parse(val.toStringAsFixed(2));
    }

    double? sanitizeEnergy(double? v) {
      if (v == null || v.isNaN || v.isInfinite) return null;

      // Chặn outlier rõ ràng để chart không vỡ scale.
      // Có thể chỉnh lại theo domain thực tế.
      if (v < 0 || v > 5000) return null;
      return v;
    }

    double? sanitizeUsd(double? v) {
      if (v == null || v.isNaN || v.isInfinite) return null;

      // Chặn outlier USD quá lớn.
      if (v < 0 || v > 1000) return null;
      return v;
    }

    final h = json['scaleHour'];

    return _HourlyCompareDto(
      scaleHour: (h is num) ? h.toInt() : int.tryParse(h.toString()) ?? 0,
      today: sanitizeEnergy(toD(json['today'])),
      yesterday: sanitizeEnergy(toD(json['yesterday'])),
      todayUsd: sanitizeUsd(round2(json['todayUsd'])),
      yesterdayUsd: sanitizeUsd(round2(json['yesterdayUsd'])),
    );
  }
}

class _LinePoint {
  final int hour;
  final double? y;

  const _LinePoint(this.hour, this.y);
}

// ─────────────────────────────────────────────────────────────────────────────
// Cache objects
// ─────────────────────────────────────────────────────────────────────────────
class _ChartData {
  final List<_LinePoint> todayPts;
  final List<_LinePoint> yesterdayPts;
  final List<_LinePoint> todayUsdPts;
  final List<_LinePoint> yesterdayUsdPts;
  final double safeMaxYLeft;
  final double safeMaxYRight;

  const _ChartData({
    required this.todayPts,
    required this.yesterdayPts,
    required this.todayUsdPts,
    required this.yesterdayUsdPts,
    required this.safeMaxYLeft,
    required this.safeMaxYRight,
  });

  static _ChartData from(List<_HourlyCompareDto> list) {
    final byHour = <int, _HourlyCompareDto>{};
    for (final r in list) {
      byHour[r.scaleHour] = r;
    }

    final todayPts = <_LinePoint>[];
    final yesterdayPts = <_LinePoint>[];
    final todayUsdPts = <_LinePoint>[];
    final yesterdayUsdPts = <_LinePoint>[];

    final leftY = <double>[];
    final rightY = <double>[];

    for (int h = 0; h < 24; h++) {
      final r = byHour[h];

      todayPts.add(_LinePoint(h, r?.today));
      yesterdayPts.add(_LinePoint(h, r?.yesterday));
      todayUsdPts.add(_LinePoint(h, r?.todayUsd));
      yesterdayUsdPts.add(_LinePoint(h, r?.yesterdayUsd));

      if (r?.today != null) leftY.add(r!.today!);
      if (r?.yesterday != null) leftY.add(r!.yesterday!);
      if (r?.todayUsd != null) rightY.add(r!.todayUsd!);
      if (r?.yesterdayUsd != null) rightY.add(r!.yesterdayUsd!);
    }

    final maxLeft = leftY.isEmpty ? 1.0 : leftY.reduce((a, b) => a > b ? a : b);
    final maxRight = rightY.isEmpty
        ? 1.0
        : rightY.reduce((a, b) => a > b ? a : b);

    return _ChartData(
      todayPts: todayPts,
      yesterdayPts: yesterdayPts,
      todayUsdPts: todayUsdPts,
      yesterdayUsdPts: yesterdayUsdPts,
      safeMaxYLeft: maxLeft <= 0 ? 1.0 : maxLeft * 1.3,
      safeMaxYRight: maxRight <= 0 ? 1.0 : maxRight * 1.15,
    );
  }
}
// class _ChartData {
//   final List<_LinePoint> todayPts;
//   final List<_LinePoint> yesterdayPts;
//   final List<_LinePoint> todayUsdPts;
//   final List<_LinePoint> yesterdayUsdPts;
//   final double safeMaxYLeft;
//   final double safeMaxYRight;
//
//   const _ChartData({
//     required this.todayPts,
//     required this.yesterdayPts,
//     required this.todayUsdPts,
//     required this.yesterdayUsdPts,
//     required this.safeMaxYLeft,
//     required this.safeMaxYRight,
//   });
//
//   static _ChartData from(List<_HourlyCompareDto> list) {
//     final byHour = <int, _HourlyCompareDto>{};
//     for (final r in list) {
//       byHour[r.scaleHour] = r;
//     }
//
//     final todayPts = <_LinePoint>[];
//     final yesterdayPts = <_LinePoint>[];
//     final todayUsdPts = <_LinePoint>[];
//     final yesterdayUsdPts = <_LinePoint>[];
//
//     final leftY = <double>[];
//     final rightY = <double>[];
//
//     for (int h = 0; h < 24; h++) {
//       final r = byHour[h];
//
//       todayPts.add(_LinePoint(h, r?.today));
//       yesterdayPts.add(_LinePoint(h, r?.yesterday));
//       todayUsdPts.add(_LinePoint(h, r?.todayUsd));
//       yesterdayUsdPts.add(_LinePoint(h, r?.yesterdayUsd));
//
//       if (r?.today != null) leftY.add(r!.today!);
//       if (r?.yesterday != null) leftY.add(r!.yesterday!);
//       if (r?.todayUsd != null) rightY.add(r!.todayUsd!);
//       if (r?.yesterdayUsd != null) rightY.add(r!.yesterdayUsd!);
//     }
//
//     final maxLeft = leftY.isEmpty ? 1.0 : leftY.reduce((a, b) => a > b ? a : b);
//     final maxRight = rightY.isEmpty
//         ? 1.0
//         : rightY.reduce((a, b) => a > b ? a : b);
//
//     return _ChartData(
//       todayPts: todayPts,
//       yesterdayPts: yesterdayPts,
//       todayUsdPts: todayUsdPts,
//       yesterdayUsdPts: yesterdayUsdPts,
//       safeMaxYLeft: maxLeft <= 0 ? 1.0 : maxLeft * 1.15,
//       safeMaxYRight: maxRight <= 0 ? 1.0 : maxRight * 1.15,
//     );
//   }
// }

class _SummaryData {
  final double sumToday;
  final double sumYday;
  final double delta;
  final double? pct;
  final bool trendUp;

  final double sumTodayUsd;
  final double sumYdayUsd;
  final double deltaUsd;
  final double? pctUsd;
  final bool trendUpUsd;

  const _SummaryData({
    required this.sumToday,
    required this.sumYday,
    required this.delta,
    required this.pct,
    required this.trendUp,
    required this.sumTodayUsd,
    required this.sumYdayUsd,
    required this.deltaUsd,
    required this.pctUsd,
    required this.trendUpUsd,
  });

  static _SummaryData from(List<_HourlyCompareDto> rows) {
    double sumToday = 0;
    double sumYday = 0;
    double sumTodayUsd = 0;
    double sumYdayUsd = 0;

    for (final r in rows) {
      sumToday += r.today ?? 0.0;
      sumYday += r.yesterday ?? 0.0;
      sumTodayUsd += r.todayUsd ?? 0.0;
      sumYdayUsd += r.yesterdayUsd ?? 0.0;
    }

    final delta = sumToday - sumYday;
    final pct = sumYday == 0 ? null : (delta / sumYday) * 100.0;

    final deltaUsd = sumTodayUsd - sumYdayUsd;
    final pctUsd = sumYdayUsd == 0 ? null : (deltaUsd / sumYdayUsd) * 100.0;

    return _SummaryData(
      sumToday: sumToday,
      sumYday: sumYday,
      delta: delta,
      pct: pct,
      trendUp: delta >= 0,
      sumTodayUsd: sumTodayUsd,
      sumYdayUsd: sumYdayUsd,
      deltaUsd: deltaUsd,
      pctUsd: pctUsd,
      trendUpUsd: deltaUsd >= 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main widget
// ─────────────────────────────────────────────────────────────────────────────

class UtilityDashboardOverviewHourlyCompare extends StatefulWidget {
  final String facId;
  final int hours;
  final String? nameEng;
  final String title;
  final ChartTheme theme;

  const UtilityDashboardOverviewHourlyCompare({
    super.key,
    required this.facId,
    required this.theme,
    this.hours = 48,
    this.title = 'Hourly Compare',
    this.nameEng,
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

  _ChartData? _cachedChartData;
  _SummaryData? _cachedSummary;
  DataHealthResult? _cachedHealth;

  bool _loadingNow = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _load();
    });
  }

  @override
  void didUpdateWidget(
    covariant UtilityDashboardOverviewHourlyCompare oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    final changed =
        oldWidget.facId != widget.facId ||
        oldWidget.hours != widget.hours ||
        oldWidget.nameEng != widget.nameEng ||
        oldWidget.theme.title != widget.theme.title;

    if (!changed) return;

    setState(() {
      rows = [];
      loading = true;
      error = null;
      _cachedChartData = null;
      _cachedSummary = null;
      _cachedHealth = null;
    });

    _load();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loadingNow) return;

    if (widget.facId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Missing facId';
        rows = [];
      });
      return;
    }

    _loadingNow = true;

    try {
      final api = context.read<UtilityDashboardOverviewApi>();
      final res = await api.getEnergyHourly(
        facId: widget.facId,
        hours: widget.hours,
        nameEn: widget.nameEng,
      );

      final list =
          res
              .map((e) => _HourlyCompareDto.fromJson(e))
              .where((e) => e.scaleHour >= 0 && e.scaleHour <= 23)
              .toList()
            ..sort((a, b) => a.scaleHour.compareTo(b.scaleHour));

      if (!mounted) return;

      _cachedChartData = _ChartData.from(list);
      _cachedSummary = _SummaryData.from(list);
      _cachedHealth = DataHealthAnalyzer.analyze(
        key: 'Hourly_${widget.facId}_${widget.theme.title}',
        loading: false,
        error: null,
        values: list
            .expand(
              (e) => [
                if (e.today != null) e.today!,
                if (e.yesterday != null) e.yesterday!,
                if (e.todayUsd != null) e.todayUsd!,
                if (e.yesterdayUsd != null) e.yesterdayUsd!,
              ],
            )
            .toList(),
      );

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
    } finally {
      _loadingNow = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final healthResult =
        _cachedHealth ??
        DataHealthAnalyzer.analyze(
          key: 'Hourly_${widget.facId}_${widget.theme.title}',
          loading: loading,
          error: error,
          values: const [],
        );

    return Container(
      height: 340,
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
            hasRows: rows.isNotEmpty,
            summary: _cachedSummary,
            theme: widget.theme,
            health: healthResult,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: _body(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
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

    final cd = _cachedChartData ?? _ChartData.from(rows);

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight <= 0 || constraints.maxWidth <= 0) {
            return const SizedBox.shrink();
          }

          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: _HourlyChart(chartData: cd, theme: widget.theme),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary bar
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final bool loading;
  final Object? error;
  final bool hasRows;
  final _SummaryData? summary;
  final ChartTheme theme;
  final DataHealthResult health;

  const _SummaryBar({
    required this.loading,
    required this.error,
    required this.hasRows,
    required this.summary,
    required this.theme,
    required this.health,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && !hasRows) return _wrapState('Loading...');
    if (error != null && !hasRows) return _wrapState('N/A');
    if (!hasRows || summary == null) return _wrapState('No data');

    final s = summary!;

    final energyColor = s.trendUp
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF22C55E);

    final usdColor = s.trendUpUsd ? const Color(0xFFFF6B6B) : theme.usdLine;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          // ? kWh
          Expanded(
            child: Text(
              'T ${s.sumToday.toStringAsFixed(0)} / '
              'P ${s.sumYday.toStringAsFixed(0)} ${theme.unit}  ',
              // '(${s.delta >= 0 ? '+' : ''}${s.delta.toStringAsFixed(0)})',
              style: TextStyle(
                color: energyColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 8),

          // ?? USD
          Expanded(
            child: Text(
              '\$${s.sumTodayUsd.toStringAsFixed(2)} / '
              '\$${s.sumYdayUsd.toStringAsFixed(2)}  ',
              // '(${s.deltaUsd >= 0 ? '+' : ''}${s.deltaUsd.toStringAsFixed(2)})',
              style: TextStyle(
                color: usdColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 6),

          // health nh? g?n
          HealthIndicator(
            result: health,
            size: 8,
            showLabel: false,
            enableTooltip: true,
          ),
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String delta,
    required Color deltaColor,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            '$title:',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            delta,
            style: TextStyle(
              color: deltaColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrapState(String s) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.fillTop.withOpacity(0.25)),
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
// ─────────────────────────────────────────────────────────────────────────────
// Chart
// ─────────────────────────────────────────────────────────────────────────────

class _HourlyChart extends StatelessWidget {
  final _ChartData chartData;
  final ChartTheme theme;

  const _HourlyChart({required this.chartData, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SfCartesianChart(
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 1,
      plotAreaBorderColor: Colors.white.withOpacity(0.10),

      // Dùng built-in legend để click ẩn/hiện series
      legend: Legend(
        isVisible: true,
        position: LegendPosition.top,
        toggleSeriesVisibility: true,
        overflowMode: LegendItemOverflowMode.scroll,
        textStyle: TextStyle(
          color: Colors.white.withOpacity(0.85),
          fontSize: 11,
        ),
      ),

      tooltipBehavior: TooltipBehavior(
        enable: true,
        header: '',
        canShowMarker: true,
        format: 'point.x : point.y',
        textStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),

      primaryXAxis: NumericAxis(
        minimum: 0,
        maximum: 23,
        interval: 2,
        decimalPlaces: 0,
        axisLabelFormatter: (AxisLabelRenderDetails args) {
          final h = args.value.toInt();

          return ChartAxisLabel(
            h.toString(), // 👈 chỉ 0,1,2...23
            TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          );
        },
        majorGridLines: MajorGridLines(
          width: 1,
          color: theme.fillBottom.withOpacity(0.12),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(0.10)),
      ),

      primaryYAxis: NumericAxis(
        name: 'leftAxis',
        minimum: 0,
        maximum: chartData.safeMaxYLeft,
        interval: chartData.safeMaxYLeft / 5,
        axisLabelFormatter: (args) {
          return ChartAxisLabel(
            args.value.toStringAsFixed(0),
            TextStyle(color: Colors.white54, fontSize: 11),
          );
        },
        majorGridLines: MajorGridLines(
          width: 1,
          color: theme.fillBottom.withOpacity(0.12),
        ),
        title: AxisTitle(
          text: theme.unit,
          alignment: ChartAlignment.center,
          textStyle: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(0.10)),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.55),
          fontSize: 11,
        ),
      ),
      axes: <ChartAxis>[
        NumericAxis(
          name: 'rightAxis',
          opposedPosition: true,
          minimum: 0,
          maximum: chartData.safeMaxYRight,
          interval: chartData.safeMaxYRight / 5,
          axisLabelFormatter: (args) {
            return ChartAxisLabel(
              args.value.toStringAsFixed(0),
              TextStyle(color: theme.usdLine.withOpacity(0.9), fontSize: 11),
            );
          },
          majorGridLines: const MajorGridLines(width: 0),
          title: AxisTitle(
            text: 'USD',
            alignment: ChartAlignment.center,
            textStyle: TextStyle(
              color: theme.usdLine.withOpacity(0.95),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          axisLine: AxisLine(color: theme.usdLine.withOpacity(0.35)),
        ),
      ],

      series: <CartesianSeries<_LinePoint, num>>[
        AreaSeries<_LinePoint, num>(
          name: 'Previous',
          dataSource: chartData.yesterdayPts,
          xValueMapper: (p, _) => p.hour,
          yValueMapper: (p, _) => p.y,
          yAxisName: 'leftAxis',
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.fillTop.withOpacity(0.45),
              theme.fillBottom.withOpacity(0.05),
            ],
          ),
          dashArray: const <double>[6, 3],
          emptyPointSettings: const EmptyPointSettings(
            mode: EmptyPointMode.gap,
          ),
          markerSettings: const MarkerSettings(isVisible: false),
        ),
        LineSeries<_LinePoint, num>(
          name: 'Today',
          dataSource: chartData.todayPts,
          xValueMapper: (p, _) => p.hour,
          yValueMapper: (p, _) => p.y,
          yAxisName: 'leftAxis',
          width: 2.8,
          color: theme.line,
          emptyPointSettings: const EmptyPointSettings(
            mode: EmptyPointMode.gap,
          ),
          markerSettings: MarkerSettings(
            isVisible: true,
            width: 5,
            height: 5,
            borderWidth: 1,
            borderColor: theme.line.withOpacity(0.9),
          ),
        ),
        AreaSeries<_LinePoint, num>(
          name: 'Previous USD',
          dataSource: chartData.yesterdayUsdPts,
          xValueMapper: (p, _) => p.hour,
          yValueMapper: (p, _) => p.y,
          yAxisName: 'rightAxis',
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.usdFillBottom.withOpacity(0.45),
              theme.usdFillBottom.withOpacity(0.05),
            ],
          ),
          dashArray: const <double>[6, 3],
          emptyPointSettings: const EmptyPointSettings(
            mode: EmptyPointMode.gap,
          ),
          markerSettings: const MarkerSettings(isVisible: false),
        ),
        LineSeries<_LinePoint, num>(
          name: 'Today USD',
          dataSource: chartData.todayUsdPts,
          xValueMapper: (p, _) => p.hour,
          yValueMapper: (p, _) => p.y,
          yAxisName: 'rightAxis',
          width: 2.4,
          color: theme.usdLine,
          emptyPointSettings: const EmptyPointSettings(
            mode: EmptyPointMode.gap,
          ),
          markerSettings: MarkerSettings(
            isVisible: true,
            width: 4,
            height: 4,
            borderWidth: 1,
            borderColor: theme.usdLine.withOpacity(0.9),
          ),
        ),
      ],
    );
  }
}
