import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../shared/charts/axis_planner.dart';
import '../../../shared/charts/chart_hover_style.dart';
import '../../../shared/charts/signal_chart_spec.dart';
import '../../../shared/charts/value_format.dart';
import '../../../shared/widgets/chart_state_widgets.dart';
import '../helpers/solar_detail_formatters.dart';
import '../models/solar_hourly_by_facility.dart';
import 'solar_detail_panel.dart';

/// Panel HOURLY SOLAR BY FACILITY: cot theo gio (0–23) moi fac mot mau,
/// legend bat / tat fac, bang tom tat ty trong + peak.
///
/// State du lieu (ngay, loading, loi) do man hinh cha giu; panel chi giu
/// state hien thi (che do cot, fac dang an).
class SolarHourlyByFacilityPanel extends StatefulWidget {
  final SolarHourlyByFacility? data;

  final DateTime date;

  /// Khoang ngay chon duoc (trong thang dang chon, khong qua hom nay).
  final DateTime firstDate;
  final DateTime lastDate;

  final bool loading;

  final String? error;

  final ValueChanged<DateTime> onDateChanged;

  final VoidCallback onRetry;

  const SolarHourlyByFacilityPanel({
    super.key,
    required this.data,
    required this.date,
    required this.firstDate,
    required this.lastDate,
    required this.loading,
    required this.error,
    required this.onDateChanged,
    required this.onRetry,
  });

  @override
  State<SolarHourlyByFacilityPanel> createState() =>
      _SolarHourlyByFacilityPanelState();
}

