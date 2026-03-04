import 'dart:async';

import 'package:dio/dio.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/chart_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../utility_models/response/minute_point.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../data_health.dart';
import '../utility_dashboard_overview_widgets/health_indicator.dart';

class UtilityDashboardOverviewMinutesChart extends StatefulWidget {
  final String facId;
  final int minutes;

  final double width;
  final double? height;
  final String? nameEng;

  /// UI
  final ChartTheme theme;

  const UtilityDashboardOverviewMinutesChart({
    super.key,
    required this.facId,
    required this.theme,
    this.minutes = 60,
    this.width = 520,
    this.height,
    this.nameEng,
  });

  @override
  State<UtilityDashboardOverviewMinutesChart> createState() =>
      _UtilityDashboardOverviewMinutesChartState();
}

class _UtilityDashboardOverviewMinutesChartState
    extends State<UtilityDashboardOverviewMinutesChart>
    with TickerProviderStateMixin {
  late final UtilityInfoBoxFx fx;

  List<MinutePointDto> rows = [];
  Object? error;
  bool loading = true;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fx = UtilityInfoBoxFx(this)..init();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final dio = context.read<Dio>();

      final res = await dio.get(
        '/api/utility/energy-minute',
        queryParameters: {
          'facId': widget.facId,
          'minutes': widget.minutes,
          'nameEn': widget.nameEng,
        },
      );

      final data = (res.data as List)
          .map((e) => MinutePointDto.fromJson(e))
          .toList();

      if (!mounted) return;

      setState(() {
        rows = data;
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
  void didUpdateWidget(
    covariant UtilityDashboardOverviewMinutesChart oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    final changed =
        oldWidget.facId != widget.facId || oldWidget.minutes != widget.minutes;

    if (!changed) return;

    setState(() {
      loading = true;
      error = null;
      rows = [];
    });

    _load();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final valid = rows.where((e) => e.value != null).toList();

    final healthResult = DataHealthAnalyzer.analyze(
      loading: loading,
      error: error,
      timestamps: valid.map((e) => e.ts.toLocal()).toList(),
      values: valid.map((e) => e.value!).toList(),
    );

    return SlideTransition(
      position: fx.slide,
      child: AnimatedBuilder(
        animation: fx.listenable,
        builder: (context, child) {
          return Transform.scale(
            scale: fx.scale.value,
            child: Container(
              width: widget.width,
              height: widget.height ?? 220,
              decoration: BoxDecoration(
                color: const Color(0xFF0B1324),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TitleBar(title: t.title, health: healthResult),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: _body(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _body() {
    if (loading) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Text(
          '$error',
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
        ),
      );
    }

    if (rows.isEmpty) {
      return Center(
        child: Text(
          'No data',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
        ),
      );
    }

    return _chart();
  }

  Widget _chart() {
    final t = widget.theme;

    final data = rows
        .where((e) => e.value != null)
        .map((e) => _ChartPoint(e.ts.toLocal(), e.value!))
        .toList();

    if (data.length < 2) {
      return Center(
        child: Text(
          'Not enough points',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
        ),
      );
    }

    final ys = data.map((e) => e.y).toList()..sort();
    final minY = ys.first;
    final maxY = ys.last;

    final range = (maxY - minY).abs();
    final pad = range == 0
        ? (maxY.abs() * 0.01).clamp(0.01, 999999)
        : range * 0.12;

    final minX = data.first.ts;
    final maxX = data.last.ts;

    final totalMinutes = maxX.difference(minX).inMinutes;
    final intervalMin = totalMinutes <= 30 ? 5 : 10;
    final safeMax = (maxY == 0 ? 1.0 : (maxY + pad).toDouble());
    return SfCartesianChart(
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 1,
      plotAreaBorderColor: Colors.white.withOpacity(0.10),
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
        intervalType: DateTimeIntervalType.minutes,
        interval: intervalMin.toDouble(),
        dateFormat: DateFormat('HH:mm'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(0.06),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(0.10)),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.55),
          fontSize: 13,
        ),
      ),
      primaryYAxis: NumericAxis(
        minimum: 0.0,
        maximum: safeMax,
        numberFormat: NumberFormat('0.##'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(0.06),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(0.10)),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.55),
          fontSize: 13,
        ),
      ),
      series: [
        // glow layer (mờ, rộng) -> nhìn “pro”
        SplineSeries<_ChartPoint, DateTime>(
          animationDuration: 1200,
          dataSource: data,
          xValueMapper: (p, _) => p.ts,
          yValueMapper: (p, _) => p.y,
          color: t.line.withOpacity(0.18),
          width: 7,
        ),

        // main area + line
        SplineAreaSeries<_ChartPoint, DateTime>(
          animationDuration: 1000,
          dataSource: data,
          xValueMapper: (p, _) => p.ts,
          yValueMapper: (p, _) => p.y,
          splineType: SplineType.natural,
          borderColor: t.line,
          borderWidth: 2,
          gradient: LinearGradient(
            colors: [t.fillTop, t.fillBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ],
    );
  }
}

class _TitleBar extends StatelessWidget {
  final String title;
  final DataHealthResult health;

  const _TitleBar({required this.title, required this.health});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1324),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.6,
              ),
            ),
          ),

          // ✅ dùng widget chung (pulse/blink/tooltip)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: HealthIndicator(
              result: health,
              size: 10,
              showLabel: false, // muốn hiện chữ thì true
              enableTooltip: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartPoint {
  final DateTime ts;
  final double y;

  _ChartPoint(this.ts, this.y);
}
