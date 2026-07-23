import 'dart:math' as math;

import 'package:factory_utility_visualization/'
    'utility_dashboard/utility_all_factory_chart/'
    'utility_daily_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_widgets.dart';
import '../../utility_dashboard_overview/utility_dashboard_overview_widgets/scada_panel_frame.dart';

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = _columnCount(constraints.maxWidth);

        final cardWidth =
            (constraints.maxWidth - ((columnCount - 1) * 10)) / columnCount;

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

            return RepaintBoundary(
              child: _DailySignalChartCard(
                key: ValueKey(
                  '$currentBoxDeviceId|'
                  '${item.plcAddress}|'
                  '${item.nameEn}|'
                  '${item.dailyValues.length}|'
                  '$cardWidth',
                ),
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
    super.key,
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
              unit: series.unit.trim().isEmpty ? null : series.unit.trim(),
              isLoading: false,
              hasError: false,
              err: null,
            ),

            _DailyLatestInfoBar(
              latestPoint: latestPoint,
              series: series,
              summary: summary,
              boxDeviceId: boxDeviceId,
              color: theme.accent,
            ),

            Expanded(
              child: points.isEmpty
                  ? const _DailyChartEmptyState()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                      child: _DailyChart(
                        series: series,
                        points: points,
                        lineColor: theme.line,
                      ),
                    ),
            ),

            _DailyChartFooter(series: series, summary: summary),
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

