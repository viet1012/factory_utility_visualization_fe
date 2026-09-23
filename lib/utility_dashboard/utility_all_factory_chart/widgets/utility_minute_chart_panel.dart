import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../models/minute_point.dart';
import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_common/info_box/utility_info_box_widgets.dart';
import '../../utility_dashboard_fac_details/widgets/hover_box_panel/hover_flow_painters.dart';
import '../../shared/widgets/chart_state_widgets.dart';
import '../../shared/widgets/scada_panel_frame.dart';
import '../../utility_dashboard_widgets/center_message.dart';
import '../controllers/utility_minute_chart_controller.dart';

// ============================================================
// INTERNAL MODELS
// ============================================================

/// A plotted point. [time] is always the minute-bucket `ts`, never the raw
/// sample time, so X-axis positioning and bucket alignment stay unchanged.
class _ChartPoint {
  final DateTime time;
  final double value;

  const _ChartPoint({required this.time, required this.value});
}

class _SeriesAnalysis {
  final bool isStale;
  final bool isFlat;
  final Duration? staleFor;

  final double minValue;
  final double maxValue;
  final double delta;

  const _SeriesAnalysis({
    required this.isStale,
    required this.isFlat,
    required this.staleFor,
    required this.minValue,
    required this.maxValue,
    required this.delta,
  });

  static const empty = _SeriesAnalysis(
    isStale: false,
    isFlat: false,
    staleFor: null,
    minValue: 0,
    maxValue: 0,
    delta: 0,
  );
}

class _PreparedSeries {
  final List<_ChartPoint> points;
  final MinutePointDto? latestPoint;
  final _SeriesAnalysis analysis;

  final String? signalName;
  final String? unit;

  final bool hidden;

  const _PreparedSeries({
    required this.points,
    required this.latestPoint,
    required this.analysis,
    required this.signalName,
    required this.unit,
    required this.hidden,
  });

  static const empty = _PreparedSeries(
    points: [],
    latestPoint: null,
    analysis: _SeriesAnalysis.empty,
    signalName: null,
    unit: null,
    hidden: false,
  );
}

class _PanelVm {
  final List<MinutePointDto> rows;
  final Object? error;
  final bool hasFetchedOnce;

  /// Poll health, kept separate from sample freshness: these describe when the
  /// controller last talked to the API, not how new the data is.
  final DateTime? lastOkAt;
  final DateTime? lastErrAt;

  const _PanelVm({
    required this.rows,
    required this.error,
    required this.hasFetchedOnce,
    required this.lastOkAt,
    required this.lastErrAt,
  });
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

// ============================================================
// PANEL
// ============================================================

class UtilityMinuteChartPanel extends StatefulWidget {
  final double width;
  final double? height;

  final String facId;
  final String? scadaId;
  final String? cate;

  final String? boxDeviceId;
  final String? plcAddress;

  final List<String>? cateIds;

  const UtilityMinuteChartPanel({
    super.key,
    required this.facId,
    this.scadaId,
    this.cate,
    this.boxDeviceId,
    this.plcAddress,
    this.cateIds,
    this.width = 520,
    this.height,
  });

  @override
  State<UtilityMinuteChartPanel> createState() =>
      _UtilityMinuteChartPanelState();
}

class _UtilityMinuteChartPanelState extends State<UtilityMinuteChartPanel> {
  // Provider poll mỗi 30 giây.
  // Sau 110 giây không có dữ liệu mới thì xem là stale.
  static const Duration _staleThreshold = Duration(seconds: 110);

  static final DateFormat _latestTimeFormat = DateFormat('HH:mm:ss');
  static final DateFormat _axisTimeFormat = DateFormat('HH:mm');
  static final NumberFormat _axisNumberFormat = NumberFormat('0.00');

  static const Animation<double> _staticFlowAnimation =
      AlwaysStoppedAnimation<double>(0.35);

  late final TooltipBehavior _tooltipBehavior;
  late final ZoomPanBehavior _zoomPanBehavior;

  late String _requestKey;

  List<MinutePointDto>? _cachedRowsReference;
  _PreparedSeries _preparedSeries = _PreparedSeries.empty;

