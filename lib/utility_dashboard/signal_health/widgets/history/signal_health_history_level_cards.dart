import 'package:flutter/material.dart';

import '../../models/signal_health_history_models.dart';
import '../../signal_health_style.dart';
import '../../utils/signal_health_history_utils.dart';

/// Level 1 / Level 2 / Level 3 cards.
///
/// Each card summarises one severity at a glance: total, trend direction, peak
/// hour and a compact sparkline. The sparkline is intentionally axis-free —
/// the Hourly Alert Trend chart remains the detailed time-series view, and both
/// read the same buckets so they always cover the same range.
///
/// Tapping a card toggles the level filter applied to the description and
/// device charts. No OK/total-signal KPI is shown — the hourly history
/// endpoint does not return `totalSignals` or `okCount`.
class SignalHealthHistoryLevelCards extends StatelessWidget {
  /// Pre-computed summary per level, from [buildLevelTrend]. All trend, peak
  /// and series maths lives in the utils layer, never in this widget.
  final HistoryLevelTrend level1Trend;
  final HistoryLevelTrend level2Trend;
  final HistoryLevelTrend level3Trend;

  final SignalHealthAlertLevel? selectedLevel;
  final ValueChanged<SignalHealthAlertLevel> onLevelTapped;

  const SignalHealthHistoryLevelCards({
    super.key,
    required this.level1Trend,
    required this.level2Trend,
    required this.level3Trend,
    required this.selectedLevel,
    required this.onLevelTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LevelCard(
          level: SignalHealthAlertLevel.level1,
          trend: level1Trend,
          icon: Icons.error_rounded,
          selected: selectedLevel == SignalHealthAlertLevel.level1,
          onTap: () => onLevelTapped(SignalHealthAlertLevel.level1),
        ),
        const SizedBox(width: 16),
        _LevelCard(
          level: SignalHealthAlertLevel.level2,
          trend: level2Trend,
          icon: Icons.warning_amber_rounded,
          selected: selectedLevel == SignalHealthAlertLevel.level2,
          onTap: () => onLevelTapped(SignalHealthAlertLevel.level2),
        ),
        const SizedBox(width: 16),
        _LevelCard(
          level: SignalHealthAlertLevel.level3,
          trend: level3Trend,
          icon: Icons.info_rounded,
          selected: selectedLevel == SignalHealthAlertLevel.level3,
          onTap: () => onLevelTapped(SignalHealthAlertLevel.level3),
        ),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  final SignalHealthAlertLevel level;
  final HistoryLevelTrend trend;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _LevelCard({
    required this.level,
    required this.trend,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Colour and severity wording both come from the enum - never restated.
    final color = level.color;

    final value = trend.total;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: .10) : kCard,
            border: Border.all(
              color: color.withValues(alpha: selected ? .85 : .35),
              width: selected ? 1.6 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    height: 30,
                    width: 30,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          level.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontSize: 11.5,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .5,
                          ),
                        ),
                        Text(
                          level.severity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: kText,
                            fontSize: 12.5,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(Icons.filter_alt_rounded, color: color, size: 15),
                  Tooltip(
                    /*
                     * richMessage thay cho message: cho phep chen mot o mau
                     * theo severity ngay truoc dong tieu de, nen tooltip cung
                     * mang dung mau cua level nhu the.
                     */
                    richMessage: TextSpan(
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        TextSpan(
                          text: '${level.label} - ${level.severity}\n',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text:
                              '${level.description}\n\n'
                              'Total = alert occurrences in the selected '
                              'period.\n'
                              'Avg/hour = average alert occurrences per '
                              'hourly bucket.\n'
                              'Peak = highest hourly alert count.\n'
                              'Sparkline = alert occurrences per hour.\n\n'
                              // Visible peak is dd/MM HH:mm; the tooltip
                              // carries the full year as well.
                              '${formatPeakTooltipLine(trend.peakValue, trend.peakTime)}\n'
                              '$kHistoryCountMeaning',
                        ),
                      ],
                    ),
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(seconds: 8),
                    textStyle: const TextStyle(color: kText, fontSize: 11.5),
                    decoration: BoxDecoration(
                      color: kCard2,
                      border: Border.all(color: kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: kSubText,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              _metricRow(value),
              const SizedBox(height: 6),
              Row(
                children: [
                  // Legend indicator: ties the caption to the line below it.
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      kHistorySparklineLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // Tinted toward the level colour but kept muted, so the
                      // caption reads as a label rather than a headline.
                      style: TextStyle(
                        color: color.withValues(alpha: .80),
                        fontSize: 9.5,
                        height: 1.2,
                        letterSpacing: .4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 24,
                child: _Sparkline(
                  values: trend.series,
                  times: trend.times,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Total / Avg-per-hour / Peak on one line, using the card's full width.
  ///
  /// [Wrap] rather than [Row]: on a wide card the three metrics sit on one
  /// line; when the card narrows (three cards on a small window, or a long
  /// peak string) they reflow onto a second line instead of overflowing.
  /// `runSpacing` keeps the wrapped line from touching the sparkline.
  Widget _metricRow(int value) {
    return Wrap(
      spacing: 14,
      runSpacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Total is the headline figure, so it keeps the larger type.
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: kText,
                fontSize: 21,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'alerts',
              style: TextStyle(
                color: kSubText,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        _metricText(formatAveragePerHour(trend.averagePerHour)),
        _metricText(formatPeakMetric(trend.peakValue, trend.peakTime)),
      ],
    );
  }

  Widget _metricText(String text) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: kSubText,
        fontSize: 11,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Compact, axis-free hourly sparkline.
///
/// Hand-painted rather than a chart widget: three render per build and they
/// need no axes, tooltips or interaction. The detailed view is the Hourly
/// Alert Trend chart.
class _Sparkline extends StatefulWidget {
  final List<int> values;

  /// Bucket timestamps, index-for-index with [values].
  final List<DateTime> times;

  final Color color;

  const _Sparkline({
    required this.values,
    required this.times,
    required this.color,
  });

  @override
  State<_Sparkline> createState() => _SparklineState();
}

class _SparklineState extends State<_Sparkline> {
  /// Index under the pointer, or null when not hovering.
  int? _hoverIndex;

  /// Maps a local x position to the nearest bucket index.
  void _updateHover(Offset localPosition, double width) {
    final values = widget.values;

    if (values.length < 2 || width <= 0) return;

    final stepX = width / (values.length - 1);

    final index = (localPosition.dx / stepX).round().clamp(
      0,
      values.length - 1,
    );

    if (index == _hoverIndex) return;

    setState(() => _hoverIndex = index);
  }

  void _clearHover() {
    if (_hoverIndex == null) return;

    setState(() => _hoverIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.values;

    // A single bucket cannot show a shape; render nothing rather than a
    // misleading flat line.
    if (values.length < 2) return const SizedBox.shrink();

    final index = _hoverIndex;

    final hasTime = index != null && index < widget.times.length;

    /*
     * Tooltip theo diem: message doi theo bucket dang hover, nen Tooltip
     * duoc key theo index de Flutter dung lai overlay voi noi dung moi.
     */
    final message = hasTime
        ? formatSparklinePointTooltip(widget.times[index], values[index])
        : '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final chart = MouseRegion(
          onHover: (event) {
            _updateHover(event.localPosition, constraints.maxWidth);
          },
          onExit: (_) => _clearHover(),
          child: CustomPaint(
            size: Size.infinite,
            painter: _SparklinePainter(
              values: values,
              color: widget.color,
              highlightIndex: index,
            ),
          ),
        );

        if (!hasTime) return chart;

        return Tooltip(
          key: ValueKey<int>(index),
          message: message,
          preferBelow: false,
          textStyle: const TextStyle(color: kText, fontSize: 11),
          decoration: BoxDecoration(
            color: kCard2,
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(7),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: chart,
        );
      },
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> values;
  final Color color;

  /// Bucket under the pointer; draws a marker so the tooltip's hour is
  /// visually tied to a point on the line.
  final int? highlightIndex;

  const _SparklinePainter({
    required this.values,
    required this.color,
    this.highlightIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;

    var maxValue = 0;

    for (final value in values) {
      if (value > maxValue) maxValue = value;
    }

    // An all-zero range draws along the baseline instead of dividing by zero.
    final safeMax = maxValue <= 0 ? 1 : maxValue;

    // Inset so the stroke is not clipped at the top and bottom edges.
    const inset = 2.0;

    final usableHeight = size.height - (inset * 2);

    final stepX = size.width / (values.length - 1);

    final line = Path();
    final fill = Path();

    for (var index = 0; index < values.length; index++) {
      final x = stepX * index;
      final y = inset + usableHeight - (values[index] / safeMax) * usableHeight;

      if (index == 0) {
        line.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        line.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }

    fill.lineTo(size.width, size.height);
    fill.close();

    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: .15));

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    final index = highlightIndex;

    if (index == null || index < 0 || index >= values.length) return;

    final markerX = stepX * index;
    final markerY =
        inset + usableHeight - (values[index] / safeMax) * usableHeight;

    // Vertical guide plus a dot, so a zero bucket still shows a marker on the
    // baseline rather than appearing to have no data.
    canvas.drawLine(
      Offset(markerX, 0),
      Offset(markerX, size.height),
      Paint()
        ..color = color.withValues(alpha: .45)
        ..strokeWidth = 1,
    );

    canvas.drawCircle(Offset(markerX, markerY), 2.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.highlightIndex != highlightIndex ||
        !_sameValues(oldDelegate.values);
  }

  bool _sameValues(List<int> other) {
    if (other.length != values.length) return false;

    for (var index = 0; index < values.length; index++) {
      if (other[index] != values[index]) return false;
    }

    return true;
  }
}
