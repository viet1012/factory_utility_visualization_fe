import 'dart:async';

import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_overview/chart_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../utility_models/response/minute_point.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../data_health.dart';
import '../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';
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

  // ── Cache health result để tránh tính lại trong build() ──────────────────
  DataHealthResult? _cachedHealth;

  bool _loadingNow = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    fx = UtilityInfoBoxFx(this)..init();
    _load();
  }

  Future<void> _load() async {
    if (_loadingNow || _disposed) return;
    _loadingNow = true;

    try {
      final api = context.read<UtilityDashboardOverviewApi>();
      final data = await api.getEnergyMinute(
        facId: widget.facId,
        minutes: widget.minutes,
        nameEn: widget.nameEng,
      );

      if (!mounted) return;

      // Chỉ setState khi data thực sự thay đổi
      if (_dataChanged(data)) {
        final valid = data.where((e) => e.value != null).toList();

        // Tính health result ngoài setState, không tính lại trong build()
        _cachedHealth = DataHealthAnalyzer.analyze(
          key: "Minutes_${widget.facId}_${widget.theme.title}",
          loading: false,
          error: null,
          values: valid.map((e) => e.value!).toList(),
        );

        setState(() {
          rows = data;
          loading = false;
          error = null;
        });
      } else {
        // Data không đổi → chỉ tắt loading, không rebuild chart
        if (loading) {
          setState(() {
            loading = false;
          });
        }
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

    // Tiếp tục poll, nhưng chỉ khi chưa dispose
    if (!_disposed) {
      Future.delayed(const Duration(seconds: 50), _load);
    }
  }

  bool _dataChanged(List<MinutePointDto> newData) {
    if (newData.length != rows.length) return true;
    for (var i = 0; i < newData.length; i++) {
      if (newData[i].value != rows[i].value || newData[i].ts != rows[i].ts) {
        return true;
      }
    }
    return false;
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
      _cachedHealth = null;
    });

    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    // debugPrint("BUILD UtilityDashboardOverviewMinutesChart");

    // Tính health chỉ khi chưa có cache (loading/error state)
    final healthResult =
        _cachedHealth ??
        DataHealthAnalyzer.analyze(
          key: "Minutes_${widget.facId}_${widget.theme.title}",
          loading: loading,
          error: error,
          values: const [],
        );

    // ── Animation chỉ bọc phần SHELL (decoration + scale), KHÔNG bọc chart ─
    return SlideTransition(
      position: fx.slide,
      child: AnimatedBuilder(
        animation: fx.listenable,
        builder: (context, child) {
          return Transform.scale(
            scale: fx.scale.value,
            // child được pass từ ngoài vào → KHÔNG rebuild theo animation frame
            child: child,
          );
        },
        // Chart nằm ở đây: chỉ build lại khi setState, không bị kéo vào loop
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
          'No data available',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 20),
        ),
      );
    }

    return _chart();
  }

  // ── RepaintBoundary isolate repaint của chart khỏi parent ────────────────
  Widget _chart() {
    final t = widget.theme;
    debugPrint("CHART BUILD");
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
    final maxY = ys.last;

    final range = (maxY - ys.first).abs();
    final pad = range == 0
        ? (maxY.abs() * 0.01).clamp(0.01, 999999)
        : range * 0.12;

    final minX = data.first.ts;
    final maxX = data.last.ts;

    final totalMinutes = maxX.difference(minX).inMinutes;
    final intervalMin = totalMinutes <= 30 ? 5 : 10;

    return RepaintBoundary(
      child: SfCartesianChart(
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
          title: AxisTitle(
            text: t.unit,
            textStyle: TextStyle(
              color: Colors.white.withOpacity(.8),
              fontSize: 13,
            ),
          ),
        ),
        series: [
          SplineSeries<_ChartPoint, DateTime>(
            animationDuration: 1200,
            dataSource: data,
            xValueMapper: (p, _) => p.ts,
            yValueMapper: (p, _) => p.y,
            color: t.line.withOpacity(0.18),
            width: 7,
          ),
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
            markerSettings: MarkerSettings(
              isVisible: true,
              width: 4,
              height: 4,
              borderWidth: 1,
              borderColor: widget.theme.line.withOpacity(0.9),
            ),
          ),
        ],
      ),
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
