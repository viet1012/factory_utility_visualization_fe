import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_common/chart_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../utility_models/response/minute_point.dart';
import '../../utility_dashboard_common/data_health.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';
import '../utility_dashboard_overview_widgets/chart_state_widgets.dart';
import '../utility_dashboard_overview_widgets/common_chart_title_bar.dart';

class UtilityDashboardOverviewMinutesChart extends StatefulWidget {
  final String facId;
  final int minutes;
  final double width;
  final double? height;
  final String? nameEng;
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
  static const Duration _pollInterval = Duration(seconds: 50);
  static const Duration _requestTimeout = Duration(seconds: 12);

  late final UtilityInfoBoxFx fx;

  List<MinutePointDto> rows = [];
  Object? error;
  bool loading = true;
  DataHealthResult? _cachedHealth;

  bool _loadingNow = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    fx = UtilityInfoBoxFx(this)..init();

    _load();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();

    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!_loadingNow && mounted) {
        _load(silent: true);
      }
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (_loadingNow || !mounted) return;

    _loadingNow = true;

    if (!silent && rows.isEmpty) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final api = context.read<UtilityDashboardOverviewApi>();

      final data = await api
          .getEnergyMinute(
            facId: widget.facId,
            minutes: widget.minutes,
            nameEn: widget.nameEng,
          )
          .timeout(_requestTimeout);

      if (!mounted) return;

      final valid = data.where((e) => e.value != null).toList();

      _cachedHealth = DataHealthAnalyzer.analyze(
        key: 'Minutes_${widget.facId}_${widget.theme.title}',
        loading: false,
        error: null,
        values: valid.map((e) => e.value!).toList(),
      );

      if (_dataChanged(data) || loading || error != null) {
        setState(() {
          rows = data;
          loading = false;
          error = null;
        });
      }
    } on TimeoutException catch (e) {
      _handleLoadError(e, '[TIMEOUT]');
    } on DioException catch (e) {
      _handleLoadError(e, '[DIO] ${e.type}');
    } catch (e) {
      _handleLoadError(e, '[ERROR]');
    } finally {
      _loadingNow = false;
    }
  }

  void _handleLoadError(Object e, String tag) {
    debugPrint('$tag $e');

    if (!mounted) return;

    _cachedHealth = DataHealthAnalyzer.analyze(
      key: 'Minutes_${widget.facId}_${widget.theme.title}',
      loading: false,
      error: true,
      values: rows.where((e) => e.value != null).map((e) => e.value!).toList(),
    );

    setState(() {
      loading = false;
      error = e;

      // Giữ rows cũ để chart không bị trắng khi API lỗi.
    });
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
        oldWidget.facId != widget.facId ||
        oldWidget.minutes != widget.minutes ||
        oldWidget.nameEng != widget.nameEng;

    if (!changed) return;

    _pollTimer?.cancel();

    setState(() {
      rows = [];
      loading = true;
      error = null;
      _cachedHealth = null;
    });

    _load();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final last = rows.isEmpty ? null : rows.last;

    final healthResult =
        _cachedHealth ??
        DataHealthAnalyzer.analyze(
          key: 'Minutes_${widget.facId}_${widget.theme.title}',
          loading: loading,
          error: error,
          values: const [],
        );

    return SlideTransition(
      position: fx.slide,
      child: AnimatedBuilder(
        animation: fx.listenable,
        builder: (context, child) {
          return Transform.scale(scale: fx.scale.value, child: child);
        },
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
              // _TitleBar(title: t.title, health: healthResult),
              CommonChartTitleBar(
                title: t.title,
                health: healthResult,

                lastVal: last == null
                    ? '--'
                    : '${last.value?.toStringAsFixed(1) ?? '--'} ${t.unit}',

                lastTs: last == null
                    ? '--'
                    : DateFormat('HH:mm:ss').format(last.ts.toLocal()),
              ),
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
      return ChartApiErrorState(color: widget.theme.line, onRetry: _load);
    }

    if (rows.isEmpty) {
      return const EmptyChartState(
        title: 'No Data Available',
        message: 'No minute data found for this period.',
      );
    }

    return _chart();
  }

  double _niceStep(double rawStep) {
    if (rawStep <= 0) return 1;

    final exp = (log(rawStep) / ln10).floor();
    final base = pow(10, exp).toDouble();
    final fraction = rawStep / base;

    if (fraction <= 1) return 1 * base;
    if (fraction <= 2) return 2 * base;
    if (fraction <= 5) return 5 * base;

    return 10 * base;
  }

  double _niceCeil(double value, double step) {
    if (step <= 0) return value;
    return (value / step).ceil() * step;
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
    final minDataY = ys.first;
    final maxDataY = ys.last;

    final dataRange = (maxDataY - minDataY).abs();

    final pad = dataRange == 0
        ? (maxDataY.abs() * 0.1).clamp(0.5, 999999).toDouble()
        : dataRange * 0.15;

    final minX = data.first.ts;
    final maxX = data.last.ts;

    final minY = 0.0;
    final rawMaxY = maxDataY + pad;
    final rawStep = (rawMaxY - minY) / 5;

    final yInterval = _niceStep(rawStep);
    final maxYWithPad = _niceCeil(rawMaxY, yInterval);

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
          minimum: minY,
          maximum: maxYWithPad,
          interval: yInterval,
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

class _ChartPoint {
  final DateTime ts;
  final double y;

  _ChartPoint(this.ts, this.y);
}
