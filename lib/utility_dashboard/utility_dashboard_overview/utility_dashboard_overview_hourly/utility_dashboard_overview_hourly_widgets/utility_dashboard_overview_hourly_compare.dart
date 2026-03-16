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
  final int scaleHour;
  final double? today;
  final double? yesterday;

  const _HourlyCompareDto({
    required this.scaleHour,
    required this.today,
    required this.yesterday,
  });

  factory _HourlyCompareDto.fromJson(Map<String, dynamic> json) {
    double? toD(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final h = json['scaleHour'];
    return _HourlyCompareDto(
      scaleHour: (h is num) ? h.toInt() : int.tryParse(h.toString()) ?? 0,
      today: toD(json['today']),
      yesterday: toD(json['yesterday']),
    );
  }
}

class _LinePoint {
  final int hour;
  final double y;
  const _LinePoint(this.hour, this.y);
}

// ─────────────────────────────────────────────────────────────────────────────
// Immutable cache objects — tính một lần, dùng nhiều lần
// ─────────────────────────────────────────────────────────────────────────────

class _ChartData {
  final List<_LinePoint> todayPts;
  final List<_LinePoint> areaPts;
  final double safeMaxY;

  const _ChartData({
    required this.todayPts,
    required this.areaPts,
    required this.safeMaxY,
  });

  static _ChartData from(List<_HourlyCompareDto> list) {
    final todayPts = <_LinePoint>[];
    final areaPts = <_LinePoint>[];

    for (final r in list) {
      if (r.today != null) todayPts.add(_LinePoint(r.scaleHour, r.today!));
      if (r.yesterday != null) {
        areaPts.add(_LinePoint(r.scaleHour, r.yesterday!));
      } else if (r.today != null) {
        areaPts.add(_LinePoint(r.scaleHour, r.today!));
      }
    }

    final allY = [...todayPts.map((e) => e.y), ...areaPts.map((e) => e.y)];
    final maxY = allY.isEmpty ? 1.0 : allY.reduce((m, v) => v > m ? v : m);

    return _ChartData(
      todayPts: todayPts,
      areaPts: areaPts,
      safeMaxY: maxY <= 0 ? 1.0 : maxY * 1.2,
    );
  }
}

class _SummaryData {
  final double sumToday;
  final double sumYday;
  final double delta;
  final double? pct;
  final bool trendUp;

  const _SummaryData({
    required this.sumToday,
    required this.sumYday,
    required this.delta,
    required this.pct,
    required this.trendUp,
  });

