import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_catalog/api/signal_history_repository.dart';
import '../../utility_catalog/models/signal_history_models.dart';
import '../../utility_catalog/widgets/signal_chart/signal_chart_gaps.dart'
    show kSignalGapBreakThreshold;
import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_widgets.dart';
import '../../utility_dashboard_fac_details/widgets/hover_box_panel/hover_flow_painters.dart';
import '../../shared/charts/axis_planner.dart';
import '../../shared/charts/chart_animation.dart';
import '../../shared/charts/chart_downsample.dart';
import '../../shared/charts/chart_hover_style.dart';
import '../../shared/charts/chart_thresholds.dart';
import '../../shared/charts/signal_chart_spec.dart';
import '../../shared/charts/signal_chart_spec_registry.dart';
import '../../shared/charts/signal_thresholds.dart';
import '../controllers/utility_chart_catalog_controller.dart';
import '../../shared/charts/value_format.dart';
import '../../shared/widgets/chart_loading_widgets.dart';
import '../../shared/widgets/chart_state_widgets.dart';
import '../../shared/widgets/lazy_chart_gate.dart';
import '../../shared/widgets/scada_panel_frame.dart';
import '../../utility_dashboard_widgets/center_message.dart';
import '../controllers/series_history_chart_controller.dart';
import '../controllers/utility_minute_chart_controller.dart';
import '../models/utility_minute_models.dart';

// ============================================================
// INTERNAL MODELS
// ============================================================

/// Phan cua [MinuteBoxState] ma mot the can: state cua box (loading /
/// error / poll health) va series cua chinh PLC nay.
class _PanelVm {
  final MinuteBoxState state;
  final MinuteSignalSeries? series;

  const _PanelVm(this.state, this.series);

  factory _PanelVm.of(MinuteBoxState state, String plcAddress) {
    return _PanelVm(state, state.data?.signals[plcAddress]);
  }

  @override
  bool operator ==(Object other) {
    return other is _PanelVm &&
        identical(other.series, series) &&
        identical(other.state.data, state.data) &&
        other.state.error == state.error &&
        other.state.lastOkAt == state.lastOkAt &&
        other.state.lastErrAt == state.lastErrAt;
  }

  @override
  int get hashCode =>
      Object.hash(series, state.error, state.lastOkAt, state.lastErrAt);
}

class _SeriesAnalysis {
  final bool isStale;
  final bool isFlat;
  final Duration? staleFor;

  const _SeriesAnalysis({
    required this.isStale,
    required this.isFlat,
    required this.staleFor,
  });

  static const empty = _SeriesAnalysis(
    isStale: false,
    isFlat: false,
    staleFor: null,
  );
}

/// Cham vuot nguong tren line: gia tri vi pham + level.
class _BreachMark {
  final DateTime time;
  final double value;
  final int level;

  const _BreachMark(this.time, this.value, this.level);
}

enum _SignalStatusType { normal, stale, flat }

class _SignalStatus {
  final _SignalStatusType type;
  final IconData icon;
  final String message;
  final Color color;

  const _SignalStatus({
    required this.type,
    required this.icon,
    required this.message,
    required this.color,
  });

  bool get shouldShow => type != _SignalStatusType.normal;
}

String _errorMessage(Object? error) {
  if (error is SignalHistoryRequestException) return error.message;
  if (error is TimeoutException) return 'Request timed out. Please try again.';
  return 'Please check your connection or try again.';
}

// ============================================================
// PANEL
// ============================================================

class UtilityMinuteChartPanel extends StatefulWidget {
  final double width;
  final double? height;

  final String facId;
  final String? cate;

  final String? boxDeviceId;
  final String? plcAddress;

  /// Ten / unit tu catalog: hien khung the ngay, khong cho du lieu.
  final String? signalName;
  final String? unit;

  const UtilityMinuteChartPanel({
    super.key,
    required this.facId,
    this.cate,
    this.boxDeviceId,
    this.plcAddress,
    this.signalName,
    this.unit,
    this.width = 520,
    this.height,
  });

  @override
  State<UtilityMinuteChartPanel> createState() =>
      _UtilityMinuteChartPanelState();
}

