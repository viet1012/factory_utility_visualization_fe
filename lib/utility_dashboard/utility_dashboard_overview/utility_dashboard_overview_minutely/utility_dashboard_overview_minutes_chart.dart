import 'dart:math';

import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_common/chart_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_dashboard_common/data_health.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../utility_dashboard_overview_models/utility_minute_dashboard_response.dart';
import '../utility_dashboard_overview_widgets/chart_state_widgets.dart';
import '../utility_dashboard_overview_widgets/common_chart_title_bar.dart';
import '../utility_dashboard_overview_widgets/scada_chart_panel.dart';

class UtilityStandardValues {
  const UtilityStandardValues._();

  // Thay lại theo tiêu chuẩn thực tế của nhà máy.
  static const double electricity = 100.0;
  static const double water = 35.0;
  static const double compressedAir = 6.0;

  static double byUtilityType(String utilityType) {
    final normalized = utilityType.trim().toUpperCase();

    if (normalized.contains('ELECTRIC')) {
      return electricity;
    }

    if (normalized.contains('WATER')) {
      return water;
    }

    if (normalized.contains('AIR') || normalized.contains('COMPRESSED')) {
      return compressedAir;
    }

    return 0;
  }
}

class UtilityDashboardOverviewMinutesChart extends StatefulWidget {
  final String facId;
  final String utilityType;
  final ChartTheme theme;

  final List<OverviewMinutePointDto> rows;
  final bool loading;
  final Object? error;

  final VoidCallback? onRetry;

  final double? height;
  final String? nameEn;

  const UtilityDashboardOverviewMinutesChart({
    super.key,
    required this.facId,
    required this.utilityType,
    required this.theme,
    required this.rows,
    required this.loading,
    required this.error,
    this.onRetry,
    this.height,
    this.nameEn,
  });

  @override
  State<UtilityDashboardOverviewMinutesChart> createState() =>
      _UtilityDashboardOverviewMinutesChartState();
}

