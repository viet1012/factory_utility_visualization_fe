import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../shared/charts/chart_hover_style.dart';
import '../../../shared/charts/value_format.dart';
import '../helpers/solar_detail_formatters.dart';
import '../models/solar_detail_data.dart';
import 'solar_detail_panel.dart';

/// Bieu do MONTHLY ENERGY TREND: stacked column Grid + Solar theo ngay,
/// duong Solar % tren truc Y phu ben phai.
class SolarDailyGenerationPanel extends StatelessWidget {
  static const String _shareAxis = 'solarShare';

  /// Cot cua hom nay (chua het ngay) to mo de khong bi hieu la sut san luong.
  static const double _partialAlpha = .4;

  final SolarDetailData data;

  /// yyyyMM, dung cho tieu de panel.
  final String month;

  /// Bam cot ngay: chuyen chart Hourly sang ngay do.
  final ValueChanged<DateTime>? onDaySelected;

  const SolarDailyGenerationPanel({
    super.key,
    required this.data,
    required this.month,
    this.onDaySelected,
  });

  void _onPointTap(ChartPointDetails details) {
    final index = details.pointIndex;
    final callback = onDaySelected;

    if (callback == null || index == null) return;
    if (index < 0 || index >= data.dailyTrend.length) return;

    callback(data.dailyTrend[index].date);
  }

