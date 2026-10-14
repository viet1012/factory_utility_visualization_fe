import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../shared/charts/axis_planner.dart';
import '../../shared/charts/chart_animation.dart';
import '../../shared/charts/chart_downsample.dart';
import '../../shared/charts/chart_hover_style.dart';
import '../../shared/charts/chart_thresholds.dart';
import '../../shared/charts/signal_chart_spec.dart';
import '../../shared/charts/signal_thresholds.dart';
import '../../shared/charts/value_format.dart';
import '../../shared/widgets/chart_loading_widgets.dart';
import '../../shared/widgets/chart_state_widgets.dart';
import '../../shared/widgets/debounced_layout_builder.dart';
import '../../shared/widgets/lazy_chart_gate.dart';
import '../../utility_catalog/api/signal_history_repository.dart';
import '../../utility_catalog/models/signal_history_models.dart';
import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_widgets.dart';
import '../../shared/widgets/scada_panel_frame.dart';
import '../controllers/utility_chart_catalog_controller.dart';
import '../controllers/utility_daily_chart_controller.dart';
import '../models/utility_daily_models.dart';

class UtilityDailyChartGrid extends StatelessWidget {
  final List<SignalChartConfig> charts;

  final String facId;
  final String cate;

  /// DEVICE dang chon (ALL hoac device that).
  final String selectedBox;

  const UtilityDailyChartGrid({
    super.key,
    required this.charts,
    required this.facId,
    required this.cate,
    required this.selectedBox,
  });

  List<SignalChartConfig> _displayCharts() {
    final selected = selectedBox.trim().toUpperCase();
    final showAll = selected.isEmpty || selected == 'ALL';

    return [
      for (final chart in charts)
        if (showAll || chart.boxDeviceId.trim().toUpperCase() == selected)
          chart,
    ]..sort(_compareCharts);
  }

  @override
  Widget build(BuildContext context) {
    final visibleCharts = _displayCharts();

    if (visibleCharts.isEmpty) {
      return const _DailyGridEmptyState();
    }

    // Resize: giu grid cu 150ms roi moi tinh lai so cot / chieu cao.
    return DebouncedLayoutBuilder(
      builder: (context, constraints) {
        final columnCount = _columnCount(constraints.maxWidth);

        final cardHeight = _cardHeight(
          availableHeight: constraints.maxHeight,
          itemCount: visibleCharts.length,
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
          itemCount: visibleCharts.length,
          itemBuilder: (context, index) {
            final chart = visibleCharts[index];

            // Key on dinh theo signal: refresh / resize khong tao lai the.
            return RepaintBoundary(
              key: ValueKey('${chart.boxDeviceId}|${chart.plcAddress}'),
              child: _DailySignalChartCard(
                chart: chart,
                facId: facId,
                cate: cate,
              ),
            );
          },
        );
      },
    );
  }

