import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../helpers/solar_detail_formatters.dart';
import '../models/solar_detail_data.dart';
import 'solar_detail_panel.dart';

/// Bieu do MONTHLY ENERGY TREND: stacked column Grid + Solar theo ngay.
class SolarDailyGenerationPanel extends StatelessWidget {
  final SolarDetailData data;

  /// yyyyMM, dung cho tieu de panel.
  final String month;

  const SolarDailyGenerationPanel({
    super.key,
    required this.data,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
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
            shared: true,
            canShowMarker: true,
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

            numberFormat: NumberFormat.compact(),

            majorGridLines: MajorGridLines(
              color: Colors.white.withValues(alpha: .06),
              width: 1,
            ),

            axisLine: const AxisLine(width: 0),

            majorTickLines: const MajorTickLines(size: 0),

            labelStyle: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),

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
              dataSource: data.dailyTrend,

              xValueMapper: (e, _) => e.date,
              yValueMapper: (e, _) => e.gridKwh,

              color: SolarDetailColors.cyan,

              width: 0.65,
              spacing: 0.10,

              enableTooltip: true,

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
                return _chartValue(e.gridKwh);
              },
            ),

            // ============================================================
            // SOLAR - PHẦN TRÊN
            // ============================================================
            StackedColumnSeries<SolarDailyTrend, DateTime>(
              name: 'Solar',
              dataSource: data.dailyTrend,

              xValueMapper: (e, _) => e.date,
              yValueMapper: (e, _) => e.solarKwh,

              color: SolarDetailColors.yellow,

              width: 0.65,
              spacing: 0.10,

              enableTooltip: true,

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
                return _chartValue(e.solarKwh);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _chartValue(num value) {
    if (value == 0) {
      return '';
    }

    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    return value.toStringAsFixed(0);
  }
}
