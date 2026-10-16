import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/charts/signal_thresholds.dart';
import '../models/water_check_models.dart';
import 'water_check_format.dart';
import 'water_visuals.dart';

/// Thang do cua thanh / bon: om nguong (rule chinh + rule phu) va gia tri.
class WaterGaugeScale {
  final double min;
  final double max;

  /// Vung an toan theo rule chinh (mep thieu = mep thang do).
  final double safeFrom;
  final double safeTo;

  const WaterGaugeScale._(this.min, this.max, this.safeFrom, this.safeTo);

  /// Null khi group khong co nguong khong trivial.
  static WaterGaugeScale? of(
    WaterGroup group,
    double? value, {
    bool zeroBased = false,
  }) {
    final rule = group.primaryThreshold;
    if (rule == null) return null;

    final points = <double>[
      for (final line in group.visibleThresholds) ...[
        if (line.low != null) line.low!,
        if (line.high != null) line.high!,
      ],
      if (value != null) value,
    ];

    var lo = points.reduce(math.min);
    var hi = points.reduce(math.max);

    // Chi co nguong tren va du lieu khong am: bat dau tu 0.
    if (zeroBased || (rule.low == null && lo >= 0)) lo = math.min(lo, 0);

    var span = hi - lo;
    if (span <= 0) span = math.max(hi.abs(), 1);

    final pad = span * .15;
    final min = (zeroBased || (rule.low == null && lo >= 0)) ? lo : lo - pad;
    final max = hi + pad;

    return WaterGaugeScale._(min, max, rule.low ?? min, rule.high ?? max);
  }

  double fraction(double v) {
    final span = max - min;
    if (span <= 0) return 0;
    return ((v - min) / span).clamp(0.0, 1.0);
  }
}

// ============================================================
// THRESHOLD BAR
// ============================================================

/// Thanh ngang: vung an toan xanh nhat, vach nguong phu theo level, vach
/// gia tri hien tai theo mau trang thai.
class WaterThresholdBar extends StatelessWidget {
  final WaterGroup group;
  final WaterSignal signal;
  final double width;

  const WaterThresholdBar({
    super.key,
    required this.group,
    required this.signal,
    this.width = 96,
  });

  @override
  Widget build(BuildContext context) {
    final scale = WaterGaugeScale.of(group, signal.value);
    if (scale == null) return SizedBox(width: width);

    final palette = WaterPalette.of(context);

    return SizedBox(
      width: width,
      height: 12,
      child: CustomPaint(
        painter: _BarPainter(
          scale: scale,
          rules: group.visibleThresholds,
          value: waterDisplayValue(signal),
          color: waterReadingColor(signal.status, palette),
          trackColor: palette.glass,
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final WaterGaugeScale scale;
  final List<WaterThreshold> rules;
  final double? value;
  final Color color;
  final Color trackColor;

  _BarPainter({
    required this.scale,
    required this.rules,
    required this.value,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    const trackH = 5.0;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, midY - trackH / 2, size.width, trackH),
      const Radius.circular(3),
    );

    canvas.drawRRect(track, Paint()..color = trackColor);

    final from = scale.fraction(scale.safeFrom) * size.width;
    final to = scale.fraction(scale.safeTo) * size.width;
    canvas.save();
    canvas.clipRRect(track);
    canvas.drawRect(
      Rect.fromLTRB(from, midY - trackH / 2, to, midY + trackH / 2),
      Paint()..color = kWaterOkColor.withValues(alpha: .28),
    );
    canvas.restore();

    for (final rule in rules) {
      final ruleColor = thresholdLevelColor(rule.level).withValues(alpha: .8);
      for (final edge in [rule.low, rule.high]) {
        if (edge == null) continue;
        final x = scale.fraction(edge) * size.width;
        canvas.drawLine(
          Offset(x, midY - 4),
          Offset(x, midY + 4),
          Paint()
            ..color = ruleColor
            ..strokeWidth = 1,
        );
      }
    }

    final current = value;
    if (current == null) return;

    final x = scale.fraction(current) * size.width;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) {
    return old.value != value ||
        old.color != color ||
        old.trackColor != trackColor ||
        old.scale.min != scale.min ||
        old.scale.max != scale.max ||
        old.rules != rules;
  }
}
