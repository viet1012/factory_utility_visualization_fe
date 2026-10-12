import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../shared/widgets/chart_state_widgets.dart';
import '../../shared/widgets/scada_panel_frame.dart';
import '../../utility_catalog/widgets/signal_chart/signal_chart_palette.dart'
    show statusCodeColor;
import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_widgets.dart';
import '../controllers/utility_hourly_chart_controller.dart';
import '../models/utility_hourly_models.dart';

// ============================================================
// FORMAT
// ============================================================

final NumberFormat _largeFormat = NumberFormat('#,##0.0');
final NumberFormat _mediumFormat = NumberFormat('0.00');
final NumberFormat _smallFormat = NumberFormat('0.####');

final DateFormat _hourAxisFormat = DateFormat('HH:00');
final DateFormat _dayAxisFormat = DateFormat('dd/MM');
final DateFormat _tooltipFormat = DateFormat('dd/MM HH:00');
final DateFormat _latestFormat = DateFormat('dd/MM HH:00');

String _fmt(double? value) {
  if (value == null || !value.isFinite) return '--';

  final magnitude = value.abs();
  if (magnitude >= 1000) return _largeFormat.format(value);
  if (magnitude >= 1) return _mediumFormat.format(value);
  return _smallFormat.format(value);
}

String _withUnit(double? value, String unit) {
  final text = _fmt(value);
  if (text == '--' || unit.trim().isEmpty) return text;
  return '$text ${unit.trim()}';
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
const Color _thresholdColor = Color(0xFFFCA5A5);
const Duration _halfHour = Duration(minutes: 30);

String _errorMessage(Object? error) {
  if (error is HourlyRequestException) return error.message;
  if (error is TimeoutException) return 'Request timed out. Please try again.';
  return 'Please check your connection or try again.';
}

// ============================================================
// PANEL
// ============================================================

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
    return Selector<UtilityHourlyChartController, HourlyBoxState>(
      selector: (_, controller) => controller.boxState(boxDeviceId),
      shouldRebuild: (previous, next) => !identical(previous, next),
      builder: (context, state, _) {
        final series = state.data?.signals[plcAddress];

        final name = (series?.name.isNotEmpty ?? false)
            ? series!.name
            : (signalName?.trim().isNotEmpty ?? false)
            ? signalName!.trim()
            : plcAddress;

        final resolvedUnit = (series?.unit.isNotEmpty ?? false)
            ? series!.unit
            : (unit ?? '');

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
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: _buildBody(context, state, series),
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
      return _HourlySkeleton(color: _theme.line);
    }

    final Widget content;

    if (series == null) {
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
          _HourlySummaryBar(series: series, theme: _theme, cate: cate),
          const SizedBox(height: 6),
          Expanded(
            child: _HourlyChart(series: series, data: data, theme: _theme),
          ),
        ],
      );
    }

    if (!state.refreshing) return content;

    // Doi range / poll: giu chart cu mo kem progress bar.
    return Stack(
      children: [
        Positioned.fill(child: Opacity(opacity: .4, child: content)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LinearProgressIndicator(
            minHeight: 2,
            color: _theme.line,
            backgroundColor: _theme.line.withValues(alpha: .12),
          ),
        ),
      ],
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
  final ChartTheme theme;
  final String cate;

  const _HourlySummaryBar({
    required this.series,
    required this.theme,
    required this.cate,
  });

  @override
  Widget build(BuildContext context) {
    final summary = HourlySeriesSummary.of(series);
    final unit = series.unit;
    final latest = summary.latest;

    final latestText = switch (series.kind) {
      HourlySignalKind.status =>
        latest?.value == null ? '--' : 'Code ${latest!.value!.round()}',
      HourlySignalKind.counter => _withUnit(
        latest?.value,
        unit.isEmpty ? '' : '$unit/h',
      ),
      HourlySignalKind.analog => _withUnit(latest?.value, unit),
    };

    final metrics = <Widget>[
      if (series.kind == HourlySignalKind.analog) ...[
        _Metric(label: 'Min', value: _fmt(summary.min)),
        _Metric(label: 'Avg', value: _fmt(summary.avg)),
        _Metric(label: 'Max', value: _fmt(summary.max)),
      ],
      if (series.kind == HourlySignalKind.counter)
        _Metric(
          label: 'Total',
          value: _withUnit(summary.total, unit),
          highlight: theme.line,
        ),
      if (series.kind == HourlySignalKind.status)
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
          if (series.kind == HourlySignalKind.status && latest?.value != null)
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
                Text(
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

  const _BreachMark(this.point, this.value);
}

class _YAxisPlan {
  final double? min;
  final double? max;
  final List<({double value, bool isHigh})> thresholds;

  const _YAxisPlan({this.min, this.max, this.thresholds = const []});
}

class _HourlyChart extends StatefulWidget {
  final HourlySignalSeries series;
  final HourlyBoxData data;
  final ChartTheme theme;

  const _HourlyChart({
    required this.series,
    required this.data,
    required this.theme,
  });

  @override
  State<_HourlyChart> createState() => _HourlyChartState();
}

class _HourlyChartState extends State<_HourlyChart> {
  late final TooltipBehavior _tooltipBehavior;

  @override
  void initState() {
    super.initState();

    _tooltipBehavior = TooltipBehavior(
      enable: true,
      color: const Color(0xFF0B1728),
      borderColor: const Color(0xFF20344D),
      borderWidth: 1,
      elevation: 0,
      canShowMarker: false,
      tooltipPosition: TooltipPosition.auto,
      builder: (data, point, series, pointIndex, seriesIndex) {
        final source = data is _BreachMark ? data.point : data;
        if (source is! HourlyPoint) return const SizedBox.shrink();

        return _HourlyTooltip(point: source, series: widget.series);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    final theme = widget.theme;
    final window = widget.data.window;
    final multiDay = widget.data.range.isMultiDay;

    final isCounter = series.kind == HourlySignalKind.counter;
    final isStatus = series.kind == HourlySignalKind.status;
    final showBand = series.showRangeBand;

    final breaches = series.showThresholds
        ? <_BreachMark>[
            for (final point in series.points)
              if (series.breachValue(point) case final value?)
                _BreachMark(point, value),
          ]
        : const <_BreachMark>[];

    final axis = _planYAxis(series, showBand: showBand);

    /*
     * Truc X phu ca range (khong chi phan co du lieu), de bucket dau chua
     * co du lieu chi la khoang trong, khong to xam.
     * COUNTER: cot dat giua gio [ts, ts+1h) nen truc mo rong them 1h.
     */
    final xMin = multiDay ? window.from : _floorHour(window.from);
    var xMax = _floorHour(window.to);
    if (isCounter) xMax = xMax.add(const Duration(hours: 1));
    if (!xMax.isAfter(xMin)) xMax = xMin.add(const Duration(hours: 1));

    // Diem le (hai ben la bucket rong) chi thay duoc khi co marker.
    final showMarkers = !multiDay;

    return SfCartesianChart(
      margin: const EdgeInsets.fromLTRB(0, 6, 6, 0),
      plotAreaBorderWidth: 1,
      plotAreaBorderColor: Colors.white.withValues(alpha: .12),
      tooltipBehavior: _tooltipBehavior,
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
        interval: isStatus ? 1 : null,
        axisLabelFormatter: (details) => ChartAxisLabel(
          isStatus
              ? details.value.round().toString()
              : _fmt(details.value.toDouble()),
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
        plotBands: [
          for (final line in axis.thresholds)
            PlotBand(
              start: line.value,
              end: line.value,
              color: Colors.transparent,
              borderColor: _thresholdColor,
              borderWidth: 1,
              dashArray: const <double>[4, 3],
              shouldRenderAboveSeries: true,
              text:
                  '${line.isHigh ? 'High' : 'Low'} '
                  '${_withUnit(line.value, series.unit)}',
              textStyle: const TextStyle(
                color: _thresholdColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
              horizontalTextAlignment: TextAnchor.end,
              verticalTextAlignment: line.isHigh
                  ? TextAnchor.end
                  : TextAnchor.start,
            ),
        ],
      ),
      series: <CartesianSeries<dynamic, DateTime>>[
        if (showBand)
          RangeAreaSeries<HourlyPoint, DateTime>(
            dataSource: series.points,
            animationDuration: 0,
            enableTooltip: false,
            color: theme.line.withValues(alpha: .16),
            borderWidth: 0,
            xValueMapper: (point, _) => point.ts,
            highValueMapper: (point, _) => point.hasValue ? point.max : null,
            lowValueMapper: (point, _) => point.hasValue ? point.min : null,
            emptyPointSettings: const EmptyPointSettings(
              mode: EmptyPointMode.gap,
            ),
          ),
        if (isCounter)
          ColumnSeries<HourlyPoint, DateTime>(
            dataSource: series.points,
            animationDuration: 0,
            width: .7,
            color: theme.line,
            gradient: LinearGradient(
              colors: [theme.line, theme.line.withValues(alpha: .45)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            xValueMapper: (point, _) => point.ts.add(_halfHour),
            yValueMapper: (point, _) => point.value,
            emptyPointSettings: const EmptyPointSettings(
              mode: EmptyPointMode.gap,
            ),
          )
        else if (isStatus)
          StepLineSeries<HourlyPoint, DateTime>(
            dataSource: series.points,
            animationDuration: 0,
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
            emptyPointSettings: const EmptyPointSettings(
              mode: EmptyPointMode.gap,
            ),
          )
        else
          LineSeries<HourlyPoint, DateTime>(
            dataSource: series.points,
            animationDuration: 0,
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
            emptyPointSettings: const EmptyPointSettings(
              mode: EmptyPointMode.gap,
            ),
          ),
        if (breaches.isNotEmpty)
          ScatterSeries<_BreachMark, DateTime>(
            dataSource: breaches,
            animationDuration: 0,
            color: _alertColor,
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
  }

  /// Truc Y luon co min/max ro rang; tin hieu phang duoc noi rong de
  /// Syncfusion khong chon interval nho hon sai so double (treo main thread).
  _YAxisPlan _planYAxis(HourlySignalSeries series, {required bool showBand}) {
    double? lo;
    double? hi;

    void include(double? value) {
      if (value == null || !value.isFinite) return;
      if (lo == null || value < lo!) lo = value;
      if (hi == null || value > hi!) hi = value;
    }

    final isCounter = series.kind == HourlySignalKind.counter;

    // COUNTER: cot bat dau tu 0.
    if (isCounter) include(0);

    for (final point in series.points) {
      include(point.value);
      if (showBand) {
        include(point.min);
        include(point.max);
      }
    }

    final dataLo = lo;
    final dataHi = hi;
    if (dataLo == null || dataHi == null) return const _YAxisPlan();

    if (series.kind == HourlySignalKind.status) {
      return _YAxisPlan(
        min: dataLo.floorToDouble() - .5,
        max: dataHi.ceilToDouble() + .5,
      );
    }

    final dataSpan = hourlyIsFlat(dataLo, dataHi)
        ? _flatSpan(dataLo, dataHi)
        : dataHi - dataLo;

    // Nguong chi keo vao truc khi nam gan dai du lieu (<= 2 x bien do).
    final thresholds = <({double value, bool isHigh})>[];

    if (series.showThresholds) {
      for (final line in [
        if (series.thresholdHigh case final high?) (value: high, isHigh: true),
        if (series.thresholdLow case final low?) (value: low, isHigh: false),
      ]) {
        final distance = line.value > dataHi
            ? line.value - dataHi
            : line.value < dataLo
            ? dataLo - line.value
            : 0.0;

        if (distance <= dataSpan * 2) {
          thresholds.add(line);
          include(line.value);
        }
      }
    }

    final axisLo = lo!;
    final axisHi = hi!;

    final pad = hourlyIsFlat(axisLo, axisHi)
        ? _flatSpan(axisLo, axisHi)
        : (axisHi - axisLo) * .12;

    return _YAxisPlan(
      min: isCounter && axisLo >= 0 ? 0 : axisLo - pad,
      max: axisHi + pad,
      thresholds: thresholds,
    );
  }

  /// Bien do gia dinh cho tin hieu phang: 10% gia tri, toi thieu 1.
  static double _flatSpan(double lo, double hi) {
    return math.max(math.max(lo.abs(), hi.abs()) * .1, 1.0);
  }
}

// ============================================================
// TOOLTIP
// ============================================================

class _HourlyTooltip extends StatelessWidget {
  final HourlyPoint point;
  final HourlySignalSeries series;

  const _HourlyTooltip({required this.point, required this.series});

  @override
  Widget build(BuildContext context) {
    final unit = series.unit;
    final end = point.ts.add(const Duration(hours: 1));

    final rows = <(String, String)>[
      switch (series.kind) {
        HourlySignalKind.analog => (
          series.isSnapshot ? 'Value' : 'Avg',
          _withUnit(point.value, unit),
        ),
        HourlySignalKind.counter => ('Usage', _withUnit(point.value, unit)),
        HourlySignalKind.status => (
          'Code',
          point.value == null ? '--' : '${point.value!.round()}',
        ),
      },
      if (point.hasRange)
        ('Min – Max', '${_fmt(point.min)} – ${_withUnit(point.max, unit)}'),
      if (point.count != null) ('Samples', '${point.count}'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_tooltipFormat.format(point.ts)} – '
            '${DateFormat('HH:00').format(end)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '$label: $value',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .82),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// SKELETON
// ============================================================

class _HourlySkeleton extends StatelessWidget {
  final Color color;

  const _HourlySkeleton({required this.color});

  @override
  Widget build(BuildContext context) {
    final block = Colors.white.withValues(alpha: .05);

    // Tinh (khong animation) de khong ton CPU khi nhieu card cung tai.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: block,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .025),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final factor in const [
                  .35,
                  .5,
                  .42,
                  .6,
                  .55,
                  .72,
                  .64,
                  .48,
                  .58,
                  .4,
                  .52,
                  .66,
                ])
                  Expanded(
                    child: FractionallySizedBox(
                      heightFactor: factor,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
