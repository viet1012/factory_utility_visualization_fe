import 'dart:async';

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
import '../../shared/widgets/lazy_chart_gate.dart';
import '../../shared/widgets/scada_panel_frame.dart';
import '../../utility_catalog/api/signal_history_repository.dart';
import '../../utility_catalog/models/signal_history_models.dart';
import '../../utility_catalog/widgets/signal_chart/signal_chart_palette.dart'
    show statusCodeColor;
import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_widgets.dart';
import '../controllers/utility_chart_catalog_controller.dart';
import '../controllers/utility_hourly_chart_controller.dart';
import '../models/utility_hourly_models.dart';

// ============================================================
// FORMAT
// ============================================================

final DateFormat _hourAxisFormat = DateFormat('HH:00');
final DateFormat _dayAxisFormat = DateFormat('dd/MM');
final DateFormat _tooltipFormat = DateFormat('dd/MM HH:00');
final DateFormat _latestFormat = DateFormat('dd/MM HH:00');
final DateFormat _hourEndFormat = DateFormat('HH:00');

/// Spec theo code / unit / kind cua response, thieu thi qua catalog.
SignalChartSpec _specOf(
  BuildContext context,
  String boxDeviceId,
  HourlySignalSeries series,
) {
  return context.read<UtilityChartCatalogController>().resolveSpecForSignal(
    boxDeviceId,
    series.plcAddress,
    code: series.code,
    unit: series.unit,
    kind: series.kind.name.toUpperCase(),
    name: series.name,
  );
}

HoverKind _hoverKindOf(SignalKind kind) {
  return switch (kind) {
    SignalKind.analog => HoverKind.analog,
    SignalKind.counter => HoverKind.counter,
    SignalKind.status => HoverKind.status,
  };
}

/// An nhan khong nam o gio boi so cua 3 (00:00, 03:00, 06:00...).
ChartAxisLabel _hourAxisLabel(AxisLabelRenderDetails details) {
  final time = DateTime.fromMillisecondsSinceEpoch(details.value.toInt());
  final aligned = time.minute == 0 && time.hour % 3 == 0;

  return ChartAxisLabel(aligned ? details.text : '', details.textStyle);
}

DateTime _floorHour(DateTime time) {
  return DateTime(time.year, time.month, time.day, time.hour);
}

const Color _alertColor = Colors.redAccent;
const Duration _halfHour = Duration(minutes: 30);
const Duration _oneHour = Duration(hours: 1);

String _errorMessage(Object? error) {
  if (error is SignalHistoryRequestException) return error.message;
  if (error is TimeoutException) return 'Request timed out. Please try again.';
  return 'Please check your connection or try again.';
}

// ============================================================
// PANEL
// ============================================================

/// Phan cua [HourlyBoxState] ma mot the can: state cua box (loading /
/// error / refreshing) va series cua chinh PLC nay.
class _PanelVm {
  final HourlyBoxState state;
  final HourlySignalSeries? series;

  const _PanelVm(this.state, this.series);

  factory _PanelVm.of(HourlyBoxState state, String plcAddress) {
    return _PanelVm(state, state.data?.signals[plcAddress]);
  }

  @override
  bool operator ==(Object other) {
    return other is _PanelVm &&
        identical(other.series, series) &&
        other.state.loading == state.loading &&
        other.state.error == state.error &&
        identical(other.state.data, state.data);
  }

  @override
  int get hashCode => Object.hash(series, state.loading, state.error);
}

class UtilityHourlyChartPanel extends StatelessWidget {
  final String facId;
  final String cate;
  final String boxDeviceId;
  final String plcAddress;

  /// Ten / unit tu catalog, dung khi chua co du lieu history.
  final String? signalName;
  final String? unit;

  const UtilityHourlyChartPanel({
    super.key,
    required this.facId,
    required this.cate,
    required this.boxDeviceId,
    required this.plcAddress,
    this.signalName,
    this.unit,
  });

  ChartTheme get _theme => ChartThemes.byCate(cate);

