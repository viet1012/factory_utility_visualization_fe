import 'dart:math' as math;

import 'package:factory_utility_visualization/'
    'utility_dashboard/utility_all_factory_chart/'
    'models/utility_daily_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../shared/charts/axis_planner.dart';
import '../../shared/charts/chart_animation.dart';
import '../../shared/charts/chart_downsample.dart';
import '../../shared/charts/chart_hover_style.dart';
import '../../shared/charts/signal_chart_spec.dart';
import '../../shared/charts/value_format.dart';
import '../../shared/widgets/chart_loading_widgets.dart';
import '../../shared/widgets/debounced_layout_builder.dart';
import '../../shared/widgets/lazy_chart_gate.dart';
import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_widgets.dart';
import '../../shared/widgets/scada_panel_frame.dart';
import '../controllers/utility_chart_catalog_controller.dart';

class UtilityDailyChartGrid extends StatelessWidget {
  final List<UtilityDailySeries> series;

  final String facId;
  final String cate;
  final String? scadaId;
  final String boxDeviceId;

  const UtilityDailyChartGrid({
    super.key,
    required this.series,
    required this.facId,
    required this.cate,
    required this.scadaId,
    required this.boxDeviceId,
  });

  @override
  Widget build(BuildContext context) {
    final visibleSeries = List<UtilityDailySeries>.from(series)
      ..sort(_compareSeries);

    if (visibleSeries.isEmpty) {
      return const _DailyGridEmptyState();
    }

    // Resize: giu grid cu 150ms roi moi tinh lai so cot / chieu cao.
    return DebouncedLayoutBuilder(
      builder: (context, constraints) {
        final columnCount = _columnCount(constraints.maxWidth);

        final cardHeight = _cardHeight(
          availableHeight: constraints.maxHeight,
          itemCount: visibleSeries.length,
          columnCount: columnCount,
        );

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: cardHeight,
          ),
          itemCount: visibleSeries.length,
          itemBuilder: (context, index) {
            final item = visibleSeries[index];

            final currentBoxDeviceId = item.boxDeviceId.trim().isNotEmpty
                ? item.boxDeviceId.trim()
                : boxDeviceId;

            // Key on dinh theo signal: refresh / resize khong tao lai the.
            return RepaintBoundary(
              key: ValueKey(
                '$currentBoxDeviceId|${item.plcAddress}|${item.nameEn}',
              ),
              child: _DailySignalChartCard(
                series: item,
                facId: facId,
                cate: cate,
                boxDeviceId: currentBoxDeviceId,
              ),
            );
          },
        );
      },
    );
  }

  int _compareSeries(UtilityDailySeries first, UtilityDailySeries second) {
    final deviceCompare = first.boxDeviceId.toUpperCase().compareTo(
      second.boxDeviceId.toUpperCase(),
    );

    if (deviceCompare != 0) {
      return deviceCompare;
    }

    final orderCompare = _signalOrder(
      first.nameEn,
    ).compareTo(_signalOrder(second.nameEn));

    if (orderCompare != 0) {
      return orderCompare;
    }

    return first.plcAddress.toUpperCase().compareTo(
      second.plcAddress.toUpperCase(),
    );
  }

  int _columnCount(double width) {
    if (width >= 1500) {
      return 3;
    }

    if (width >= 900) {
      return 2;
    }

    return 1;
  }

  double _cardHeight({
    required double availableHeight,
    required int itemCount,
    required int columnCount,
  }) {
    final rowCount = (itemCount / columnCount).ceil();

    if (rowCount <= 1) {
      return math.max(380, availableHeight - 16);
    }

    if (availableHeight >= 900) {
      return 400;
    }

    return 370;
  }

  int _signalOrder(String name) {
    final value = name.trim().toUpperCase();

    if (value.contains('TEMPERURE') || value.contains('TEMPERATURE')) {
      return 0;
    }

    if (value.contains('HUMITY') || value.contains('HUMIDITY')) {
      return 1;
    }

    if (value == 'VOLTAGE V12') return 10;
    if (value == 'VOLTAGE V23') return 11;
    if (value == 'VOLTAGE V31') return 12;

    if (value == 'CURRENT I1') return 20;
    if (value == 'CURRENT I2') return 21;
    if (value == 'CURRENT I3') return 22;

    if (value == 'TOTAL POWER') {
      return 30;
    }

    if (value == 'TOTAL ENERGY CONSUMPTION') {
      return 31;
    }

    if (value.contains('POWER FACTOR')) {
      return 32;
    }

    if (value.contains('COMPRESSED AIR')) {
      return 40;
    }

    if (value.contains('COOLING TANK')) {
      return 50;
    }

    if (value.contains('PIPELINE PRESSURE')) {
      return 60;
    }

    if (value.contains('WATER LEVEL')) {
      return 70;
    }

    return 99;
  }
}