  bool get _hasBoxDeviceId => (widget.boxDeviceId ?? '').trim().isNotEmpty;

  bool get _hasPlcAddress => (widget.plcAddress ?? '').trim().isNotEmpty;

  bool get _canFetch => _hasBoxDeviceId;

  bool get _canRenderSignal => _hasBoxDeviceId && _hasPlcAddress;

  String get _plcAddressOrEmpty => widget.plcAddress?.trim() ?? '';

  ChartTheme get _theme => ChartThemes.byCate(widget.cate);

  @override
  void initState() {
    super.initState();

    _tooltipBehavior = TooltipBehavior(
      enable: true,
      canShowMarker: true,
      header: '',
      textStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
    );

    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      zoomMode: ZoomMode.y,
    );

    _refreshRequestKey();

    // Không gọi API ở đây.
  }

  @override
  void didUpdateWidget(covariant UtilityMinuteChartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_didRequestParamsChange(oldWidget, widget)) {
      return;
    }

    _cachedRowsReference = null;
    _preparedSeries = _PreparedSeries.empty;

    _refreshRequestKey();

    // Không gọi API.
  }

  // ============================================================
  // REQUEST
  // ============================================================

  bool _didRequestParamsChange(
    UtilityMinuteChartPanel oldWidget,
    UtilityMinuteChartPanel newWidget,
  ) {
    return oldWidget.facId != newWidget.facId ||
        oldWidget.scadaId != newWidget.scadaId ||
        oldWidget.cate != newWidget.cate ||
        oldWidget.boxDeviceId != newWidget.boxDeviceId ||
        oldWidget.plcAddress != newWidget.plcAddress;
  }

  void _refreshRequestKey() {
    final provider = context.read<UtilityMinuteChartController>();

    _requestKey = provider.buildKey(
      facId: widget.facId,
      scadaId: widget.scadaId,
      boxDeviceId: widget.boxDeviceId,
    );
  }

  Future<void> _retryCurrentBox() async {
    final provider = context.read<UtilityMinuteChartController>();

    await provider.refreshKey(_requestKey);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Selector<UtilityMinuteChartController, _PanelVm>(
      selector: (_, provider) {
        return _PanelVm(
          rows: provider.getRowsForPlc(_requestKey, _plcAddressOrEmpty),
          error: provider.getError(_requestKey),
          hasFetchedOnce: provider.hasFetchedOnce(_requestKey),
          lastOkAt: provider.lastOkAt(_requestKey),
          lastErrAt: provider.lastErrAt(_requestKey),
        );
      },
      shouldRebuild: (previous, next) {
        return !identical(previous.rows, next.rows) ||
            previous.error != next.error ||
            previous.hasFetchedOnce != next.hasFetchedOnce ||
            previous.lastOkAt != next.lastOkAt ||
            previous.lastErrAt != next.lastErrAt;
      },
      builder: (context, vm, _) {
        _prepareRowsIfNeeded(vm.rows);

        return RepaintBoundary(
          child: ScadaPanelFrame(color: _theme.accent, child: _buildPanel(vm)),
        );
      },
    );
  }

  void _prepareRowsIfNeeded(List<MinutePointDto> rows) {
    if (identical(_cachedRowsReference, rows)) {
      return;
    }

    _cachedRowsReference = rows;
    _preparedSeries = _prepareSeries(rows);
  }

  _PreparedSeries _prepareSeries(List<MinutePointDto> rows) {
    if (rows.isEmpty) {
      return _PreparedSeries.empty;
    }

    var hidden = false;
    MinutePointDto? latestPoint;

    String? signalName;
    String? unit;

    final points = <_ChartPoint>[];

    double? minValue;
    double? maxValue;

    for (final row in rows) {
      final nameEn = (row.nameEn ?? '').trim();

      if (nameEn.toLowerCase().contains('slave multifunction meter')) {
        hidden = true;
      }

      signalName = nameEn.isNotEmpty ? nameEn : row.cateId;

      unit = row.unit;

      final value = row.value;

      if (value == null || !value.isFinite) {
        continue;
      }

      latestPoint = row;

      final localTime = row.ts.toLocal();

      points.add(_ChartPoint(time: localTime, value: value));

      if (minValue == null || value < minValue) {
        minValue = value;
      }

      if (maxValue == null || value > maxValue) {
        maxValue = value;
      }
    }

    if (points.isEmpty || minValue == null || maxValue == null) {
      return _PreparedSeries(
        points: const [],
        latestPoint: latestPoint ?? rows.last,
        analysis: _SeriesAnalysis.empty,
        signalName: signalName,
        unit: unit,
        hidden: hidden,
      );
    }

    /*
     * latestPoint la row cuoi cung co value hop le, tuong ung voi points.last.
     * Do tuoi lay tu realSampleTime cua chinh row do.
     */
    final resolvedLatestPoint = latestPoint ?? rows.last;

    final analysis = _analyzePreparedSeries(
      points: points,
      latestSampleTime: resolvedLatestPoint.realSampleTime,
      minValue: minValue,
      maxValue: maxValue,
    );

    return _PreparedSeries(
      points: List<_ChartPoint>.unmodifiable(points),
      latestPoint: resolvedLatestPoint,
      analysis: analysis,
      signalName: signalName,
      unit: unit,
      hidden: hidden,
    );
  }

  Widget _buildPanel(_PanelVm vm) {
    final prepared = _preparedSeries;

    if (prepared.hidden) {
      return const SizedBox.shrink();
    }

    final hasError = vm.error != null;

    final isLoading = _canFetch && !vm.hasFetchedOnce && !hasError;

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
            boxDeviceId: prepared.signalName,
            plcAddress: widget.plcAddress,
            unit: prepared.unit,
            isLoading: isLoading,
            hasError: hasError,
            err: vm.error,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _buildBody(vm: vm, prepared: prepared),
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

  Widget _buildBody({required _PanelVm vm, required _PreparedSeries prepared}) {
    if (!_canRenderSignal) {
      return EmptyChartState(
        icon: Icons.settings_input_component_rounded,
        title: 'Missing Signal Configuration',
        message: 'boxDeviceId or plcAddress is missing.',
        color: _theme.line,
      );
    }

    final hasError = vm.error != null;

    if (!vm.hasFetchedOnce && !hasError) {
      return Center(
        child: SizedBox.square(
          dimension: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: _theme.line,
          ),
        ),
      );
    }

    if (hasError && vm.rows.isEmpty) {
      return ChartApiErrorState(color: _theme.line, onRetry: _retryCurrentBox);
    }

    if (vm.rows.isEmpty) {
      return EmptyChartState(
        icon: Icons.timeline_rounded,
        title: 'No Minute Data',
        message: 'No chart data found in selected time window.',
        color: _theme.line,
      );
    }

    if (prepared.points.isEmpty) {
      return EmptyChartState(
        icon: Icons.show_chart_rounded,
        title: 'No Valid Points',
        message: 'All returned values are invalid or null.',
        color: _theme.line,
      );
    }

    final latestPoint = prepared.latestPoint;

    if (latestPoint == null) {
      return EmptyChartState(
        icon: Icons.show_chart_rounded,
        title: 'No Valid Points',
        message: 'Latest signal point is unavailable.',
        color: _theme.line,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLatestInfoBar(latestPoint, prepared.analysis, vm),
        const SizedBox(height: 6),
        Expanded(child: _buildChart(prepared.points, prepared.analysis)),
      ],
    );
  }

  // ============================================================
  // LATEST INFO
  // ============================================================

  Widget _buildLatestInfoBar(
    MinutePointDto latestPoint,
    _SeriesAnalysis analysis,
    _PanelVm vm,
  ) {
    final status = _resolveSignalStatus(analysis, vm);

    final unit = latestPoint.unit?.trim() ?? '';

    final value = latestPoint.value;

    final latestValue = value == null
        ? '--'
        : '${value.toStringAsFixed(2)}'
              '${unit.isEmpty ? '' : ' $unit'}';

    /*
     * Hien thi thoi diem thuc cua sample (11:15:46), khong phai moc bucket
     * (11:15:00), de khop voi con so "No new sample for" ben canh.
     */
    final latestTime = _latestTimeFormat.format(
      latestPoint.realSampleTime.toLocal(),
    );

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
    final lastOk = vm.lastOkAt;
    final lastErr = vm.lastErrAt;

    final failedLast =
        vm.error != null &&
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

  Widget _buildChart(List<_ChartPoint> data, _SeriesAnalysis analysis) {
    if (data.length < 2) {
      return const CenterMessage(message: 'Not enough points');
    }

    final yBounds = _computeYAxisBoundsFromAnalysis(analysis);

    final xBounds = _computeXAxisBounds(data);

    return SfCartesianChart(
      // Không đặt ValueKey theo data.length hoặc timestamp.
      // Giữ nguyên chart state, tránh dispose/recreate.
      plotAreaBorderWidth: 1,
      plotAreaBorderColor: Colors.white.withValues(alpha: .12),
      tooltipBehavior: _tooltipBehavior,
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
        minimum: yBounds.minY,
        maximum: yBounds.maxY,
        numberFormat: _axisNumberFormat,
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
      series: <CartesianSeries<_ChartPoint, DateTime>>[
        SplineAreaSeries<_ChartPoint, DateTime>(
          animationDuration: 0,
          dataSource: data,
          xValueMapper: (point, _) => point.time,
          yValueMapper: (point, _) => point.value,
          splineType: SplineType.natural,
          color: _theme.line,
          borderColor: _theme.accent,
          borderWidth: 2,
          gradient: LinearGradient(
            colors: [_theme.fillTop, _theme.fillBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          markerSettings: const MarkerSettings(isVisible: false),
        ),
      ],
    );
  }

  // ============================================================
  // ANALYSIS
  // ============================================================

  /*
   * [latestSampleTime] la thoi diem THUC cua sample moi nhat
   * (sampleRecordedAt ?? ts), khong phai moc bucket cua diem cuoi.
   *
   * Vi du: bucket ts = 11:15:00 nhung sample thuc te ghi luc 11:15:46.473.
   * Do tuoi phai tinh tu 11:15:46.473, neu khong moi diem se bi cong them
   * tuy y toi 59 giay va bao stale som.
   */
  _SeriesAnalysis _analyzePreparedSeries({
    required List<_ChartPoint> points,
    required DateTime latestSampleTime,
    required double minValue,
    required double maxValue,
  }) {
    if (points.isEmpty) {
      return _SeriesAnalysis.empty;
    }

    var staleFor = DateTime.now().difference(latestSampleTime);

    // Tránh duration âm nếu clock phía server nhanh hơn client.
    if (staleFor.isNegative) {
      staleFor = Duration.zero;
    }

    final isStale = staleFor > _staleThreshold;
    final delta = (maxValue - minValue).abs();

    final averageMagnitude = (minValue.abs() + maxValue.abs()) / 2;

    final safeMagnitude = averageMagnitude < .01 ? .01 : averageMagnitude;

    final calculatedEpsilon = safeMagnitude * .0005;

    final epsilon = calculatedEpsilon.clamp(.01, 999999.0);

    final isFlat = !isStale && points.length >= 2 && delta <= epsilon;

    return _SeriesAnalysis(
      isStale: isStale,
      isFlat: isFlat,
      staleFor: staleFor,
      minValue: minValue,
      maxValue: maxValue,
      delta: delta,
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

  ({double minY, double maxY}) _computeYAxisBoundsFromAnalysis(
    _SeriesAnalysis analysis,
  ) {
    final minValue = analysis.minValue;
    final maxValue = analysis.maxValue;
    final range = analysis.delta;

    final rangePadding = range * .20;

    final magnitude = minValue.abs() > maxValue.abs()
        ? minValue.abs()
        : maxValue.abs();

    final minimumPadding = magnitude * .01;

    final padding = rangePadding > 0
        ? rangePadding
        : minimumPadding > .01
        ? minimumPadding
        : .01;

    return (minY: minValue - padding, maxY: maxValue + padding);
  }

  ({DateTime minX, DateTime maxX, int intervalMinutes}) _computeXAxisBounds(
    List<_ChartPoint> data,
  ) {
    final minX = data.first.time;
    var maxX = data.last.time;

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
