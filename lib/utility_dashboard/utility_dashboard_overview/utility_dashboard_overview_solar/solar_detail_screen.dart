import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../utility_dashboard_overview_widgets/month_label_badge.dart';

// TODO: sửa import theo project của bạn.
// import 'package:your_project/core/network/dio_client.dart';

class SolarDetailScreen extends StatefulWidget {
  final String facId;

  /// yyyyMM
  /// Ví dụ: 202608
  final String month;

  const SolarDetailScreen({
    super.key,
    required this.facId,
    required this.month,
  });

  @override
  State<SolarDetailScreen> createState() => _SolarDetailScreenState();
}

class _SolarDetailScreenState extends State<SolarDetailScreen> {
  // ============================================================
  // API
  // ============================================================

  /// Nếu project bạn đã có DioClient:
  ///
  /// Dio get _dio => DioClient.dio;
  ///
  /// thì bỏ đoạn Dio() này đi.
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:9999',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  // ============================================================
  // STATE
  // ============================================================

  SolarDetailData? _data;

  bool _loading = true;
  bool _refreshing = false;

  String? _error;

  int _requestVersion = 0;

  Timer? _refreshTimer;

  /// Detail không cần query liên tục.
  /// 1 tiếng refresh một lần.
  static const Duration _refreshInterval = Duration(hours: 1);

  // ============================================================
  // COLORS
  // ============================================================

  static const Color _bg = Color(0xff020b15);

  static const Color _panel2 = Color(0xff071d30);

  static const Color _cyan = Color(0xff22d3ee);

  static const Color _yellow = Color(0xffffb800);

  static const Color _green = Color(0xff63f06d);

  static const Color _border = Color(0xff17415d);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _load();