  int _compareCharts(SignalChartConfig first, SignalChartConfig second) {
    final deviceCompare = first.boxDeviceId.toUpperCase().compareTo(
      second.boxDeviceId.toUpperCase(),
    );

    if (deviceCompare != 0) {
      return deviceCompare;
    }

    final orderCompare = _signalOrder(
      first.nameEn ?? '',
    ).compareTo(_signalOrder(second.nameEn ?? ''));

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

const Color _alertColor = Colors.redAccent;

String _errorMessage(Object? error) {
  if (error is SignalHistoryRequestException) return error.message;
  if (error is TimeoutException) return 'Request timed out. Please try again.';
  return 'Please check your connection or try again.';
}

/// Phan cua [DailyBoxState] ma mot the can.
class _CardVm {
  final DailyBoxState state;
  final DailySignalSeries? series;

  const _CardVm(this.state, this.series);

  @override
  bool operator ==(Object other) {
    return other is _CardVm &&
        identical(other.series, series) &&
        identical(other.state.data, state.data) &&
        other.state.loading == state.loading &&
        other.state.error == state.error;
  }

  @override
  int get hashCode => Object.hash(series, state.loading, state.error);
}

class _DailySignalChartCard extends StatelessWidget {
  final SignalChartConfig chart;

  final String facId;
  final String cate;

  const _DailySignalChartCard({
    required this.chart,
    required this.facId,
    required this.cate,
  });

  String get _box => chart.boxDeviceId.trim();

  String get _plc => chart.plcAddress.trim();

  @override
  Widget build(BuildContext context) {
    final theme = ChartThemes.byCate(cate);

    return Selector<UtilityDailyChartController, _CardVm>(
      selector: (_, controller) {
        final state = controller.boxState(_box);
        return _CardVm(state, state.data?.signals[_plc]);
      },
      builder: (context, vm, _) {
        final state = vm.state;
        final series = vm.series;

        final spec = dailySpecOf(context, chart, series);

        final rawUnit = (series?.unit.isNotEmpty ?? false)
            ? series!.unit
            : (chart.unit ?? '');
        final unit = spec.resolveUnit(rawUnit);

        final name = _displaySignalName(
          (series?.name.isNotEmpty ?? false) ? series!.name : chart.nameEn ?? '',
        );

        final points = series?.points ?? const <DailyPoint>[];
        final latestPoint = points.isEmpty ? null : points.last;

        final breachCount = series?.visibleBreachCount ?? 0;

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
                  boxDeviceId: name,
                  plcAddress: _plc,
                  unit: unit.isEmpty ? null : unit,
                  isLoading: state.loading,
                  hasError: state.error != null,
                  err: state.error == null ? null : _errorMessage(state.error),
                  breachCount: breachCount,
                  lastBreachAt: series?.lastBreachAt,
                  breachColor: breachCount > 0
                      ? breachBadgeColor(
                          points.map(series!.breachLevel),
                          series.thresholds,
                        )
                      : _alertColor,
                ),

                _DailyLatestInfoBar(
                  latestPoint: latestPoint,
                  name: name,
                  unit: unit,
                  spec: spec,
                  boxDeviceId: _box,
                  color: theme.accent,
                  thresholds: (series?.showThresholds ?? false)
                      ? series!.thresholds
                      : const <SignalThreshold>[],
                ),

                Expanded(child: _buildBody(context, vm, spec, unit, theme)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    _CardVm vm,
    SignalChartSpec spec,
    String unit,
    ChartTheme theme,
  ) {
    final state = vm.state;
    final series = vm.series;

    if (state.data == null) {
      if (state.error != null) {
        return ChartApiErrorState(
          color: theme.line,
          message: _errorMessage(state.error),
          onRetry: () => context.read<UtilityDailyChartController>().retry(),
        );
      }

      return ChartBodySkeleton(color: theme.line);
    }

    if (series == null || series.points.isEmpty) {
      return const _DailyChartEmptyState();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: LazyChartGate(
        placeholder: ChartBodySkeleton(color: theme.line),
        builder: (_) => _DailyChart(
          series: series,
          spec: spec,
          unit: unit,
          points: series.points,
          lineColor: theme.line,
        ),
      ),
    );
  }
}

/// Daily: COUNTER ve cot theo delta cua ngay, con lai ve lineBand theo
/// ngay; truc / so le / format lay tu SignalChartSpec. Code / unit / kind
/// lay tu response, thieu thi qua /chart-catalog theo (box, plc).
SignalChartSpec dailySpecOf(
  BuildContext context,
  SignalChartConfig chart,
  DailySignalSeries? series,
) {
  final spec = context
      .read<UtilityChartCatalogController>()
      .resolveSpecForSignal(
        chart.boxDeviceId,
        chart.plcAddress,
        code: series?.code,
        unit: series?.unit,
        kind: series?.kind.name.toUpperCase(),
        name: series?.name,
      );

  if (spec.style == ChartStyle.bar || spec.style == ChartStyle.lineBand) {
    return spec;
  }

  return spec.copyWith(style: ChartStyle.lineBand);
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
  final DailyPoint? latestPoint;
  final String name;
  final String unit;
  final SignalChartSpec spec;
  final String boxDeviceId;
  final Color color;

  /// Nguong cho chip (rong voi COUNTER / STATUS).
  final List<SignalThreshold> thresholds;

  const _DailyLatestInfoBar({
    required this.latestPoint,
    required this.name,
    required this.unit,
    required this.spec,
    required this.boxDeviceId,
    required this.color,
    required this.thresholds,
  });

  @override
  Widget build(BuildContext context) {
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
            child: Icon(_dailySignalStyle(name, '').icon, color: color, size: 17),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    formatValue(latestPoint?.value, decimals: spec.decimals),
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

                // ANALOG co nguong: khoang cach toi nguong gan nhat.
                if (thresholds.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: ThresholdChip(
                      thresholds: thresholds,
                      value: latestPoint?.value,
                      unit: unit,
                      decimals: spec.decimals,
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
                DateFormat('dd/MMM', 'en_US').format(latestPoint!.day),

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

/// Cham vuot nguong tren line: gia tri vi pham + level.
class _BreachMark {
  final DateTime day;
  final double value;
  final int level;

  const _BreachMark(this.day, this.value, this.level);
}

class _DailyChart extends StatefulWidget {
  final DailySignalSeries series;
  final SignalChartSpec spec;
  final String unit;
  final List<DailyPoint> points;
  final Color lineColor;

  const _DailyChart({
    required this.series,
    required this.spec,
    required this.unit,
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
  Map<int, DailyPoint> _pointsByDay = const {};

  bool get _energy => widget.spec.style == ChartStyle.bar;

  DailyPoint? get _selectedPoint {
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

  Widget _hoverCard(DailyPoint point) {
    final hasRange = !_energy && point.hasRange;

    return ChartHoverCard(
      title: _hoverDateFormat.format(point.day),
      rows: ChartHoverStyle.rows(
        kind: _energy ? HoverKind.counter : HoverKind.analog,
        value: point.value,
        unit: widget.unit,
        decimals: widget.spec.decimals,
        min: hasRange ? point.min : null,
        max: hasRange ? point.max : null,
        samples: point.count > 0 ? point.count : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final energy = _energy;
    final spec = widget.spec;
    final series = widget.series;
    final analog = series.kind == SignalKind.analog;

    final hasBand = !energy && widget.points.any((p) => p.hasRange);

    final points = downsampleMinMax(
      widget.points,
      value: (DailyPoint p) => p.value,
      low: hasBand ? (DailyPoint p) => p.min ?? p.value : null,
      high: hasBand ? (DailyPoint p) => p.max ?? p.value : null,
    );

    _pointsByDay = {
      for (final point in points) point.day.millisecondsSinceEpoch: point,
    };

    final axis = planAxis(
      values: [
        for (final point in points) ...[
          point.value,
          if (hasBand) ...[point.min, point.max],
        ],
      ],
      spec: spec,
      thresholds: series.showThresholds ? series.thresholds : const [],
    );

    // Vuot nguong: cot to mau level, line them cham mau level.
    final levels = <int, int>{
      for (final point in points)
        if (series.breachLevel(point) case final level?)
          point.day.millisecondsSinceEpoch: level,
    };

    final breaches = energy
        ? const <_BreachMark>[]
        : <_BreachMark>[
            for (final point in points)
              if (levels[point.day.millisecondsSinceEpoch] case final level?)
                _BreachMark(
                  point.day,
                  breachMarkValue(
                    series.thresholds,
                    level,
                    value: point.value!,
                    min: analog ? point.min : null,
                    max: analog ? point.max : null,
                  ),
                  level,
                ),
          ];

    final animationMs = _animation.duration();

    final chart = SfCartesianChart(
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
        majorTickLines: const MajorTickLines(size: 3, color: Color(0xFF334155)),
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
        labelStyle: const TextStyle(color: Color(0xFF71869F), fontSize: 12),
        axisLabelFormatter: (AxisLabelRenderDetails details) {
          return ChartAxisLabel(axis.label(details.value), details.textStyle);
        },
        plotBands: thresholdPlotBands(axis, widget.unit),
      ),

      series: <CartesianSeries<dynamic, DateTime>>[
        if (energy)
          ..._buildEnergySeries(points, animationMs, levels)
        else
          ..._buildMeasuredSeries(points, animationMs, hasBand: hasBand),
        if (breaches.isNotEmpty)
          ScatterSeries<_BreachMark, DateTime>(
            dataSource: breaches,
            animationDuration: animationMs,
            enableTrackball: false,
            enableTooltip: false,
            color: _alertColor,
            pointColorMapper: (mark, _) => thresholdLevelColor(mark.level),
            xValueMapper: (mark, _) => mark.day,
            yValueMapper: (mark, _) => mark.value,
            markerSettings: const MarkerSettings(
              height: 7,
              width: 7,
              shape: DataMarkerType.circle,
              borderWidth: 0,
            ),
          ),
      ],
    );

    return Column(
      children: [
        _DailySelectedPointPanel(
          point: _selectedPoint,
          unit: widget.unit,
          spec: spec,
          energy: energy,
          color: widget.lineColor,
        ),

        const SizedBox(height: 4),

        // Nguong qua xa du lieu: khong keo truc, chi hien nhan o mep.
        Expanded(child: withOffscaleThresholds(chart, axis, widget.unit)),
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

  List<CartesianSeries<DailyPoint, DateTime>> _buildEnergySeries(
    List<DailyPoint> points,
    double animationMs,
    Map<int, int> levels,
  ) {
    Color barColor(DailyPoint point) {
      final level = levels[point.day.millisecondsSinceEpoch];
      return level == null
          ? widget.lineColor.withValues(alpha: .78)
          : thresholdLevelColor(level);
    }

    return [
      ColumnSeries<DailyPoint, DateTime>(
        dataSource: points,
        xValueMapper: (point, _) => point.day,
        yValueMapper: (point, _) => point.value,

        // onPointTap nằm trên Series,
        // không nằm trên SfCartesianChart.
        onPointTap: _handlePointTap,

        name: 'Daily consumption',

        color: widget.lineColor.withValues(alpha: .78),
        pointColorMapper: (point, _) => barColor(point),
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
              (data as DailyPoint).value,
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

  List<CartesianSeries<DailyPoint, DateTime>> _buildMeasuredSeries(
    List<DailyPoint> points,
    double animationMs, {
    required bool hasBand,
  }) {
    return [
      if (hasBand)
        RangeAreaSeries<DailyPoint, DateTime>(
          dataSource: points,
          xValueMapper: (point, _) => point.day,
          lowValueMapper: (point, _) => point.min,
          highValueMapper: (point, _) => point.max,
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

      LineSeries<DailyPoint, DateTime>(
        dataSource: points,
        xValueMapper: (point, _) => point.day,
        yValueMapper: (point, _) => point.value,

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
  final DailyPoint? point;
  final String unit;
  final SignalChartSpec spec;
  final bool energy;
  final Color color;

  const _DailySelectedPointPanel({
    required this.point,
    required this.unit,
    required this.spec,
    required this.energy,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final selectedPoint = point;
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
                    value: selectedPoint.value,
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
                          value: selectedPoint.value,
                          unit: unit,
                          decimals: decimals,
                          color: color,
                        ),
                      ),

                      _IosMetricDivider(),

                      Expanded(
                        child: _SelectedMetric(
                          label: 'MIN',
                          value: selectedPoint.min,
                          unit: unit,
                          decimals: decimals,
                        ),
                      ),

                      _IosMetricDivider(),

                      Expanded(
                        child: _SelectedMetric(
                          label: 'MAX',
                          value: selectedPoint.max,
                          unit: unit,
                          decimals: decimals,
                        ),
                      ),

                      _IosMetricDivider(),

                      Expanded(
                        child: _SelectedMetric(
                          label: 'LATEST',
                          value: selectedPoint.last,
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
  final DailyPoint point;
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
        DateFormat('dd/MMM', 'en_US').format(point.day),
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