class _UtilityMinuteChartPanelState extends State<UtilityMinuteChartPanel> {
  /// Khong co bucket moi lau hon nguong ngat duong (> 3 phut) thi xem la
  /// stale: le 1–3 phut trong la binh thuong (chu ky ghi ~65s).
  static const Duration _staleThreshold = kSignalGapBreakThreshold;

  static const Color _alertColor = Colors.redAccent;

  static final DateFormat _latestTimeFormat = DateFormat('HH:mm');
  static final DateFormat _axisTimeFormat = DateFormat('HH:mm');
  static final DateFormat _hoverTimeFormat = DateFormat('dd/MM HH:mm');

  static const Animation<double> _staticFlowAnimation =
      AlwaysStoppedAnimation<double>(0.35);

  late final TrackballBehavior _trackball;
  late final ZoomPanBehavior _zoomPanBehavior;
  final FirstPaintAnimation _animation = FirstPaintAnimation();

  /// Series + spec dang ve, de trackball tra lai diem goc tu x.
  MinuteSignalSeries? _series;
  SignalChartSpec _spec = SignalChartSpecRegistry.fallback;
  Map<int, MinutePoint> _pointsByTime = const {};

  /// Phan tich stale / flat, tinh lai khi series doi.
  MinuteSignalSeries? _analyzedSeries;
  _SeriesAnalysis _analysis = _SeriesAnalysis.empty;

  String get _box => widget.boxDeviceId?.trim() ?? '';

  String get _plc => widget.plcAddress?.trim() ?? '';

  bool get _canRenderSignal => _box.isNotEmpty && _plc.isNotEmpty;

  ChartTheme get _theme => ChartThemes.byCate(widget.cate);

  @override
  void initState() {
    super.initState();

    _trackball = ChartHoverStyle.trackball(
      markerColor: _theme.line,
      builder: (context, details) {
        final x = details.point?.x;
        if (x is! DateTime) return const SizedBox.shrink();

        final point = _pointsByTime[x.millisecondsSinceEpoch];
        if (point == null || !point.hasValue) return const SizedBox.shrink();

        return _hoverCard(point);
      },
    );

    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      zoomMode: ZoomMode.y,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // Chi lang nghe phan du lieu cua chinh signal nay trong box.
    return Selector<UtilityMinuteChartController, _PanelVm>(
      selector: (_, controller) => _PanelVm.of(controller.boxState(_box), _plc),
      builder: (context, vm, _) {
        return RepaintBoundary(
          child: ScadaPanelFrame(color: _theme.accent, child: _buildPanel(vm)),
        );
      },
    );
  }

  /// Spec theo code / unit / kind cua response, thieu thi qua catalog.
  /// COUNTER: ve chi so cong to goc dang line, truc bam du lieu.
  SignalChartSpec _resolveSpec(MinuteSignalSeries? series) {
    final spec = context
        .read<UtilityChartCatalogController>()
        .resolveSpecForSignal(
          _box,
          _plc,
          code: series?.code,
          unit: series?.unit ?? widget.unit,
          kind: series?.kind.name.toUpperCase(),
          name: series?.name ?? widget.signalName,
        );

    return series?.kind == SignalKind.counter
        ? spec.copyWith(style: ChartStyle.lineBand, axis: AxisMode.fitData)
        : spec;
  }

