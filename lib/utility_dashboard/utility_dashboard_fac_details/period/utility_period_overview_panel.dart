import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../models/period/utility_period_dashboard.dart';
import '../utility_period_api.dart';

class _RankedUtilityBox {
  final int rank;

  final UtilityPeriodBox box;

  const _RankedUtilityBox({required this.rank, required this.box});
}

String _formatCompactValue(double value) {
  if (value >= 1000000) {
    final n = value / 1000000;

    return '${_trimNumber(n, 2)}M';
  }

  if (value >= 1000) {
    final n = value / 1000;

    return '${_trimNumber(n, 2)}K';
  }

  return _trimNumber(value, 1);
}

String _trimNumber(double value, int decimals) {
  var text = value.toStringAsFixed(decimals);

  text = text.replaceFirst(RegExp(r'\.?0+$'), '');

  return text;
}

class UtilityPeriodOverviewPanel extends StatefulWidget {
  final String facId;
  final UtilityPeriodApi api;
  final String utilityType;
  final ValueChanged<UtilityPeriodDashboard?>? onDataChanged;

  const UtilityPeriodOverviewPanel({
    super.key,
    required this.facId,
    required this.api,
    required this.utilityType,
    this.onDataChanged,
  });

  @override
  State<UtilityPeriodOverviewPanel> createState() =>
      _UtilityPeriodOverviewPanelState();
}

