import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../signal_chart/signal_chart_palette.dart';
import 'filter_chart_groups.dart';

/// Timeline STATUS: moi device mot hang, mau = statusCodeColor(last).
/// Re chuot: vach doc + the ghi thoi diem va ma cua moi device.
class FilterStatusTimeline extends StatefulWidget {
  final List<FilterChartMember> members;

  const FilterStatusTimeline({super.key, required this.members});

  static const double rowHeight = 16;
  static const double rowGap = 5;
  static const double labelWidth = 120;
  static const double axisHeight = 18;

  /// Chieu cao can cho [count] hang.
  static double heightFor(int count) {
    return count * (rowHeight + rowGap) + axisHeight;
  }

  @override
  State<FilterStatusTimeline> createState() => _FilterStatusTimelineState();
}

class _Run {
  final DateTime start;
  final DateTime end;
  final int code;

  const _Run(this.start, this.end, this.code);
}

class _FilterStatusTimelineState extends State<FilterStatusTimeline> {
  /// Vi tri chuot trong vung timeline (null = khong re).
  double? _hoverX;

  @override
  Widget build(BuildContext context) {
    final members = [
      for (final member in widget.members)
        if (member.series != null) member,
    ];

    final runs = <FilterChartMember, List<_Run>>{
      for (final member in members) member: _runsOf(member),
    };

    DateTime? from;
    DateTime? to;

    for (final list in runs.values) {
      for (final run in list) {
        if (from == null || run.start.isBefore(from)) from = run.start;
        if (to == null || run.end.isAfter(to)) to = run.end;
      }
    }

    if (from == null || to == null || !to.isAfter(from)) {
      return const Center(
        child: Text(
          'No status data in this range',
          style: TextStyle(color: SignalChartColors.mutedText, fontSize: 12),
        ),
      );
    }

    final start = from;
    final span = to.difference(start).inMilliseconds.toDouble();
    final multiDay = to.difference(start) > const Duration(days: 1);
    final format = DateFormat(multiDay ? 'dd/MM HH:mm' : 'HH:mm');

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(
          constraints.maxWidth - FilterStatusTimeline.labelWidth,
          1.0,
        );

        DateTime timeAt(double x) => start.add(
          Duration(milliseconds: (x.clamp(0, width) / width * span).round()),
        );

        final hoverX = _hoverX;
        final hoverTime = hoverX == null ? null : timeAt(hoverX);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                for (final member in members)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: FilterStatusTimeline.rowGap,
                    ),
                    child: SizedBox(
                      height: FilterStatusTimeline.rowHeight,
                      child: Row(
                        children: [
                          SizedBox(
                            width: FilterStatusTimeline.labelWidth,
                            child: Text(
                              member.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: SignalChartColors.subText,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: CustomPaint(
                              painter: _RunsPainter(
                                runs[member]!,
                                start,
                                span,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(
                  height: FilterStatusTimeline.axisHeight,
                  child: Row(
                    children: [
                      const SizedBox(width: FilterStatusTimeline.labelWidth),
                      Text(format.format(start), style: _axisStyle),
                      const Spacer(),
                      Text(format.format(to!), style: _axisStyle),
                    ],
                  ),
                ),
              ],
            ),
            // Vung re chuot chi phu phan timeline.
            Positioned(
              left: FilterStatusTimeline.labelWidth,
              top: 0,
              width: width,
              bottom: FilterStatusTimeline.axisHeight,
              child: MouseRegion(
                onHover: (event) =>
                    setState(() => _hoverX = event.localPosition.dx),
                onExit: (_) => setState(() => _hoverX = null),
                child: const SizedBox.expand(),
              ),
            ),
            if (hoverX != null && hoverTime != null) ...[
              Positioned(
                left: FilterStatusTimeline.labelWidth + hoverX,
                top: 0,
                bottom: FilterStatusTimeline.axisHeight,
                child: IgnorePointer(
                  child: Container(
                    width: 1,
                    color: Colors.white.withValues(alpha: .45),
                  ),
                ),
              ),
              Positioned(
                // Lat the sang trai khi gan mep phai.
                left: hoverX > width / 2
                    ? null
                    : FilterStatusTimeline.labelWidth + hoverX + 8,
                right: hoverX > width / 2 ? width - hoverX + 8 : null,
                top: 0,
                child: IgnorePointer(
                  child: _HoverCard(
                    time: format.format(hoverTime),
                    entries: [
                      for (final member in members)
                        (
                          member: member,
                          code: _codeAt(runs[member]!, hoverTime),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static const TextStyle _axisStyle = TextStyle(
    color: SignalChartColors.mutedText,
    fontSize: 10.5,
  );

  /// Gop bucket lien tiep cung ma thanh mot doan; bucket rong ngat doan.
  static List<_Run> _runsOf(FilterChartMember member) {
    final series = member.series!;
    final points = series.points;
    final runs = <_Run>[];

    final step =
        series.bucket ??
        (points.length > 1
            ? points[1].ts.difference(points[0].ts)
            : const Duration(minutes: 1));

    DateTime? runStart;
    int? runCode;
    DateTime? runEnd;

    void flush() {
      if (runStart != null && runCode != null && runEnd != null) {
        runs.add(_Run(runStart!, runEnd!, runCode!));
      }
      runStart = null;
      runCode = null;
      runEnd = null;
    }

    for (final point in points) {
      final value = series.plotValue(point);

      if (value == null) {
        flush();
        continue;
      }

      final code = value.round();
      final end = point.ts.add(step);

      if (runCode == code && runEnd != null && !point.ts.isAfter(runEnd!)) {
        runEnd = end;
        continue;
      }

      flush();
      runStart = point.ts;
      runCode = code;
      runEnd = end;
    }

    flush();
    return runs;
  }

  static int? _codeAt(List<_Run> runs, DateTime time) {
    for (final run in runs) {
      if (!time.isBefore(run.start) && time.isBefore(run.end)) return run.code;
    }
    return null;
  }
}

class _RunsPainter extends CustomPainter {
  final List<_Run> runs;
  final DateTime start;
  final double span;

  _RunsPainter(this.runs, this.start, this.span);

  @override
  void paint(Canvas canvas, Size size) {
    // Nen nhat: khoang khong co du lieu de trong tren nen nay.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3)),
      Paint()..color = Colors.white.withValues(alpha: .04),
    );

    for (final run in runs) {
      final x0 = run.start.difference(start).inMilliseconds / span * size.width;
      final x1 = run.end.difference(start).inMilliseconds / span * size.width;

      canvas.drawRect(
        Rect.fromLTRB(x0, 0, math.max(x1, x0 + 1), size.height),
        Paint()..color = statusCodeColor(run.code),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RunsPainter old) {
    return !identical(old.runs, runs) || old.start != start || old.span != span;
  }
}

class _HoverCard extends StatelessWidget {
  final String time;
  final List<({FilterChartMember member, int? code})> entries;

  const _HoverCard({required this.time, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: SignalChartColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SignalChartColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            time,
            style: const TextStyle(
              color: SignalChartColors.mutedText,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    color: entry.code == null
                        ? Colors.transparent
                        : statusCodeColor(entry.code!),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      entry.member.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SignalChartColors.subText,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    entry.code == null ? '—' : 'Code ${entry.code}',
                    style: const TextStyle(
                      color: SignalChartColors.text,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
