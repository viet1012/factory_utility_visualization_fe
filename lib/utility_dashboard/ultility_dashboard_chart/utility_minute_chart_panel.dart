import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_models/response/minute_point.dart';
import '../../utility_state/minute_series_provider.dart';
import '../utility_dashboard_common/chart_theme.dart';
import '../utility_dashboard_common/info_box/utility_info_box_widgets.dart';
import '../utility_dashboard_fac_details/widgets/hover_box_panel/hover_flow_painters.dart';
import '../utility_dashboard_overview/utility_dashboard_overview_widgets/chart_state_widgets.dart';
import '../utility_dashboard_widgets/center_message.dart';

class _ChartPoint {
  final DateTime time;
  final double value;

  const _ChartPoint(this.time, this.value);
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
}

class _PanelVm {
  final List<MinutePointDto> rows;
  final Object? error;
  final bool hasFetchedOnce;

  const _PanelVm({
    required this.rows,
    required this.error,
    required this.hasFetchedOnce,
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

class _UtilityMinuteChartPanelState extends State<UtilityMinuteChartPanel>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late String _requestKey;

  // Provider đang poll mỗi 30s.
  // 30s * 3 + 20s buffer = 110s.
  // Nếu quá 110s chưa có điểm mới thì xem là stale.
  static const Duration _staleThreshold = Duration(seconds: 110);

  late final AnimationController _flowController;

  @override
  bool get wantKeepAlive => true;

  bool get _hasBoxDeviceId => (widget.boxDeviceId ?? '').trim().isNotEmpty;

  bool get _hasPlcAddress => (widget.plcAddress ?? '').trim().isNotEmpty;

  bool get _canFetch => _hasBoxDeviceId;

  bool get _canRenderSignal => _hasBoxDeviceId && _hasPlcAddress;

  String get _plcAddressOrEmpty => widget.plcAddress ?? '';

  IconData get _cateIcon => ChartThemes.cateIcon(widget.cate);

  Color _cateIconColor(ChartTheme theme) {
    return ChartThemes.cateIconColor(widget.cate, theme);
  }

  ChartTheme get _theme => ChartThemes.getThemeByCate(widget.cate);

  @override
  void initState() {
    super.initState();
    _refreshRequestKey();
    _scheduleRegisterAndFetch();
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _flowController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant UtilityMinuteChartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_didRequestParamsChange(oldWidget, widget)) return;

    _refreshRequestKey();
    _scheduleRegisterAndFetch();
  }

  bool _didRequestParamsChange(
    UtilityMinuteChartPanel oldWidget,
    UtilityMinuteChartPanel newWidget,
  ) {
    return oldWidget.facId != newWidget.facId ||
        oldWidget.scadaId != newWidget.scadaId ||
        oldWidget.cate != newWidget.cate ||
        oldWidget.boxDeviceId != newWidget.boxDeviceId ||
        oldWidget.plcAddress != newWidget.plcAddress ||
        oldWidget.cateIds?.join(',') != newWidget.cateIds?.join(',');
  }

  void _scheduleRegisterAndFetch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _registerAndFetch();
    });
  }

  void _refreshRequestKey() {
    final provider = context.read<MinuteSeriesProvider>();

    _requestKey = provider.buildKey(
      facId: widget.facId,
      scadaId: widget.scadaId,
      cate: widget.cate,
      boxDeviceId: widget.boxDeviceId,
      cateIds: widget.cateIds,
    );
  }

  void _registerAndFetch() {
    final provider = context.read<MinuteSeriesProvider>();

    provider.upsertRequest(
      key: _requestKey,
      facId: widget.facId,
      scadaId: widget.scadaId,
      cate: widget.cate,
      boxDeviceId: widget.boxDeviceId,
      cateIds: widget.cateIds,
    );

    if (_canFetch) {
      provider.fetchKeyNow(_requestKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Selector<MinuteSeriesProvider, _PanelVm>(
      selector: (_, provider) => _PanelVm(
        rows: provider.getRowsForPlc(_requestKey, _plcAddressOrEmpty),
        error: provider.getError(_requestKey),
        hasFetchedOnce: provider.hasFetchedOnce(_requestKey),
      ),
      shouldRebuild: (prev, next) =>
          !identical(prev.rows, next.rows) ||
          prev.error != next.error ||
          prev.hasFetchedOnce != next.hasFetchedOnce,
      builder: (context, vm, _) => RepaintBoundary(child: _buildPanel(vm)),
    );
  }

  Widget _buildPanel(_PanelVm vm) {
    final rows = vm.rows;

    final shouldHide = rows.any((e) {
      final name = (e.nameEn ?? '').trim().toLowerCase();
      return name.contains('slave multifunction meter');
    });

    if (shouldHide) return const SizedBox.shrink();

    final error = vm.error;
    final hasError = error != null;
    final isLoading = _canFetch && !vm.hasFetchedOnce && !hasError;

    final signalDisplayName = rows.isNotEmpty
        ? (rows.last.nameEn ?? rows.last.cateId)
        : null;

    final unit = rows.isNotEmpty ? rows.last.unit : null;

    return Container(
      width: widget.width,
      height: widget.height ?? 320,
      decoration: _panelDecoration(_theme),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UtilityInfoBoxWidgets.header(
              facilityColor: _theme.fillTop,
              facTitle: widget.facId,
              boxDeviceId: signalDisplayName,
              plcAddress: widget.plcAddress,
              unit: unit,
              isLoading: isLoading,
              hasError: hasError,
              err: error,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _buildBody(
                  rows: rows,
                  error: error,
                  hasFetchedOnce: vm.hasFetchedOnce,
                ),
              ),
            ),
          ],
        ),
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
          Colors.white.withOpacity(0.06),
          Colors.white.withOpacity(0.02),
        ],
      ),
      border: Border.all(color: theme.line.withOpacity(0.18), width: 1),
      boxShadow: [
        BoxShadow(
          color: theme.line.withOpacity(0.25),
          blurRadius: 18,
          spreadRadius: 1,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.5),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  Widget _buildBody({
    required List<MinutePointDto> rows,
    required Object? error,
    required bool hasFetchedOnce,
  }) {
    final hasError = error != null;

    if (!_canRenderSignal) {
      return EmptyChartState(
        icon: Icons.settings_input_component_rounded,
        title: 'Missing Signal Configuration',
        message: 'boxDeviceId or plcAddress is missing.',
        color: _theme.line,
      );
    }

    if (!hasFetchedOnce && !hasError) {
      return Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: _theme.line,
          ),
        ),
      );
    }

    if (hasError && rows.isEmpty) {
      return ChartApiErrorState(color: _theme.line, onRetry: _registerAndFetch);
    }

    if (rows.isEmpty) {
      return EmptyChartState(
        icon: Icons.timeline_rounded,
        title: 'No Minute Data',
        message: 'No chart data found in selected time window.',
        color: _theme.line,
      );
    }

    final chartPoints = _toChartPoints(rows);
    final latestPoint = _findLatestPoint(rows);

    if (chartPoints.isEmpty) {
      return EmptyChartState(
        icon: Icons.show_chart_rounded,
        title: 'No Valid Points',
        message: 'All returned values are invalid or null.',
        color: _theme.line,
      );
    }

    final analysis = _analyzeSeries(chartPoints);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLatestInfoBar(latestPoint, analysis),
        const SizedBox(height: 6),
        Expanded(child: _buildChart(chartPoints)),
      ],
    );
  }

  Widget _buildLatestInfoBar(
    MinutePointDto latestPoint,
    _SeriesAnalysis analysis,
  ) {
    final status = _resolveSignalStatus(analysis);

    final latestUnit = latestPoint.unit != null && latestPoint.unit!.isNotEmpty
        ? latestPoint.unit!
        : '';

    final latestValue = latestPoint.value != null
        ? '${latestPoint.value!.toStringAsFixed(2)}'
              '${latestUnit.isEmpty ? '' : ' $latestUnit'}'
        : '--';

    final latestTime = DateFormat('HH:mm:ss').format(latestPoint.ts.toLocal());

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: ScadaEnergyIcon(
              icon: _cateIcon,
              color: _cateIconColor(_theme),
              cate: widget.cate ?? '',
              animation: _flowController,
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Container(
                  width: 1,
                  height: 16,
                  color: Colors.white.withOpacity(0.12),
                ),

                const SizedBox(width: 10),

                Text(
                  latestTime,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
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
        color: status.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withOpacity(0.28)),
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
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _SignalStatus _resolveSignalStatus(_SeriesAnalysis analysis) {
    if (analysis.isStale) {
      return _SignalStatus(
        type: _SignalStatusType.stale,
        icon: Icons.timer_off_rounded,
        message: 'No new data ${_formatDuration(analysis.staleFor!)}',
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

  Widget _buildChart(List<_ChartPoint> data) {
    if (data.length < 2) {
      return CenterMessage(message: 'Not enough points');
    }

    final axisBounds = _computeYAxisBounds(data);
    final timeBounds = _computeXAxisBounds(data);

    return SfCartesianChart(
      key: ValueKey(
        '${widget.facId}_${widget.cate}_${widget.boxDeviceId}_${widget.plcAddress}_${data.length}_${data.last.time.millisecondsSinceEpoch}',
      ),
      plotAreaBorderWidth: 1,
      plotAreaBorderColor: Colors.white.withOpacity(0.12),
      tooltipBehavior: _buildTooltipBehavior(),
      zoomPanBehavior: ZoomPanBehavior(
        enablePinching: true,
        enablePanning: true,
        zoomMode: ZoomMode.y,
      ),
      primaryXAxis: DateTimeAxis(
        minimum: timeBounds.minX,
        maximum: timeBounds.maxX,
        intervalType: DateTimeIntervalType.minutes,
        interval: timeBounds.intervalMinutes.toDouble(),
        dateFormat: DateFormat('HH:mm'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(0.08),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(0.15), width: 1),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.75),
          fontSize: 14,
        ),
      ),
      primaryYAxis: NumericAxis(
        minimum: axisBounds.minY,
        maximum: axisBounds.maxY,
        numberFormat: NumberFormat('0.00'),
        majorGridLines: MajorGridLines(
          width: 1,
          color: Colors.white.withOpacity(0.08),
        ),
        axisLine: AxisLine(color: Colors.white.withOpacity(0.15), width: 1),
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.75),
          fontSize: 14,
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

  TooltipBehavior _buildTooltipBehavior() {
    return TooltipBehavior(
      enable: true,
      canShowMarker: true,
      header: '',
      textStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  List<_ChartPoint> _toChartPoints(List<MinutePointDto> rows) {
    return rows
        .where((row) => row.value != null)
        .map((row) => _ChartPoint(row.ts.toLocal(), row.value!))
        .toList();
  }

  MinutePointDto _findLatestPoint(List<MinutePointDto> rows) {
    return rows.lastWhere((row) => row.value != null, orElse: () => rows.last);
  }

  _SeriesAnalysis _analyzeSeries(List<_ChartPoint> points) {
    if (points.isEmpty) {
      return const _SeriesAnalysis(
        isStale: false,
        isFlat: false,
        staleFor: null,
        minValue: 0,
        maxValue: 0,
        delta: 0,
      );
    }

    final latestTime = points.last.time;
    final staleFor = DateTime.now().difference(latestTime);
    final isStale = staleFor > _staleThreshold;

    double minValue = points.first.value;
    double maxValue = points.first.value;

    for (final point in points) {
      if (point.value < minValue) minValue = point.value;
      if (point.value > maxValue) maxValue = point.value;
    }

    final delta = (maxValue - minValue).abs();

    final avg = ((minValue.abs() + maxValue.abs()) / 2.0).clamp(
      0.01,
      double.infinity,
    );

    final eps = (avg * 0.0005).clamp(0.01, 999999.0);

    final isFlat = !isStale && points.length >= 2 && delta <= eps;

    return _SeriesAnalysis(
      isStale: isStale,
      isFlat: isFlat,
      staleFor: staleFor,
      minValue: minValue,
      maxValue: maxValue,
      delta: delta,
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    }

    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds % 60}s';
    }

    return '${d.inSeconds}s';
  }

  ({double minY, double maxY}) _computeYAxisBounds(List<_ChartPoint> data) {
    final values = data.map((e) => e.value).toList()..sort();

    final minValue = values.first;
    final maxValue = values.last;
    final range = (maxValue - minValue).abs();
    final rangePadding = range * 0.2;

    final magnitude = maxValue.abs() > minValue.abs()
        ? maxValue.abs()
        : minValue.abs();

    final minimumPadding = magnitude * 0.01;

    final safePadding = rangePadding > 0
        ? rangePadding
        : (minimumPadding > 0.01 ? minimumPadding : 0.01);

    return (minY: minValue - safePadding, maxY: maxValue + safePadding);
  }

  ({DateTime minX, DateTime maxX, int intervalMinutes}) _computeXAxisBounds(
    List<_ChartPoint> data,
  ) {
    final minX = data.first.time;
    final maxX = data.last.time;

    final totalMinutes = maxX.difference(minX).inMinutes.abs();
    final intervalMinutes = totalMinutes <= 30 ? 5 : 10;

    return (minX: minX, maxX: maxX, intervalMinutes: intervalMinutes);
  }
}
