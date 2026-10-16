import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/charts/value_format.dart';

/// Mau / format / khung card dung chung cho MONITORING › Electricity.
abstract final class ElectricityColors {
  static const Color cardBg = Color(0xFF0A1A2C);
  static const Color cardBorder = Color(0xFF1C3550);
  static const Color text = Color(0xFFE6EEF7);
  static const Color textDim = Color(0xFF8DA2B8);
  static const Color textFaint = Color(0xFF5B7088);
  static const Color track = Color(0xFF15283D);
  static const Color prevBar = Color(0xFF4A5E75);

  static const Color up = Color(0xFFFF9F43);
  static const Color down = Color(0xFF2ECC71);

  static const Color facA = Color(0xFF3B82F6);
  static const Color facB = Color(0xFF22D3EE);
  static const Color facC = Color(0xFFEC4899);
  static const Color compressedAir = Color(0xFFA78BFA);
  static const Color other = Color(0xFF94A3B8);

  static const Color highPeak = Color(0xFF1E3A8A);
  static const Color normal = Color(0xFF3B82F6);
  static const Color lowPeak = Color(0xFF93C5FD);
  static const Color solar = Color(0xFF22C55E);

  /// Cung mot mau cho moi fac tren moi card.
  static Color factory(String facId) {
    switch (facId.toUpperCase().replaceAll(' ', '_')) {
      case 'FAC_A':
      case 'A':
        return facA;
      case 'FAC_B':
      case 'B':
        return facB;
      case 'FAC_C':
      case 'C':
        return facC;
      default:
        return other;
    }
  }
}

// ============================================================
// FORMAT
// ============================================================

/// kWh: so nguyen, co dau phan cach.
String fmtKwh(num? kwh) => formatValue(kwh, decimals: 0);

/// MWh: 1 so le.
String fmtMwh(num? kwh) => formatValue(kwh == null ? null : kwh / 1000, decimals: 1);

/// USD: 2 so le.
String fmtUsd(num? usd) {
  final text = formatValue(usd, decimals: 2);
  if (text == kMissingValue) return text;
  return text.startsWith('-') ? '-\$${text.substring(1)}' : '\$$text';
}

/// Don gia USD/kWh (thuong < 0.2): giu 4 so le de khong thanh 0.08.
String fmtRate(num? rate) {
  final text = formatValue(rate, decimals: 4);
  return text == kMissingValue ? text : '\$$text';
}

/// %: 1 so le.
String fmtPct(num? pct) {
  final text = formatValue(pct, decimals: 1);
  return text == kMissingValue ? text : '$text%';
}

String fmtSignedPct(num? pct) {
  if (pct == null || !pct.isFinite) return kMissingValue;
  final text = fmtPct(pct.abs());
  if (pct > 0) return '+$text';
  if (pct < 0) return '-$text';
  return text;
}

// ============================================================
// TIME (chuoi ISO kem offset nha may: doc truc tiep, khong doi mui gio)
// ============================================================

class PlantTime {
  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;

  const PlantTime(this.year, this.month, this.day, this.hour, this.minute);

  static final RegExp _pattern = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}))?',
  );

  static PlantTime? tryParse(String? text) {
    final match = _pattern.firstMatch(text?.trim() ?? '');
    if (match == null) return null;
    int g(int i) => int.tryParse(match.group(i) ?? '') ?? 0;
    return PlantTime(g(1), g(2), g(3), g(4), g(5));
  }

  bool get isMidnight => hour == 0 && minute == 0;

  DateTime get date => DateTime(year, month, day);

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  static String formatHour(int hour) => '${hour.toString().padLeft(2, '0')}:00';
}

/// `Oct 12–Oct 18`; `to` la moc ket thuc (00:00 duoc coi la ngay truoc).
String formatPlantRange(String from, String to) {
  final start = PlantTime.tryParse(from);
  final end = PlantTime.tryParse(to);
  if (start == null) return kMissingValue;
  if (end == null) return PlantTime.formatDate(start.date);

  var endDate = end.date;
  if (end.isMidnight && endDate.isAfter(start.date)) {
    endDate = endDate.subtract(const Duration(days: 1));
  }

  final startText = PlantTime.formatDate(start.date);
  final endText = PlantTime.formatDate(endDate);
  return startText == endText ? startText : '$startText–$endText';
}

// ============================================================
// WIDGETS
// ============================================================

class ElectricityCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ElectricityCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: ElectricityColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ElectricityColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: ElectricityColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .3,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// ▲ / ▼ + %: tang mau cam, giam mau xanh, null -> `—`.
class ChangeBadge extends StatelessWidget {
  final double? changePct;
  final String? suffix;
  final double fontSize;

  const ChangeBadge({
    super.key,
    required this.changePct,
    this.suffix,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final pct = changePct;
    if (pct == null || !pct.isFinite) {
      return Text(
        kMissingValue,
        style: TextStyle(color: ElectricityColors.textDim, fontSize: fontSize),
      );
    }

    final color = pct > 0
        ? ElectricityColors.up
        : pct < 0
        ? ElectricityColors.down
        : ElectricityColors.textDim;
    final arrow = pct > 0 ? '▲' : (pct < 0 ? '▼' : '•');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$arrow ${fmtPct(pct.abs())}${suffix == null ? '' : ' $suffix'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Mot thanh ngang, [value] / [max].
class HBar extends StatelessWidget {
  final double? value;
  final double max;
  final Color color;
  final double height;

  const HBar({
    super.key,
    required this.value,
    required this.max,
    required this.color,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    final v = value;
    final fraction = (v == null || max <= 0) ? 0.0 : (v / max).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: ElectricityColors.track),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.toDouble(),
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hai thanh: hien tai (mau) / ky truoc (xam).
class CompareBars extends StatelessWidget {
  final double? current;
  final double? previous;
  final double max;
  final Color color;

  const CompareBars({
    super.key,
    required this.current,
    required this.previous,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HBar(value: current, max: max, color: color),
        const SizedBox(height: 3),
        HBar(value: previous, max: max, color: ElectricityColors.prevBar),
      ],
    );
  }
}

/// Phan con lai cua thang: soc cheo.
class StripePainter extends CustomPainter {
  final Color color;

  const StripePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const gap = 6.0;
    for (var x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(StripePainter oldDelegate) => oldDelegate.color != color;
}

class Sparkline extends StatelessWidget {
  final List<double?> values;
  final Color color;

  const Sparkline({super.key, required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 22),
      painter: _SparklinePainter(values, color),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double?> values;
  final Color color;

  _SparklinePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final points = values.whereType<double>().toList();
    if (points.length < 2) return;

    final minV = points.reduce(math.min);
    final maxV = points.reduce(math.max);
    final span = maxV - minV == 0 ? 1.0 : maxV - minV;
    final stepX = size.width / (values.length - 1);

    final path = Path();
    var started = false;
    Offset? last;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      final p = Offset(
        i * stepX,
        size.height - 2 - (v - minV) / span * (size.height - 4),
      );
      if (started) {
        path.lineTo(p.dx, p.dy);
      } else {
        path.moveTo(p.dx, p.dy);
        started = true;
      }
      last = p;
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
    if (last != null) canvas.drawCircle(last, 2.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.values != values;
}

class SkeletonBox extends StatelessWidget {
  final double? height;
  final double? width;

  const SkeletonBox({super.key, this.height, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: ElectricityColors.track,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
