import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';
import '../../utility_dashboard_overview_widgets/scada_panel_frame.dart';

class HourlyTempCompareDto {
  final int scaleHour;
  final double? today;
  final double? yesterday;

  const HourlyTempCompareDto({
    required this.scaleHour,
    this.today,
    this.yesterday,
  });

  factory HourlyTempCompareDto.fromJson(Map<String, dynamic> json) {
    double? toD(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return HourlyTempCompareDto(
      scaleHour: json['scaleHour'] is int
          ? json['scaleHour']
          : int.tryParse(json['scaleHour'].toString()) ?? 0,
      yesterday: toD(json['yesterday']),
      today: toD(json['today']),
    );
  }

  double? get diff {
    if (today == null || yesterday == null) return null;
    return today! - yesterday!;
  }
}

class CoolingTankTemperaturePanel extends StatefulWidget {
  final String facId;
  final int hours;
  final ChartTheme theme;
  final String utilityType; // WATER / AIR

  const CoolingTankTemperaturePanel({
    super.key,
    required this.facId,
    this.hours = 24,
    required this.theme,
    this.utilityType = 'WATER',
  });

  @override
  State<CoolingTankTemperaturePanel> createState() =>
      _CoolingTankTemperaturePanelState();
}

class _CoolingTankTemperaturePanelState
    extends State<CoolingTankTemperaturePanel> {
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _pollInterval = Duration(minutes: 1);

  List<HourlyTempCompareDto> rows = [];
  bool loading = true;
  Object? error;
  Timer? _timer;
  bool _loadingNow = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(_pollInterval, (_) => _load(silent: true));
  }