// ============================================================
// HEADER
// ============================================================
BoxDecoration _dailyPanelDecoration(ChartTheme theme) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(20),
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.white.withOpacity(.06), Colors.white.withOpacity(.02)],
    ),
    border: Border.all(color: theme.line.withOpacity(.18)),
    boxShadow: [
      BoxShadow(
        color: theme.line.withOpacity(.18),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: Colors.black.withOpacity(.32),
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
  final String boxDeviceId;
  final Color color;

  const _DailyLatestInfoBar({
    required this.latestPoint,
    required this.series,
    required this.summary,
    required this.boxDeviceId,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final unit = series.unit.trim();

    return Container(
      height: 42,
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(.22)),
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
                    _formatNumber(summary.latestValue),
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
                        color: Colors.white.withOpacity(.58),
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
                  color: Colors.white.withOpacity(.12),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    boxDeviceId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.58),
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
                color: color.withOpacity(.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color.withOpacity(.22)),
              ),
              child: Text(
                DateFormat('dd/MM').format(latestPoint!.recordDate),
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
  final List<UtilityDailyPoint> points;
  final Color lineColor;

  const _DailyChart({
    required this.series,
    required this.points,
    required this.lineColor,
  });

  @override
  State<_DailyChart> createState() => _DailyChartState();
}

class _DailyChartState extends State<_DailyChart> {
  int? _selectedPointIndex;

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

    _selectLatestPoint();
  }

  @override
  void didUpdateWidget(covariant _DailyChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    final dataChanged =
        oldWidget.series.boxDeviceId != widget.series.boxDeviceId ||
        oldWidget.series.plcAddress != widget.series.plcAddress ||
        oldWidget.series.nameEn != widget.series.nameEn ||
        !_samePointDates(oldWidget.points, widget.points);

    if (!dataChanged) {
      return;
    }

    _selectLatestPoint();
  }

  void _selectLatestPoint() {
    _selectedPointIndex = widget.points.isEmpty
        ? null
        : widget.points.length - 1;
  }

  bool _samePointDates(
    List<UtilityDailyPoint> first,
    List<UtilityDailyPoint> second,
  ) {
    if (first.length != second.length) {
      return false;
    }

    for (var index = 0; index < first.length; index++) {
      if (first[index].recordDate != second[index].recordDate) {
        return false;
      }
    }

    return true;
  }

  void _handlePointTap(ChartPointDetails details) {
    final index = details.pointIndex;

    if (index == null || index < 0 || index >= widget.points.length) {
      return;
    }

    setState(() => _selectedPointIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final energy = widget.series.isEnergyConsumption;

    final bounds = _DailyChartBounds.from(
      series: widget.series,
      points: widget.points,
    );

    return Column(
      children: [
        _DailySelectedPointPanel(
          point: _selectedPoint,
          series: widget.series,
          energy: energy,
          color: widget.lineColor,
        ),

        const SizedBox(height: 4),

        Expanded(
          child: SfCartesianChart(
            margin: const EdgeInsets.fromLTRB(4, 2, 8, 0),
            plotAreaBorderWidth: 0,

            tooltipBehavior: TooltipBehavior(enable: false),

            trackballBehavior: TrackballBehavior(
              enable: true,
              activationMode: ActivationMode.singleTap,
              tooltipDisplayMode: TrackballDisplayMode.none,
              lineType: TrackballLineType.vertical,
              lineColor: widget.lineColor.withOpacity(.55),
              lineWidth: 1,
              markerSettings: TrackballMarkerSettings(
                markerVisibility: TrackballVisibilityMode.visible,
                width: 8,
                height: 8,
                borderWidth: 2,
                borderColor: widget.lineColor,
                color: const Color(0xFF0B1727),
              ),
            ),

            primaryXAxis: DateTimeCategoryAxis(
              dateFormat: DateFormat('dd/MM'),
              interval: _xAxisInterval(widget.points.length),
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
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
              ),
            ),

            primaryYAxis: NumericAxis(
              minimum: bounds.minimum,
              maximum: bounds.maximum,
              rangePadding: ChartRangePadding.none,
              axisLine: const AxisLine(width: 0),
              majorTickLines: const MajorTickLines(size: 0),
              majorGridLines: MajorGridLines(
                width: .65,
                color: Colors.white.withOpacity(.065),
                dashArray: const <double>[4, 4],
              ),
              labelStyle: const TextStyle(
                color: Color(0xFF71869F),
                fontSize: 8.5,
              ),
              axisLabelFormatter: (AxisLabelRenderDetails details) {
                return ChartAxisLabel(
                  _compactAxisNumber(details.value),
                  details.textStyle,
                );
              },
            ),

            series: energy ? _buildEnergySeries() : _buildMeasuredSeries(),
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

  List<CartesianSeries<UtilityDailyPoint, DateTime>> _buildEnergySeries() {
    return [
      ColumnSeries<UtilityDailyPoint, DateTime>(
        dataSource: widget.points,
        xValueMapper: (point, _) => point.recordDate,
        yValueMapper: (point, _) => point.consumption,

        // onPointTap nằm trên Series,
        // không nằm trên SfCartesianChart.
        onPointTap: _handlePointTap,

        name: 'Daily consumption',

        color: widget.lineColor.withOpacity(.78),
        borderColor: widget.lineColor,
        borderWidth: 1,

        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),

        width: .62,
        spacing: .16,

        enableTooltip: false,
        animationDuration: 300,

        dataLabelSettings: DataLabelSettings(
          isVisible: widget.points.length <= 8,
          labelAlignment: ChartDataLabelAlignment.top,
          textStyle: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ];
  }

  List<CartesianSeries<UtilityDailyPoint, DateTime>> _buildMeasuredSeries() {
    final rangePoints = widget.points
        .where((point) => point.minValue != null && point.maxValue != null)
        .toList(growable: false);

    return [
      RangeAreaSeries<UtilityDailyPoint, DateTime>(
        dataSource: rangePoints,
        xValueMapper: (point, _) => point.recordDate,
        lowValueMapper: (point, _) => point.minValue,
        highValueMapper: (point, _) => point.maxValue,
        color: widget.lineColor.withOpacity(.10),
        borderColor: widget.lineColor.withOpacity(.22),
        borderWidth: .8,
        name: 'Min - Max',
        enableTooltip: false,
        animationDuration: 0,
      ),

      SplineSeries<UtilityDailyPoint, DateTime>(
        dataSource: widget.points,
        xValueMapper: (point, _) => point.recordDate,
        yValueMapper: (point, _) => point.avgValue ?? point.lastValue,

        // Click marker AVG để đổi ngày.
        onPointTap: _handlePointTap,

        name: 'Daily average',

        color: widget.lineColor,
        width: 2.4,

        enableTooltip: false,

        markerSettings: MarkerSettings(
          isVisible: true,
          width: widget.points.length <= 16 ? 7 : 5,
          height: widget.points.length <= 16 ? 7 : 5,
          shape: DataMarkerType.circle,
          color: widget.lineColor,
          borderWidth: 1.7,
          borderColor: const Color(0xFF0B1727),
        ),

        animationDuration: 300,
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
  final bool energy;
  final Color color;

  const _DailySelectedPointPanel({
    required this.point,
    required this.series,
    required this.energy,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final selectedPoint = point;
    final unit = series.unit.trim();

    if (selectedPoint == null) {
      return Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(.035),
          border: Border.all(color: Colors.white.withOpacity(.07)),
        ),
        child: Text(
          'Tap a point to view daily values',
          style: TextStyle(
            color: Colors.white.withOpacity(.42),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.09)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(.085),
            color.withOpacity(.045),
            Colors.white.withOpacity(.025),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: color.withOpacity(.055),
            blurRadius: 16,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Row(
        children: [
          _SelectedDateBadge(point: selectedPoint, color: color),

          const SizedBox(width: 10),

          Container(
            width: 1,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withOpacity(.10),
            ),
          ),

          const SizedBox(width: 10),

          if (energy)
            Expanded(
              child: _SelectedMetric(
                label: 'Consumption',
                value: selectedPoint.consumption,
                unit: unit,
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
                      label: 'Average',
                      value: selectedPoint.avgValue ?? selectedPoint.lastValue,
                      unit: unit,
                      color: color,
                    ),
                  ),

                  _IosMetricDivider(),

                  Expanded(
                    child: _SelectedMetric(
                      label: 'Minimum',
                      value: selectedPoint.minValue,
                      unit: unit,
                    ),
                  ),

                  _IosMetricDivider(),

                  Expanded(
                    child: _SelectedMetric(
                      label: 'Maximum',
                      value: selectedPoint.maxValue,
                      unit: unit,
                    ),
                  ),

                  _IosMetricDivider(),

                  Expanded(
                    child: _SelectedMetric(
                      label: 'Latest',
                      value: selectedPoint.lastValue,
                      unit: unit,
                    ),
                  ),
                ],
              ),
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
        color: Colors.white.withOpacity(.075),
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
      constraints: const BoxConstraints(minWidth: 76),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withOpacity(.22)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(.16), Colors.white.withOpacity(.055)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('dd').format(point.recordDate),
            style: TextStyle(
              color: color,
              fontSize: 18,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: -.3,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            DateFormat('MMM yyyy').format(point.recordDate),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(.58),
              fontSize: 8.5,
              height: 1,
              fontWeight: FontWeight.w600,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedMetric extends StatelessWidget {
  final String label;
  final double? value;
  final String unit;
  final Color? color;
  final bool centered;

  const _SelectedMetric({
    required this.label,
    required this.value,
    required this.unit,
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
            color: Colors.white.withOpacity(.42),
            fontSize: 8.5,
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
                _formatDailyValue(value),
                maxLines: 1,
                style: TextStyle(
                  color: color ?? Colors.white.withOpacity(.90),
                  fontSize: 14,
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
                    color: Colors.white.withOpacity(.38),
                    fontSize: 8.5,
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
// Y AXIS BOUNDS
// ============================================================

class _DailyChartBounds {
  final double minimum;
  final double maximum;

  const _DailyChartBounds({required this.minimum, required this.maximum});

  factory _DailyChartBounds.from({
    required UtilityDailySeries series,
    required List<UtilityDailyPoint> points,
  }) {
    final values = <double>[];

    if (series.isEnergyConsumption) {
      values.addAll(
        points.map((point) => point.consumption).whereType<double>(),
      );
    } else {
      for (final point in points) {
        final min = point.minValue;
        final max = point.maxValue;
        final avg = point.avgValue ?? point.lastValue;

        if (min != null && min.isFinite) {
          values.add(min);
        }

        if (max != null && max.isFinite) {
          values.add(max);
        }

        if (avg != null && avg.isFinite) {
          values.add(avg);
        }
      }
    }

    if (values.isEmpty) {
      return const _DailyChartBounds(minimum: 0, maximum: 1);
    }

    final rawMin = values.reduce(math.min);

    final rawMax = values.reduce(math.max);

    if (rawMin == rawMax) {
      final padding = rawMin.abs() < 1 ? .5 : rawMin.abs() * .08;

      return _DailyChartBounds(
        minimum: rawMin - padding,
        maximum: rawMax + padding,
      );
    }

    final difference = rawMax - rawMin;

    final padding = difference * .14;

    var minimum = rawMin - padding;

    final maximum = rawMax + padding;

    if (series.isEnergyConsumption && minimum > 0) {
      minimum = 0;
    }

    return _DailyChartBounds(minimum: minimum, maximum: maximum);
  }
}

// ============================================================
// FOOTER
// ============================================================

class _DailyChartFooter extends StatelessWidget {
  final UtilityDailySeries series;
  final _DailySeriesSummary summary;

  const _DailyChartFooter({required this.series, required this.summary});

  @override
  Widget build(BuildContext context) {
    final energy = series.isEnergyConsumption;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF091523),
        border: Border(top: BorderSide(color: Color(0xFF20344D))),
      ),
      child: energy
          ? Row(
              children: [
                _DailyMetric(
                  label: 'TOTAL',
                  value: _formatNumber(summary.totalValue),
                  unit: series.unit,
                ),

                const Spacer(),

                _DailyMetric(
                  label: 'AVG/DAY',
                  value: _formatNumber(summary.averageValue),
                  unit: series.unit,
                ),

                const Spacer(),

                _DailyMetric(
                  label: 'MAX DAY',
                  value: _formatNumber(summary.maxValue),
                  unit: series.unit,
                ),
              ],
            )
          : Row(
              children: [
                _DailyMetric(
                  label: 'MIN',
                  value: _formatNumber(summary.minValue),
                  unit: series.unit,
                ),

                const Spacer(),

                _DailyMetric(
                  label: 'AVG',
                  value: _formatNumber(summary.averageValue),
                  unit: series.unit,
                ),

                const Spacer(),

                _DailyMetric(
                  label: 'MAX',
                  value: _formatNumber(summary.maxValue),
                  unit: series.unit,
                ),
              ],
            ),
    );
  }
}

class _DailyMetric extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _DailyMetric({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: .35,
          ),
        ),

        const SizedBox(width: 5),

        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFD2DEEC),
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),

        if (unit.trim().isNotEmpty) ...[
          const SizedBox(width: 3),

          Text(
            unit.trim(),
            style: const TextStyle(
              color: Color(0xFF71869F),
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

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

    return values.reduce(math.min);
  }

  static double? _maxOrNull(List<double> values) {
    if (values.isEmpty) {
      return null;
    }

    return values.reduce(math.max);
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

String _formatDailyValue(double? value) {
  if (value == null || !value.isFinite) {
    return '--';
  }

  final absolute = value.abs();

  if (absolute >= 1000000) {
    return NumberFormat('#,##0').format(value);
  }

  if (absolute >= 1000) {
    return NumberFormat('#,##0.00').format(value);
  }

  if (absolute >= 100) {
    return value.toStringAsFixed(2);
  }

  if (absolute >= 10) {
    return value.toStringAsFixed(3);
  }

  return value.toStringAsFixed(4);
}

String _compactAxisNumber(num value) {
  final number = value.toDouble();
  final absolute = number.abs();

  if (absolute >= 1000000) {
    return '${(number / 1000000).toStringAsFixed(1)}M';
  }

  if (absolute >= 1000) {
    return '${(number / 1000).toStringAsFixed(1)}K';
  }

  if (absolute >= 100) {
    return number.toStringAsFixed(0);
  }

  if (absolute >= 10) {
    return number.toStringAsFixed(1);
  }

  return number.toStringAsFixed(2);
}

String _formatNumber(double? value) {
  if (value == null || !value.isFinite) {
    return '--';
  }

  final absolute = value.abs();

  if (absolute >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(2)}M';
  }

  if (absolute >= 1000) {
    return '${(value / 1000).toStringAsFixed(2)}K';
  }

  if (absolute >= 100) {
    return value.toStringAsFixed(1);
  }

  if (absolute >= 10) {
    return value.toStringAsFixed(2);
  }

  return value.toStringAsFixed(3);
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
