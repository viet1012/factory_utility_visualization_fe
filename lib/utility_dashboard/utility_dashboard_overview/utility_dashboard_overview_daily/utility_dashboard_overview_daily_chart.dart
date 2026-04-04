import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_common/data_health.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../../utility_dashboard_common/utility_fac_style.dart';
import '../utility_dashboard_overview_api/utility_dashboard_overview_api.dart';
import '../utility_dashboard_overview_widgets/health_indicator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DTOs
// ─────────────────────────────────────────────────────────────────────────────

class _DailyDto {
  final DateTime date;
  final double value;

  _DailyDto(this.date, this.value);

  factory _DailyDto.fromJson(Map<String, dynamic> json) {
    final d = (json['date'] ?? '').toString();
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

// ─────────────────────────────────────────────────────────────────────────────
// Pre-computed chart data — tính một lần, cache lại
// ─────────────────────────────────────────────────────────────────────────────

class _DailyChartData {
  final List<_BarPoint> points;
  final DateTime minX;
  final DateTime maxX;
  final double safeMaxY;

  const _DailyChartData({
    required this.points,
    required this.minX,
    required this.maxX,
    required this.safeMaxY,
  });

  static _DailyChartData from(List<_DailyDto> rows, String month) {
    final pts = rows.map((e) => _BarPoint(e.date.toLocal(), e.value)).toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));

    final maxY = pts.isEmpty
        ? 1.0
        : pts.map((e) => e.y).reduce((m, v) => v > m ? v : m);

    // ✅ Parse month (yyyyMM) để tính full tháng
    final year = int.parse(month.substring(0, 4));
    final monthNum = int.parse(month.substring(4, 6));

    // ✅ Ngày đầu tháng
    final firstDay = DateTime(year, monthNum, 1);

    // ✅ Ngày cuối tháng (ngày đầu tháng sau - 1 ngày)
    final lastDay = DateTime(
      year,
      monthNum + 1,
      1,
    ).subtract(const Duration(days: 1));

    // ✅ PADDING: Thêm 0.5 ngày trước để không bị cắt
    final paddedMinX = firstDay.subtract(const Duration(hours: 12));
    final paddedMaxX = lastDay.add(const Duration(hours: 12));

    return _DailyChartData(
      points: pts,
      minX: paddedMinX, // ✅ Bắt đầu hôm trước ngày 1
      maxX: paddedMaxX, // ✅ Kết thúc hôm sau ngày cuối
      safeMaxY: maxY <= 0 ? 1.0 : maxY * 1.15,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StatefulWidget
// ─────────────────────────────────────────────────────────────────────────────

class UtilityDashboardOverviewDailyChart extends StatefulWidget {
  final double width;
  final double? height;
  final String facId;
  final String month; // yyyyMM
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
  late final UtilityInfoBoxFx fx;

  List<_DailyDto> rows = [];
  bool loading = true;
  Object? error;

  // ── Cache — không tính lại trong build() ─────────────────────────────────
  DataHealthResult? _cachedHealth;
  _DailyChartData? _cachedChartData;
  String? _cachedLastVal;
  String? _cachedLastTs;

  bool _loadingNow = false;
  bool _disposed = false;

  bool get _hasRequired =>
      widget.facId.trim().isNotEmpty &&
      widget.month.trim().isNotEmpty &&
      RegExp(r'^\d{6}$').hasMatch(widget.month.trim());

  @override
  void initState() {
    super.initState();
    fx = UtilityInfoBoxFx(this)..init();
    _load();
  }

  @override
  void didUpdateWidget(covariant UtilityDashboardOverviewDailyChart old) {
    super.didUpdateWidget(old);
    if (old.facId == widget.facId && old.month == widget.month) return;

    setState(() {
      loading = true;
      error = null;
      rows = [];
      _cachedHealth = null;
      _cachedChartData = null;
      _cachedLastVal = null;
      _cachedLastTs = null;
    });

    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    fx.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loadingNow || _disposed) return;

    if (!_hasRequired) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Missing/invalid facId or month(yyyyMM)';
        rows = [];
      });
      return;
    }

    _loadingNow = true;