  @override
  void didUpdateWidget(covariant CoolingTankTemperaturePanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.facId != widget.facId ||
        oldWidget.hours != widget.hours ||
        oldWidget.utilityType != widget.utilityType) {
      setState(() {
        rows = [];
        loading = true;
        error = null;
      });

      _load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
          .getCoolingTankHourly(
            facId: widget.facId,
            hours: widget.hours,
            type: widget.utilityType,
          )
          .timeout(_requestTimeout);

      if (!mounted) return;

      setState(() {
        rows = data..sort((a, b) => a.scaleHour.compareTo(b.scaleHour));
        loading = false;
        error = null;
      });
    } catch (e) {
      _handleError(e);
    } finally {
      _loadingNow = false;
    }
  }

  void _handleError(Object e) {
    if (!mounted) return;

    setState(() {
      loading = false;
      error = e;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading && rows.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (error != null && rows.isEmpty) {
      return _StateBox(
        theme: widget.theme,
        title: 'Load Failed',
        message: 'Unable to load ${widget.theme.title.toLowerCase()} data.',
      );
    }

    if (rows.isEmpty) {
      return _StateBox(
        theme: widget.theme,
        title: 'No Data',
        message: 'No ${widget.theme.title.toLowerCase()} data found.',
      );
    }

    final latest = rows.lastWhere(
      (e) => e.today != null,
      orElse: () => rows.last,
    );

    return ScadaPanelFrame(
      color: widget.theme.line,
      child: _TemperatureTrendCard(
        theme: widget.theme,
        rows: rows,
        current: latest.today,
        diff: latest.diff,
      ),
    );
  }
}

class _TemperatureTrendCard extends StatelessWidget {
  final ChartTheme theme;
  final List<HourlyTempCompareDto> rows;
  final double? current;
  final double? diff;

  const _TemperatureTrendCard({
    required this.theme,
    required this.rows,
    required this.current,
    required this.diff,
  });

  @override
  Widget build(BuildContext context) {
    final todayValues = rows
        .where((e) => e.today != null)
        .map((e) => e.today!)
        .toList();

    final minVal = todayValues.isEmpty ? null : todayValues.reduce(min);
    final maxVal = todayValues.isEmpty ? null : todayValues.reduce(max);

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          Row(
            children: [
              //Text(
              //   theme.title,
              //   style: TextStyle(
              //     color: theme.accent,
              //     fontSize: 13,
              //     fontWeight: FontWeight.w900,
              //   ),
              // ),
              //
              Icon(theme.icon, color: theme.line, size: 18),

              // const SizedBox(width: 14),
              Text(
                current == null ? '--' : current!.toStringAsFixed(1),
                style: TextStyle(
                  color: theme.line,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),

              const SizedBox(width: 4),

              Text(
                theme.unit,
                style: TextStyle(
                  color: theme.line.withOpacity(.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(width: 18),

              _CompactStat('Min', minVal),

              const SizedBox(width: 12),

              _CompactStat('Max', maxVal),

              const Spacer(),

              _MiniDiffCard(diff: diff),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _TempLineChart(theme: theme, rows: rows),
          ),
        ],
      ),
    );
  }
}

class _TempLineChart extends StatelessWidget {
  final ChartTheme theme;
  final List<HourlyTempCompareDto> rows;

  const _TempLineChart({required this.theme, required this.rows});

  @override
  Widget build(BuildContext context) {
    final todayPoints = rows
        .where((e) => e.today != null)
        .map((e) => _TempPoint(e.scaleHour, e.today!))
        .toList();

    final yesterdayPoints = rows
        .where((e) => e.yesterday != null)
        .map((e) => _TempPoint(e.scaleHour, e.yesterday!))
        .toList();

    final allValues = [
      ...todayPoints.map((e) => e.value),
      ...yesterdayPoints.map((e) => e.value),
    ];

    if (allValues.length < 2) {
      return Center(
        child: Text(
          'Not enough points',
          style: TextStyle(color: Colors.white.withOpacity(.65)),
        ),
      );
    }

    final minValue = allValues.reduce(min);
    final maxValue = allValues.reduce(max);
    final range = maxValue - minValue;
    final pad = max(range * .18, 0.5);

    final minY = minValue - pad;
    final maxY = maxValue + pad;

    return SfCartesianChart(
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 0,
      legend: Legend(
        isVisible: true,
        position: LegendPosition.top,
        alignment: ChartAlignment.center,
        textStyle: TextStyle(
          color: Colors.white.withOpacity(.75),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      primaryXAxis: NumericAxis(
        minimum: 0,
        maximum: 23,
        interval: 2,
        decimalPlaces: 0,
        axisLabelFormatter: (args) {
          return ChartAxisLabel(
            args.value.toInt().toString(),
            TextStyle(
              color: Colors.white.withOpacity(.70),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          );
        },
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(.04),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(.10)),
      ),
      primaryYAxis: NumericAxis(
        minimum: minY,
        maximum: maxY,
        interval: (maxY - minY) / 5,
        labelFormat: '{value}${theme.unit}',
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(.04),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(.10)),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(.50),
          fontSize: 10,
        ),
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        decimalPlaces: 1,
        format: 'Hour point.x : point.y${theme.unit}',
      ),
      series: [
        AreaSeries<_TempPoint, int>(
          name: 'Yesterday',
          dataSource: yesterdayPoints,
          xValueMapper: (p, _) => p.hour,
          yValueMapper: (p, _) => p.value,
          borderColor: const Color(0xFF9CA3AF),
          borderWidth: 2,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF9CA3AF).withOpacity(.20),
              const Color(0xFF9CA3AF).withOpacity(.02),
            ],
          ),
          emptyPointSettings: const EmptyPointSettings(
            mode: EmptyPointMode.gap,
          ),
          markerSettings: const MarkerSettings(isVisible: false),
        ),
        LineSeries<_TempPoint, int>(
          name: 'Today',
          dataSource: todayPoints,
          xValueMapper: (p, _) => p.hour,
          yValueMapper: (p, _) => p.value,
          dataLabelMapper: (p, _) => p.value.toStringAsFixed(1),
          color: theme.line,
          width: 2.4,
          emptyPointSettings: const EmptyPointSettings(
            mode: EmptyPointMode.gap,
          ),
          markerSettings: const MarkerSettings(
            isVisible: true,
            width: 4,
            height: 4,
          ),
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.top,
            textStyle: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _TempPoint {
  final int hour;
  final double value;

  const _TempPoint(this.hour, this.value);
}

class _Panel extends StatelessWidget {
  final ChartTheme theme;
  final Widget child;

  const _Panel({required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF061C2E).withOpacity(.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.line.withOpacity(.55)),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

class _StateBox extends StatelessWidget {
  final ChartTheme theme;
  final String title;
  final String message;

  const _StateBox({
    required this.theme,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      theme: theme,
      child: Center(
        child: Text(
          '$title\n$message',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.line, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String label;
  final double? value;

  const _CompactStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label ',
          style: TextStyle(
            color: Colors.white.withOpacity(.55),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value == null ? '--' : value!.toStringAsFixed(1),
          style: const TextStyle(
            color: Color(0xFF38BDF8),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _MiniDiffCard extends StatelessWidget {
  final double? diff;

  const _MiniDiffCard({required this.diff});

  @override
  Widget build(BuildContext context) {
    final d = diff ?? 0;
    final isDown = d < 0;

    return Container(
      width: 70,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF061827).withOpacity(.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(.14)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            diff == null
                ? '--'
                : '${d >= 0 ? '+' : '-'}${d.abs().toStringAsFixed(1)}',
            style: TextStyle(
              color: isDown ? const Color(0xFF4ADE80) : Colors.redAccent,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'vs Yday',
            style: TextStyle(color: Colors.white.withOpacity(.6), fontSize: 10),
          ),
        ],
      ),
    );
  }
}
