import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';
import '../../utility_dashboard_overview_widgets/scada_panel_frame.dart';

const TextStyle _labelStyle = TextStyle(
  color: Colors.white,
  fontSize: 12,
  fontWeight: FontWeight.w800,
  letterSpacing: .5,
);

class HourlyTempCompareDto {
  final DateTime hourTime;
  final double? currentTemp;
  final double? previousTemp;
  final double? diffTemp;

  HourlyTempCompareDto({
    required this.hourTime,
    this.currentTemp,
    this.previousTemp,
    this.diffTemp,
  });

  factory HourlyTempCompareDto.fromJson(Map<String, dynamic> json) {
    double? toD(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return HourlyTempCompareDto(
      hourTime: DateTime.parse(json['hourTime'].toString()),
      currentTemp: toD(json['currentTemp']),
      previousTemp: toD(json['previousTemp']),
      diffTemp: toD(json['diffTemp']),
    );
  }
}

class CoolingTankTemperaturePanel extends StatefulWidget {
  final String facId;
  final int hours;
  final ChartTheme theme;

  const CoolingTankTemperaturePanel({
    super.key,
    required this.facId,
    this.hours = 24,
    required this.theme,
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
    _timer = Timer.periodic(_pollInterval, (_) {
      _load(silent: true);
    });
  }

  @override
  void didUpdateWidget(covariant CoolingTankTemperaturePanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.facId != widget.facId || oldWidget.hours != widget.hours) {
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
          .getCoolingTankHourly(facId: widget.facId, hours: widget.hours)
          .timeout(_requestTimeout);

      if (!mounted) return;

      setState(() {
        rows = data..sort((a, b) => a.hourTime.compareTo(b.hourTime));
        loading = false;
        error = null;
      });
    } on DioException catch (e) {
      _handleError(e);
    } on TimeoutException catch (e) {
      _handleError(e);
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
      return const _StateBox(
        title: 'Load Failed',
        message: 'Unable to load cooling tank temperature.',
      );
    }

    if (rows.isEmpty) {
      return const _StateBox(
        title: 'No Temperature Data',
        message: 'No cooling tank temperature data found.',
      );
    }

    final latest = rows.lastWhere(
      (e) => e.currentTemp != null,
      orElse: () => rows.last,
    );

    return ScadaPanelFrame(
      color: widget.theme.line,

      child: _TemperatureTrendCard(
        rows: rows,
        current: latest.currentTemp,
        diff: latest.diffTemp,
      ),
    );
  }
}

class _TemperatureTrendCard extends StatelessWidget {
  final List<HourlyTempCompareDto> rows;
  final double? current;
  final double? diff;

  const _TemperatureTrendCard({
    required this.rows,
    required this.current,
    required this.diff,
  });

  @override
  Widget build(BuildContext context) {
    final d = diff ?? 0;

    final values = rows
        .where((e) => e.currentTemp != null)
        .map((e) => e.currentTemp!)
        .toList();

    final minVal = values.isEmpty ? null : values.reduce(min);
    final maxVal = values.isEmpty ? null : values.reduce(max);
    final avgVal = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('COOLING TANK TEMPERATURE', style: _labelStyle),

          const SizedBox(height: 4),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                current == null ? '--' : '${current!.toStringAsFixed(1)}°C',
                style: const TextStyle(
                  color: Color(0xFF22D3EE),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),

              const SizedBox(width: 10),

              _InlineStat('Min', minVal, const Color(0xFF38BDF8)),
              const SizedBox(width: 6),
              _InlineStat('Avg', avgVal, const Color(0xFF22C55E)),
              const SizedBox(width: 6),
              _InlineStat('Max', maxVal, const Color(0xFFF97316)),

              const Spacer(),

              Text(
                '${d >= 0 ? '+' : '-'}${d.abs().toStringAsFixed(1)}°C',
                style: TextStyle(
                  color: d >= 0 ? Colors.redAccent : Colors.greenAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Expanded(child: _TempLineChart(rows: rows)),
        ],
      ),
    );
  }
}

class _TempLineChart extends StatelessWidget {
  final List<HourlyTempCompareDto> rows;

  const _TempLineChart({required this.rows});

  @override
  Widget build(BuildContext context) {
    final points = rows
        .where((e) => e.currentTemp != null)
        .map((e) => _TempPoint(e.hourTime, e.currentTemp!))
        .toList();

    if (points.length < 2) {
      return Center(
        child: Text(
          'Not enough points',
          style: TextStyle(color: Colors.white.withOpacity(.65)),
        ),
      );
    }

    final ys = points.map((e) => e.value).toList();
    final minY = max(0, ys.reduce(min) - 2).toDouble();
    final maxY = ys.reduce(max) + 2;

    return SfCartesianChart(
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 0,
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('HH:mm'),
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
      primaryYAxis: NumericAxis(
        minimum: minY,
        maximum: maxY,
        interval: 1,
        labelFormat: '{value}°',
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
      tooltipBehavior: TooltipBehavior(enable: true),
      series: [
        SplineAreaSeries<_TempPoint, DateTime>(
          dataSource: points,
          xValueMapper: (p, _) => p.time,
          yValueMapper: (p, _) => p.value,
          borderWidth: 2,
          borderColor: const Color(0xFF22D3EE),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF22D3EE).withOpacity(.38),
              const Color(0xFF22D3EE).withOpacity(.02),
            ],
          ),
          markerSettings: const MarkerSettings(
            isVisible: true,
            width: 3,
            height: 3,
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF061C2E).withOpacity(.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0891B2).withOpacity(.55)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0891B2).withOpacity(.16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

class _StateBox extends StatelessWidget {
  final String title;
  final String message;

  const _StateBox({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Center(
        child: Text(
          '$title\n$message',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF22D3EE),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _TempPoint {
  final DateTime time;
  final double value;

  _TempPoint(this.time, this.value);
}

class _InlineStat extends StatelessWidget {
  final String label;
  final double? value;
  final Color color;

  const _InlineStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label ${value == null ? '--' : value!.toStringAsFixed(1)}°',
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
    );
  }
}