  // Tính ngoài build(), snapshot tại thời điểm fetch xong
  static _SummaryData from(List<_HourlyCompareDto> rows) {
    final nowScaleHour = DateTime.now().hour + 1;
    double sumToday = 0, sumYday = 0;

    for (final r in rows) {
      if (r.scaleHour <= nowScaleHour) {
        sumToday += r.today ?? 0.0;
        sumYday += r.yesterday ?? 0.0;
      }
    }

    final delta = sumToday - sumYday;
    final pct = sumYday == 0 ? null : (delta / sumYday) * 100.0;

    return _SummaryData(
      sumToday: sumToday,
      sumYday: sumYday,
      delta: delta,
      pct: pct,
      trendUp: delta >= 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StatefulWidget
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

  // ── Toàn bộ derived state cache ở đây, KHÔNG tính trong build() ──────────
  DataHealthResult? _cachedHealth;
  _ChartData? _cachedChartData;
  _SummaryData? _cachedSummary;

  bool _loadingNow = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant UtilityDashboardOverviewHourlyCompare old) {
    super.didUpdateWidget(old);
    if (old.facId == widget.facId && old.hours == widget.hours) return;

    setState(() {
      loading = true;
      error = null;
      rows = [];
      _cachedHealth = null;
      _cachedChartData = null;
      _cachedSummary = null;
    });

    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _load() async {
    if (_loadingNow || _disposed) return;

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
              .where((e) => e.scaleHour >= 1 && e.scaleHour <= 24)
              .toList()
            ..sort((a, b) => a.scaleHour.compareTo(b.scaleHour));

      if (!mounted) return;

      if (_dataChanged(list)) {
        // Tính toàn bộ cache TRƯỚC setState — không block UI thread lâu
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
                ],
              )
              .toList(),
        );

        setState(() {
          rows = list;
          loading = false;
          error = null;
        });
      } else {
        if (loading) setState(() => loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e;
        loading = false;
      });
    } finally {
      _loadingNow = false;
    }

    if (!_disposed) {
      Future.delayed(const Duration(seconds: 30), _load);
    }
  }

  bool _dataChanged(List<_HourlyCompareDto> next) {
    if (next.length != rows.length) return true;
    for (var i = 0; i < next.length; i++) {
      if (next[i].scaleHour != rows[i].scaleHour ||
          next[i].today != rows[i].today ||
          next[i].yesterday != rows[i].yesterday)
        return true;
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build — chỉ đọc cache, không tính toán gì
  // ─────────────────────────────────────────────────────────────────────────

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
          // SummaryBar nhận data đã tính sẵn, KHÔNG tính trong build()
          _SummaryBar(
            loading: loading,
            error: error,
            hasRows: rows.isNotEmpty,
            summary: _cachedSummary,
            theme: widget.theme,
            health: healthResult,
          ),
          const SizedBox(height: 8),
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
      child: _HourlyChart(chartData: cd, theme: widget.theme),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SummaryBar — StatelessWidget thuần, nhận _SummaryData đã tính sẵn
// Không còn loop, không còn tính toán trong build()
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
    if (loading && !hasRows) return _wrap('Loading...');
    if (error != null && !hasRows) return _wrap('N/A');
    if (!hasRows || summary == null) return _wrap('No data');

    final s = summary!;
    final trendColor = s.trendUp ? const Color(0xFFFF6B6B) : theme.line;
    final trendIcon = s.trendUp ? Icons.arrow_upward : Icons.arrow_downward;

    final deltaStr = s.pct == null
        ? s.delta.toStringAsFixed(0)
        : '${s.delta >= 0 ? '+' : ''}${s.delta.toStringAsFixed(1)} '
              '(${s.pct!.toStringAsFixed(1)}%)';

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
            'T ${s.sumToday.toStringAsFixed(1)} ${theme.unit}',
            style: TextStyle(
              color: theme.line,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'P ${s.sumYday.toStringAsFixed(1)} ${theme.unit}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            deltaStr,
            style: TextStyle(
              color: trendColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 10),
          HealthIndicator(
            result: health,
            size: 10,
            showLabel: false,
            enableTooltip: true,
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
// _HourlyChart — StatelessWidget thuần, chỉ rebuild khi chartData/theme đổi
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
          color: theme.fillBottom.withOpacity(0.12),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(0.10)),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.55),
          fontSize: 13,
        ),
      ),
      primaryYAxis: NumericAxis(
        minimum: 0,
        maximum: chartData.safeMaxY,
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
        AreaSeries<_LinePoint, num>(
          name: 'Previous',
          dataSource: chartData.areaPts,
          xValueMapper: (p, _) => p.hour,
          yValueMapper: (p, _) => p.y,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.fillTop.withOpacity(0.45),
              theme.fillBottom.withOpacity(0.05),
            ],
          ),
          borderColor: Colors.transparent,
        ),
        LineSeries<_LinePoint, num>(
          name: 'Today',
          dataSource: chartData.todayPts,
          xValueMapper: (p, _) => p.hour,
          yValueMapper: (p, _) => p.y,
          width: 2.6,
          color: theme.line,
          markerSettings: MarkerSettings(
            isVisible: true,
            width: 6,
            height: 6,
            borderWidth: 1,
            borderColor: theme.line.withOpacity(0.9),
          ),
        ),
      ],
    );
  }
}