    try {
      final api = context.read<UtilityDashboardOverviewApi>();
      final res = await api.getEnergyDaily(
        facId: widget.facId,
        month: widget.month,
        nameEn: widget.nameEng,
      );

      final list =
          res
              .map((e) => _DailyDto.fromJson(Map<String, dynamic>.from(e)))
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));

      if (!mounted) return;

      // Chỉ rebuild khi data thực sự thay đổi
      if (_dataChanged(list)) {
        _recomputeCache(list);
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
      Future.delayed(const Duration(minutes: 60), _load);
    }
  }

  bool _dataChanged(List<_DailyDto> next) {
    if (next.length != rows.length) return true;
    for (var i = 0; i < next.length; i++) {
      if (next[i].value != rows[i].value || next[i].date != rows[i].date)
        return true;
    }
    return false;
  }

  // Tính toàn bộ derived data một lần, lưu vào cache
  void _recomputeCache(List<_DailyDto> list) {
    _cachedHealth = DataHealthAnalyzer.analyze(
      key: "Daily_${widget.facId}_${widget.theme.title}",
      loading: false,
      error: null,
      values: list.map((e) => e.value).toList(),
    );

    // ✅ Pass month vào để tính full tháng
    _cachedChartData = list.isEmpty
        ? null
        : _DailyChartData.from(list, widget.month);

    // lastVal / lastTs
    if (list.isEmpty) {
      _cachedLastVal = '--';
      _cachedLastTs = '--';
    } else {
      final now = DateTime.now();
      final isCurrentMonth = DateFormat('yyyyMM').format(now) == widget.month;

      _DailyDto lastDto;
      if (isCurrentMonth) {
        final today = DateTime(now.year, now.month, now.day);
        lastDto = list.firstWhere(
          (e) =>
              e.date.year == today.year &&
              e.date.month == today.month &&
              e.date.day == today.day,
          orElse: () => list.last,
        );
      } else {
        lastDto = list.last;
      }

      _cachedLastVal =
          '${lastDto.value.toStringAsFixed(1)} ${widget.theme.unit}';
      _cachedLastTs = DateFormat('yyyy-MM-dd').format(lastDto.date);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build — chỉ layout + animation shell, chart KHÔNG rebuild theo animation
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final facilityColor = UtilityFacStyle.colorFromFac(widget.facId);

    final healthResult =
        _cachedHealth ??
        DataHealthAnalyzer.analyze(
          key: "Daily_${widget.facId}_${widget.theme.title}",
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
          // ⭐ child ở đây KHÔNG rebuild theo animation frame
          builder: (context, child) =>
              Transform.scale(scale: fx.scale.value, child: child),
          child: _Shell(
            width: widget.width,
            height: widget.height ?? 320,
            facilityColor: facilityColor,
            child: _Body(
              theme: widget.theme,
              hasRequired: _hasRequired,
              loading: loading,
              error: error,
              rows: rows,
              health: healthResult,
              lastVal: _cachedLastVal ?? '--',
              lastTs: _cachedLastTs ?? '--',
              chartData: _cachedChartData,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Shell — decoration container, tách ra để không drag chart vào rebuild
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// _Body — layout + title bar, nhận chart data từ ngoài
// ─────────────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final ChartTheme theme;
  final bool hasRequired;
  final bool loading;
  final Object? error;
  final List<_DailyDto> rows;
  final DataHealthResult health;
  final String lastVal;
  final String lastTs;
  final _DailyChartData? chartData;

  const _Body({
    required this.theme,
    required this.hasRequired,
    required this.loading,
    required this.error,
    required this.rows,
    required this.health,
    required this.lastVal,
    required this.lastTs,
    required this.chartData,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasRequired) {
      return Center(
        child: Text(
          'Missing facId or month(yyyyMM)',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
      );
    }

    if (loading && rows.isEmpty) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TitleBar(
          theme: theme,
          health: health,
          lastVal: lastVal,
          lastTs: lastTs,
        ),
        const SizedBox(height: 6),
        rows.isEmpty
            ? Expanded(
                child: Center(
                  child: Text(
                    'No data available',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 20,
                    ),
                  ),
                ),
              )
            : Expanded(
                // RepaintBoundary: chart có GPU layer riêng
                // parent repaint (hover glow, border...) không kéo chart theo
                child: RepaintBoundary(
                  child: _DailyBarChart(theme: theme, data: chartData!),
                ),
              ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TitleBar — StatelessWidget, rebuild độc lập với chart
// ─────────────────────────────────────────────────────────────────────────────

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
          Text(
            theme.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.all(8),
            child: HealthIndicator(
              result: health,
              size: 10,
              showLabel: false,
              enableTooltip: true,
            ),
          ),
          const SizedBox(width: 8),
          const Spacer(),
          Expanded(
            child: Text(
              'Last: $lastVal • $lastTs',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DailyBarChart — StatelessWidget thuần, KHÔNG bao giờ rebuild trừ khi
// chartData hoặc theme thay đổi thực sự
// ─────────────────────────────────────────────────────────────────────────────

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
        // ✅ Chỉ hiển thị ngày
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(0.08),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(0.15), width: 1),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.75),
          fontSize: 13,
        ),
        // ✅ Padding để label không bị cắt
        labelPosition: ChartDataLabelPosition.outside,
        // ✅ Thêm margin cho trục X
        edgeLabelPlacement: EdgeLabelPlacement.hide, // Ẩn label ở tepi
      ),
      primaryYAxis: NumericAxis(
        minimum: 0,
        maximum: data.safeMaxY,
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