class _UtilityDashboardOverviewMinutesChartState
    extends State<UtilityDashboardOverviewMinutesChart>
    with TickerProviderStateMixin {
  late final UtilityInfoBoxFx fx;

  DataHealthResult? _cachedHealth;

  List<OverviewMinutePointDto>? _cachedRowsReference;
  String? _cachedFacId;
  String? _cachedUtilityType;
  String? _cachedThemeTitle;
  bool? _cachedLoading;
  Object? _cachedError;

  _MainChartData? _mainChartData;
  _WaterChartData? _waterChartData;
  OverviewMinutePointDto? _headerPoint;

  List<OverviewMinutePointDto> get rows => widget.rows;

  bool get loading => widget.loading;

  Object? get error => widget.error;

  bool get _isWater => widget.utilityType.trim().toUpperCase() == 'WATER';

  bool get _isElectricity =>
      widget.utilityType.trim().toUpperCase() == 'ELECTRICITY';

  double get _standardValue {
    return UtilityStandardValues.byUtilityType(widget.utilityType);
  }

  @override
  void initState() {
    super.initState();

    fx = UtilityInfoBoxFx(this)..init();

    _prepareData();
  }

  @override
  void didUpdateWidget(
    covariant UtilityDashboardOverviewMinutesChart oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    final changed =
        !identical(oldWidget.rows, widget.rows) ||
        oldWidget.facId != widget.facId ||
        oldWidget.utilityType != widget.utilityType ||
        oldWidget.theme.title != widget.theme.title ||
        oldWidget.loading != widget.loading ||
        oldWidget.error != widget.error;

    if (changed) {
      _prepareData(force: true);
    }
  }

  void _prepareData({bool force = false}) {
    if (!force &&
        identical(_cachedRowsReference, widget.rows) &&
        _cachedFacId == widget.facId &&
        _cachedUtilityType == widget.utilityType &&
        _cachedThemeTitle == widget.theme.title &&
        _cachedLoading == widget.loading &&
        _cachedError == widget.error) {
      return;
    }

    _cachedRowsReference = widget.rows;
    _cachedFacId = widget.facId;
    _cachedUtilityType = widget.utilityType;
    _cachedThemeTitle = widget.theme.title;
    _cachedLoading = widget.loading;
    _cachedError = widget.error;

    final validRows = widget.rows
        .where(
          (item) =>
              item.value != null &&
              !item.value!.isNaN &&
              !item.value!.isInfinite,
        )
        .toList(growable: false);

    _headerPoint = null;

    for (final point in validRows) {
      final currentHeader = _headerPoint;

      if (currentHeader == null || point.value! > currentHeader.value!) {
        _headerPoint = point;
      }
    }

    _cachedHealth = DataHealthAnalyzer.analyze(
      key:
          'Minutes_${widget.facId}_${widget.theme.title}_${widget.utilityType}',
      loading: widget.loading,
      error: widget.error,
      values: validRows.map((item) => item.value!).toList(growable: false),
    );

    if (_isWater) {
      _mainChartData = null;
      _waterChartData = validRows.isEmpty
          ? null
          : _WaterChartData.from(
              rows: validRows,
              facId: widget.facId,
              standardValue: _standardValue,
            );
    } else {
      _waterChartData = null;
      _mainChartData = validRows.isEmpty
          ? null
          : _MainChartData.from(
              rows: validRows,
              utilityType: widget.utilityType,
              standardValue: _standardValue,
            );
    }
  }

  @override
  void dispose() {
    fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final health =
        _cachedHealth ??
        DataHealthAnalyzer.analyze(
          key:
              'Minutes_${widget.facId}_${widget.theme.title}_${widget.utilityType}',
          loading: widget.loading,
          error: widget.error,
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
                title: widget.theme.title,
                health: health,
                backgroundColor: Colors.transparent,
                borderColor: widget.theme.line.withOpacity(.44),
                valueLabel: 'Max',
                value: _headerPoint == null
                    ? '--'
                    : '${_headerPoint!.value!.toStringAsFixed(1)} '
                          '${widget.theme.unit}',
                valueTs: _headerPoint == null
                    ? '--'
                    : DateFormat('HH:mm:ss').format(_headerPoint!.ts.toLocal()),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (loading && rows.isEmpty) {
      return Center(
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: widget.theme.line,
          ),
        ),
      );
    }

    if (error != null && rows.isEmpty) {
      return ChartApiErrorState(
        color: widget.theme.line,
        onRetry: widget.onRetry ?? () {},
      );
    }

    if (rows.isEmpty) {
      return const EmptyChartState(
        title: 'No Data Available',
        message: 'No minute data found for this period.',
      );
    }

    if (_isWater) {
      final data = _waterChartData;

      if (data == null || data.totalPoints < 2) {
        return const _NotEnoughPoints();
      }

      return RepaintBoundary(
        child: _WaterMinuteChart(
          key: ValueKey('water_${widget.facId}_${widget.utilityType}'),
          data: data,
          theme: widget.theme,
          standardValue: _standardValue,
        ),
      );
    }

    final data = _mainChartData;

    if (data == null || data.points.length < 2) {
      return const _NotEnoughPoints();
    }

    return RepaintBoundary(
      child: _MainMinuteChart(
        key: ValueKey(
          'main_${widget.facId}_${widget.utilityType}_${widget.nameEn ?? ''}',
        ),
        data: data,
        theme: widget.theme,
        isElectricity: _isElectricity,
        standardValue: _standardValue,
      ),
    );
  }
}

// ============================================================
// COMMON POINT
// ============================================================

class _ChartPoint {
  final DateTime ts;
  final double y;
  final String nameEn;

  const _ChartPoint({required this.ts, required this.y, required this.nameEn});
}

// ============================================================
// MAIN ELECTRICITY / AIR DATA
// ============================================================

class _MainChartData {
  final List<_ChartPoint> points;

  final DateTime minX;
  final DateTime maxX;

  final double minY;
  final double maxY;
  final double interval;

  const _MainChartData({
    required this.points,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.interval,
  });