class _UtilityPeriodOverviewPanelState
    extends State<UtilityPeriodOverviewPanel> {
  // ============================================================
  // CONSTANTS
  // ============================================================

  static const String _week = 'WEEK';
  static const String _month = 'MONTH';

  static const Color _background = Color(0xFF06111F);
  static const Color _panel = Color(0xFF0A1B2D);
  static const Color _border = Color(0xFF17354B);

  static const Color _positiveColor = Color(0xFF22C55E);
  static const Color _negativeColor = Colors.orangeAccent;

  static const double _panelRadius = 10;

  // ============================================================
  // STATE
  // ============================================================

  String _period = _week;

  DateTime _selectedDate = DateTime.now();

  UtilityPeriodDashboard? _data;

  bool _loading = true;
  bool _refreshing = false;

  String? _error;

  int _requestToken = 0;

  // ============================================================
  // DERIVED STATE
  // ============================================================

  ChartTheme get _theme {
    return ChartThemes.byCate(widget.utilityType);
  }

  bool get _isMonth {
    return _period == _month;
  }

  bool get _hasData {
    return _data != null;
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    unawaited(_load(mainLoading: true));
  }

  @override
  void didUpdateWidget(covariant UtilityPeriodOverviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.facId != widget.facId) {
      unawaited(_load(mainLoading: true));
      return;
    }

    // reload khi FacDetailBody đổi utilityType
    if (oldWidget.utilityType != widget.utilityType) {
      unawaited(_load());
    }
  }

  // ============================================================
  // API
  // ============================================================

  Future<void> _load({bool mainLoading = false}) async {
    final int requestToken = ++_requestToken;
    _beginLoading(mainLoading: mainLoading);

    try {
      final UtilityPeriodDashboard result = await widget.api.getDashboard(
        facId: widget.facId,
        type: widget.utilityType, // <-- đổi từ _utilityType
        period: _period,
        date: _selectedDate,
      );

      if (!_isRequestValid(requestToken)) return;

      setState(() {
        _data = result;
        _loading = false;
        _refreshing = false;
        _error = null;
      });

      // ============================================================
      // ĐẨY ĐÚNG DASHBOARD ĐANG HIỂN THỊ LÊN PARENT
      // ============================================================

      widget.onDataChanged?.call(result);
    } catch (error, stackTrace) {
      debugPrint('[UTILITY PERIOD] load failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!_isRequestValid(requestToken)) return;

      setState(() {
        _loading = false;
        _refreshing = false;
        if (_data == null) _error = error.toString();
      });
    }
  }

  void _beginLoading({required bool mainLoading}) {
    if (!mounted) {
      return;
    }

    setState(() {
      _error = null;

      if (!_hasData || mainLoading) {
        _loading = true;
        _refreshing = false;
      } else {
        _refreshing = true;
      }
    });
  }

  bool _isRequestValid(int token) {
    return mounted && token == _requestToken;
  }

  // ============================================================
  // PERIOD
  // ============================================================

  void _setPeriod(String value) {
    if (_period == value) {
      return;
    }

    setState(() {
      _period = value;
    });

    unawaited(_load());
  }

  // ============================================================
  // DATE NAVIGATION
  // ============================================================

  void _previousPeriod() {
    _changePeriodDate(-1);
  }

  void _nextPeriod() {
    _changePeriodDate(1);
  }

  void _changePeriodDate(int direction) {
    setState(() {
      if (_isMonth) {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month + direction,
          1,
        );
      } else {
        _selectedDate = _selectedDate.add(Duration(days: 7 * direction));
      }
    });

    unawaited(_load());
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          _buildHeader(),

          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'UTILITY OVERVIEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(width: 16),

              _periodButton(value: _week, title: '7 DAYS'),

              const SizedBox(width: 6),

              _periodButton(value: _month, title: 'MONTH'),

              const Spacer(),

              _buildPeriodSelector(),

              const SizedBox(width: 6),

              if (_refreshing) ...[
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _theme.line,
                  ),
                ),

                const SizedBox(width: 6),
              ],

              SizedBox(
                width: 34,
                height: 34,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Refresh',
                  onPressed: _refreshing ? null : () => _load(),
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PERIOD BUTTON
  // ============================================================

  Widget _periodButton({required String value, required String title}) {
    final bool selected = _period == value;

    final Color accent = _theme.line;

    return InkWell(
      onTap: () => _setPeriod(value),
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? accent.withOpacity(.12)
              : Colors.white.withOpacity(.035),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? accent.withOpacity(.75) : _border,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected ? accent : Colors.white60,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PERIOD SELECTOR
  // ============================================================
  bool get _canGoNext {
    if (_isMonth) {
      final now = DateTime.now();

      return _selectedDate.year < now.year ||
          (_selectedDate.year == now.year && _selectedDate.month < now.month);
    }

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    return selected.isBefore(today);
  }

  Widget _buildPeriodSelector() {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _periodArrow(
            icon: Icons.chevron_left_rounded,
            onTap: _previousPeriod,
          ),

          Container(
            constraints: const BoxConstraints(minWidth: 120),
            alignment: Alignment.center,
            child: Text(
              _periodLabel(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          _periodArrow(
            icon: Icons.chevron_right_rounded,
            onTap: _canGoNext ? _nextPeriod : null,
          ),
        ],
      ),
    );
  }

  Widget _periodArrow({required IconData icon, required VoidCallback? onTap}) {
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 30,
        height: 32,
        child: Icon(
          icon,
          color: enabled ? Colors.white70 : Colors.white24,
          size: 20,
        ),
      ),
    );
  }

  String _periodLabel() {
    final data = _data;

    // ============================================================
    // DATA TỪ API
    // ============================================================

    if (data != null) {
      if (_isMonth) {
        return DateFormat('MM/yyyy').format(data.fromDate);
      }

      return '${DateFormat('dd/MM').format(data.fromDate)}'
          ' - '
          '${DateFormat('dd/MM').format(data.toDate)}';
    }

    // ============================================================
    // CHƯA CÓ DATA
    // ============================================================

    if (_isMonth) {
      return DateFormat('MM/yyyy').format(_selectedDate);
    }

    // selectedDate = ngày cuối
    final fromDate = _selectedDate.subtract(const Duration(days: 6));

    return '${DateFormat('dd/MM').format(fromDate)}'
        ' - '
        '${DateFormat('dd/MM').format(_selectedDate)}';
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_loading && _data == null) {
      return Center(child: CircularProgressIndicator(color: _theme.line));
    }

    if (_error != null && _data == null) {
      return _buildError();
    }

    final data = _data;

    if (data == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Expanded(
          flex: 4,
          child: Row(
            children: [
              Expanded(child: _buildByBoxPanel(data)),

              const SizedBox(width: 4),

              Expanded(child: _buildTrendPanel(data)),
            ],
          ),
        ),

        const SizedBox(height: 4),

        Expanded(flex: 5, child: _buildHeatmap(data)),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 26,
          ),

          const SizedBox(height: 8),

          Text(
            _error ?? 'Unable to load data',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),

          const SizedBox(height: 10),

          ElevatedButton.icon(
            onPressed: () => _load(mainLoading: true),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TREND
  // ============================================================

  Widget _buildTrendPanel(UtilityPeriodDashboard data) {
    final ChartTheme theme = _theme;

    final double? change = data.changePercent;

    final bool hasChange = change != null;

    final bool decreased = hasChange && change < 0;

    final Color changeColor = !hasChange
        ? Colors.white54
        : decreased
        ? _positiveColor
        : _negativeColor;

    return _panelBox(
      title: 'TOTAL ${theme.title} CONSUMPTION (${data.unit})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _formatNumber(data.total),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(width: 5),

              Text(
                data.unit,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(width: 10),

              _changeBadge(change: change, color: changeColor),

              const Spacer(),

              _trendBadge(theme: theme),
            ],
          ),

          const SizedBox(height: 8),

          Expanded(
            child: SfCartesianChart(
              margin: EdgeInsets.zero,
              plotAreaBorderWidth: 0,

              primaryXAxis: DateTimeAxis(
                dateFormat: DateFormat(_isMonth ? 'dd' : 'dd/MM'),
                intervalType: DateTimeIntervalType.days,
                majorGridLines: const MajorGridLines(width: 0),
                majorTickLines: const MajorTickLines(width: 0),
                axisLine: AxisLine(
                  color: Colors.white.withOpacity(.08),
                  width: 1,
                ),
                labelStyle: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),

              primaryYAxis: NumericAxis(
                numberFormat: NumberFormat.compact(),
                labelStyle: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
                axisLine: const AxisLine(width: 0),
                majorTickLines: const MajorTickLines(width: 0),
                majorGridLines: MajorGridLines(
                  color: Colors.white.withOpacity(.055),
                  width: 1,
                  dashArray: const [4, 4],
                ),
              ),

              trackballBehavior: TrackballBehavior(
                enable: true,
                activationMode: ActivationMode.singleTap,
                lineType: TrackballLineType.vertical,
                lineColor: Colors.white.withOpacity(.20),
                lineWidth: 1,
                tooltipDisplayMode: TrackballDisplayMode.floatAllPoints,
                tooltipSettings: const InteractiveTooltip(
                  enable: true,
                  format: 'point.x : point.y',
                ),
              ),

              series: <CartesianSeries>[
                SplineAreaSeries<UtilityPeriodTrend, DateTime>(
                  name: 'Consumption',

                  dataSource: data.trend,

                  xValueMapper: (item, _) => item.date,

                  yValueMapper: (item, _) => item.value,

                  borderColor: theme.line,

                  borderWidth: 2.2,

                  splineType: SplineType.natural,

                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [theme.fillTop, theme.fillBottom],
                  ),

                  markerSettings: MarkerSettings(
                    isVisible: true,
                    width: 5,
                    height: 5,
                    color: theme.line,
                    borderColor: _panel,
                    borderWidth: 1.5,
                  ),

                  dataLabelSettings: const DataLabelSettings(isVisible: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _changeBadge({required double? change, required Color color}) {
    final bool hasValue = change != null;

    final bool decreased = hasValue && change < 0;

    return Tooltip(
      message: 'Compared with the same progress of the previous period',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasValue) ...[
              Icon(
                decreased
                    ? Icons.arrow_downward_rounded
                    : change == 0
                    ? Icons.remove_rounded
                    : Icons.arrow_upward_rounded,
                size: 12,
                color: color,
              ),

              const SizedBox(width: 2),
            ],

            Text(
              hasValue ? '${change.abs().toStringAsFixed(1)}%' : '--',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendBadge({required ChartTheme theme}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.line.withOpacity(.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.line.withOpacity(.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 2,
            decoration: BoxDecoration(
              color: theme.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(width: 5),

          Text(
            _isMonth ? 'Daily Trend' : '7-Day Trend',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BY PANEL
  // ============================================================

  Widget _buildByBoxPanel(UtilityPeriodDashboard data) {
    final ChartTheme theme = _theme;

    // ============================================================
    // SORT DESC
    // ============================================================

    final sortedBoxes = [...data.byBox]
      ..sort((a, b) => b.total.compareTo(a.total));

    // ============================================================
    // WRAP DATA WITH RANK
    // ============================================================

    final rankedBoxes = List<_RankedUtilityBox>.generate(sortedBoxes.length, (
      index,
    ) {
      final item = sortedBoxes[index];

      return _RankedUtilityBox(rank: index + 1, box: item);
    }, growable: false);

    return _panelBox(
      title: '${theme.title} CONSUMPTION BY PANEL (${data.unit})',

      child: SfCartesianChart(
        margin: EdgeInsets.zero,

        plotAreaBorderWidth: 0,

        // ========================================================
        // CATEGORY AXIS
        // ========================================================
        primaryXAxis: CategoryAxis(
          isInversed: true,

          labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),

          majorGridLines: const MajorGridLines(width: 0),

          majorTickLines: const MajorTickLines(width: 0),
        ),

        // ========================================================
        // VALUE AXIS
        // ========================================================
        primaryYAxis: NumericAxis(
          numberFormat: NumberFormat.compact(),

          labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),

          majorGridLines: MajorGridLines(color: Colors.white.withOpacity(.05)),
        ),

        // ========================================================
        // TOOLTIP
        // ========================================================
        tooltipBehavior: TooltipBehavior(
          enable: true,
          header: '',
          format: 'point.x : point.y ${data.unit}',
        ),

        // ========================================================
        // SERIES
        // ========================================================
        series: [
          BarSeries<_RankedUtilityBox, String>(
            name: theme.title,

            dataSource: rankedBoxes,

            // ====================================================
            // HIỆN RANK TRƯỚC BOX ID
            //
            // 1  DP-P8
            // 2  DPA-AC1
            // ====================================================
            xValueMapper: (item, _) => '${item.rank}  ${item.box.boxId}',

            yValueMapper: (item, _) => item.box.total,

            color: theme.line,

            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(3),
            ),

            // ====================================================
            // VALUE TRÊN BAR
            // ====================================================
            dataLabelMapper: (item, _) => _formatCompactValue(item.box.total),

            dataLabelSettings: const DataLabelSettings(
              isVisible: true,

              labelAlignment: ChartDataLabelAlignment.outer,

              textStyle: TextStyle(
                color: Colors.white,

                fontSize: 11,

                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEATMAP
  // ============================================================

  Widget _buildHeatmap(UtilityPeriodDashboard data) {
    final range = _heatRange(data);

    return _panelBox(
      title: '${_theme.title} CONSUMPTION HEATMAP (${data.unit})',
      child: Column(
        children: [
          SizedBox(
            height: 22,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [_buildHeatLegend()],
            ),
          ),

          const SizedBox(height: 4),

          _buildHeatmapHeader(data),

          Expanded(
            child: ListView.builder(
              itemCount: data.boxTrend.length,
              itemBuilder: (context, index) {
                final row = data.boxTrend[index];

                return _heatmapRow(row, range.min, range.max);
              },
            ),
          ),

          _heatmapTotalRow(data),
        ],
      ),
    );
  }

  Widget _buildHeatmapHeader(UtilityPeriodDashboard data) {
    return Container(
      height: 36,
      color: Colors.white.withOpacity(.025),
      child: Row(
        children: [
          const SizedBox(
            width: 130,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Panel',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          ),

          ...data.columns.map(
            (column) => Expanded(
              child: Center(
                child: Text(
                  column,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(
            width: 70,
            child: Center(
              child: Text(
                'Total',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heatmapRow(UtilityPeriodBoxTrend row, double min, double max) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Tooltip(
                  message: row.boxId,
                  child: Text(
                    row.boxId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),

          for (final value in row.values)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(.5),
                alignment: Alignment.center,
                color: _heatColor(value, min, max),
                child: Text(
                  _formatInteger(value),
                  style: TextStyle(
                    color: value <= 0 ? Colors.white30 : Colors.white,
                    fontSize: 12,
                    fontWeight: value > 0 ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),

          SizedBox(
            width: 70,
            child: Center(
              child: Text(
                _formatInteger(row.total),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heatmapTotalRow(UtilityPeriodDashboard data) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.04),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(.08))),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 130,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'TOTAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),

          for (final value in data.columnTotals)
            Expanded(
              child: Center(
                child: Text(
                  _formatInteger(value),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),

          SizedBox(
            width: 70,
            child: Center(
              child: Text(
                _formatInteger(data.grandTotal),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEAT LEGEND
  // ============================================================

  Widget _buildHeatLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Low',
          style: TextStyle(color: Colors.white60, fontSize: 10),
        ),

        const SizedBox(width: 6),

        Container(
          width: 110,
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF174F37),
                Color(0xFF4A8F38),
                Color(0xFFC7A51C),
                Color(0xFFD66A18),
                Color(0xFFC93232),
              ],
            ),
          ),
        ),

        const SizedBox(width: 6),

        const Text(
          'High',
          style: TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }

  // ============================================================
  // PANEL
  // ============================================================

  Widget _panelBox({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(_panelRadius),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),

          const SizedBox(height: 6),

          Expanded(child: child),
        ],
      ),
    );
  }

  // ============================================================
  // FORMAT
  // ============================================================

  String _formatNumber(num value) {
    return NumberFormat('#,##0').format(value);
  }

  String _formatInteger(num value) {
    return NumberFormat('#,##0').format(value);
  }

  // ============================================================
  // HEAT RANGE
  // ============================================================

  ({double min, double max}) _heatRange(UtilityPeriodDashboard data) {
    double? min;
    double? max;

    for (final row in data.boxTrend) {
      for (final value in row.values) {
        if (!value.isFinite || value <= 0) {
          continue;
        }

        min = min == null
            ? value
            : value < min
            ? value
            : min;

        max = max == null
            ? value
            : value > max
            ? value
            : max;
      }
    }

    return (min: min ?? 0, max: max ?? 0);
  }

  // ============================================================
  // HEAT COLOR
  // ============================================================

  Color _heatColor(double value, double min, double max) {
    if (!value.isFinite || value <= 0) {
      return Colors.white.withOpacity(.025);
    }

    if (max <= min) {
      return const Color(0xFF3F8F4D).withOpacity(.72);
    }

    final double ratio = ((value - min) / (max - min)).clamp(0.0, 1.0);

    if (ratio <= .25) {
      return Color.lerp(
        const Color(0xFF174F37),
        const Color(0xFF4A8F38),
        ratio / .25,
      )!.withOpacity(.82);
    }

    if (ratio <= .50) {
      return Color.lerp(
        const Color(0xFF4A8F38),
        const Color(0xFFC7A51C),
        (ratio - .25) / .25,
      )!.withOpacity(.84);
    }

    if (ratio <= .75) {
      return Color.lerp(
        const Color(0xFFC7A51C),
        const Color(0xFFD66A18),
        (ratio - .50) / .25,
      )!.withOpacity(.86);
    }

    return Color.lerp(
      const Color(0xFFD66A18),
      const Color(0xFFC93232),
      (ratio - .75) / .25,
    )!.withOpacity(.90);
  }
}
