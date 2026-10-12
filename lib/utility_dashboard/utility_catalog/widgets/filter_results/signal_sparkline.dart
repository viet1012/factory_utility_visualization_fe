import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/signal_history_models.dart';
import '../signal_chart/signal_chart_palette.dart';

/// Sparkline 1h khong truc cho bang Filter results (~24px).
///
/// - ANALOG / COUNTER: duong avg; diem null ngat duong.
/// - STATUS: dai mau theo `last` cua tung bucket (moi ma trang thai 1 mau).
class SignalSparkline extends StatelessWidget {
  final SignalHistorySeries series;
  final Color color;
  final double height;

  const SignalSparkline({
    super.key,
    required this.series,
    required this.color,
    this.height = 24,
  });

  @override
  Widget build(BuildContext context) {
    final isStatus = series.kind == SignalKind.status;

    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: isStatus
            ? _StatusStripPainter(series)
            : _LinePainter(series, color),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final SignalHistorySeries series;
  final Color color;

  _LinePainter(this.series, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final points = series.points;
    if (points.length < 2) return;

    double? lo;
    double? hi;

    for (final point in points) {
      final value = series.plotValue(point);
      if (value == null) continue;
      lo = lo == null ? value : math.min(lo, value);
      hi = hi == null ? value : math.max(hi, value);
    }

    if (lo == null || hi == null) return;

    final start = points.first.ts.millisecondsSinceEpoch;
    final span = math.max(points.last.ts.millisecondsSinceEpoch - start, 1);

    // Tin hieu phang (bien do ~0): ve duong giua.
    final range = hi - lo;
    final flat = range <= math.max(hi.abs() * 1e-9, 1e-6);

    double yOf(double value) {
      if (flat) return size.height / 2;
      const pad = 2.0;
      return pad + (1 - (value - lo!) / range) * (size.height - pad * 2);
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    var drawing = false;

    for (final point in points) {
      final value = series.plotValue(point);

      if (value == null) {
        drawing = false; // diem null: ngat duong
        continue;
      }

      final x =
          (point.ts.millisecondsSinceEpoch - start) / span * size.width;
      final y = yOf(value);

      if (drawing) {
        path.lineTo(x, y);
      } else {
        path.moveTo(x, y);
        drawing = true;
      }
    }

    canvas.drawPath(path, paint);

    // Cham cuoi = gia tri gan nhat.
    for (var i = points.length - 1; i >= 0; i--) {
      final value = series.plotValue(points[i]);
      if (value == null) continue;

      final x =
          (points[i].ts.millisecondsSinceEpoch - start) / span * size.width;
      canvas.drawCircle(
        Offset(x, yOf(value)),
        1.8,
        Paint()
          ..color = series.isOutOfRange(value) ? SignalChartColors.alert : color,
      );
      break;
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) {
    return !identical(old.series, series) || old.color != color;
  }
}

class _StatusStripPainter extends CustomPainter {
  final SignalHistorySeries series;

  _StatusStripPainter(this.series);

  @override
  void paint(Canvas canvas, Size size) {
    final points = series.points;
    if (points.isEmpty) return;

    final start = points.first.ts.millisecondsSinceEpoch;
    final end = points.length > 1
        ? points.last.ts.millisecondsSinceEpoch +
              (points.last.ts.millisecondsSinceEpoch -
                  points[points.length - 2].ts.millisecondsSinceEpoch)
        : start + 1;
    final span = math.max(end - start, 1);

    const stripHeight = 10.0;
    final top = (size.height - stripHeight) / 2;

    for (var i = 0; i < points.length; i++) {
      final value = series.plotValue(points[i]);
      if (value == null) continue; // khong co du lieu: de trong

      final x0 = (points[i].ts.millisecondsSinceEpoch - start) / span;
      final x1 = i + 1 < points.length
          ? (points[i + 1].ts.millisecondsSinceEpoch - start) / span
          : 1.0;

      canvas.drawRect(
        Rect.fromLTWH(
          x0 * size.width,
          top,
          math.max((x1 - x0) * size.width, 1),
          stripHeight,
        ),
        Paint()..color = statusCodeColor(value.round()),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StatusStripPainter old) {
    return !identical(old.series, series);
  }
}