    _startRefreshTimer();
  }

  @override
  void didUpdateWidget(covariant SolarDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final facChanged = oldWidget.facId != widget.facId;

    final monthChanged = oldWidget.month != widget.month;

    if (facChanged || monthChanged) {
      _requestVersion++;

      _load(mainLoading: true);
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted || _refreshing) {
        return;
      }

      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _requestVersion++;

    _refreshTimer?.cancel();

    super.dispose();
  }

  // ============================================================
  // API LOAD
  // ============================================================

  Future<void> _load({bool silent = false, bool mainLoading = false}) async {
    if (!mounted) return;

    final requestVersion = ++_requestVersion;

    final fac = widget.facId.trim().isEmpty ? 'KVH' : widget.facId.trim();

    final month = widget.month.trim();

    if (month.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Month is required';
      });

      return;
    }

    if (!silent) {
      setState(() {
        if (mainLoading || _data == null) {
          _loading = true;
        } else {
          _refreshing = true;
        }

        _error = null;
      });
    } else {
      setState(() {
        _refreshing = true;
      });
    }

    try {
      final response = await _dio.get<dynamic>(
        '/api/solar/detail',
        queryParameters: {'facId': fac, 'month': month},
      );

      if (response.data is! Map) {
        throw const FormatException('Invalid Solar API response');
      }

      final result = SolarDetailData.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );

      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _data = result;

        _loading = false;
        _refreshing = false;

        _error = null;
      });
    } on DioException catch (e) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _loading = false;
        _refreshing = false;

        _error = _dioError(e);
      });
    } catch (e) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _loading = false;
        _refreshing = false;

        _error = 'Cannot load Solar Detail';
      });
    }
  }

  String _dioError(DioException error) {
    final code = error.response?.statusCode;

    if (code != null) {
      return 'Solar API error: HTTP $code';
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Solar API timeout';
    }

    return 'Cannot connect to Solar API';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _background()),

            Column(
              children: [
                _header(),

                Expanded(child: _body()),
              ],
            ),

            if (_refreshing)
              const Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: _cyan,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _background() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.4,
          colors: [Color(0xff07263d), Color(0xff020b15)],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xff03111d).withOpacity(.95),
        border: Border(bottom: BorderSide(color: _cyan.withOpacity(.15))),
      ),
      child: Row(
        children: [
          _backButton(),

          const SizedBox(width: 20),

          const Text(
            'SOLAR ENERGY ANALYTICS',
            style: TextStyle(
              color: _yellow,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: .6,
            ),
          ),

          const Spacer(),

          MonthLabelBadge(monthLabel: widget.month),

          const SizedBox(width: 10),

          _facilityBadge(),

          const SizedBox(width: 10),

          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshing ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded, color: _cyan),
          ),
        ],
      ),
    );
  }

  Widget _backButton() {
    return InkWell(
      onTap: () => Navigator.of(context).pop(),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _cyan.withOpacity(.25)),
        ),
        child: const Row(
          children: [
            Icon(Icons.arrow_back_rounded, color: _cyan, size: 18),
            SizedBox(width: 6),
            Text(
              'BACK',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _facilityBadge() {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _cyan.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cyan.withOpacity(.35)),
      ),
      alignment: Alignment.center,
      child: Text(
        widget.facId.toUpperCase(),
        style: const TextStyle(
          color: _cyan,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _body() {
    if (_loading && _data == null) {
      return const Center(child: CircularProgressIndicator(color: _cyan));
    }

    if (_error != null && _data == null) {
      return _errorView();
    }

    final data = _data;

    if (data == null) {
      return _errorView();
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // =========================================================
          // TOP KPI
          // =========================================================
          SizedBox(height: 120, child: _compactKpiSection(data)),

          const SizedBox(height: 7),

          // =========================================================
          // MIDDLE
          //
          // Monthly trend + Energy source
          // =========================================================
          Expanded(
            flex: 58,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 7, child: _compactDailyGenerationPanel(data)),

                const SizedBox(width: 7),

                Expanded(flex: 3, child: _compactEnergySourcePanel(data)),
              ],
            ),
          ),

          const SizedBox(height: 7),

          // =========================================================
          // BOTTOM
          //
          // Hourly + Cost/Environment
          // =========================================================
          Expanded(
            flex: 42,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 6, child: _compactHourlyPanel(data)),

                const SizedBox(width: 7),

                Expanded(flex: 4, child: _compactImpactPanel(data)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // KPI
  // ============================================================
  Widget _compactKpiSection(SolarDetailData data) {
    final s = data.summary;
    final cost = data.costImpact;
    final env = data.environmentalImpact;

    return Row(
      children: [
        Expanded(
          child: _compactKpi(
            title: 'CURRENT POWER',
            value: '${_formatNumber(s.currentPowerKw)} kW',
            icon: Icons.wb_sunny_rounded,
            color: _yellow,
            note: 'LIVE',
          ),
        ),

        const SizedBox(width: 5),

        Expanded(
          child: _compactKpi(
            title: 'SOLAR ENERGY',
            value: _formatEnergy(s.solarKwh),
            icon: Icons.solar_power_rounded,
            color: _yellow,
            note: 'MONTH',
          ),
        ),

        const SizedBox(width: 5),

        Expanded(
          child: _compactKpi(
            title: 'GRID ENERGY',
            value: _formatEnergy(s.gridKwh),
            icon: Icons.electric_bolt_rounded,
            color: _cyan,
            note: 'MONTH',
          ),
        ),

        const SizedBox(width: 5),

        // =========================================================
        // NEW
        // =========================================================
        Expanded(
          child: _compactKpi(
            title: 'TOTAL ENERGY',
            value: _formatEnergy(s.totalKwh),
            icon: Icons.energy_savings_leaf_rounded,
            color: Colors.white70,
            note: 'SOLAR + GRID',
          ),
        ),

        const SizedBox(width: 5),

        Expanded(
          child: _compactKpi(
            title: 'SOLAR SHARE',
            value: '${s.solarSharePercent.toStringAsFixed(1)}%',
            icon: Icons.pie_chart_rounded,
            color: _yellow,
            note: 'SOLAR / TOTAL',
          ),
        ),

        const SizedBox(width: 5),

        Expanded(
          child: _compactKpi(
            title: 'SOLAR COST',
            value: '\$${_money(cost.solarCostUsd)}',
            icon: Icons.attach_money_rounded,
            color: _green,
            note: 'RATE × 83%',
          ),
        ),

        const SizedBox(width: 5),

        Expanded(
          child: _compactKpi(
            title: 'SAVING',
            value: '\$${_money(cost.savingUsd)}',
            icon: Icons.savings_rounded,
            color: _green,
            note: '${cost.savingPercent.toStringAsFixed(0)}%',
          ),
        ),

        const SizedBox(width: 5),

        Expanded(
          child: _compactKpi(
            title: 'CO₂ AVOIDED',
            value: '${env.co2Ton.toStringAsFixed(1)} ton',
            icon: Icons.eco_rounded,
            color: _green,
            note: '${_compact(env.equivalentTrees)} trees',
          ),
        ),
      ],
    );
  }

  Widget _compactKpi({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? note,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(.08),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(.25)),
            ),
            child: Icon(icon, color: color, size: 21),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 4),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),

                if (note != null) ...[
                  const SizedBox(height: 2),

                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DAILY GENERATION
  // ============================================================
  Widget _compactDailyGenerationPanel(SolarDetailData data) {
    return _panel(
      title:
          'MONTHLY ENERGY TREND • ${_monthLabel(widget.month).toUpperCase()}',
      titleColor: _yellow,

      child: Expanded(
        child: SfCartesianChart(
          margin: EdgeInsets.zero,
          plotAreaBorderWidth: 0,

          // =========================================================
          // LEGEND
          // =========================================================
          legend: const Legend(
            isVisible: true,
            position: LegendPosition.top,
            alignment: ChartAlignment.center,
            textStyle: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),

          // =========================================================
          // TOOLTIP
          // =========================================================
          tooltipBehavior: TooltipBehavior(
            enable: true,
            shared: true,
            canShowMarker: true,
          ),

          // =========================================================
          // X AXIS
          // =========================================================
          primaryXAxis: DateTimeAxis(
            dateFormat: DateFormat('dd'),

            intervalType: DateTimeIntervalType.days,

            interval: 1,

            majorGridLines: const MajorGridLines(width: 0),

            axisLine: AxisLine(color: Colors.white.withOpacity(.20)),

            majorTickLines: const MajorTickLines(size: 0),

            labelStyle: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),

          // =========================================================
          // Y AXIS
          // =========================================================
          primaryYAxis: NumericAxis(
            minimum: 0,

            numberFormat: NumberFormat.compact(),

            majorGridLines: MajorGridLines(
              color: Colors.white.withOpacity(.06),
              width: 1,
            ),

            axisLine: const AxisLine(width: 0),

            majorTickLines: const MajorTickLines(size: 0),

            labelStyle: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),

          // =========================================================
          // STACKED COLUMN
          //
          // GRID + SOLAR = TOTAL
          // =========================================================
          series: <CartesianSeries<SolarDailyTrend, DateTime>>[
            // ============================================================
            // GRID - PHẦN DƯỚI
            // ============================================================
            StackedColumnSeries<SolarDailyTrend, DateTime>(
              name: 'Grid',
              dataSource: data.dailyTrend,

              xValueMapper: (e, _) => e.date,
              yValueMapper: (e, _) => e.gridKwh,

              color: _cyan,

              width: 0.65,
              spacing: 0.10,

              enableTooltip: true,

              // ============================
              // HIỂN THỊ VALUE
              // ============================
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                labelAlignment: ChartDataLabelAlignment.middle,
                textStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),

              dataLabelMapper: (e, _) {
                return _chartValue(e.gridKwh);
              },
            ),

            // ============================================================
            // SOLAR - PHẦN TRÊN
            // ============================================================
            StackedColumnSeries<SolarDailyTrend, DateTime>(
              name: 'Solar',
              dataSource: data.dailyTrend,

              xValueMapper: (e, _) => e.date,
              yValueMapper: (e, _) => e.solarKwh,

              color: _yellow,

              width: 0.65,
              spacing: 0.10,

              enableTooltip: true,

              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),

              // ============================
              // HIỂN THỊ VALUE
              // ============================
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                labelAlignment: ChartDataLabelAlignment.middle,
                textStyle: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),

              dataLabelMapper: (e, _) {
                return _chartValue(e.solarKwh);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _chartValue(num value) {
    if (value == 0) {
      return '';
    }

    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    return value.toStringAsFixed(0);
  }

  // ============================================================
  // ENERGY SOURCE
  // ============================================================

  Widget _compactEnergySourcePanel(SolarDetailData data) {
    final s = data.summary;

    final pie = [
      _PieData('Solar', s.solarKwh, _yellow),
      _PieData('Grid', s.gridKwh, _cyan),
    ];

    return _panel(
      title: 'ENERGY SOURCE',
      titleColor: _yellow,
      child: Expanded(
        child: Row(
          children: [
            Expanded(
              child: SfCircularChart(
                margin: EdgeInsets.zero,

                series: <CircularSeries<_PieData, String>>[
                  DoughnutSeries<_PieData, String>(
                    dataSource: pie,
                    xValueMapper: (e, _) => e.name,
                    yValueMapper: (e, _) => e.value,
                    pointColorMapper: (e, _) => e.color,
                    innerRadius: '68%',
                    radius: '88%',
                  ),
                ],

                annotations: [
                  CircularChartAnnotation(
                    widget: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${s.solarSharePercent.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: _yellow,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const Text(
                          'SOLAR',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _miniSourceRow('Solar', _formatEnergy(s.solarKwh), _yellow),

                  const SizedBox(height: 8),

                  _miniSourceRow('Main', _formatEnergy(s.gridKwh), _cyan),

                  const SizedBox(height: 8),

                  _miniSourceRow(
                    'Total',
                    _formatEnergy(s.totalKwh),
                    Colors.white70,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniSourceRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),

        const SizedBox(width: 6),

        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ),

        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _compactHourlyPanel(SolarDetailData data) {
    final hourly = data.hourlyProfile;

    return _panel(
      title:
          'HOURLY SOLAR PROFILE • '
          '${DateFormat('dd MMM yyyy').format(hourly.date)}',
      titleColor: _yellow,
      child: Expanded(
        child: Row(
          children: [
            SizedBox(
              width: 135,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _smallMetric('ENERGY', _formatEnergy(hourly.totalEnergyKwh)),

                  _smallMetric(
                    'PEAK',
                    '${_formatNumber(hourly.peakEnergyKwh)} kWh',
                  ),

                  _smallMetric(
                    'PEAK HOUR',
                    hourly.peakHour == null
                        ? '-'
                        : '${hourly.peakHour!.toString().padLeft(2, '0')}:00',
                  ),
                ],
              ),
            ),

            Expanded(
              child: SfCartesianChart(
                margin: EdgeInsets.zero,
                plotAreaBorderWidth: 0,

                primaryXAxis: NumericAxis(
                  minimum: 0,
                  maximum: 23,
                  interval: 3,
                  labelFormat: '{value}:00',
                  majorGridLines: MajorGridLines(
                    color: Colors.white.withOpacity(.03),
                  ),
                  labelStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                ),

                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.compact(),
                  majorGridLines: MajorGridLines(
                    color: Colors.white.withOpacity(.05),
                  ),
                  labelStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                  ),
                ),

                tooltipBehavior: TooltipBehavior(enable: true),

                series: <CartesianSeries<SolarHourlyPoint, int>>[
                  ColumnSeries<SolarHourlyPoint, int>(
                    name: 'Solar',
                    dataSource: hourly.points,

                    xValueMapper: (e, _) => e.hour,

                    yValueMapper: (e, _) => e.energyKwh,

                    color: _yellow,

                    width: 0.65,

                    spacing: 0.15,

                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),

          const SizedBox(height: 2),

          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COST IMPACT
  // ============================================================

  Widget _compactImpactPanel(SolarDetailData data) {
    final cost = data.costImpact;
    final env = data.environmentalImpact;

    return _panel(
      title: 'COST & ENVIRONMENT • ${_monthLabel(widget.month).toUpperCase()}',
      titleColor: _green,
      child: Expanded(
        child: Column(
          children: [
            // =====================================================
            // COST
            // =====================================================
            Expanded(
              flex: 6,
              child: Row(
                children: [
                  Expanded(
                    child: _miniImpactValue(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'NORMAL COST',
                      value: '\$${_money(cost.normalCostUsd)}',
                      color: _cyan,
                      note: 'EVN × 100%',
                    ),
                  ),

                  const SizedBox(width: 6),

                  Expanded(
                    child: _miniImpactValue(
                      icon: Icons.solar_power_rounded,
                      title: 'SOLAR COST',
                      value: '\$${_money(cost.solarCostUsd)}',
                      color: _yellow,
                      note: 'EVN × 83%',
                    ),
                  ),

                  const SizedBox(width: 6),

                  Expanded(
                    child: _miniImpactValue(
                      icon: Icons.savings_rounded,
                      title: 'SAVING',
                      value: '\$${_money(cost.savingUsd)}',
                      color: _green,
                      note: '${cost.savingPercent.toStringAsFixed(0)}%',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            Divider(height: 1, color: Colors.white.withOpacity(.08)),

            const SizedBox(height: 5),

            // =====================================================
            // ENVIRONMENT
            // =====================================================
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Expanded(
                    child: _impactEnvironment(
                      icon: Icons.eco_rounded,
                      title: 'CO₂ AVOIDED',
                      value: '${env.co2Ton.toStringAsFixed(2)} ton',
                    ),
                  ),

                  _verticalDivider(),

                  Expanded(
                    child: _impactEnvironment(
                      icon: Icons.park_rounded,
                      title: 'TREES',
                      value: _compact(env.equivalentTrees),
                    ),
                  ),

                  _verticalDivider(),

                  Expanded(
                    child: _impactEnvironment(
                      icon: Icons.science_outlined,
                      title: 'CO₂ FACTOR',
                      value: '${env.co2Factor}',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            Container(
              height: 25,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: _green.withOpacity(.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _green.withOpacity(.13)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 22,
                    color: Colors.white38,
                  ),

                  const SizedBox(width: 5),

                  const Expanded(
                    child: Text(
                      'Solar electricity rate = EVN tariff × 83%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),

                  Text(
                    'SAVE ${cost.savingPercent.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: _green,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniImpactValue({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? note,
  }) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: color.withOpacity(.035),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),

          const SizedBox(height: 3),

          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 3),

          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          if (note != null)
            Text(
              note,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _impactEnvironment({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: _green, size: 22),

        const SizedBox(height: 2),

        Text(
          title,
          style: const TextStyle(
            color: _green,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 2),

        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: Colors.white.withOpacity(.08),
    );
  }

  // ============================================================
  // PANEL
  // ============================================================

  Widget _panel({
    required String title,
    required Color titleColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: titleColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: .2,
            ),
          ),

          const SizedBox(height: 5),

          child,
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: _panel2.withOpacity(.92),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border.withOpacity(.8)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.35),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Colors.redAccent,
            size: 38,
          ),

          const SizedBox(height: 10),

          Text(
            _error ?? 'No Solar data',
            style: const TextStyle(color: Colors.white70),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: () => _load(mainLoading: true),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reload'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FORMAT
  // ============================================================

  String _monthLabel(String value) {
    if (value.length != 6) {
      return value;
    }

    final year = int.tryParse(value.substring(0, 4));

    final month = int.tryParse(value.substring(4, 6));

    if (year == null || month == null || month < 1 || month > 12) {
      return value;
    }

    return DateFormat('MMM yyyy').format(DateTime(year, month));
  }

  String _formatNumber(double value) {
    return NumberFormat('#,##0.0').format(value);
  }

  String _formatEnergy(double kwh) {
    if (kwh >= 1000) {
      return '${(kwh / 1000).toStringAsFixed(1)} MWh';
    }

    return '${kwh.toStringAsFixed(1)} kWh';
  }

  String _money(double value) {
    return NumberFormat('#,##0.00').format(value);
  }

  String _vnd(double value) {
    return NumberFormat('#,##0').format(value);
  }

  String _compact(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    return value.toStringAsFixed(0);
  }
}

// ============================================================================
// API MODEL
// ============================================================================

class SolarDetailData {
  final String facId;

  final String month;

  final DateTime? generatedAt;

  final SolarDetailSummary summary;

  final List<SolarDailyTrend> dailyTrend;

  final SolarCostImpact costImpact;

  final SolarEnvironmentalImpact environmentalImpact;

  final SolarHourlyProfile hourlyProfile;

  const SolarDetailData({
    required this.facId,
    required this.month,
    required this.generatedAt,
    required this.summary,
    required this.dailyTrend,
    required this.costImpact,
    required this.environmentalImpact,
    required this.hourlyProfile,
  });

  factory SolarDetailData.fromJson(Map<String, dynamic> json) {
    final dailyRaw = json['dailyTrend'];

    return SolarDetailData(
      facId: json['facId']?.toString() ?? '',
      month: json['month']?.toString() ?? '',
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? ''),
      summary: SolarDetailSummary.fromJson(_map(json['summary'])),
      dailyTrend: dailyRaw is List
          ? dailyRaw
                .whereType<Map>()
                .map(
                  (e) => SolarDailyTrend.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList(growable: false)
          : const [],
      costImpact: SolarCostImpact.fromJson(_map(json['costImpact'])),
      environmentalImpact: SolarEnvironmentalImpact.fromJson(
        _map(json['environmentalImpact']),
      ),
      hourlyProfile: SolarHourlyProfile.fromJson(_map(json['hourlyProfile'])),
    );
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const {};
  }
}

// ============================================================================
// SUMMARY
// ============================================================================

class SolarDetailSummary {
  final double currentPowerKw;

  final double solarKwh;

  final double gridKwh;

  final double totalKwh;

  final double solarSharePercent;

  const SolarDetailSummary({
    required this.currentPowerKw,
    required this.solarKwh,
    required this.gridKwh,
    required this.totalKwh,
    required this.solarSharePercent,
  });

  factory SolarDetailSummary.fromJson(Map<String, dynamic> json) {
    return SolarDetailSummary(
      currentPowerKw: _num(json['currentPowerKw']),
      solarKwh: _num(json['solarKwh']),
      gridKwh: _num(json['gridKwh']),
      totalKwh: _num(json['totalKwh']),
      solarSharePercent: _num(json['solarSharePercent']),
    );
  }
}

// ============================================================================
// DAILY
// ============================================================================

class SolarDailyTrend {
  final DateTime date;

  final double solarKwh;

  final double gridKwh;

  final double totalKwh;

  final double solarSharePercent;

  const SolarDailyTrend({
    required this.date,
    required this.solarKwh,
    required this.gridKwh,
    required this.totalKwh,
    required this.solarSharePercent,
  });

  factory SolarDailyTrend.fromJson(Map<String, dynamic> json) {
    return SolarDailyTrend(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime(2000),
      solarKwh: _num(json['solarKwh']),
      gridKwh: _num(json['gridKwh']),
      totalKwh: _num(json['totalKwh']),
      solarSharePercent: _num(json['solarSharePercent']),
    );
  }
}

// ============================================================================
// COST
// ============================================================================

class SolarCostImpact {
  final double solarEnergyKwh;

  final double normalCostVnd;

  final double solarCostVnd;

  final double savingVnd;

  final double normalCostUsd;

  final double solarCostUsd;

  final double savingUsd;

  final double savingPercent;

  const SolarCostImpact({
    required this.solarEnergyKwh,
    required this.normalCostVnd,
    required this.solarCostVnd,
    required this.savingVnd,
    required this.normalCostUsd,
    required this.solarCostUsd,
    required this.savingUsd,
    required this.savingPercent,
  });

  factory SolarCostImpact.fromJson(Map<String, dynamic> json) {
    return SolarCostImpact(
      solarEnergyKwh: _num(json['solarEnergyKwh']),
      normalCostVnd: _num(json['normalCostVnd']),
      solarCostVnd: _num(json['solarCostVnd']),
      savingVnd: _num(json['savingVnd']),
      normalCostUsd: _num(json['normalCostUsd']),
      solarCostUsd: _num(json['solarCostUsd']),
      savingUsd: _num(json['savingUsd']),
      savingPercent: _num(json['savingPercent']),
    );
  }
}

// ============================================================================
// ENVIRONMENT
// ============================================================================

class SolarEnvironmentalImpact {
  final double co2Kg;

  final double co2Ton;

  final double equivalentTrees;

  final double co2Factor;

  const SolarEnvironmentalImpact({
    required this.co2Kg,
    required this.co2Ton,
    required this.equivalentTrees,
    required this.co2Factor,
  });

  factory SolarEnvironmentalImpact.fromJson(Map<String, dynamic> json) {
    return SolarEnvironmentalImpact(
      co2Kg: _num(json['co2Kg']),
      co2Ton: _num(json['co2Ton']),
      equivalentTrees: _num(json['equivalentTrees']),
      co2Factor: _num(json['co2Factor']),
    );
  }
}

// ============================================================================
// HOURLY
// ============================================================================

class SolarHourlyProfile {
  final DateTime date;

  final double totalEnergyKwh;

  final double peakEnergyKwh;

  final int? peakHour;

  final List<SolarHourlyPoint> points;

  const SolarHourlyProfile({
    required this.date,
    required this.totalEnergyKwh,
    required this.peakEnergyKwh,
    required this.peakHour,
    required this.points,
  });

  factory SolarHourlyProfile.fromJson(Map<String, dynamic> json) {
    final raw = json['points'];

    return SolarHourlyProfile(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      totalEnergyKwh: _num(json['totalEnergyKwh']),
      peakEnergyKwh: _num(json['peakEnergyKwh']),
      peakHour: _intOrNull(json['peakHour']),
      points: raw is List
          ? raw
                .whereType<Map>()
                .map(
                  (e) =>
                      SolarHourlyPoint.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

class SolarHourlyPoint {
  final int hour;

  final double energyKwh;

  const SolarHourlyPoint({required this.hour, required this.energyKwh});

  factory SolarHourlyPoint.fromJson(Map<String, dynamic> json) {
    return SolarHourlyPoint(
      hour: _intOrNull(json['hour']) ?? 0,
      energyKwh: _num(json['energyKwh']),
    );
  }
}

// ============================================================================
// PIE
// ============================================================================

class _PieData {
  final String name;

  final double value;

  final Color color;

  const _PieData(this.name, this.value, this.color);
}

// ============================================================================
// JSON HELPERS
// ============================================================================

double _num(dynamic value) {
  if (value == null) {
    return 0;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString()) ?? 0;
}

int? _intOrNull(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value.toString());
}