  @override
  Widget build(BuildContext context) {
    // Chi lang nghe phan du lieu cua chinh signal nay trong box.
    return Selector<UtilityHourlyChartController, _PanelVm>(
      selector: (_, controller) =>
          _PanelVm.of(controller.boxState(boxDeviceId), plcAddress),
      builder: (context, vm, _) {
        final state = vm.state;
        final series = vm.series;
        final spec = series == null
            ? null
            : _specOf(context, boxDeviceId, series);

        final name = (series?.name.isNotEmpty ?? false)
            ? series!.name
            : (signalName?.trim().isNotEmpty ?? false)
            ? signalName!.trim()
            : plcAddress;

        final rawUnit = (series?.unit.isNotEmpty ?? false)
            ? series!.unit
            : (unit ?? '');
        final resolvedUnit = spec?.resolveUnit(rawUnit) ?? rawUnit;

        final breachCount = series?.visibleBreachCount ?? 0;

        return RepaintBoundary(
          child: ScadaPanelFrame(
            color: _theme.accent,
            child: Container(
              decoration: _panelDecoration(_theme),
              clipBehavior: Clip.hardEdge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UtilityInfoBoxWidgets.header(
                    facilityColor: _theme.fillTop,
                    facTitle: facId,
                    boxDeviceId: name,
                    plcAddress: plcAddress,
                    unit: resolvedUnit,
                    isLoading: state.loading,
                    hasError: state.error != null,
                    err: state.error == null
                        ? null
                        : _errorMessage(state.error),
                    breachCount: breachCount,
                    lastBreachAt: series?.lastBreachAt,
                    breachColor: breachCount > 0
                        ? breachBadgeColor(
                            series!.points.map(series.breachLevel),
                            series.thresholds,
                          )
                        : _alertColor,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: _buildBody(context, state, series, spec),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    HourlyBoxState state,
    HourlySignalSeries? series,
    SignalChartSpec? spec,
  ) {
    final data = state.data;

    if (data == null) {
      if (state.error != null) {
        return ChartApiErrorState(
          color: _theme.line,
          message: _errorMessage(state.error),
          onRetry: () => context.read<UtilityHourlyChartController>().retry(),
        );
      }

      // Lan dau: skeleton (dang tai hoac sap tai).
      return ChartBodySkeleton(color: _theme.line);
    }

    final Widget content;

    if (series == null || spec == null) {
      content = EmptyChartState(
        icon: Icons.schedule_rounded,
        title: 'No Hourly Data',
        message: 'No hourly history for $plcAddress in this range.',
        color: _theme.line,
      );
    } else if (series.parseError != null) {
      content = EmptyChartState(
        icon: Icons.report_problem_outlined,
        title: 'Invalid Signal Data',
        message: 'Hourly data for $plcAddress could not be parsed.',
        color: _theme.line,
      );
    } else if (series.valuedPoints.isEmpty) {
      content = EmptyChartState(
        icon: Icons.schedule_rounded,
        title: 'No Hourly Data',
        message: 'No samples recorded in this range.',
        color: _theme.line,
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HourlySummaryBar(series: series, spec: spec, theme: _theme),
          const SizedBox(height: 6),
          Expanded(
            child: LazyChartGate(
              placeholder: ChartBodySkeleton(
                color: _theme.line,
                withSummary: false,
              ),
              builder: (_) => _HourlyChart(
                series: series,
                spec: spec,
                data: data,
                theme: _theme,
              ),
            ),
          ),
        ],
      );
    }

    // Doi range: giu chart cu mo kem progress bar.
    return ChartBusyOverlay(
      busy: state.refreshing,
      color: _theme.line,
      child: content,
    );
  }

  BoxDecoration _panelDecoration(ChartTheme theme) {
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
}

// ============================================================
// SUMMARY
// ============================================================

class _HourlySummaryBar extends StatelessWidget {
  final HourlySignalSeries series;
  final SignalChartSpec spec;
  final ChartTheme theme;

  const _HourlySummaryBar({
    required this.series,
    required this.spec,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final summary = HourlySeriesSummary.of(series);
    final unit = spec.resolveUnit(series.unit);
    final latest = summary.latest;

    String fmt(double? value) => formatValue(value, decimals: spec.decimals);
    String withUnit(double? value, String unit) =>
        formatWithUnit(value, unit, decimals: spec.decimals);

    final latestText = switch (series.kind) {
      SignalKind.status =>
        latest?.value == null
            ? kMissingValue
            : 'Code ${latest!.value!.round()}',
      SignalKind.counter => withUnit(
        latest?.value,
        unit.isEmpty ? '' : '$unit/h',
      ),
      SignalKind.analog => withUnit(latest?.value, unit),
    };

    final metrics = <Widget>[
      if (series.kind == SignalKind.analog) ...[
        _Metric(label: 'Min', value: fmt(summary.min)),
        _Metric(label: 'Avg', value: fmt(summary.avg)),
        _Metric(label: 'Max', value: fmt(summary.max)),
      ],
      if (series.kind == SignalKind.counter)
        _Metric(
          label: 'Total',
          value: withUnit(summary.total, unit),
          highlight: theme.line,
        ),
      if (series.kind == SignalKind.status)
        _Metric(label: 'Changes', value: '${summary.statusChanges}'),
    ];

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        children: [
          if (series.kind == SignalKind.status && latest?.value != null)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: statusCodeColor(latest!.value!.round()),
                shape: BoxShape.circle,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(theme.icon, size: 18, color: theme.iconColor),
            ),
          Flexible(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        latestText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                    // ANALOG co nguong: khoang cach toi nguong gan nhat.
                    if (series.showThresholds) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: ThresholdChip(
                          thresholds: series.thresholds,
                          value: latest?.value,
                          unit: unit,
                          decimals: spec.decimals,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  latest == null
                      ? 'Latest hour'
                      : 'Latest hour · ${_latestFormat.format(latest.ts)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .52),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 20,
            color: Colors.white.withValues(alpha: .12),
          ),
          const SizedBox(width: 4),
          for (final metric in metrics) Flexible(flex: 2, child: metric),
          if (series.isSnapshot) ...[
            const SizedBox(width: 6),
            const _SnapshotNote(),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color? highlight;

  const _Metric({required this.label, required this.value, this.highlight});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .46),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
              height: 1.2,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: highlight ?? Colors.white.withValues(alpha: .86),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotNote extends StatelessWidget {
  const _SnapshotNote();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Ranges over 24h show one snapshot value per hour (no min/max).',
      child: Text(
        'hourly snapshot',
        style: TextStyle(
          color: Colors.white.withValues(alpha: .42),
          fontSize: 9.5,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ============================================================
// CHART
// ============================================================

class _BreachMark {
  final HourlyPoint point;
  final double value;
  final int level;

  const _BreachMark(this.point, this.value, this.level);
}

class _HourlyChart extends StatefulWidget {
  final HourlySignalSeries series;
  final SignalChartSpec spec;
  final HourlyBoxData data;
  final ChartTheme theme;

  const _HourlyChart({
    required this.series,
    required this.spec,
    required this.data,
    required this.theme,
  });

  @override
  State<_HourlyChart> createState() => _HourlyChartState();
}

class _HourlyChartState extends State<_HourlyChart> {
  late final TrackballBehavior _trackball;
  final FirstPaintAnimation _animation = FirstPaintAnimation();

  /// Bucket theo moc gio (ms) de trackball tim lai diem goc tu x.
  Map<int, HourlyPoint> _pointsByHour = const {};

  @override
  void initState() {
    super.initState();

    _trackball = ChartHoverStyle.trackball(
      markerColor: widget.theme.line,
      builder: (context, details) {
        final point = _pointAt(details.point?.x);
        if (point == null) return const SizedBox.shrink();

        return _HourlyTooltip(
          point: point,
          series: widget.series,
          spec: widget.spec,
        );
      },
    );
  }

  HourlyPoint? _pointAt(Object? x) {
    final time = switch (x) {
      DateTime value => value,
      num value => DateTime.fromMillisecondsSinceEpoch(value.toInt()),
      _ => null,
    };
    if (time == null) return null;

    // Cot (bar) dat giua gio: floor ve dau gio.
    return _pointsByHour[_floorHour(time).millisecondsSinceEpoch];
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    final spec = widget.spec;
    final theme = widget.theme;
    final window = widget.data.window;
    final multiDay = widget.data.range.isMultiDay;

    _pointsByHour = {
      for (final point in series.points)
        _floorHour(point.ts).millisecondsSinceEpoch: point,
    };

    final unit = spec.resolveUnit(series.unit);
    final animationMs = _animation.duration();
    final style = spec.style;
    final isBar = style == ChartStyle.bar;
    final showBand = style == ChartStyle.lineBand && series.showRangeBand;
    final showThresholds = series.showThresholds;

    final points = downsampleMinMax(
      series.points,
      value: (point) => point.value,
      low: showBand ? (HourlyPoint point) => point.min ?? point.value : null,
      high: showBand ? (HourlyPoint point) => point.max ?? point.value : null,
    );

    final axis = planAxis(
      values: [
        for (final point in points) ...[
          point.value,
          if (showBand) ...[point.min, point.max],
        ],
      ],
      spec: spec,
      thresholds: showThresholds ? series.thresholds : const [],
    );

    // Level vuot nguong theo bucket: cot to mau level, line them cham mau.
    final levels = <int, int>{
      for (final point in series.points)
        if (series.breachLevel(point) case final level?)
          point.ts.millisecondsSinceEpoch: level,
    };

    Color barColor(HourlyPoint point) {
      final level = levels[point.ts.millisecondsSinceEpoch];
      return level == null ? theme.line : thresholdLevelColor(level);
    }

    final analog = series.kind == SignalKind.analog;
    final breaches = isBar
        ? const <_BreachMark>[]
        : <_BreachMark>[
            for (final point in series.points)
              if (levels[point.ts.millisecondsSinceEpoch] case final level?)
                _BreachMark(
                  point,
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

    /*
     * Truc X phu ca range (khong chi phan co du lieu), de bucket dau chua
     * co du lieu chi la khoang trong, khong to xam.
     * Bar: cot dat giua gio [ts, ts+1h) nen truc mo rong them 1h.
     */
    final xMin = multiDay ? window.from : _floorHour(window.from);
    var xMax = _floorHour(window.to);
    if (isBar) xMax = xMax.add(_oneHour);
    if (!xMax.isAfter(xMin)) xMax = xMin.add(_oneHour);

    // Diem le (hai ben la bucket rong) chi thay duoc khi co marker.
    final showMarkers = !multiDay;

    const gap = EmptyPointSettings(mode: EmptyPointMode.gap);

    final chart = SfCartesianChart(
      margin: const EdgeInsets.fromLTRB(0, 6, 6, 0),
      plotAreaBorderWidth: 1,
      plotAreaBorderColor: Colors.white.withValues(alpha: .12),
      trackballBehavior: _trackball,
      primaryXAxis: DateTimeAxis(
        minimum: xMin,
        maximum: xMax,
        intervalType: multiDay
            ? DateTimeIntervalType.days
            : DateTimeIntervalType.hours,
        /*
         * Today / 24h: nhan o gio boi so cua 3 tinh tu 00:00, ke ca khi 24h
         * bat dau o gio le (vd 10:37 -> nhan dau 12:00). Syncfusion 30.1.42
         * da tu canh moc nhan ve floor(hour / interval) * interval theo gio
         * dia phuong va bo nhan truoc minimum (DateTimeAxis._niceStart);
         * _hourAxisLabel chi la chot chan neu cach canh do thay doi.
         */
        interval: multiDay ? 1 : 3,
        dateFormat: multiDay ? _dayAxisFormat : _hourAxisFormat,
        axisLabelFormatter: multiDay ? null : _hourAxisLabel,
        edgeLabelPlacement: EdgeLabelPlacement.shift,
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withValues(alpha: .08),
        ),
        axisLine: AxisLine(
          color: Colors.white.withValues(alpha: .15),
          width: 1,
        ),
        majorTickLines: const MajorTickLines(size: 0),
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: .72),
          fontSize: 11,
        ),
      ),
      primaryYAxis: NumericAxis(
        minimum: axis.min,
        maximum: axis.max,
        interval: axis.interval,
        axisLabelFormatter: (details) => ChartAxisLabel(
          axis.label(details.value),
          TextStyle(color: Colors.white.withValues(alpha: .72), fontSize: 11),
        ),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withValues(alpha: .08),
        ),
        axisLine: AxisLine(
          color: Colors.white.withValues(alpha: .15),
          width: 1,
        ),
        majorTickLines: const MajorTickLines(size: 0),
        plotBands: thresholdPlotBands(axis, unit),
      ),
      series: <CartesianSeries<dynamic, DateTime>>[
        if (showBand)
          RangeAreaSeries<HourlyPoint, DateTime>(
            dataSource: points,
            animationDuration: animationMs,
            enableTooltip: false,
            enableTrackball: false,
            color: theme.line.withValues(alpha: .16),
            borderWidth: 0,
            xValueMapper: (point, _) => point.ts,
            highValueMapper: (point, _) => point.hasValue ? point.max : null,
            lowValueMapper: (point, _) => point.hasValue ? point.min : null,
            emptyPointSettings: gap,
          ),
        switch (style) {
          ChartStyle.bar => ColumnSeries<HourlyPoint, DateTime>(
            dataSource: points,
            animationDuration: animationMs,
            width: .7,
            color: theme.line,
            // Gradient de len pointColorMapper: chi dung khi khong cot nao
            // vuot nguong.
            gradient: levels.isEmpty
                ? LinearGradient(
                    colors: [theme.line, theme.line.withValues(alpha: .45)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            pointColorMapper: (point, _) => barColor(point),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            xValueMapper: (point, _) => point.ts.add(_halfHour),
            yValueMapper: (point, _) => point.value,
            emptyPointSettings: gap,
          ),
          ChartStyle.step => StepLineSeries<HourlyPoint, DateTime>(
            dataSource: points,
            animationDuration: animationMs,
            width: 2.2,
            color: theme.line,
            xValueMapper: (point, _) => point.ts,
            yValueMapper: (point, _) => point.value,
            // Moi doan to theo ma trang thai, cung mau voi tab Catalog.
            pointColorMapper: (point, _) => point.value == null
                ? theme.line
                : statusCodeColor(point.value!.round()),
            markerSettings: MarkerSettings(
              isVisible: showMarkers,
              height: 3,
              width: 3,
              borderWidth: 0,
            ),
            emptyPointSettings: gap,
          ),
          ChartStyle.area => AreaSeries<HourlyPoint, DateTime>(
            dataSource: points,
            animationDuration: animationMs,
            gradient: LinearGradient(
              colors: [
                theme.line.withValues(alpha: .42),
                theme.line.withValues(alpha: .04),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderColor: theme.line,
            borderWidth: 2,
            borderDrawMode: BorderDrawMode.top,
            xValueMapper: (point, _) => point.ts,
            yValueMapper: (point, _) => point.value,
            markerSettings: MarkerSettings(
              isVisible: showMarkers,
              height: 3,
              width: 3,
              color: theme.line,
              borderWidth: 0,
            ),
            emptyPointSettings: gap,
          ),
          ChartStyle.lineBand => LineSeries<HourlyPoint, DateTime>(
            dataSource: points,
            animationDuration: animationMs,
            width: 2,
            color: theme.line,
            xValueMapper: (point, _) => point.ts,
            yValueMapper: (point, _) => point.value,
            markerSettings: MarkerSettings(
              isVisible: showMarkers,
              height: 3,
              width: 3,
              color: theme.line,
              borderWidth: 0,
            ),
            emptyPointSettings: gap,
          ),
        },
        if (breaches.isNotEmpty)
          ScatterSeries<_BreachMark, DateTime>(
            dataSource: breaches,
            animationDuration: animationMs,
            enableTrackball: false,
            color: _alertColor,
            pointColorMapper: (mark, _) => thresholdLevelColor(mark.level),
            xValueMapper: (mark, _) => mark.point.ts,
            yValueMapper: (mark, _) => mark.value,
            markerSettings: const MarkerSettings(
              height: 6,
              width: 6,
              shape: DataMarkerType.circle,
              borderWidth: 0,
            ),
          ),
      ],
    );

    // Nguong qua xa du lieu: khong keo truc, chi hien nhan o mep.
    return withOffscaleThresholds(chart, axis, unit);
  }
}

// ============================================================
// TOOLTIP
// ============================================================

class _HourlyTooltip extends StatelessWidget {
  final HourlyPoint point;
  final HourlySignalSeries series;
  final SignalChartSpec spec;

  const _HourlyTooltip({
    required this.point,
    required this.series,
    required this.spec,
  });

  @override
  Widget build(BuildContext context) {
    final end = point.ts.add(_oneHour);

    return ChartHoverCard(
      title:
          '${_tooltipFormat.format(point.ts)} – '
          '${_hourEndFormat.format(end)}',
      rows: ChartHoverStyle.rows(
        kind: _hoverKindOf(series.kind),
        value: point.value,
        unit: spec.resolveUnit(series.unit),
        decimals: spec.decimals,
        min: point.hasRange ? point.min : null,
        max: point.hasRange ? point.max : null,
        samples: point.count,
        isSnapshot: series.isSnapshot,
      ),
    );
  }
}
