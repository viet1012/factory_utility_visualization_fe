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

  // `_activeRequestId != null` nghĩa là có 1 request đang bay.
  // requestId tăng dần mỗi lần gọi, dùng để chỉ áp response mới nhất vào UI —
  // đồng bộ pattern với MonthlySummaryScreen.
  int? _activeRequestId;
  int _requestSeq = 0;

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    fx = UtilityInfoBoxFx(this)..init();

    unawaited(_load());
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();

    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted || _activeRequestId != null) return;
      unawaited(_load(silent: true));
    });
  }

  /// Gọi API thuần, không đụng setState/mounted — dễ test độc lập.
  Future<List<MinutePointDto>> _fetchMinuteData({
    required String facId,
    required int minutes,
    required String? nameEn,
    required String utilityType,
  }) async {
    final api = context.read<UtilityDashboardOverviewApi>();

    return api
        .getEnergyMinute(
          facId: facId,
          minutes: minutes,
          nameEn: nameEn,
          utilityType: utilityType,
        )
        .timeout(_requestTimeout);
  }

  Future<void> _load({bool silent = false, bool force = false}) async {
    if (!mounted) return;

    // Có request khác đang chạy và không force -> bỏ qua (không "nuốt" mất
    // yêu cầu vĩnh viễn: caller có force=true, ví dụ didUpdateWidget, vẫn
    // luôn tạo được request mới, không phụ thuộc request cũ đã xong hay chưa).
    if (_activeRequestId != null && !force) return;

    final requestId = ++_requestSeq;
    _activeRequestId = requestId;

    final requestFacId = widget.facId;
    final requestMinutes = widget.minutes;
    final requestNameEn = widget.nameEn;
    final requestUtilityType = widget.utilityType;

    if (!silent && rows.isEmpty) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final data = await _fetchMinuteData(
        facId: requestFacId,
        minutes: requestMinutes,
        nameEn: requestNameEn,
        utilityType: requestUtilityType,
      );

      if (!mounted) return;

      // Chỉ request mới nhất mới được phép áp vào UI — chặn trường hợp
      // response cũ (facId/minutes/nameEn trước đó) về trễ hơn response mới.
      if (_activeRequestId != requestId) return;

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
      _handleLoadError(e, '[TIMEOUT]', requestId);
    } on DioException catch (e) {
      _handleLoadError(e, '[DIO] ${e.type}', requestId);
    } catch (e) {
      _handleLoadError(e, '[ERROR]', requestId);
    } finally {
      if (_activeRequestId == requestId) {
        _activeRequestId = null;
      }
    }
  }

  void _handleLoadError(Object e, String tag, int requestId) {
    debugPrint('$tag $e');

    if (!mounted || _activeRequestId != requestId) return;

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

    // force: true — luôn tạo request mới cho tham số mới, kể cả khi 1 poll
    // cũ đang bay. Nhờ _requestId, response cũ (nếu về sau) sẽ tự bị bỏ qua.
    unawaited(_load(force: true));
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
      return ChartApiErrorState(
        color: widget.theme.line,
        onRetry: () => _load(force: true),
      );
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

  // Map<String, List<_ChartPoint>> _groupWaterPoints() {
  //   final data = rows
  //       .where((e) => e.value != null)
  //       .map(
  //         (e) => _ChartPoint(
  //           e.ts.toLocal(),
  //           e.value!,
  //           (e.nameEn == null || e.nameEn!.trim().isEmpty)
  //               ? 'Cooling tank'
  //               : e.nameEn!.trim(),
  //         ),
  //       )
  //       .toList();
  //
  //   final grouped = <String, List<_ChartPoint>>{};
  //
  //   for (final p in data) {
  //     grouped.putIfAbsent(p.nameEn, () => []).add(p);
  //   }
  //
  //   for (final item in grouped.values) {
  //     item.sort((a, b) => a.ts.compareTo(b.ts));
  //   }
  //
  //   return grouped;
  // }
  bool _isKvhFac() {
    final fac = widget.facId.trim().toUpperCase();

    return fac == 'KVH' || fac.contains('KVH');
  }

  String _waterName(String? nameEn) {
    final name = nameEn?.trim();

    if (name == null || name.isEmpty) {
      return 'Cooling tank';
    }

    return name;
  }

  DateTime _minuteKey(DateTime ts) {
    return DateTime(ts.year, ts.month, ts.day, ts.hour, ts.minute);
  }

  String _kvhSeriesName(String rawName) {
    // Ví dụ: "KVH - Tank 1" -> "KVH"
    if (rawName.contains('-')) {
      final prefix = rawName.split('-').first.trim();

      if (prefix.isNotEmpty) {
        return prefix;
      }
    }

    // Nếu API chỉ trả "Tank 1", "Tank 2" thì vẫn gom về KVH
    return widget.facId.trim().isEmpty ? 'KVH' : widget.facId.trim();
  }

  Map<String, List<_ChartPoint>> _groupWaterPoints() {
    final isKvh = _isKvhFac();

    // FAC A / B / C giữ nguyên: mỗi nameEn là 1 line riêng
    if (!isKvh) {
      final grouped = <String, List<_ChartPoint>>{};

      for (final e in rows.where((e) => e.value != null)) {
        final rawName = _waterName(e.nameEn);

        final point = _ChartPoint(e.ts.toLocal(), e.value!, rawName);

        grouped.putIfAbsent(rawName, () => <_ChartPoint>[]);
        grouped[rawName]!.add(point);
      }

      for (final item in grouped.values) {
        item.sort((a, b) => a.ts.compareTo(b.ts));
      }

      return grouped;
    }

    // KVH: gom nhiều tank lại thành 1 series, cùng phút thì lấy trung bình
    final bucket = <String, Map<DateTime, List<double>>>{};

    for (final e in rows.where((e) => e.value != null)) {
      final rawName = _waterName(e.nameEn);
      final seriesName = _kvhSeriesName(rawName);

      final ts = _minuteKey(e.ts.toLocal());

      bucket.putIfAbsent(seriesName, () => <DateTime, List<double>>{});
      bucket[seriesName]!.putIfAbsent(ts, () => <double>[]);
      bucket[seriesName]![ts]!.add(e.value!);
    }

    final grouped = <String, List<_ChartPoint>>{};

    for (final entry in bucket.entries) {
      final seriesName = entry.key;

      final points = entry.value.entries.map((timeEntry) {
        final values = timeEntry.value;
        final avg = values.reduce((a, b) => a + b) / values.length;

        return _ChartPoint(timeEntry.key, avg, seriesName);
      }).toList()..sort((a, b) => a.ts.compareTo(b.ts));

      grouped[seriesName] = points;
    }

    return grouped;
  }

  Widget _waterCleanChart() {
    final t = widget.theme;
    final rawGrouped = _groupWaterPoints();

    // Chuẩn hóa tên series và loại bỏ group rỗng.
    // Fac_A và "Fac_A " sẽ được gom chung.
    final grouped = <String, List<_ChartPoint>>{};

    for (final entry in rawGrouped.entries) {
      final seriesName = entry.key.trim();

      if (seriesName.isEmpty || entry.value.isEmpty) {
        continue;
      }

      grouped.putIfAbsent(seriesName, () => <_ChartPoint>[]);
      grouped[seriesName]!.addAll(entry.value);
    }

    // Sắp xếp điểm theo thời gian và loại trùng timestamp.
    for (final entry in grouped.entries) {
      final pointsByTime = <DateTime, _ChartPoint>{};

      for (final point in entry.value) {
        // Nếu cùng timestamp bị trùng, giữ bản ghi cuối.
        pointsByTime[point.ts] = point;
      }

      entry.value
        ..clear()
        ..addAll(pointsByTime.values)
        ..sort((a, b) => a.ts.compareTo(b.ts));
    }

    grouped.removeWhere((_, points) => points.isEmpty);

    final data = grouped.values.expand((points) => points).toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));

    debugPrint(
      'WATER GROUP COUNT = ${grouped.length}, '
      'NAMES = ${grouped.keys.toList()}',
    );

    if (data.length < 2 || grouped.isEmpty) {
      return const Center(
        child: Text(
          'Not enough points',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      );
    }

    final showLegend = grouped.length > 1;

    // Xếp hạng series theo giá trị trung bình.
    final rankedEntries = grouped.entries.toList()
      ..sort((a, b) {
        final avgA =
            a.value.fold<double>(0, (sum, point) => sum + point.y) /
            a.value.length;

        final avgB =
            b.value.fold<double>(0, (sum, point) => sum + point.y) /
            b.value.length;

        return avgB.compareTo(avgA);
      });

    final rankByName = <String, int>{};

    for (var i = 0; i < rankedEntries.length; i++) {
      rankByName[rankedEntries[i].key] = i;
    }

    // Tìm thời gian nhỏ nhất/lớn nhất trên toàn bộ dữ liệu.
    final minTs = data
        .map((point) => point.ts)
        .reduce((a, b) => a.isBefore(b) ? a : b);

    final maxTs = data
        .map((point) => point.ts)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    final ys = data.map((point) => point.y).toList()..sort();

    final minValue = ys.first;
    final maxValue = ys.last;
    final range = maxValue - minValue;

    final padding = max(range * 0.10, 0.2);
    final minY = minValue - padding;
    final maxY = maxValue + padding;
    final yInterval = max((maxY - minY) / 4, 0.1);

    return SfCartesianChart(
      key: ValueKey('water_${grouped.keys.join('|')}_${data.length}'),
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

      tooltipBehavior: TooltipBehavior(
        enable: true,
        header: '',
        format: 'point.x\nseries.name: point.y',
      ),

      primaryXAxis: DateTimeAxis(
        minimum: minTs,
        maximum: maxTs.add(const Duration(minutes: 2)),
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
        interval: yInterval,
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
            color: Colors.white.withOpacity(.8),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),

      // Chỉ tạo đúng 1 LineSeries cho mỗi FAC.
      series: grouped.entries.map((entry) {
        final seriesName = entry.key;
        final points = entry.value;
        final rank = rankByName[seriesName] ?? 0;

        final color = _seriesColorByRank(rank: rank, total: grouped.length);

        return LineSeries<_ChartPoint, DateTime>(
          name: seriesName,
          dataSource: points,
          xValueMapper: (point, _) => point.ts,
          yValueMapper: (point, _) => point.y,

          width: rank == 0 ? 3.0 : 2.0,
          color: color,

          markerSettings: const MarkerSettings(isVisible: false),

          // Chỉ hiển thị label tại điểm cuối.
          dataLabelMapper: (point, index) {
            final isLastPoint = index == points.length - 1;

            if (!isLastPoint) {
              return null;
            }

            return point.y.toStringAsFixed(1);
          },

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
      }).toList(),
    );
  }
}

class _ChartPoint {
  final DateTime ts;
  final double y;
  final String nameEn;

  _ChartPoint(this.ts, this.y, this.nameEn);
}
