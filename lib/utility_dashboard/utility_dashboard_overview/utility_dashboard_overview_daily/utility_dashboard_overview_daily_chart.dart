import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../../utility_dashboard_common/utility_fac_style.dart';
import '../chart_theme.dart';
import '../data_health.dart';
import '../utility_dashboard_overview_widgets/health_indicator.dart';

class _DailyDto {
  final DateTime date;
  final double value;

  _DailyDto(this.date, this.value);

  factory _DailyDto.fromJson(Map<String, dynamic> json) {
    final d = (json['date'] ?? '').toString(); // "2026-03-01"
    final v = json['value'];

    return _DailyDto(
      DateTime.parse(d),
      (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0,
    );
  }
}

class _BarPoint {
  final DateTime ts;
  final double y;

  _BarPoint(this.ts, this.y);
}

class UtilityDashboardOverviewDailyChart extends StatefulWidget {
  final double width;
  final double? height;

  /// API
  final String facId;
  final String month; // yyyyMM (vd: 202603)

  /// optional UI
  final String title; // header title
  final ChartTheme theme;

  const UtilityDashboardOverviewDailyChart({
    super.key,
    required this.facId,
    required this.month,
    required this.theme,
    this.title = 'Total Energy Consumption',
    this.width = 520,
    this.height,
  });

  @override
  State<UtilityDashboardOverviewDailyChart> createState() =>
      _UtilityDashboardOverviewDailyChartState();
}

class _UtilityDashboardOverviewDailyChartState
    extends State<UtilityDashboardOverviewDailyChart>
    with TickerProviderStateMixin {
  late final UtilityInfoBoxFx fx;

  List<_DailyDto> rows = [];
  bool loading = true;
  Object? error;

  Timer? _timer;

  bool get _hasRequired =>
      widget.facId.trim().isNotEmpty &&
      widget.month.trim().isNotEmpty &&
      RegExp(r'^\d{6}$').hasMatch(widget.month.trim());

  @override
  void initState() {
    super.initState();
    fx = UtilityInfoBoxFx(this)..init();
    _load(force: true);
    // optional auto refresh
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _load());
  }

  @override
  void didUpdateWidget(covariant UtilityDashboardOverviewDailyChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    final changed =
        oldWidget.facId != widget.facId || oldWidget.month != widget.month;

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
    fx.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    if (!_hasRequired) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Missing/invalid facId or month(yyyyMM)';
        rows = [];
      });
      return;
    }

    try {
      final dio = context.read<Dio>();

      final res = await dio.get(
        '/api/utility/energy-daily',
        queryParameters: {'facId': widget.facId, 'month': widget.month},
        options: force ? Options(headers: {'Cache-Control': 'no-cache'}) : null,
      );

      final list =
          (res.data as List)
              .map((e) => _DailyDto.fromJson(Map<String, dynamic>.from(e)))
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));

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
    final facilityColor = UtilityFacStyle.colorFromFac(widget.facId);
    final t = widget.theme;
    final valid = rows.where((e) => e.value != null).toList();

    final healthResult = DataHealthAnalyzer.analyze(
      loading: loading,
      error: error,
      timestamps: valid.map((e) => e.date.toLocal()).toList(),
      values: valid.map((e) => e.value!).toList(),
    );
    return SlideTransition(
      position: fx.slide,
      child: MouseRegion(
        onEnter: (_) => fx.onHover(true),
        onExit: (_) => fx.onHover(false),
        child: AnimatedBuilder(
          animation: fx.listenable,
          builder: (context, child) {
            return Transform.scale(
              scale: fx.scale.value,
              child: Container(
                width: widget.width,
                height: widget.height ?? 320,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2E1A47).withOpacity(0.25),
                      const Color(0xFF1A2A6C).withOpacity(0.18),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: facilityColor.withOpacity(0.22),
                      blurRadius: 18,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: _body(t, healthResult),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _body(ChartTheme t, DataHealthResult health) {
    if (!_hasRequired) {
      return Center(
        child: Text(
          'Missing facId or month(yyyyMM)',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
      );
    }

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && rows.isEmpty) {
      return Center(
        child: Text(
          'API error:\n$error',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
      );
    }

    if (rows.isEmpty) {
      return Center(
        child: Text(
          'No data',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
      );
    }

    final now = DateTime.now();
    final currentMonth = DateFormat('yyyyMM').format(now);

    // mặc định lấy ngày cuối data
    _DailyDto lastDto = rows.last;

    // nếu đang xem tháng hiện tại → lấy hôm nay
    if (widget.month == currentMonth) {
      final today = DateTime(now.year, now.month, now.day);

      final todayRow = rows.firstWhere(
        (e) =>
            e.date.year == today.year &&
            e.date.month == today.month &&
            e.date.day == today.day,
        orElse: () => rows.last,
      );

      lastDto = todayRow;
    }

    final lastVal = '${lastDto.value.toStringAsFixed(1)} ${t.unit}';
    final lastTs = DateFormat('yyyy-MM-dd').format(lastDto.date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.fillTop.withOpacity(0.35)), // ✅
          ),
          child: Row(
            children: [
              // const Icon(Icons.bar_chart, size: 16, color: Colors.white),
              // const SizedBox(width: 8),
              Text(
                t.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: HealthIndicator(
                  result: health,
                  size: 10,
                  showLabel: false, // muốn hiện chữ thì true
                  enableTooltip: true,
                ),
              ),
              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  'Last: $lastVal  • $lastTs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => _load(force: true),
                icon: Icon(
                  Icons.refresh_rounded,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(child: _chart(t)),
      ],
    );
  }

  Widget _chart(ChartTheme t) {
    final data = rows.map((e) => _BarPoint(e.date.toLocal(), e.value)).toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));

    final minX = data.first.ts;
    final maxX = data.last.ts;

    final ys = data.map((e) => e.y).toList()..sort();
    final maxY = ys.isEmpty ? 1.0 : ys.last;
    final safeMaxY = (maxY <= 0) ? 1.0 : (maxY * 1.15);

    return SfCartesianChart(
      plotAreaBorderWidth: 1,
      plotAreaBorderColor: Colors.white.withOpacity(0.12),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        canShowMarker: true,
        header: '',
        textStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      primaryXAxis: DateTimeAxis(
        minimum: minX,
        maximum: maxX,
        intervalType: DateTimeIntervalType.days,
        interval: 1,
        labelRotation: 45,
        dateFormat: DateFormat('dd-MM'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(0.08),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(0.15), width: 1),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.75),
          fontSize: 13,
        ),
      ),
      primaryYAxis: NumericAxis(
        minimum: 0,
        maximum: safeMaxY,
        numberFormat: NumberFormat('0.##'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(0.08),
        ),
        title: AxisTitle(
          text: t.unit,
          alignment: ChartAlignment.center,
          textStyle: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(0.15), width: 1),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.75),
          fontSize: 13,
        ),
      ),
      series: <CartesianSeries<_BarPoint, DateTime>>[
        ColumnSeries<_BarPoint, DateTime>(
          animationDuration: 1000,
          dataSource: data,
          xValueMapper: (p, _) => p.ts,
          yValueMapper: (p, _) => p.y,
          width: 0.75,
          spacing: 0.2,
          borderRadius: const BorderRadius.all(Radius.circular(6)),

          // ✅ màu theo theme
          color: t.line,
          // fallback nếu gradient không ăn

          // ✅ gradient theo theme (pro)
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.fillTop, t.fillBottom],
          ),

          // ✅ viền nhẹ
          borderColor: t.line.withOpacity(0.95),
          borderWidth: 0.8,
        ),
      ],
    );
  }
}