  factory _MainChartData.from({
    required List<OverviewMinutePointDto> rows,
    required String utilityType,
    required double standardValue,
  }) {
    final points =
        rows
            .where((item) => item.value != null)
            .map(
              (item) => _ChartPoint(
                ts: item.ts.toLocal(),
                y: item.value!,
                nameEn: item.nameEn?.trim().isNotEmpty == true
                    ? item.nameEn!.trim()
                    : utilityType,
              ),
            )
            .toList()
          ..sort((a, b) => a.ts.compareTo(b.ts));

    final values = points.map((point) => point.y).toList(growable: false);

    final minDataY = values.reduce(min);
    final maxDataY = values.reduce(max);

    final minSourceY = min(minDataY, standardValue);

    final maxSourceY = max(maxDataY, standardValue);

    final dataRange = (maxSourceY - minSourceY).abs();

    final padding = dataRange == 0
        ? max(maxSourceY.abs() * .10, .5)
        : dataRange * .15;

    final isElectricity = utilityType.trim().toUpperCase() == 'ELECTRICITY';

    late final double minY;
    late final double maxY;

    if (isElectricity) {
      minY = 0;

      final rawMax = max(maxDataY, standardValue) + padding;

      final step = _niceStep(rawMax / 5);

      maxY = _niceCeil(rawMax, step);
    } else {
      minY = minSourceY - padding;
      maxY = maxSourceY + padding;
    }

    final interval = _niceStep((maxY - minY) / 5);

    return _MainChartData(
      points: List<_ChartPoint>.unmodifiable(points),
      minX: points.first.ts,
      maxX: points.last.ts,
      minY: minY,
      maxY: maxY,
      interval: interval,
    );
  }
}

// ============================================================
// WATER DATA
// ============================================================

class _WaterSeries {
  final String name;
  final List<_ChartPoint> points;
  final int rank;

  const _WaterSeries({
    required this.name,
    required this.points,
    required this.rank,
  });
}

class _WaterChartData {
  final List<_WaterSeries> series;

  final DateTime minX;
  final DateTime maxX;

  final double minY;
  final double maxY;
  final double interval;

  final int totalPoints;

  const _WaterChartData({
    required this.series,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.interval,
    required this.totalPoints,
  });