  @override
  Widget build(BuildContext context) {
    final trend = data.dailyTrend;

    // Truc trai: MWh khi ngay lon nhat >= 1000 kWh, nguoc lai kWh.
    final maxTotal = trend.fold<double>(
      0,
      (acc, e) => math.max(acc, e.totalKwh),
    );
    final useMwh = maxTotal >= 1000;
    final unit = useMwh ? 'MWh' : 'kWh';
    final scale = useMwh ? 1000.0 : 1.0;
    final decimals = useMwh ? 1 : 0;

    double toUnit(double kwh) => kwh / scale;

    // Truc phai: 0 -> max(20%, boi so 5 lam tron len cua gia tri lon nhat).
    final maxShare = trend.fold<double>(
      0,
      (acc, e) => math.max(acc, e.solarSharePercent ?? 0),
    );
    final shareMax = math.max(20.0, (maxShare / 5).ceil() * 5.0);
    final shareInterval = 5.0 * (shareMax / 25).ceil();

    final now = DateTime.now();
    bool isToday(SolarDailyTrend e) =>
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day;

    Color columnColor(SolarDailyTrend e, Color color) =>
        isToday(e) ? color.withValues(alpha: _partialAlpha) : color;

    String label(double kwh) =>
        kwh == 0 ? '' : formatValue(toUnit(kwh), decimals: decimals);

    const axisLabelStyle = TextStyle(
      color: Colors.white60,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    return SolarDetailPanel(
      title:
          'MONTHLY ENERGY TREND • '
          '${SolarDetailFormatters.monthLabel(month).toUpperCase()}',
      titleColor: SolarDetailColors.yellow,

      child: Expanded(
        child: SfCartesianChart(
          margin: EdgeInsets.zero,
          plotAreaBorderWidth: 0,

          // =========================================================
          // LEGEND
          // =========================================================
          legend: const Legend(
            isVisible: true,
            position: LegendPosition.top,
            alignment: ChartAlignment.center,
            textStyle: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),

          // =========================================================
          // TOOLTIP
          // =========================================================
          tooltipBehavior: TooltipBehavior(
            enable: true,
            builder: (point, _, _, _, _) {
              final e = point as SolarDailyTrend;
              final share = e.solarSharePercent;

              return ChartHoverCard(
                title:
                    DateFormat('dd MMM yyyy').format(e.date) +
                    (isToday(e) ? ' (today, partial)' : ''),
                rows: [
                  ('Grid', formatWithUnit(toUnit(e.gridKwh), unit)),
                  ('Solar', formatWithUnit(toUnit(e.solarKwh), unit)),
                  (
                    'Solar share',
                    share == null
                        ? kMissingValue
                        : '${formatValue(share, decimals: 1)}%',
                  ),
                ],
                swatches: const [
                  SolarDetailColors.cyan,
                  SolarDetailColors.yellow,
                  SolarDetailColors.green,
                ],
              );
            },
          ),

          // =========================================================
          // X AXIS
          // =========================================================
          primaryXAxis: DateTimeAxis(
            dateFormat: DateFormat('dd'),

            intervalType: DateTimeIntervalType.days,

            interval: 1,

            majorGridLines: const MajorGridLines(width: 0),

            axisLine: AxisLine(color: Colors.white.withValues(alpha: .20)),

            majorTickLines: const MajorTickLines(size: 0),

            labelStyle: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),

          // =========================================================
          // Y AXIS
          // =========================================================
          primaryYAxis: NumericAxis(
            minimum: 0,

            title: AxisTitle(text: unit, textStyle: axisLabelStyle),

            axisLabelFormatter: (details) => ChartAxisLabel(
              formatValue(details.value, decimals: decimals),
              details.textStyle,
            ),

            majorGridLines: MajorGridLines(
              color: Colors.white.withValues(alpha: .06),
              width: 1,
            ),

            axisLine: const AxisLine(width: 0),

            majorTickLines: const MajorTickLines(size: 0),

            labelStyle: axisLabelStyle,
          ),

          // =========================================================
          // Y AXIS PHU - SOLAR %
          // =========================================================
          axes: <ChartAxis>[
            NumericAxis(
              name: _shareAxis,
              opposedPosition: true,
              minimum: 0,
              maximum: shareMax,
              interval: shareInterval,
              axisLabelFormatter: (details) => ChartAxisLabel(
                '${formatValue(details.value, decimals: 0)}%',
                details.textStyle,
              ),
              majorGridLines: const MajorGridLines(width: 0),
              axisLine: const AxisLine(width: 0),
              majorTickLines: const MajorTickLines(size: 0),
              labelStyle: axisLabelStyle,
            ),
          ],

          // =========================================================
          // STACKED COLUMN
          //
          // GRID + SOLAR = TOTAL
          // =========================================================
          series: <CartesianSeries<SolarDailyTrend, DateTime>>[
            // ============================================================
            // GRID - PHẦN DƯỚI
            // ============================================================
            StackedColumnSeries<SolarDailyTrend, DateTime>(
              name: 'Grid',
              dataSource: trend,

              xValueMapper: (e, _) => e.date,
              yValueMapper: (e, _) => toUnit(e.gridKwh),

              color: SolarDetailColors.cyan,

              pointColorMapper: (e, _) =>
                  columnColor(e, SolarDetailColors.cyan),

              width: 0.65,
              spacing: 0.10,

              enableTooltip: true,

              onPointTap: _onPointTap,

              // ============================
              // HIỂN THỊ VALUE
              // ============================
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                labelAlignment: ChartDataLabelAlignment.middle,
                textStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),

              dataLabelMapper: (e, _) {
                return label(e.gridKwh);
              },
            ),

            // ============================================================
            // SOLAR - PHẦN TRÊN
            // ============================================================
            StackedColumnSeries<SolarDailyTrend, DateTime>(
              name: 'Solar',
              dataSource: trend,

              xValueMapper: (e, _) => e.date,
              yValueMapper: (e, _) => toUnit(e.solarKwh),

              color: SolarDetailColors.yellow,

              pointColorMapper: (e, _) =>
                  columnColor(e, SolarDetailColors.yellow),

              width: 0.65,
              spacing: 0.10,

              enableTooltip: true,

              onPointTap: _onPointTap,

              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),

              // ============================
              // HIỂN THỊ VALUE
              // ============================
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                labelAlignment: ChartDataLabelAlignment.middle,
                textStyle: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),

              dataLabelMapper: (e, _) {
                return label(e.solarKwh);
              },
            ),

            // ============================================================
            // SOLAR % - DUONG NET DUT, TRUC PHAI
            // ============================================================
            LineSeries<SolarDailyTrend, DateTime>(
              name: 'Solar %',
              dataSource: trend,
              yAxisName: _shareAxis,

              xValueMapper: (e, _) => e.date,
              yValueMapper: (e, _) => e.solarSharePercent,

              color: SolarDetailColors.green,
              width: 2,
              dashArray: const <double>[5, 4],

              markerSettings: const MarkerSettings(
                isVisible: true,
                width: 5,
                height: 5,
                shape: DataMarkerType.circle,
                color: SolarDetailColors.green,
                borderWidth: 0,
              ),

              enableTooltip: true,

              onPointTap: _onPointTap,
            ),
          ],
        ),
      ),
    );
  }
}