// ============================================================
// DAILY SIGNAL CARD
// ============================================================

class _DailySignalChartCard extends StatelessWidget {
  final UtilityDailySeries series;

  final String facId;
  final String cate;
  final String boxDeviceId;

  const _DailySignalChartCard({
    required this.series,
    required this.facId,
    required this.cate,
    required this.boxDeviceId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ChartThemes.byCate(cate);

    final sortedPoints = series.sortedPoints;

    final points = sortedPoints
        .where(_hasMeaningfulValue)
        .toList(growable: false);

    final latestPoint = points.isEmpty ? null : points.last;

    final summary = _DailySeriesSummary.from(series: series, points: points);

    final spec = dailySpecOf(context, series, boxDeviceId);

    return ScadaPanelFrame(
      color: theme.accent,
      child: Container(
        decoration: _dailyPanelDecoration(theme),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UtilityInfoBoxWidgets.header(
              facilityColor: theme.fillTop,
              facTitle: facId,
              boxDeviceId: _displaySignalName(series.nameEn),
              plcAddress: series.plcAddress,
              unit: spec.resolveUnit(series.unit).isEmpty
                  ? null
                  : spec.resolveUnit(series.unit),
              isLoading: false,
              hasError: false,
              err: null,
            ),

            _DailyLatestInfoBar(
              latestPoint: latestPoint,
              series: series,
              summary: summary,
              spec: spec,
              boxDeviceId: boxDeviceId,
              color: theme.accent,
            ),

            Expanded(
              child: points.isEmpty
                  ? const _DailyChartEmptyState()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                      child: LazyChartGate(
                        placeholder: ChartBodySkeleton(color: theme.line),
                        builder: (_) => _DailyChart(
                          series: series,
                          spec: spec,
                          points: points,
                          lineColor: theme.line,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasMeaningfulValue(UtilityDailyPoint point) {
    if (series.isEnergyConsumption) {
      return point.consumption != null;
    }

    return point.avgValue != null || point.lastValue != null;
  }
}

/// Daily: COUNTER (DAILY_DELTA) ve cot theo ngay, ANALOG ve lineBand theo
/// ngay; truc / so le / format lay tu SignalChartSpec. API daily khong tra
/// code nen code / unit / ten tra qua /chart-catalog theo (box, plc).
SignalChartSpec dailySpecOf(
  BuildContext context,
  UtilityDailySeries series,
  String boxDeviceId,
) {
  final energy = series.isEnergyConsumption;

  final spec = context
      .read<UtilityChartCatalogController>()
      .resolveSpecForSignal(
        series.boxDeviceId.trim().isNotEmpty ? series.boxDeviceId : boxDeviceId,
        series.plcAddress,
        unit: series.unit,
        kind: energy ? 'COUNTER' : 'ANALOG',
        name: series.nameEn,
      );

  final style = energy ? ChartStyle.bar : ChartStyle.lineBand;
  if (spec.style == style) return spec;

  return SignalChartSpec(
    style: style,
    axis: energy ? AxisMode.zeroBased : spec.axis,
    fixedMin: spec.fixedMin,
    fixedMax: spec.fixedMax,
    decimals: spec.decimals,
    showThreshold: spec.showThreshold,
    hideTrivialLowerThreshold: spec.hideTrivialLowerThreshold,
    unitOverride: spec.unitOverride,
  );
}

// ============================================================
// HEADER
// ============================================================
BoxDecoration _dailyPanelDecoration(ChartTheme theme) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(20),
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: .06),
        Colors.white.withValues(alpha: .02),
      ],
    ),
    border: Border.all(color: theme.line.withValues(alpha: .18)),
    boxShadow: [
      BoxShadow(
        color: theme.line.withValues(alpha: .18),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: .32),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

class _DailyLatestInfoBar extends StatelessWidget {
  final UtilityDailyPoint? latestPoint;
  final UtilityDailySeries series;
  final _DailySeriesSummary summary;
  final SignalChartSpec spec;
  final String boxDeviceId;
  final Color color;

  const _DailyLatestInfoBar({
    required this.latestPoint,
    required this.series,
    required this.summary,
    required this.spec,
    required this.boxDeviceId,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final unit = spec.resolveUnit(series.unit);

    return Container(
      height: 42,
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: .22)),
            ),
            child: Icon(
              _dailySignalStyle(series.nameEn, '').icon,
              color: color,
              size: 17,
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    formatValue(summary.latestValue, decimals: spec.decimals),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),

                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      unit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .58),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],

                const SizedBox(width: 10),

                Container(
                  width: 1,
                  height: 17,
                  color: Colors.white.withValues(alpha: .12),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    boxDeviceId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .58),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (latestPoint != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color.withValues(alpha: .22)),
              ),
              child: Text(
                // DateFormat('dd/MM').format(latestPoint!.recordDate),
                DateFormat('dd/MMM', 'en_US').format(latestPoint!.recordDate),

                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// DAILY CHART
// ============================================================

class _DailyChart extends StatefulWidget {
  final UtilityDailySeries series;
  final SignalChartSpec spec;
  final List<UtilityDailyPoint> points;
  final Color lineColor;

  const _DailyChart({
    required this.series,
    required this.spec,
    required this.points,
    required this.lineColor,
  });

  @override
  State<_DailyChart> createState() => _DailyChartState();
}

class _DailyChartState extends State<_DailyChart> {
  static final DateFormat _axisDateFormat = DateFormat('dd/MM');
  static final DateFormat _hoverDateFormat = DateFormat('EEE dd/MM', 'en_US');

  late final TrackballBehavior _trackball;
  final FirstPaintAnimation _animation = FirstPaintAnimation();

  int? _selectedPointIndex;

  /// Diem theo ngay (ms) de trackball tra lai diem goc tu x.
  Map<int, UtilityDailyPoint> _pointsByDay = const {};

  UtilityDailyPoint? get _selectedPoint {
    final index = _selectedPointIndex;

    if (index == null || index < 0 || index >= widget.points.length) {
      return null;
    }

    return widget.points[index];
  }

  @override
  void initState() {
    super.initState();

    _trackball = ChartHoverStyle.trackball(
      markerColor: widget.lineColor,
      builder: (context, details) {
        final x = details.point?.x;
        final point = x is DateTime
            ? _pointsByDay[x.millisecondsSinceEpoch]
            : null;
        if (point == null) return const SizedBox.shrink();

        return _hoverCard(point);
      },
    );

    _selectLatestPoint();
  }

  @override
  void didUpdateWidget(covariant _DailyChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    final dataChanged =
        oldWidget.series.boxDeviceId != widget.series.boxDeviceId ||
        oldWidget.series.plcAddress != widget.series.plcAddress ||
        oldWidget.series.nameEn != widget.series.nameEn ||
        !identical(oldWidget.points, widget.points);

    if (dataChanged) _selectLatestPoint();
  }

  void _selectLatestPoint() {
    _selectedPointIndex = widget.points.isEmpty
        ? null
        : widget.points.length - 1;
  }

  void _handlePointTap(ChartPointDetails details) {
    final index = details.pointIndex;

    if (index == null || index < 0 || index >= widget.points.length) {
      return;
    }

    setState(() => _selectedPointIndex = index);
  }

  double? _mainValue(UtilityDailyPoint point) {
    return widget.series.isEnergyConsumption
        ? point.consumption
        : point.avgValue ?? point.lastValue;
  }

  Widget _hoverCard(UtilityDailyPoint point) {
    final energy = widget.series.isEnergyConsumption;
    final hasRange = point.minValue != null && point.maxValue != null;

    return ChartHoverCard(
      title: _hoverDateFormat.format(point.recordDate),
      rows: ChartHoverStyle.rows(
        kind: energy ? HoverKind.counter : HoverKind.analog,
        value: _mainValue(point),
        unit: widget.spec.resolveUnit(widget.series.unit),
        decimals: widget.spec.decimals,
        min: hasRange ? point.minValue : null,
        max: hasRange ? point.maxValue : null,
        samples: point.sampleCount > 0 ? point.sampleCount : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final energy = widget.series.isEnergyConsumption;
    final spec = widget.spec;

    final hasBand =
        !energy &&
        widget.points.any((p) => p.minValue != null && p.maxValue != null);

    final points = downsampleMinMax(
      widget.points,
      value: _mainValue,
      low: hasBand
          ? (UtilityDailyPoint p) => p.minValue ?? _mainValue(p)
          : null,
      high: hasBand
          ? (UtilityDailyPoint p) => p.maxValue ?? _mainValue(p)
          : null,
    );

    _pointsByDay = {
      for (final point in points)
        point.recordDate.millisecondsSinceEpoch: point,
    };

    final axis = planAxis(
      values: [
        for (final point in points) ...[
          _mainValue(point),
          if (hasBand) ...[point.minValue, point.maxValue],
        ],
      ],
      spec: spec,
    );

    final animationMs = _animation.duration();

    return Column(
      children: [
        _DailySelectedPointPanel(
          point: _selectedPoint,
          series: widget.series,
          spec: spec,
          energy: energy,
          color: widget.lineColor,
        ),

        const SizedBox(height: 4),

        Expanded(
          child: SfCartesianChart(
            margin: const EdgeInsets.fromLTRB(4, 2, 8, 0),
            plotAreaBorderWidth: 0,

            trackballBehavior: _trackball,

            primaryXAxis: DateTimeCategoryAxis(
              dateFormat: _axisDateFormat,
              interval: _xAxisInterval(points.length),
              labelRotation: -35,
              edgeLabelPlacement: EdgeLabelPlacement.shift,
              labelIntersectAction: AxisLabelIntersectAction.hide,
              axisLine: const AxisLine(color: Color(0xFF263D5D), width: 1),
              majorGridLines: const MajorGridLines(width: 0),
              majorTickLines: const MajorTickLines(
                size: 3,
                color: Color(0xFF334155),
              ),
              labelStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),

            primaryYAxis: NumericAxis(
              minimum: axis.min,
              maximum: axis.max,
              interval: axis.interval,
              rangePadding: ChartRangePadding.none,
              axisLine: const AxisLine(width: 0),
              majorTickLines: const MajorTickLines(size: 0),
              majorGridLines: MajorGridLines(
                width: .65,
                color: Colors.white.withValues(alpha: .065),
                dashArray: const <double>[4, 4],
              ),
              labelStyle: const TextStyle(
                color: Color(0xFF71869F),
                fontSize: 12,
              ),
              axisLabelFormatter: (AxisLabelRenderDetails details) {
                return ChartAxisLabel(
                  axis.label(details.value),
                  details.textStyle,
                );
              },
            ),

            series: energy
                ? _buildEnergySeries(points, animationMs)
                : _buildMeasuredSeries(points, animationMs, hasBand: hasBand),
          ),
        ),
      ],
    );
  }

  double _xAxisInterval(int count) {
    if (count <= 8) {
      return 1;
    }

    if (count <= 16) {
      return 2;
    }

    if (count <= 24) {
      return 3;
    }

    return 4;
  }

  List<CartesianSeries<UtilityDailyPoint, DateTime>> _buildEnergySeries(
    List<UtilityDailyPoint> points,
    double animationMs,
  ) {
    return [
      ColumnSeries<UtilityDailyPoint, DateTime>(
        dataSource: points,
        xValueMapper: (point, _) => point.recordDate,
        yValueMapper: (point, _) => point.consumption,

        // onPointTap nằm trên Series,
        // không nằm trên SfCartesianChart.
        onPointTap: _handlePointTap,

        name: 'Daily consumption',

        color: widget.lineColor.withValues(alpha: .78),
        borderColor: widget.lineColor,
        borderWidth: 1,

        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),

        width: .62,
        spacing: .16,

        enableTooltip: false,
        animationDuration: animationMs,

        dataLabelSettings: DataLabelSettings(
          isVisible: points.length <= 8,
          labelAlignment: ChartDataLabelAlignment.top,
          builder: (data, point, series, pointIndex, seriesIndex) => Text(
            formatValue(
              (data as UtilityDailyPoint).consumption,
              decimals: widget.spec.decimals,
            ),
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ];
  }

  List<CartesianSeries<UtilityDailyPoint, DateTime>> _buildMeasuredSeries(
    List<UtilityDailyPoint> points,
    double animationMs, {
    required bool hasBand,
  }) {
    return [
      if (hasBand)
        RangeAreaSeries<UtilityDailyPoint, DateTime>(
          dataSource: points,
          xValueMapper: (point, _) => point.recordDate,
          lowValueMapper: (point, _) => point.minValue,
          highValueMapper: (point, _) => point.maxValue,
          color: widget.lineColor.withValues(alpha: .10),
          borderColor: widget.lineColor.withValues(alpha: .22),
          borderWidth: .8,
          name: 'Min - Max',
          enableTooltip: false,
          enableTrackball: false,
          animationDuration: 0,
          emptyPointSettings: const EmptyPointSettings(
            mode: EmptyPointMode.gap,
          ),
        ),

      LineSeries<UtilityDailyPoint, DateTime>(
        dataSource: points,
        xValueMapper: (point, _) => point.recordDate,
        yValueMapper: (point, _) => _mainValue(point),

        // Click marker AVG để đổi ngày.
        onPointTap: _handlePointTap,

        name: 'Daily average',

        color: widget.lineColor,
        width: 2.4,

        enableTooltip: false,

        markerSettings: MarkerSettings(
          isVisible: true,
          width: points.length <= 16 ? 7 : 5,
          height: points.length <= 16 ? 7 : 5,
          shape: DataMarkerType.circle,
          color: widget.lineColor,
          borderWidth: 1.7,
          borderColor: const Color(0xFF0B1727),
        ),

        animationDuration: animationMs,
      ),
    ];
  }
}

// ============================================================
// SELECTED DAY PANEL
// ============================================================
class _DailySelectedPointPanel extends StatelessWidget {
  final UtilityDailyPoint? point;
  final UtilityDailySeries series;
  final SignalChartSpec spec;
  final bool energy;
  final Color color;

  const _DailySelectedPointPanel({
    required this.point,
    required this.series,
    required this.spec,
    required this.energy,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final selectedPoint = point;
    final unit = spec.resolveUnit(series.unit);
    final decimals = spec.decimals;

    if (selectedPoint == null) {
      return Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: .035),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: .42),
            ),
            const SizedBox(width: 7),
            Text(
              'Tap a chart point to view details',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .48),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .30), width: 1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: .10),
            Colors.white.withValues(alpha: .055),
            Colors.white.withValues(alpha: .025),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: color.withValues(alpha: .08),
            blurRadius: 18,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Nhãn giúp người dùng biết đây là dữ liệu vừa chọn.
          Row(
            children: [
              Icon(Icons.touch_app_rounded, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                'SELECTED CHART POINT',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
              const Spacer(),
              Text(
                'Tap another point to change',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .34),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              _SelectedDateBadge(point: selectedPoint, color: color),

              const SizedBox(width: 10),

              Container(
                width: 1,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withValues(alpha: .16),
                ),
              ),

              const SizedBox(width: 10),

              if (energy)
                Expanded(
                  child: _SelectedMetric(
                    label: 'Consumption',
                    value: selectedPoint.consumption,
                    unit: unit,
                    decimals: decimals,
                    color: color,
                    centered: false,
                  ),
                )
              else
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _SelectedMetric(
                          label: 'AVG',
                          value:
                              selectedPoint.avgValue ?? selectedPoint.lastValue,
                          unit: unit,
                          decimals: decimals,
                          color: color,
                        ),
                      ),

                      _IosMetricDivider(),

                      Expanded(
                        child: _SelectedMetric(
                          label: 'MIN',
                          value: selectedPoint.minValue,
                          unit: unit,
                          decimals: decimals,
                        ),
                      ),

                      _IosMetricDivider(),

                      Expanded(
                        child: _SelectedMetric(
                          label: 'MAX',
                          value: selectedPoint.maxValue,
                          unit: unit,
                          decimals: decimals,
                        ),
                      ),

                      _IosMetricDivider(),

                      Expanded(
                        child: _SelectedMetric(
                          label: 'LATEST',
                          value: selectedPoint.lastValue,
                          unit: unit,
                          decimals: decimals,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IosMetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: .075),
      ),
    );
  }
}

class _SelectedDateBadge extends StatelessWidget {
  final UtilityDailyPoint point;
  final Color color;

  const _SelectedDateBadge({required this.point, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 82),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: .22)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: .16),
            Colors.white.withValues(alpha: .055),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        DateFormat('dd/MMM', 'en_US').format(point.recordDate),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 16,
          height: 1,
          fontWeight: FontWeight.w800,
          letterSpacing: -.2,
        ),
      ),
    );
  }
}