  factory _WaterChartData.from({
    required List<OverviewMinutePointDto> rows,
    required String facId,
    required double standardValue,
  }) {
    final grouped = _groupWaterRows(rows: rows, facId: facId);

    final cleaned = <String, List<_ChartPoint>>{};

    for (final entry in grouped.entries) {
      final name = entry.key.trim();

      if (name.isEmpty || entry.value.isEmpty) {
        continue;
      }

      final byTime = <DateTime, _ChartPoint>{};

      for (final point in entry.value) {
        byTime[point.ts] = point;
      }

      final points = byTime.values.toList()
        ..sort((a, b) => a.ts.compareTo(b.ts));

      if (points.isNotEmpty) {
        cleaned[name] = points;
      }
    }

    final rankedEntries = cleaned.entries.toList()
      ..sort((a, b) {
        final avgA =
            a.value.fold<double>(0, (sum, point) => sum + point.y) /
            a.value.length;

        final avgB =
            b.value.fold<double>(0, (sum, point) => sum + point.y) /
            b.value.length;

        return avgB.compareTo(avgA);
      });

    final series = <_WaterSeries>[];

    for (var index = 0; index < rankedEntries.length; index++) {
      final entry = rankedEntries[index];

      series.add(
        _WaterSeries(
          name: entry.key,
          points: List<_ChartPoint>.unmodifiable(entry.value),
          rank: index,
        ),
      );
    }

    final allPoints = series.expand((item) => item.points).toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));

    final values = allPoints.map((point) => point.y).toList(growable: false);

    final minValue = values.reduce(min);
    final maxValue = values.reduce(max);

    final minSource = min(minValue, standardValue);

    final maxSource = max(maxValue, standardValue);

    final range = maxSource - minSource;

    final padding = max(range * .10, .2);

    final minY = minSource - padding;
    final maxY = maxSource + padding;

    return _WaterChartData(
      series: List<_WaterSeries>.unmodifiable(series),
      minX: allPoints.first.ts,
      maxX: allPoints.last.ts,
      minY: minY,
      maxY: maxY,
      interval: max((maxY - minY) / 4, .1),
      totalPoints: allPoints.length,
    );
  }

  static Map<String, List<_ChartPoint>> _groupWaterRows({
    required List<OverviewMinutePointDto> rows,
    required String facId,
  }) {
    final normalizedFac = facId.trim().toUpperCase();

    final isKvh = normalizedFac == 'KVH' || normalizedFac.contains('KVH');

    if (!isKvh) {
      final grouped = <String, List<_ChartPoint>>{};

      for (final item in rows) {
        final value = item.value;

        if (value == null) continue;

        final name = _waterName(item.nameEn);

        grouped.putIfAbsent(name, () => <_ChartPoint>[]);

        grouped[name]!.add(
          _ChartPoint(ts: item.ts.toLocal(), y: value, nameEn: name),
        );
      }

      return grouped;
    }

    /*
     * KVH:
     * API mới thường trả:
     * Fac_A - Tank xx
     * Fac_B - Tank xx
     * Fac_C - Tank xx
     *
     * Mỗi FAC thành một series.
     * Trong cùng phút, nếu có nhiều điểm thì lấy trung bình.
     */
    final buckets = <String, Map<DateTime, List<double>>>{};

    for (final item in rows) {
      final value = item.value;

      if (value == null) continue;

      final rawName = _waterName(item.nameEn);
      final seriesName = _kvhSeriesName(rawName, fallback: facId);

      final minute = _minuteKey(item.ts.toLocal());

      buckets.putIfAbsent(seriesName, () => <DateTime, List<double>>{});

      buckets[seriesName]!.putIfAbsent(minute, () => <double>[]);

      buckets[seriesName]![minute]!.add(value);
    }

    final grouped = <String, List<_ChartPoint>>{};

    for (final seriesEntry in buckets.entries) {
      final points = <_ChartPoint>[];

      for (final minuteEntry in seriesEntry.value.entries) {
        final values = minuteEntry.value;

        final average =
            values.fold<double>(0, (sum, value) => sum + value) / values.length;

        points.add(
          _ChartPoint(ts: minuteEntry.key, y: average, nameEn: seriesEntry.key),
        );
      }

      points.sort((a, b) => a.ts.compareTo(b.ts));

      grouped[seriesEntry.key] = points;
    }

    return grouped;
  }

  static String _waterName(String? nameEn) {
    final name = nameEn?.trim();

    if (name == null || name.isEmpty) {
      return 'Cooling tank';
    }

    return name;
  }

  static DateTime _minuteKey(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
    );
  }

  static String _kvhSeriesName(String rawName, {required String fallback}) {
    final separatorIndex = rawName.indexOf(' - ');

    if (separatorIndex > 0) {
      final prefix = rawName.substring(0, separatorIndex).trim();

      if (prefix.isNotEmpty) {
        return prefix;
      }
    }

    return fallback.trim().isEmpty ? 'KVH' : fallback.trim();
  }
}

// ============================================================
// MAIN CHART
// ============================================================
PlotBand _standardPlotBand({
  required double value,
  required String unit,
  required Color color,
}) {
  return PlotBand(
    start: value,
    end: value,

    // Vẽ trên series để điện/nước/khí đều giống nhau.
    shouldRenderAboveSeries: true,

    borderWidth: 2,
    borderColor: color,

    // Nét đứt giống nhau.
    dashArray: const <double>[7, 5],

    text: 'Standard ${value.toStringAsFixed(1)} $unit',
    textStyle: TextStyle(
      color: color,
      fontSize: 11,
      fontWeight: FontWeight.w800,
    ),

    horizontalTextAlignment: TextAnchor.end,
    verticalTextAlignment: TextAnchor.start,
  );
}

class _MainMinuteChart extends StatelessWidget {
  final _MainChartData data;
  final ChartTheme theme;
  final bool isElectricity;
  final double standardValue;

  const _MainMinuteChart({
    super.key,
    required this.data,
    required this.theme,
    required this.isElectricity,
    required this.standardValue,
  });

  @override
  Widget build(BuildContext context) {
    final lastPoint = data.points.last;

    final maxX = data.maxX.add(const Duration(minutes: 2));

    /*
     * Standard line cũng dùng _ChartPoint.
     * Không dùng _StandardPoint riêng nữa.
     */
    final standardPoints = <_ChartPoint>[
      _ChartPoint(ts: data.minX, y: standardValue, nameEn: 'Standard'),
      _ChartPoint(ts: maxX, y: standardValue, nameEn: 'Standard'),
    ];

    return SfCartesianChart(
      enableAxisAnimation: false,
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 1,
      plotAreaBorderColor: Colors.white.withOpacity(.10),

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
        maximum: maxX,
        intervalType: DateTimeIntervalType.minutes,
        dateFormat: DateFormat('HH:mm'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(.06),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(.10)),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(.55),
          fontSize: 13,
        ),
      ),

