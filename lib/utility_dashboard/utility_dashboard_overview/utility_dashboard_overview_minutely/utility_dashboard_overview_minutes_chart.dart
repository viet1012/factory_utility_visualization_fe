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
import '../utility_dashboard_overview_widgets/scada_chart_panel.dart';

class UtilityDashboardOverviewMinutesChart extends StatefulWidget {
  final String facId;
  final int minutes;
  final double? height;
  final String? nameEn;
  final ChartTheme theme;
  final String utilityType;

  const UtilityDashboardOverviewMinutesChart({
    super.key,
    required this.facId,
    required this.theme,
    this.minutes = 60,
    this.height,
    this.nameEn,
    required this.utilityType,
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
            nameEn: widget.nameEn,
            utilityType: widget.utilityType,
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
    });
  }

  bool _dataChanged(List<MinutePointDto> newData) {
    if (newData.length != rows.length) return true;

    for (var i = 0; i < newData.length; i++) {
      if (newData[i].value != rows[i].value ||
          newData[i].ts != rows[i].ts ||
          newData[i].nameEn != rows[i].nameEn) {
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
        oldWidget.nameEn != widget.nameEn;

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

    final validRows = rows.where((e) => e.value != null).toList();

    MinutePointDto? headerPoint;

    final valid = rows.where((e) => e.value != null).toList();

    if (valid.isNotEmpty) {
      headerPoint = valid.reduce((a, b) => a.value! >= b.value! ? a : b);
    }

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
        child: ScadaChartPanel(
          height: widget.height ?? 220,
          color: widget.theme.line,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CommonChartTitleBar(
                title: t.title,
                health: healthResult,
                backgroundColor: Colors.transparent,
                borderColor: widget.theme.line.withOpacity(.44),
                valueLabel: 'Max',
                value: headerPoint == null
                    ? '--'
                    : '${headerPoint.value!.toStringAsFixed(1)} ${t.unit}',

                valueTs: headerPoint == null
                    ? '--'
                    : DateFormat('HH:mm:ss').format(headerPoint.ts.toLocal()),
              ),

              Expanded(child: _body()),
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

    final isWater = widget.utilityType.toUpperCase() == 'WATER';

    if (isWater) {
      return _waterCleanChart();
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
        // .map((e) => _ChartPoint(e.ts.toLocal(), e.value!))
        .map(
          (e) => _ChartPoint(
            e.ts.toLocal(),
            e.value!,
            e.nameEn ?? widget.utilityType,
          ),
        )
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

    double minY;
    double maxY;

    if (widget.utilityType.toUpperCase() == 'ELECTRICITY') {
      // Electricity luôn bắt đầu từ 0
      minY = 0;

      final rawMaxY = maxDataY + pad;
      final step = _niceStep((rawMaxY - minY) / 5);

      maxY = _niceCeil(rawMaxY, step);
    } else {
      // Water / Air scale theo dữ liệu
      minY = minDataY - pad;
      maxY = maxDataY + pad;
    }
    final lastPoint = data.last;
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
          maximum: maxX.add(const Duration(minutes: 2)),
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
          maximum: maxY,
          interval: _niceStep((maxY - minY) / 5),
          numberFormat: NumberFormat('0.0'),

          majorGridLines: MajorGridLines(
            width: 1,
            color: Colors.white.withOpacity(.06),
          ),
          axisLine: AxisLine(color: Colors.white.withOpacity(.10)),
          labelStyle: TextStyle(
            color: Colors.white.withOpacity(.55),
            fontSize: 13,
          ),
          title: AxisTitle(
            text: t.unit,
            alignment: ChartAlignment.center,
            textStyle: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w600,
              fontSize: 12,
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
          ScatterSeries<_ChartPoint, DateTime>(
            isVisibleInLegend: false,
            dataSource: [lastPoint],

            xValueMapper: (p, _) => p.ts,
            yValueMapper: (p, _) => p.y,

            color: t.line,

            markerSettings: MarkerSettings(
              isVisible: true,
              width: 4,
              height: 4,
              borderWidth: 2,
              borderColor: Colors.white,
            ),

            dataLabelMapper: (p, _) => p.y.toStringAsFixed(1),

            dataLabelSettings: const DataLabelSettings(
              isVisible: true,
              labelAlignment: ChartDataLabelAlignment.outer,
              textStyle: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _seriesColorByRank({required int rank, required int total}) {
    final base = HSLColor.fromColor(widget.theme.line);

    if (total <= 1) {
      return base.withLightness(0.48).toColor();
    }

    // rank = 0 là line cao nhất -> đậm nhất
    const darkest = 0.34;
    const lightest = 0.72;

    final ratio = rank / (total - 1);
    final lightness = darkest + ((lightest - darkest) * ratio);

    return base
        .withLightness(lightness.clamp(0.25, 0.80))
        .withSaturation((base.saturation * 0.95).clamp(0.55, 1.0))
        .toColor();
  }

  String _shortTanknameEn(String nameEn) {
    return nameEn
        .replaceAll('_PT100', '')
        .replaceAll('Cooling tank ', 'Tank ')
        .replaceAll('temperature data', '')
        .trim();
  }

  Map<String, List<_ChartPoint>> _groupWaterPoints() {
    final data = rows
        .where((e) => e.value != null)
        .map(
          (e) => _ChartPoint(
            e.ts.toLocal(),
            e.value!,
            (e.nameEn == null || e.nameEn!.trim().isEmpty)
                ? 'Cooling tank'
                : e.nameEn!.trim(),
          ),
        )
        .toList();

    final grouped = <String, List<_ChartPoint>>{};

    for (final p in data) {
      grouped.putIfAbsent(p.nameEn, () => []).add(p);
    }

    for (final item in grouped.values) {
      item.sort((a, b) => a.ts.compareTo(b.ts));
    }

    return grouped;
  }

  Widget _waterCleanChart() {
    final t = widget.theme;
    final grouped = _groupWaterPoints();
    final data = grouped.values.expand((e) => e).toList();
    final showLegend = grouped.length > 1;

    if (data.length < 2) {
      return const Center(
        child: Text(
          'Not enough points',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      );
    }

    final rankedEntries = grouped.entries.toList()
      ..sort((a, b) {
        final avgA =
            a.value.map((e) => e.y).reduce((x, y) => x + y) / a.value.length;

        final avgB =
            b.value.map((e) => e.y).reduce((x, y) => x + y) / b.value.length;

        return avgB.compareTo(avgA);
      });

    final rankByName = <String, int>{};
    for (var i = 0; i < rankedEntries.length; i++) {
      rankByName[rankedEntries[i].key] = i;
    }

    final ys = data.map((e) => e.y).toList()..sort();
    final minValue = ys.first;
    final maxValue = ys.last;
    final range = maxValue - minValue;

    final padding = max(range * 0.1, 0.2);
    final minY = minValue - padding;
    final maxY = maxValue + padding;

    return SfCartesianChart(
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 1,
      plotAreaBorderColor: Colors.white.withOpacity(.08),
      legend: Legend(
        isVisible: showLegend,
        position: LegendPosition.top,
        overflowMode: LegendItemOverflowMode.wrap,
        textStyle: TextStyle(
          color: Colors.white.withOpacity(.75),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      tooltipBehavior: TooltipBehavior(enable: true, header: ''),
      primaryXAxis: DateTimeAxis(
        minimum: data.first.ts,
        maximum: data.last.ts.add(const Duration(minutes: 2)),
        intervalType: DateTimeIntervalType.minutes,
        dateFormat: DateFormat('HH:mm'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(.04),
        ),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(.55),
          fontSize: 11,
        ),
      ),
      primaryYAxis: NumericAxis(
        minimum: minY,
        maximum: maxY,
        interval: (maxY - minY) / 4,
        numberFormat: NumberFormat('0.0'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(.05),
        ),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(.55),
          fontSize: 11,
        ),
        title: AxisTitle(
          text: t.unit,
          alignment: ChartAlignment.center,
          textStyle: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
      series: [
        ...grouped.entries.map((entry) {
          final rank = rankByName[entry.key] ?? 0;

          final color = _seriesColorByRank(rank: rank, total: grouped.length);

          final points = entry.value;

          return LineSeries<_ChartPoint, DateTime>(
            name: _shortTanknameEn(entry.key),
            dataSource: points,
            xValueMapper: (p, _) => p.ts,
            yValueMapper: (p, _) => p.y,
            width: rank == 0 ? 3.0 : 2.0,
            color: color,
            markerSettings: const MarkerSettings(isVisible: false),
          );
        }),

        ...grouped.entries.map((entry) {
          final rank = rankByName[entry.key] ?? 0;

          final color = _seriesColorByRank(rank: rank, total: grouped.length);

          final lastPoint = entry.value.last;

          return ScatterSeries<_ChartPoint, DateTime>(
            isVisibleInLegend: false,
            dataSource: [lastPoint],
            xValueMapper: (p, _) => p.ts,
            yValueMapper: (p, _) => p.y,
            color: color,
            markerSettings: MarkerSettings(
              isVisible: true,
              width: rank == 0 ? 6 : 4,
              height: rank == 0 ? 6 : 4,
              borderWidth: 2,
              borderColor: Colors.white.withOpacity(.9),
            ),
            dataLabelMapper: (p, _) => p.y.toStringAsFixed(1),
            dataLabelSettings: DataLabelSettings(
              isVisible: true,
              labelAlignment: ChartDataLabelAlignment.outer,
              textStyle: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ChartPoint {
  final DateTime ts;
  final double y;
  final String nameEn;

  _ChartPoint(this.ts, this.y, this.nameEn);
}
