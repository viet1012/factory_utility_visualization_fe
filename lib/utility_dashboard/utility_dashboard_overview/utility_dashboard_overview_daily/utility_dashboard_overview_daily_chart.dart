import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_common/data_health.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../../utility_dashboard_common/utility_fac_style.dart';
import '../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';
import '../utility_dashboard_overview_widgets/chart_state_widgets.dart';
import '../utility_dashboard_overview_widgets/common_chart_title_bar.dart';
import '../utility_dashboard_overview_widgets/health_indicator.dart';

class _DailyDto {
  final DateTime date;
  final double value;

  _DailyDto(this.date, this.value);

  factory _DailyDto.fromJson(Map<String, dynamic> json) {
    final d = (json['date'] ?? '').toString();
    final v = json['value'];

    return _DailyDto(
      DateTime.parse(d),
      v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0,
    );
  }
}

class _BarPoint {
  final DateTime ts;
  final double y;

  _BarPoint(this.ts, this.y);
}

class _DailyChartData {
  final List<_BarPoint> points;
  final DateTime minX;
  final DateTime maxX;
  final double maxY;
  final double yInterval;

  const _DailyChartData({
    required this.points,
    required this.minX,
    required this.maxX,
    required this.maxY,
    required this.yInterval,
  });

  static _DailyChartData from(List<_DailyDto> rows, String month) {
    final points =
        rows.map((e) => _BarPoint(e.date.toLocal(), e.value)).toList()
          ..sort((a, b) => a.ts.compareTo(b.ts));

    final year = int.parse(month.substring(0, 4));
    final monthNum = int.parse(month.substring(4, 6));

    final firstDay = DateTime(year, monthNum, 1);
    final lastDay = DateTime(
      year,
      monthNum + 1,
      1,
    ).subtract(const Duration(days: 1));

    final maxDataY = points.isEmpty
        ? 1.0
        : points.map((e) => e.y).reduce((a, b) => a > b ? a : b);

    final rawMaxY = maxDataY <= 0 ? 1.0 : maxDataY * 1.15;
    final interval = _niceStep(rawMaxY / 5);
    final maxY = _niceCeil(rawMaxY, interval);

    return _DailyChartData(
      points: points,
      minX: firstDay.subtract(const Duration(hours: 12)),
      maxX: lastDay.add(const Duration(hours: 12)),
      maxY: maxY,
      yInterval: interval,
    );
  }

  static double _niceStep(double rawStep) {
    if (rawStep <= 0) return 1;

    final exp = (log(rawStep) / ln10).floor();
    final base = pow(10, exp).toDouble();
    final fraction = rawStep / base;

    if (fraction <= 1) return 1 * base;
    if (fraction <= 2) return 2 * base;
    if (fraction <= 5) return 5 * base;

    return 10 * base;
  }

  static double _niceCeil(double value, double step) {
    if (step <= 0) return value;
    return (value / step).ceil() * step;
  }
}

class UtilityDashboardOverviewDailyChart extends StatefulWidget {
  final double width;
  final double? height;
  final String facId;
  final String month;
  final String nameEng;
  final ChartTheme theme;

  const UtilityDashboardOverviewDailyChart({
    super.key,
    required this.facId,
    required this.month,
    required this.theme,
    this.nameEng = 'Total Energy Consumption',
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
  static const Duration _pollInterval = Duration(minutes: 60);
  static const Duration _requestTimeout = Duration(seconds: 15);

  late final UtilityInfoBoxFx fx;

  List<_DailyDto> rows = [];
  bool loading = true;
  Object? error;

  DataHealthResult? _cachedHealth;
  _DailyChartData? _cachedChartData;
  String _lastVal = '--';
  String _lastTs = '--';

  bool _loadingNow = false;
  Timer? _pollTimer;

  bool get _hasRequired {
    final fac = widget.facId.trim();
    final month = widget.month.trim();

    return fac.isNotEmpty && RegExp(r'^\d{6}$').hasMatch(month);
  }

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

    if (!_hasRequired) {
      setState(() {
        loading = false;
        error = 'Missing/invalid facId or month(yyyyMM)';
        rows = [];
        _cachedHealth = null;
        _cachedChartData = null;
        _lastVal = '--';
        _lastTs = '--';
      });
      return;
    }

    _loadingNow = true;

    if (!silent && rows.isEmpty) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final api = context.read<UtilityDashboardOverviewApi>();

      final res = await api
          .getEnergyDaily(
            facId: widget.facId,
            month: widget.month,
            nameEn: widget.nameEng,
          )
          .timeout(_requestTimeout);

      final list =
          res
              .map((e) => _DailyDto.fromJson(Map<String, dynamic>.from(e)))
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));

      if (!mounted) return;