      primaryYAxis: NumericAxis(
        minimum: data.minY,
        maximum: data.maxY,
        interval: data.interval,
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
          text: theme.unit,
          alignment: ChartAlignment.center,
          textStyle: TextStyle(
            color: Colors.white.withOpacity(.80),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),

      /*
       * Tất cả series đều dùng:
       * CartesianSeries<_ChartPoint, DateTime>
       */
      series: <CartesianSeries<_ChartPoint, DateTime>>[
        // ======================================================
        // STANDARD LINE
        // ======================================================
        LineSeries<_ChartPoint, DateTime>(
          name: 'Standard',
          animationDuration: 0,
          dataSource: standardPoints,
          xValueMapper: (point, _) => point.ts,
          yValueMapper: (point, _) => point.y,
          color: theme.line,
          width: 2,
          dashArray: const <double>[7, 5],
          isVisibleInLegend: false,
          enableTooltip: false,
          markerSettings: const MarkerSettings(isVisible: false),

          /*
           * Chỉ hiện label ở điểm cuối.
           */
          dataLabelMapper: (point, index) {
            if (index != standardPoints.length - 1) {
              return null;
            }

            return 'Standard '
                '${standardValue.toStringAsFixed(1)} '
                '${theme.unit}';
          },

          dataLabelSettings: DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.outer,
            textStyle: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        // ======================================================
        // GLOW LINE
        // ======================================================
        SplineSeries<_ChartPoint, DateTime>(
          animationDuration: 0,
          dataSource: data.points,
          xValueMapper: (point, _) => point.ts,
          yValueMapper: (point, _) => point.y,
          color: theme.line.withOpacity(.15),
          width: 6,
          enableTooltip: false,
          isVisibleInLegend: false,
        ),

        // ======================================================
        // MAIN AREA
        // ======================================================
        SplineAreaSeries<_ChartPoint, DateTime>(
          animationDuration: 0,
          dataSource: data.points,
          xValueMapper: (point, _) => point.ts,
          yValueMapper: (point, _) => point.y,
          splineType: SplineType.natural,
          borderColor: theme.line,
          borderWidth: 2,
          gradient: LinearGradient(
            colors: [theme.fillTop, theme.fillBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          markerSettings: MarkerSettings(
            isVisible: data.points.length <= 30,
            width: 4,
            height: 4,
            borderWidth: 1,
            borderColor: theme.line.withOpacity(.90),
          ),
          isVisibleInLegend: false,
        ),

        // ======================================================
        // LAST POINT
        // ======================================================
        ScatterSeries<_ChartPoint, DateTime>(
          isVisibleInLegend: false,
          enableTooltip: false,
          dataSource: <_ChartPoint>[lastPoint],
          xValueMapper: (point, _) => point.ts,
          yValueMapper: (point, _) => point.y,
          color: theme.line,
          markerSettings: const MarkerSettings(
            isVisible: true,
            width: 6,
            height: 6,
            borderWidth: 2,
            borderColor: Colors.white,
          ),
          dataLabelMapper: (point, _) {
            return point.y.toStringAsFixed(1);
          },
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.outer,
            textStyle: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// WATER CHART
// ============================================================

class _WaterMinuteChart extends StatelessWidget {
  final _WaterChartData data;
  final ChartTheme theme;
  final double standardValue;

  const _WaterMinuteChart({
    super.key,
    required this.data,
    required this.theme,
    required this.standardValue,
  });

  @override
  Widget build(BuildContext context) {
    final showLegend = data.series.length > 1;

    final maxX = data.maxX.add(const Duration(minutes: 2));

    final standardPoints = <_ChartPoint>[
      _ChartPoint(ts: data.minX, y: standardValue, nameEn: 'Standard'),
      _ChartPoint(ts: maxX, y: standardValue, nameEn: 'Standard'),
    ];

    final chartSeries = <CartesianSeries<_ChartPoint, DateTime>>[
      // ========================================================
      // STANDARD LINE
      // ========================================================
      LineSeries<_ChartPoint, DateTime>(
        name: 'Standard',
        animationDuration: 0,
        dataSource: standardPoints,
        xValueMapper: (point, _) => point.ts,
        yValueMapper: (point, _) => point.y,
        color: theme.line,
        width: 2,
        dashArray: const <double>[7, 5],
        isVisibleInLegend: false,
        enableTooltip: false,
        markerSettings: const MarkerSettings(isVisible: false),
        dataLabelMapper: (point, index) {
          if (index != standardPoints.length - 1) {
            return null;
          }

          return 'Standard '
              '${standardValue.toStringAsFixed(1)} '
              '${theme.unit}';
        },
        dataLabelSettings: DataLabelSettings(
          isVisible: true,
          labelAlignment: ChartDataLabelAlignment.outer,
          textStyle: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ];

    // ==========================================================
    // WATER SERIES
    // ==========================================================
    for (final waterSeries in data.series) {
      final color = _seriesColorByRank(
        baseColor: theme.line,
        rank: waterSeries.rank,
        total: data.series.length,
      );

      chartSeries.add(
        LineSeries<_ChartPoint, DateTime>(
          name: waterSeries.name,
          dataSource: waterSeries.points,
          animationDuration: 0,
          xValueMapper: (point, _) => point.ts,
          yValueMapper: (point, _) => point.y,
          width: waterSeries.rank == 0 ? 3 : 2,
          color: color,
          markerSettings: const MarkerSettings(isVisible: false),
          dataLabelMapper: (point, index) {
            if (index != waterSeries.points.length - 1) {
              return null;
            }

            return point.y.toStringAsFixed(1);
          },
          dataLabelSettings: DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.outer,
            textStyle: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return SfCartesianChart(
      enableAxisAnimation: false,
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
        minimum: data.minX,
        maximum: maxX,
        intervalType: DateTimeIntervalType.minutes,
        dateFormat: DateFormat('HH:mm'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(.04),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(.08)),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(.55),
          fontSize: 11,
        ),
      ),

      primaryYAxis: NumericAxis(
        minimum: data.minY,
        maximum: data.maxY,
        interval: data.interval,
        numberFormat: NumberFormat('0.0'),

        // Không dùng plotBands nữa.
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(.05),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(.08)),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(.55),
          fontSize: 11,
        ),
        title: AxisTitle(
          text: theme.unit,
          alignment: ChartAlignment.center,
          textStyle: TextStyle(
            color: Colors.white.withOpacity(.80),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),

      series: chartSeries,
    );
  }
}
// ============================================================
// HELPERS
// ============================================================

class _NotEnoughPoints extends StatelessWidget {
  const _NotEnoughPoints();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Not enough points',
        style: TextStyle(color: Colors.white.withOpacity(.70), fontSize: 13),
      ),
    );
  }
}

double _niceStep(double rawStep) {
  if (rawStep <= 0 || rawStep.isNaN || rawStep.isInfinite) {
    return 1;
  }

  final exponent = (log(rawStep) / ln10).floor();

  final base = pow(10, exponent).toDouble();

  final fraction = rawStep / base;

  if (fraction <= 1) return base;
  if (fraction <= 2) return 2 * base;
  if (fraction <= 5) return 5 * base;

  return 10 * base;
}

double _niceCeil(double value, double step) {
  if (step <= 0 || step.isNaN || step.isInfinite) {
    return value;
  }

  return (value / step).ceil() * step;
}

Color _seriesColorByRank({
  required Color baseColor,
  required int rank,
  required int total,
}) {
  final base = HSLColor.fromColor(baseColor);

  if (total <= 1) {
    return base.withLightness(.48).toColor();
  }

  const darkest = .34;
  const lightest = .72;

  final ratio = rank / (total - 1);

  final lightness = darkest + ((lightest - darkest) * ratio);

  return base
      .withLightness(lightness.clamp(.25, .80))
      .withSaturation((base.saturation * .95).clamp(.55, 1))
      .toColor();
}