  Widget _buildPanel(_PanelVm vm) {
    final series = vm.series;

    if (series?.hidden ?? false) {
      return const SizedBox.shrink();
    }

    final state = vm.state;
    final hasError = state.error != null;

    // Chi lan dau (chua co du lieu) moi bao dang tai.
    final isLoading = _canRenderSignal && state.data == null && !hasError;

    final spec = _resolveSpec(series);
    final unit = spec.resolveUnit(
      (series?.unit.isNotEmpty ?? false) ? series!.unit : widget.unit,
    );

    final name = (series?.name.isNotEmpty ?? false)
        ? series!.name
        : widget.signalName;

    final breachCount = series?.visibleBreachCount ?? 0;

    return Container(
      width: widget.width,
      height: widget.height ?? 320,
      decoration: _panelDecoration(_theme),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UtilityInfoBoxWidgets.header(
            facilityColor: _theme.fillTop,
            facTitle: widget.facId,
            boxDeviceId: name,
            plcAddress: widget.plcAddress,
            unit: unit,
            isLoading: isLoading,
            hasError: hasError,
            err: hasError ? _errorMessage(state.error) : null,
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
              child: _buildBody(vm: vm, spec: spec, unit: unit),
            ),
          ),
        ],
      ),
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

      // Giảm blur so với bản cũ để nhẹ GPU hơn.
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

  Widget _buildBody({
    required _PanelVm vm,
    required SignalChartSpec spec,
    required String unit,
  }) {
    if (!_canRenderSignal) {
      return EmptyChartState(
        icon: Icons.settings_input_component_rounded,
        title: 'Missing Signal Configuration',
        message: 'boxDeviceId or plcAddress is missing.',
        color: _theme.line,
      );
    }

    final state = vm.state;
    final data = state.data;
    final series = vm.series;

    if (data == null) {
      if (state.error != null) {
        return ChartApiErrorState(
          color: _theme.line,
          message: _errorMessage(state.error),
          onRetry: () => context.read<UtilityMinuteChartController>().retry(),
        );
      }

      // Lan dau: khung the + skeleton, khong spinner.
      return ChartBodySkeleton(color: _theme.line);
    }

    if (series == null) {
      return EmptyChartState(
        icon: Icons.timeline_rounded,
        title: 'No Minute Data',
        message: 'No chart data found in selected time window.',
        color: _theme.line,
      );
    }

    if (series.parseError != null) {
      return EmptyChartState(
        icon: Icons.report_problem_outlined,
        title: 'Invalid Signal Data',
        message: 'Minute data for $_plc could not be parsed.',
        color: _theme.line,
      );
    }

    final latest = series.latest;

    if (latest == null) {
      return EmptyChartState(
        icon: Icons.show_chart_rounded,
        title: 'No Valid Points',
        message: 'No samples recorded in the last 60 minutes.',
        color: _theme.line,
      );
    }

    if (!identical(_analyzedSeries, series)) {
      _analyzedSeries = series;
      _analysis = _analyze(series, latest);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLatestInfoBar(series, latest, vm, spec, unit),
        const SizedBox(height: 6),
        Expanded(
          child: LazyChartGate(
            placeholder: ChartBodySkeleton(
              color: _theme.line,
              withSummary: false,
            ),
            builder: (_) => _buildChart(series, data, spec, unit),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LATEST INFO
  // ============================================================

  Widget _buildLatestInfoBar(
    MinuteSignalSeries series,
    MinutePoint latest,
    _PanelVm vm,
    SignalChartSpec spec,
    String unit,
  ) {
    final status = _resolveSignalStatus(_analysis, vm);

    final latestValue = spec.style == ChartStyle.step
        ? 'Code ${latest.value!.round()}'
        : formatWithUnit(latest.value, unit, decimals: spec.decimals);

    final latestTime = _latestTimeFormat.format(latest.ts);

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 34,
            child: ScadaEnergyIcon(
              icon: _theme.icon,
              color: _theme.iconColor,
              cate: widget.cate ?? '',
              animation: _staticFlowAnimation,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    latestValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 1,
                  height: 16,
                  color: Colors.white.withValues(alpha: .12),
                ),
                const SizedBox(width: 10),
                Text(
                  latestTime,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .62),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          if (status.shouldShow) ...[
            const SizedBox(width: 8),
            _buildStatusChip(status),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(_SignalStatus status) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: status.color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              status.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: status.color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact refresh-health suffix, e.g. ` · Last refresh 12s ago` or
  /// ` · Refresh failed`.
  ///
  /// Sample freshness stays the primary signal; this only distinguishes
  /// "source has no new sample" from "polling is failing or not running".
  String _pollHealthSuffix(_PanelVm vm) {
    final lastOk = vm.state.lastOkAt;
    final lastErr = vm.state.lastErrAt;

    final failedLast =
        vm.state.error != null &&
        (lastOk == null || (lastErr != null && lastErr.isAfter(lastOk)));

    if (failedLast) return ' · Refresh failed';

    if (lastOk == null) return ' · Waiting for refresh';

    return ' · Last refresh '
        '${_formatDuration(DateTime.now().difference(lastOk))} ago';
  }

  _SignalStatus _resolveSignalStatus(_SeriesAnalysis analysis, _PanelVm vm) {
    if (analysis.isStale) {
      return _SignalStatus(
        type: _SignalStatusType.stale,
        icon: Icons.timer_off_rounded,
        message:
            'No new sample for ${_formatDuration(analysis.staleFor!)}'
            '${_pollHealthSuffix(vm)}',
        color: Colors.orange,
      );
    }

    if (analysis.isFlat) {
      return const _SignalStatus(
        type: _SignalStatusType.flat,
        icon: Icons.horizontal_rule_rounded,
        message: 'Value unchanged',
        color: Colors.blueGrey,
      );
    }

    return const _SignalStatus(
      type: _SignalStatusType.normal,
      icon: Icons.check_circle_rounded,
      message: '',
      color: Colors.green,
    );
  }

  // ============================================================
  // CHART
  // ============================================================

  Widget _buildChart(
    MinuteSignalSeries series,
    SeriesBoxData<MinuteSignalSeries> data,
    SignalChartSpec spec,
    String unit,
  ) {
    final readings = series.plotPoints;

    if (readings.where((point) => point.hasValue).length < 2) {
      return const CenterMessage(message: 'Not enough points');
    }

    final style = spec.style;
    final analog = series.kind == SignalKind.analog;
    final counter = series.kind == SignalKind.counter;

    final points = downsampleMinMax(readings, value: (point) => point.value);

    _series = series;
    _spec = spec;
    _pointsByTime = {
      for (final point in points) point.ts.millisecondsSinceEpoch: point,
    };

    // COUNTER: nhan truc la so nguyen (vd 271,880 / 271,900), khong nguong.
    final axis = planAxis(
      values: points.map((point) => point.value),
      spec: counter ? spec.copyWith(decimals: 0) : spec,
      thresholds: series.showThresholds ? series.thresholds : const [],
    );

    // Vuot nguong: line them cham mau level.
    final breaches = <_BreachMark>[
      for (final point in points)
        if (series.breachLevel(point) case final level?)
          _BreachMark(
            point.ts,
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

    final xBounds = _computeXAxisBounds(readings);
    final animationMs = _animation.duration();

    const gap = EmptyPointSettings(mode: EmptyPointMode.gap);

    final chart = SfCartesianChart(
      // Không đặt ValueKey theo data.length hoặc timestamp.
      // Giữ nguyên chart state, tránh dispose/recreate.
      plotAreaBorderWidth: 1,
      plotAreaBorderColor: Colors.white.withValues(alpha: .12),
      trackballBehavior: _trackball,
      zoomPanBehavior: _zoomPanBehavior,
      primaryXAxis: DateTimeAxis(
        minimum: xBounds.minX,
        maximum: xBounds.maxX,
        intervalType: DateTimeIntervalType.minutes,
        interval: xBounds.intervalMinutes.toDouble(),
        dateFormat: _axisTimeFormat,
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withValues(alpha: .08),
        ),
        axisLine: AxisLine(
          color: Colors.white.withValues(alpha: .15),
          width: 1,
        ),
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: .72),
          fontSize: 12,
        ),
      ),
      primaryYAxis: NumericAxis(
        minimum: axis.min,
        maximum: axis.max,
        interval: axis.interval,
        axisLabelFormatter: (details) => ChartAxisLabel(
          axis.label(details.value),
          TextStyle(color: Colors.white.withValues(alpha: .72), fontSize: 12),
        ),
        title: counter && unit.isNotEmpty
            ? AxisTitle(
                text: unit,
                textStyle: TextStyle(
                  color: Colors.white.withValues(alpha: .52),
                  fontSize: 10,
                ),
              )
            : const AxisTitle(),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withValues(alpha: .08),
        ),
        axisLine: AxisLine(
          color: Colors.white.withValues(alpha: .15),
          width: 1,
        ),
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: .72),
          fontSize: 12,
        ),
        plotBands: thresholdPlotBands(axis, unit),
      ),
      series: <CartesianSeries<dynamic, DateTime>>[
        switch (style) {
          ChartStyle.area => AreaSeries<MinutePoint, DateTime>(
            animationDuration: animationMs,
            dataSource: points,
            xValueMapper: (point, _) => point.ts,
            yValueMapper: (point, _) => point.value,
            borderColor: _theme.accent,
            borderWidth: 2,
            borderDrawMode: BorderDrawMode.top,
            gradient: LinearGradient(
              colors: [_theme.fillTop, _theme.fillBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            emptyPointSettings: gap,
          ),
          ChartStyle.step => StepLineSeries<MinutePoint, DateTime>(
            animationDuration: animationMs,
            dataSource: points,
            xValueMapper: (point, _) => point.ts,
            yValueMapper: (point, _) => point.value,
            color: _theme.line,
            width: 2,
            emptyPointSettings: gap,
          ),
          // COUNTER da doi sang lineBand o _resolveSpec.
          ChartStyle.lineBand ||
          ChartStyle.bar => LineSeries<MinutePoint, DateTime>(
            animationDuration: animationMs,
            dataSource: points,
            xValueMapper: (point, _) => point.ts,
            yValueMapper: (point, _) => point.value,
            color: _theme.line,
            width: 2,
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
            xValueMapper: (mark, _) => mark.time,
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

  Widget _hoverCard(MinutePoint point) {
    final spec = _spec;
    final series = _series;
    final unit = spec.resolveUnit(series?.unit ?? widget.unit);

    // COUNTER: chi so cong to goc cuoi phut.
    if (series?.kind == SignalKind.counter) {
      return ChartHoverCard(
        title: _hoverTimeFormat.format(point.ts),
        rows: [
          (
            'Reading',
            formatWithUnit(point.value, unit, decimals: spec.decimals),
          ),
        ],
      );
    }

    final hasRange =
        series?.kind == SignalKind.analog &&
        point.min != null &&
        point.max != null;

    return ChartHoverCard(
      title: _hoverTimeFormat.format(point.ts),
      rows: ChartHoverStyle.rows(
        kind: spec.style == ChartStyle.step
            ? HoverKind.status
            : HoverKind.analog,
        value: point.value,
        unit: unit,
        decimals: spec.decimals,
        min: hasRange ? point.min : null,
        max: hasRange ? point.max : null,
        samples: point.count,
      ),
    );
  }

  // ============================================================
  // ANALYSIS
  // ============================================================

  /// Stale: bucket co du lieu moi nhat da ket thuc lau hon [_staleThreshold].
  /// Flat: bien do gia tri trong cua so qua nho.
  _SeriesAnalysis _analyze(MinuteSignalSeries series, MinutePoint latest) {
    var staleFor = DateTime.now().difference(latest.ts.add(kMinuteBucket));

    // Tránh duration âm nếu clock phía server nhanh hơn client.
    if (staleFor.isNegative) {
      staleFor = Duration.zero;
    }

    final isStale = staleFor > _staleThreshold;

    double? minValue;
    double? maxValue;
    var count = 0;

    for (final point in series.points) {
      final value = point.value;
      if (value == null || !value.isFinite) continue;

      count++;
      if (minValue == null || value < minValue) minValue = value;
      if (maxValue == null || value > maxValue) maxValue = value;
    }

    if (minValue == null || maxValue == null) {
      return _SeriesAnalysis(
        isStale: isStale,
        isFlat: false,
        staleFor: staleFor,
      );
    }

    final delta = (maxValue - minValue).abs();

    final averageMagnitude = (minValue.abs() + maxValue.abs()) / 2;

    final safeMagnitude = averageMagnitude < .01 ? .01 : averageMagnitude;

    final epsilon = (safeMagnitude * .0005).clamp(.01, 999999.0);

    final isFlat = !isStale && count >= 2 && delta <= epsilon;

    return _SeriesAnalysis(
      isStale: isStale,
      isFlat: isFlat,
      staleFor: staleFor,
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h '
          '${duration.inMinutes % 60}m';
    }

    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m '
          '${duration.inSeconds % 60}s';
    }

    return '${duration.inSeconds}s';
  }

  ({DateTime minX, DateTime maxX, int intervalMinutes}) _computeXAxisBounds(
    List<MinutePoint> data,
  ) {
    final minX = data.first.ts;
    var maxX = data.last.ts;

    // Syncfusion có thể hiển thị không ổn nếu minX == maxX.
    if (!maxX.isAfter(minX)) {
      maxX = minX.add(const Duration(minutes: 1));
    }

    final totalMinutes = maxX.difference(minX).inMinutes.abs();

    final intervalMinutes = switch (totalMinutes) {
      <= 30 => 5,
      <= 60 => 10,
      <= 180 => 30,
      _ => 60,
    };

    return (minX: minX, maxX: maxX, intervalMinutes: intervalMinutes);
  }
}