      if (_dataChanged(list) || loading || error != null) {
        _recomputeCache(list);

        setState(() {
          rows = list;
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
      key: 'Daily_${widget.facId}_${widget.theme.title}',
      loading: false,
      error: true,
      values: rows.map((e) => e.value).toList(),
    );

    setState(() {
      loading = false;
      error = e;

      // Giữ rows cũ để chart không bị trắng khi API lỗi.
    });
  }

  bool _dataChanged(List<_DailyDto> next) {
    if (next.length != rows.length) return true;

    for (var i = 0; i < next.length; i++) {
      if (next[i].value != rows[i].value || next[i].date != rows[i].date) {
        return true;
      }
    }

    return false;
  }

  void _recomputeCache(List<_DailyDto> list) {
    _cachedHealth = DataHealthAnalyzer.analyze(
      key: 'Daily_${widget.facId}_${widget.theme.title}',
      loading: false,
      error: null,
      values: list.map((e) => e.value).toList(),
    );

    _cachedChartData = list.isEmpty
        ? null
        : _DailyChartData.from(list, widget.month);

    if (list.isEmpty) {
      _lastVal = '--';
      _lastTs = '--';
      return;
    }

    final now = DateTime.now();
    final isCurrentMonth = DateFormat('yyyyMM').format(now) == widget.month;

    final lastDto = isCurrentMonth
        ? list.firstWhere(
            (e) =>
                e.date.year == now.year &&
                e.date.month == now.month &&
                e.date.day == now.day,
            orElse: () => list.last,
          )
        : list.last;

    _lastVal = '${lastDto.value.toStringAsFixed(1)} ${widget.theme.unit}';
    _lastTs = DateFormat('yyyy-MM-dd').format(lastDto.date);
  }

  @override
  void didUpdateWidget(covariant UtilityDashboardOverviewDailyChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    final changed =
        oldWidget.facId != widget.facId ||
        oldWidget.month != widget.month ||
        oldWidget.nameEng != widget.nameEng;

    if (!changed) return;

    _pollTimer?.cancel();

    setState(() {
      rows = [];
      loading = true;
      error = null;
      _cachedHealth = null;
      _cachedChartData = null;
      _lastVal = '--';
      _lastTs = '--';
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
    final facilityColor = UtilityFacStyle.colorFromFac(widget.facId);

    final healthResult =
        _cachedHealth ??
        DataHealthAnalyzer.analyze(
          key: 'Daily_${widget.facId}_${widget.theme.title}',
          loading: loading,
          error: error,
          values: const [],
        );

    return SlideTransition(
      position: fx.slide,
      child: MouseRegion(
        onEnter: (_) => fx.onHover(true),
        onExit: (_) => fx.onHover(false),
        child: AnimatedBuilder(
          animation: fx.listenable,
          builder: (context, child) {
            return Transform.scale(scale: fx.scale.value, child: child);
          },
          child: _Shell(
            width: widget.width,
            height: widget.height ?? 320,
            facilityColor: facilityColor,
            child: _body(healthResult),
          ),
        ),
      ),
    );
  }

  Widget _body(DataHealthResult health) {
    if (!_hasRequired) {
      return const EmptyChartState(
        icon: Icons.warning_amber_rounded,
        title: 'Invalid Parameters',
        message: 'Missing facId or invalid month format.',
      );
    }

    if (loading && rows.isEmpty) {
      return Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: widget.theme.line,
          ),
        ),
      );
    }

    if (error != null && rows.isEmpty) {
      return ChartApiErrorState(color: widget.theme.line, onRetry: _load);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        CommonChartTitleBar(
          title: widget.theme.title,
          health: health,
          lastVal: _lastVal,
          lastTs: _lastTs,
          borderColor: widget.theme.fillTop.withOpacity(0.35),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: rows.isEmpty || _cachedChartData == null
              ? const EmptyChartState(
                  title: 'No Daily Data',
                  message:
                      'No utility consumption data available for this month.',
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                    color: Colors.black.withOpacity(0.05),
                  ),
                  child: RepaintBoundary(
                    child: _DailyBarChart(
                      theme: widget.theme,
                      data: _cachedChartData!,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Shell extends StatelessWidget {
  final double width;
  final double height;
  final Color facilityColor;
  final Widget child;

  const _Shell({
    required this.width,
    required this.height,
    required this.facilityColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
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
        border: Border.all(color: Colors.white.withOpacity(0.12)),
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
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
    );
  }
}

class _TitleBar extends StatelessWidget {
  final ChartTheme theme;
  final DataHealthResult health;
  final String lastVal;
  final String lastTs;

  const _TitleBar({
    required this.theme,
    required this.health,
    required this.lastVal,
    required this.lastTs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: theme.fillTop.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              theme.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          HealthIndicator(
            result: health,
            size: 10,
            showLabel: false,
            enableTooltip: true,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'Last: $lastVal • $lastTs',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyBarChart extends StatelessWidget {
  final ChartTheme theme;
  final _DailyChartData data;

  const _DailyBarChart({required this.theme, required this.data});

  @override
  Widget build(BuildContext context) {
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
        minimum: data.minX,
        maximum: data.maxX,
        intervalType: DateTimeIntervalType.days,
        interval: 1,
        labelRotation: 45,
        dateFormat: DateFormat('dd'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(0.08),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(0.15), width: 1),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.75),
          fontSize: 13,
        ),
        labelPosition: ChartDataLabelPosition.outside,
        edgeLabelPlacement: EdgeLabelPlacement.hide,
      ),
      primaryYAxis: NumericAxis(
        minimum: 0,
        maximum: data.maxY,
        interval: data.yInterval,
        numberFormat: NumberFormat('0.##'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(0.08),
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
        axisLine: AxisLine(color: Colors.white.withOpacity(0.15), width: 1),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.75),
          fontSize: 13,
        ),
      ),
      series: <CartesianSeries<_BarPoint, DateTime>>[
        ColumnSeries<_BarPoint, DateTime>(
          animationDuration: 1000,
          dataSource: data.points,
          xValueMapper: (p, _) => p.ts,
          yValueMapper: (p, _) => p.y,
          width: 0.85,
          spacing: 0.2,
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          color: theme.line,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.fillTop, theme.fillBottom],
          ),
          borderColor: theme.line.withOpacity(0.95),
          borderWidth: 0.8,
        ),
      ],
    );
  }
}