class _SolarHourlyByFacilityPanelState
    extends State<SolarHourlyByFacilityPanel> {
  static const String _unit = 'kWh';

  /// Duoi do rong nay bang tom tat xuong duoi chart.
  static const double _narrowWidth = 640;

  static const SignalChartSpec _axisSpec = SignalChartSpec(
    style: ChartStyle.bar,
    axis: AxisMode.zeroBased,
    decimals: 0,
    showThreshold: false,
  );

  bool _stacked = true;

  final Set<String> _hidden = {};

  @override
  Widget build(BuildContext context) {
    return SolarDetailPanel(
      title: 'HOURLY SOLAR BY FACILITY',
      titleColor: SolarDetailColors.yellow,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [_modeToggle(), const SizedBox(width: 8), _dateNav()],
      ),
      child: Expanded(child: _content()),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _content() {
    final error = widget.error;
    if (error != null) {
      return ChartApiErrorState(
        onRetry: widget.onRetry,
        title: 'Unable to Load Hourly Data',
        message: error,
      );
    }

    final data = widget.data;
    if (data == null) {
      return const Center(
        child: CircularProgressIndicator(color: SolarDetailColors.yellow),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedOpacity(
            opacity: widget.loading ? .35 : 1,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(ignoring: widget.loading, child: _body(data)),
          ),
        ),

        if (widget.loading)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: SolarDetailColors.yellow,
            ),
          ),
      ],
    );
  }

  Widget _body(SolarHourlyByFacility data) {
    final facilities = data.facilities;

    if (facilities.isEmpty) {
      return const EmptyChartState(
        icon: Icons.wb_sunny_outlined,
        message: 'There is no solar data for this day.',
      );
    }

    final colors = [
      for (final (i, fac) in facilities.indexed)
        SolarDetailColors.facility(fac.facId, fallbackIndex: i),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < _narrowWidth;

        final chart = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _legend(facilities, colors),
            const SizedBox(height: 4),
            Expanded(child: _chart(facilities, colors)),
          ],
        );

        final summary = _summary(data, colors);

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: chart),
              const SizedBox(height: 6),
              summary,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: chart),
            const SizedBox(width: 10),
            SizedBox(width: 250, child: Center(child: summary)),
          ],
        );
      },
    );
  }

  // ============================================================
  // HEADER CONTROLS
  // ============================================================

  Widget _modeToggle() {
    Widget segment(String label, bool selected, bool stacked) {
      return InkWell(
        onTap: selected ? null : () => setState(() => _stacked = stacked),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? SolarDetailColors.yellow.withValues(alpha: .18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? SolarDetailColors.yellow : Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SolarDetailColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment('Stacked', _stacked, true),
          segment('Side by side', !_stacked, false),
        ],
      ),
    );
  }

  Widget _dateNav() {
    final date = _dayOf(widget.date);
    final first = _dayOf(widget.firstDate);
    final last = _dayOf(widget.lastDate);

    final canPrev = date.isAfter(first);
    final canNext = date.isBefore(last);

    Widget arrow(IconData icon, String tooltip, bool enabled, int delta) {
      return IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        iconSize: 20,
        color: Colors.white70,
        disabledColor: Colors.white24,
        onPressed: enabled
            ? () => widget.onDateChanged(date.add(Duration(days: delta)))
            : null,
        icon: Icon(icon),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        arrow(Icons.chevron_left_rounded, 'Previous day', canPrev, -1),

        InkWell(
          onTap: last.isBefore(first) ? null : () => _pickDate(first, last),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: SolarDetailColors.yellow,
                ),
                const SizedBox(width: 5),
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),

        arrow(Icons.chevron_right_rounded, 'Next day', canNext, 1),
      ],
    );
  }

  Future<void> _pickDate(DateTime first, DateTime last) async {
    final current = _dayOf(widget.date);
    final initial = current.isBefore(first)
        ? first
        : current.isAfter(last)
        ? last
        : current;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );

    if (picked == null || !mounted) return;
    if (_dayOf(picked) == current) return;

    widget.onDateChanged(_dayOf(picked));
  }

  // ============================================================
  // LEGEND
  // ============================================================

  Widget _legend(List<SolarFacilityHourly> facilities, List<Color> colors) {
    final toggleable = facilities.length > 1;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final (i, fac) in facilities.indexed)
          _legendItem(fac, colors[i], toggleable),
      ],
    );
  }

  Widget _legendItem(SolarFacilityHourly fac, Color color, bool toggleable) {
    final hidden = _hidden.contains(fac.facId);

    return InkWell(
      onTap: toggleable
          ? () => setState(() {
              if (!_hidden.remove(fac.facId)) _hidden.add(fac.facId);
            })
          : null,
      borderRadius: BorderRadius.circular(6),
      child: Opacity(
        opacity: hidden ? .35 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${fac.facId}  ',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    TextSpan(
                      text: formatWithUnit(fac.totalKwh, _unit, decimals: 1),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  decoration: hidden ? TextDecoration.lineThrough : null,
                  decorationColor: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CHART
  // ============================================================

  Widget _chart(List<SolarFacilityHourly> facilities, List<Color> colors) {
    final rows = [
      for (var hour = 0; hour < 24; hour++)
        _HourRow(hour, [for (final fac in facilities) fac.kwhAt(hour)]),
    ];

    final visible = [
      for (final (i, fac) in facilities.indexed)
        if (!_hidden.contains(fac.facId)) i,
    ];

    final axis = planAxis(
      values: [
        0,
        for (final row in rows)
          if (_stacked)
            row.sumOf(visible)
          else
            for (final i in visible) row.values[i],
      ],
      spec: _axisSpec,
    );

    const labelStyle = TextStyle(
      color: Colors.white60,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    return SfCartesianChart(
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 0,

      tooltipBehavior: TooltipBehavior(
        enable: true,
        builder: (data, point, series, pointIndex, seriesIndex) {
          return _tooltip(data as _HourRow, facilities, colors, visible);
        },
      ),

      primaryXAxis: CategoryAxis(
        interval: 2,
        labelIntersectAction: AxisLabelIntersectAction.hide,
        majorGridLines: const MajorGridLines(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        axisLine: AxisLine(color: Colors.white.withValues(alpha: .20)),
        labelStyle: labelStyle,
      ),

      primaryYAxis: NumericAxis(
        minimum: axis.min,
        maximum: axis.max,
        interval: axis.interval,
        title: const AxisTitle(text: _unit, textStyle: labelStyle),
        axisLabelFormatter: (details) =>
            ChartAxisLabel(axis.label(details.value), details.textStyle),
        majorGridLines: MajorGridLines(
          color: Colors.white.withValues(alpha: .06),
        ),
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        labelStyle: labelStyle,
      ),

      series: <CartesianSeries<_HourRow, String>>[
        for (final i in visible)
          if (_stacked)
            StackedColumnSeries<_HourRow, String>(
              name: facilities[i].facId,
              dataSource: rows,
              xValueMapper: (r, _) => r.label,
              yValueMapper: (r, _) => r.values[i],
              color: colors[i],
              width: .7,
              spacing: 0,
            )
          else
            ColumnSeries<_HourRow, String>(
              name: facilities[i].facId,
              dataSource: rows,
              xValueMapper: (r, _) => r.label,
              yValueMapper: (r, _) => r.values[i],
              color: colors[i],
              width: .8,
              spacing: .1,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
            ),
      ],
    );
  }

  Widget _tooltip(
    _HourRow row,
    List<SolarFacilityHourly> facilities,
    List<Color> colors,
    List<int> visible,
  ) {
    final showTotal = visible.length > 1;

    return ChartHoverCard(
      title: row.range,
      rows: [
        for (final i in visible)
          (
            facilities[i].facId,
            formatWithUnit(row.values[i], _unit, decimals: 1),
          ),
        if (showTotal)
          ('Total', formatWithUnit(row.sumOf(visible), _unit, decimals: 1)),
      ],
      swatches: [for (final i in visible) colors[i], if (showTotal) null],
    );
  }

  // ============================================================
  // SUMMARY TABLE
  // ============================================================

  Widget _summary(SolarHourlyByFacility data, List<Color> colors) {
    final facilities = data.facilities;

    final sum = facilities.fold<double>(0, (acc, f) => acc + f.totalKwh);

    final totalPeak = data.totalPeak;

    const headStyle = TextStyle(
      color: Colors.white38,
      fontSize: 10,
      fontWeight: FontWeight.w800,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text('FACILITY / SHARE', style: headStyle),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'PEAK',
                  textAlign: TextAlign.right,
                  style: headStyle,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'HOUR',
                  textAlign: TextAlign.right,
                  style: headStyle,
                ),
              ),
            ],
          ),
        ),

        for (final (i, fac) in facilities.indexed)
          _summaryRow(
            fac: fac,
            color: colors[i],
            share: sum > 0 ? fac.totalKwh / sum : 0,
          ),

        if (facilities.length > 1) ...[
          Divider(height: 10, color: Colors.white.withValues(alpha: .12)),
          _peakRow(
            label: 'KVH peak',
            kwh: totalPeak?.kwh,
            hour: totalPeak?.hour,
            color: Colors.white,
          ),
        ],
      ],
    );
  }

  Widget _summaryRow({
    required SolarFacilityHourly fac,
    required Color color,
    required double share,
  }) {
    final hidden = _hidden.contains(fac.facId);

    return Opacity(
      opacity: hidden ? .4 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fac.facId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${formatValue(share * 100, decimals: 1)}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: share.clamp(0, 1).toDouble(),
                      minHeight: 5,
                      color: color,
                      backgroundColor: Colors.white.withValues(alpha: .08),
                    ),
                  ),
                ],
              ),
            ),
            ..._peakCells(fac.peakKwh, fac.peakHour, Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _peakRow({
    required String label,
    required double? kwh,
    required int? hour,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          ..._peakCells(kwh, hour, color),
        ],
      ),
    );
  }

  List<Widget> _peakCells(double? kwh, int? hour, Color color) {
    final style = TextStyle(
      color: color,
      fontSize: 12,
      fontWeight: FontWeight.w800,
    );

    return [
      Expanded(
        flex: 3,
        child: Text(
          formatWithUnit(kwh, _unit, decimals: 1),
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
      Expanded(
        flex: 2,
        child: Text(
          hour == null ? kMissingValue : _hourLabel(hour),
          textAlign: TextAlign.right,
          style: style,
        ),
      ),
    ];
  }

  static DateTime _dayOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

String _hourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';

/// Mot gio tren truc X; [values] theo thu tu facilities (null = chua co).
class _HourRow {
  final int hour;
  final List<double?> values;

  const _HourRow(this.hour, this.values);

  String get label => hour.toString().padLeft(2, '0');

  /// "09:00–10:00"
  String get range => '${_hourLabel(hour)}–${_hourLabel(hour + 1)}';

  /// Tong cac fac [indexes], bo qua gio null; null khi khong co gia tri nao.
  double? sumOf(List<int> indexes) {
    double? total;

    for (final i in indexes) {
      final v = values[i];
      if (v == null) continue;
      total = (total ?? 0) + v;
    }

    return total;
  }
}