class _SelectedMetric extends StatelessWidget {
  final String label;
  final double? value;
  final String unit;
  final int decimals;
  final Color? color;
  final bool centered;

  const _SelectedMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.decimals,
    this.color,
    this.centered = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: centered ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .42),
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 5),

        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: centered ? Alignment.center : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatValue(value, decimals: decimals),
                maxLines: 1,
                style: TextStyle(
                  color: color ?? Colors.white.withValues(alpha: .90),
                  fontSize: 16,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.15,
                ),
              ),

              if (unit.isNotEmpty) ...[
                const SizedBox(width: 3),

                Text(
                  unit,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .38),
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
// ============================================================
// FOOTER
// ============================================================

// ============================================================
// SUMMARY
// ============================================================

class _DailySeriesSummary {
  final double? latestValue;
  final double? minValue;
  final double? maxValue;
  final double? averageValue;
  final double? totalValue;

  const _DailySeriesSummary({
    required this.latestValue,
    required this.minValue,
    required this.maxValue,
    required this.averageValue,
    required this.totalValue,
  });

  factory _DailySeriesSummary.from({
    required UtilityDailySeries series,
    required List<UtilityDailyPoint> points,
  }) {
    final energy = series.isEnergyConsumption;

    final mainValues = points
        .map(
          (point) =>
              energy ? point.consumption : point.avgValue ?? point.lastValue,
        )
        .whereType<double>()
        .where((value) => value.isFinite)
        .toList(growable: false);

    final minValues = points
        .map((point) => point.minValue)
        .whereType<double>()
        .where((value) => value.isFinite)
        .toList(growable: false);

    final maxValues = points
        .map((point) => point.maxValue)
        .whereType<double>()
        .where((value) => value.isFinite)
        .toList(growable: false);

    final latest = mainValues.isEmpty ? null : mainValues.last;

    final average = mainValues.isEmpty
        ? null
        : mainValues.reduce((first, second) => first + second) /
              mainValues.length;

    final total = mainValues.isEmpty
        ? null
        : mainValues.reduce((first, second) => first + second);

    return _DailySeriesSummary(
      latestValue: latest,
      minValue: energy ? _minOrNull(mainValues) : _minOrNull(minValues),
      maxValue: energy ? _maxOrNull(mainValues) : _maxOrNull(maxValues),
      averageValue: average,
      totalValue: total,
    );
  }

  static double? _minOrNull(List<double> values) {
    if (values.isEmpty) {
      return null;
    }

    return values.reduce((a, b) => a < b ? a : b);
  }

  static double? _maxOrNull(List<double> values) {
    if (values.isEmpty) {
      return null;
    }

    return values.reduce((a, b) => a > b ? a : b);
  }
}

// ============================================================
// SIGNAL STYLE
// ============================================================

class _DailySignalStyle {
  final Color color;
  final IconData icon;

  const _DailySignalStyle({required this.color, required this.icon});
}

_DailySignalStyle _dailySignalStyle(String name, String cate) {
  final value = name.trim().toUpperCase();

  if (value.contains('TEMPERURE') || value.contains('TEMPERATURE')) {
    return const _DailySignalStyle(
      color: Color(0xFFF97316),
      icon: Icons.thermostat_rounded,
    );
  }

  if (value.contains('HUMITY') || value.contains('HUMIDITY')) {
    return const _DailySignalStyle(
      color: Color(0xFF38BDF8),
      icon: Icons.water_drop_rounded,
    );
  }

  if (value.startsWith('VOLTAGE')) {
    return const _DailySignalStyle(
      color: Color(0xFFFACC15),
      icon: Icons.electric_bolt_rounded,
    );
  }

  if (value.startsWith('CURRENT')) {
    return const _DailySignalStyle(
      color: Color(0xFFF59E0B),
      icon: Icons.electrical_services_rounded,
    );
  }

  if (value == 'TOTAL POWER') {
    return const _DailySignalStyle(
      color: Color(0xFFFFB020),
      icon: Icons.speed_rounded,
    );
  }

  if (value == 'TOTAL ENERGY CONSUMPTION') {
    return const _DailySignalStyle(
      color: Color(0xFFFACC15),
      icon: Icons.energy_savings_leaf_rounded,
    );
  }

  if (value.contains('POWER FACTOR')) {
    return const _DailySignalStyle(
      color: Color(0xFFFDE047),
      icon: Icons.analytics_rounded,
    );
  }

  if (value.contains('COMPRESSED AIR') || value.contains('PIPELINE PRESSURE')) {
    return const _DailySignalStyle(
      color: Color(0xFF8B5CF6),
      icon: Icons.air_rounded,
    );
  }

  if (value.contains('COOLING TANK')) {
    return const _DailySignalStyle(
      color: Color(0xFF22D3EE),
      icon: Icons.thermostat_rounded,
    );
  }

  if (value.contains('WATER LEVEL')) {
    return const _DailySignalStyle(
      color: Color(0xFF06B6D4),
      icon: Icons.waves_rounded,
    );
  }

  final category = cate.trim().toUpperCase();

  if (category.contains('WATER')) {
    return const _DailySignalStyle(
      color: Color(0xFF22D3EE),
      icon: Icons.water_drop_rounded,
    );
  }

  if (category.contains('AIR') || category.contains('COMPRESSED')) {
    return const _DailySignalStyle(
      color: Color(0xFF8B5CF6),
      icon: Icons.air_rounded,
    );
  }

  return const _DailySignalStyle(
    color: Color(0xFFFACC15),
    icon: Icons.bolt_rounded,
  );
}

// ============================================================
// FORMAT
// ============================================================

String _displaySignalName(String name) {
  final value = name.trim();

  switch (value.toUpperCase()) {
    case 'TEMPERURE DATA':
      return 'Temperature';

    case 'HUMITY DATA':
      return 'Humidity';

    case 'SENSOR COMPRESSED AIR PRESSURE DATA':
      return 'Compressed Air Pressure';

    case 'COOLING TANK TEMPERATURE DATA':
      return 'Cooling Tank Temperature';

    case 'DATA PIPELINE PRESSURE':
      return 'Pipeline Pressure';

    case 'WATER LEVEL DATA COOLING WATER PIT':
      return 'Cooling Water Pit Level';

    case 'AVERAGE POWER FACTOR(COS PHI)':
      return 'Average Power Factor';

    default:
      return value.isEmpty ? 'Unknown Signal' : value;
  }
}

// ============================================================
// EMPTY STATES
// ============================================================

class _DailyGridEmptyState extends StatelessWidget {
  const _DailyGridEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.query_stats_rounded, color: Color(0xFF526A84), size: 38),

          SizedBox(height: 10),

          Text(
            'No matching daily signals',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyChartEmptyState extends StatelessWidget {
  const _DailyChartEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No daily points',
        style: TextStyle(
          color: Color(0xFF71869F),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
