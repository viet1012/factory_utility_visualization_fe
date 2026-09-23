import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../shared/widgets/chart_state_widgets.dart';
import '../../models/signal_health_history_models.dart';
import '../../signal_health_style.dart';
import '../../utils/signal_health_history_utils.dart';
import 'signal_health_history_panel.dart';

/// Stacked hourly alert trend, split by severity level.
///
/// Counts alert OCCURRENCES per hour, not unique devices/signals/descriptions
/// — see [kHistoryTrendHelp]. Receives an already-aggregated series from
/// [buildTrendSeries]; no aggregation happens here.
class SignalHealthHistoryTrendChart extends StatefulWidget {
  final List<HistoryTrendPoint> points;

  const SignalHealthHistoryTrendChart({super.key, required this.points});

  @override
  State<SignalHealthHistoryTrendChart> createState() =>
      _SignalHealthHistoryTrendChartState();
}

class _SignalHealthHistoryTrendChartState
    extends State<SignalHealthHistoryTrendChart> {
  late final TooltipBehavior _tooltipBehavior;

  @override
  void initState() {
    super.initState();

    /*
     * Tooltip dung builder rieng thay vi tooltip mac dinh, vi yeu cau la
     * luon hien full datetime (dd/MM/yyyy HH:mm) cung ca ba level va tong,
     * trong mot khoi duy nhat - khong phai mot dong cho moi series.
     */
    _tooltipBehavior = TooltipBehavior(
      enable: true,
      shared: true,
      color: kCard2,
      borderColor: kBorder,
      borderWidth: 1,
      /*
       * Overlay thay vi nam trong layout cua chart:
       *
       * - shouldAlwaysShow = false + canShowMarker = false: khong giu mot
       *   khoi chiem cho trong vung ve.
       * - tooltipPosition.auto: Syncfusion tu lat tooltip len hoac xuong
       *   theo vi tri con tro, nen khong bi cat o day hay dinh bieu do.
       *   Khong hardcode bottom.
       * - Padding nam trong _TrendTooltip (TooltipBehavior khong co tham so
       *   padding), nen chi co dung mot lop padding.
       */
      canShowMarker: false,
      shouldAlwaysShow: false,
      tooltipPosition: TooltipPosition.auto,
      elevation: 0,
      builder: (data, point, series, pointIndex, seriesIndex) {
        if (pointIndex < 0 || pointIndex >= widget.points.length) {
          return const SizedBox.shrink();
        }

        return _TrendTooltip(point: widget.points[pointIndex]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;

    // A single-day range needs no date on the axis; a multi-day one does.
    final singleDay = _isSingleDay(points);

    return SignalHealthHistoryChartShell(
      title: 'Hourly Alert Trend',
      subtitle: kHistoryTrendSubtitle,
      icon: Icons.show_chart_rounded,
      helpText: kHistoryTrendHelp,
      child: points.isEmpty
          ? const EmptyChartState(
              title: 'No Alerts',
              message: 'No alerts were recorded in this range.',
            )
          : SfCartesianChart(
              plotAreaBorderWidth: 1,
              plotAreaBorderColor: Colors.white.withValues(alpha: .12),
              tooltipBehavior: _tooltipBehavior,
              legend: const Legend(
                isVisible: true,
                position: LegendPosition.top,
                overflowMode: LegendItemOverflowMode.wrap,
                textStyle: TextStyle(color: kSubText, fontSize: 11),
              ),
              primaryXAxis: DateTimeAxis(
                intervalType: DateTimeIntervalType.hours,
                /*
                 * 24-gio, khong AM/PM. Nhan duoc build thu cong de co the
                 * xuong dong them ngay tai moc nua dem khi range nhieu ngay.
                 */
                axisLabelFormatter: (details) {
                  final value = DateTime.fromMillisecondsSinceEpoch(
                    details.value.toInt(),
                  );

                  return ChartAxisLabel(
                    formatTrendAxisLabel(value, singleDay: singleDay),
                    const TextStyle(color: kSubText, fontSize: 10.5),
                  );
                },
                majorGridLines: MajorGridLines(
                  width: 1,
                  color: Colors.white.withValues(alpha: .08),
                ),
                axisLine: AxisLine(
                  color: Colors.white.withValues(alpha: .15),
                  width: 1,
                ),
                labelStyle: const TextStyle(color: kSubText, fontSize: 10.5),
              ),
              primaryYAxis: NumericAxis(
                minimum: 0,
                // Integer alert counts: a fractional tick would be meaningless.
                decimalPlaces: 0,
                title: const AxisTitle(
                  text: 'Alert occurrences',
                  textStyle: TextStyle(color: kSubText, fontSize: 10.5),
                ),
                majorGridLines: MajorGridLines(
                  width: 1,
                  color: Colors.white.withValues(alpha: .08),
                ),
                axisLine: AxisLine(
                  color: Colors.white.withValues(alpha: .15),
                  width: 1,
                ),
                labelStyle: const TextStyle(color: kSubText, fontSize: 11),
              ),
              series: <CartesianSeries<HistoryTrendPoint, DateTime>>[
                _series(SignalHealthAlertLevel.level1, (point) => point.level1),
                _series(SignalHealthAlertLevel.level2, (point) => point.level2),
                _series(SignalHealthAlertLevel.level3, (point) => point.level3),
              ],
            ),
    );
  }

  bool _isSingleDay(List<HistoryTrendPoint> points) {
    if (points.length < 2) return true;

    final first = points.first.bucketTime.toLocal();
    final last = points.last.bucketTime.toLocal();

    return first.year == last.year &&
        first.month == last.month &&
        first.day == last.day;
  }

  /// Legend name and colour both come from [SignalHealthAlertLevel], so the
  /// trend can never disagree with the level cards.
  StackedColumnSeries<HistoryTrendPoint, DateTime> _series(
    SignalHealthAlertLevel level,
    int Function(HistoryTrendPoint) selector,
  ) {
    return StackedColumnSeries<HistoryTrendPoint, DateTime>(
      name: level.legendLabel,
      animationDuration: 0,
      dataSource: widget.points,
      color: level.color,
      xValueMapper: (point, _) => point.bucketTime,
      yValueMapper: (point, _) => selector(point),
    );
  }
}

/// Tooltip body: full local datetime, all three level counts, and the total.
///
/// Sizing rules that keep this inside the chart bounds:
///
/// - `mainAxisSize: MainAxisSize.min` on every Column/Row, so the widget is
///   only as tall as its content and never tries to fill the box Syncfusion
///   hands it.
/// - No fixed heights and no `Divider` (which reserves its own layout height
///   even at `height: 1`); the separator is a 1px `Container` instead.
/// - `IntrinsicWidth` + a `maxWidth` constraint so the block stays compact
///   horizontally without a `minWidth` forcing extra wrapping.
/// - Compact type and tight spacing throughout.
///
/// Total height is ~92px, which fits the plot area at any pointer position.
class _TrendTooltip extends StatelessWidget {
  final HistoryTrendPoint point;

  const _TrendTooltip({required this.point});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      constraints: const BoxConstraints(maxWidth: 210),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatFullDateTime(point.bucketTime),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kText,
                fontSize: 11,
                height: 1.15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            _line(SignalHealthAlertLevel.level1, point.level1),
            _line(SignalHealthAlertLevel.level2, point.level2),
            _line(SignalHealthAlertLevel.level3, point.level3),
            // 1px rule instead of a Divider: no reserved layout height.
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: kBorder,
            ),
            _totalRow(),
          ],
        ),
      ),
    );
  }

  Widget _totalRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Total alerts',
          maxLines: 1,
          style: TextStyle(
            color: kSubText,
            fontSize: 10.5,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${point.total}',
            textAlign: TextAlign.right,
            maxLines: 1,
            style: const TextStyle(
              color: kText,
              fontSize: 10.5,
              height: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _line(SignalHealthAlertLevel level, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: level.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            level.legendLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kSubText,
              fontSize: 10.5,
              height: 1.15,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              maxLines: 1,
              style: const TextStyle(
                color: kText,
                fontSize: 10.5,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
