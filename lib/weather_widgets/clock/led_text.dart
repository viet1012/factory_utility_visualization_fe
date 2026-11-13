import 'package:flutter/material.dart';

/// Hiển thị số kiểu đèn LED 7 đoạn (vẽ bằng CustomPainter, không cần font).
///
/// Hỗ trợ: `0-9`, `:`, `.`, `-`, `°`, và khoảng trắng.
/// Đoạn tắt vẫn hiện mờ như đồng hồ LED thật; đoạn sáng có quầng phát sáng.
class LedText extends StatelessWidget {
  final String text;
  final double height;
  final Color color;

  /// Dấu `:` sáng hay tắt (để nhấp nháy theo giây).
  final bool colonOn;

  const LedText(
    this.text, {
    super.key,
    required this.height,
    required this.color,
    this.colonOn = true,
  });

  /// Độ nghiêng kiểu đồng hồ LED (tỉ lệ theo chiều cao).
  static const double _skew = 0.08;

  static double _charWidth(String ch, double h) => switch (ch) {
    ':' => h * 0.26,
    '.' => h * 0.22,
    '°' => h * 0.34,
    ' ' => h * 0.3,
    _ => h * 0.56,
  };

  static double _spacing(double h) => h * 0.13;

  static double measure(String text, double h) {
    if (text.isEmpty) return 0;
    var w = 0.0;
    for (final ch in text.split('')) {
      w += _charWidth(ch, h);
    }
    return w + _spacing(h) * (text.length - 1) + h * _skew;
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(measure(text, height), height),
      painter: _LedPainter(text, color, colonOn),
    );
  }
}

// Bit của từng đoạn: a(trên) b(phải-trên) c(phải-dưới) d(dưới)
// e(trái-dưới) f(trái-trên) g(giữa).
const _a = 1, _b = 2, _c = 4, _d = 8, _e = 16, _f = 32, _g = 64;
const _digitMask = <String, int>{
  '0': _a | _b | _c | _d | _e | _f,
  '1': _b | _c,
  '2': _a | _b | _g | _e | _d,
  '3': _a | _b | _g | _c | _d,
  '4': _f | _g | _b | _c,
  '5': _a | _f | _g | _c | _d,
  '6': _a | _f | _g | _e | _c | _d,
  '7': _a | _b | _c,
  '8': _a | _b | _c | _d | _e | _f | _g,
  '9': _a | _b | _c | _d | _f | _g,
  '-': _g,
};

class _LedPainter extends CustomPainter {
  final String text;
  final Color color;
  final bool colonOn;

  _LedPainter(this.text, this.color, this.colonOn);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final t = h * 0.13; // độ dày đoạn
    final gap = t * 0.2; // khe giữa các đoạn

    final on = Path();
    final off = Path();

    var x = 0.0;
    for (final ch in text.split('')) {
      final w = LedText._charWidth(ch, h);
      switch (ch) {
        case ':':
          final r = t * 0.55;
          final dots = Path()
            ..addOval(
              Rect.fromCircle(center: Offset(x + w / 2, h * 0.3), radius: r),
            )
            ..addOval(
              Rect.fromCircle(center: Offset(x + w / 2, h * 0.72), radius: r),
            );
          (colonOn ? on : off).addPath(dots, Offset.zero);
        case '.':
          on.addOval(
            Rect.fromCircle(
              center: Offset(x + w / 2, h - t * 0.6),
              radius: t * 0.6,
            ),
          );
        case '°':
          // ký hiệu độ = 4 đoạn trên (a b f g) của 1 số nhỏ
          _addDigit(
            on,
            off,
            _a | _b | _f | _g,
            x,
            0,
            w,
            h * 0.46,
            t * 0.7,
            gap * 0.7,
            drawOff: false,
          );
        case ' ':
          break;
        default:
          final mask = _digitMask[ch];
          if (mask != null) _addDigit(on, off, mask, x, 0, w, h, t, gap);
      }
      x += w + LedText._spacing(h);
    }

    canvas.save();
    // nghiêng nhẹ sang phải giống đồng hồ LED
    canvas.translate(h * LedText._skew, 0);
    canvas.skew(-LedText._skew, 0);

    // đoạn tắt: mờ
    canvas.drawPath(off, Paint()..color = color.withValues(alpha: .09));

    // quầng sáng + lõi đoạn sáng
    canvas.drawPath(
      on,
      Paint()
        ..color = color.withValues(alpha: .55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, t * 0.9),
    );
    canvas.drawPath(on, Paint()..color = color);
    // lõi sáng hơn ở giữa cho cảm giác LED
    canvas.drawPath(
      on,
      Paint()
        ..color = Color.lerp(color, Colors.white, .45)!.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = t * 0.18,
    );

    canvas.restore();
  }

  /// Thêm các đoạn của 1 chữ số vào path on/off.
  static void _addDigit(
    Path on,
    Path off,
    int mask,
    double x,
    double y,
    double w,
    double h,
    double t,
    double gap, {
    bool drawOff = true,
  }) {
    final half = t / 2;
    final midY = y + h / 2;

    void seg(int bit, Path p) {
      if (mask & bit != 0) {
        on.addPath(p, Offset.zero);
      } else if (drawOff) {
        off.addPath(p, Offset.zero);
      }
    }

    // Đoạn ngang: hình lục giác vát 2 đầu.
    Path horiz(double cy) {
      final x0 = x + half + gap;
      final x1 = x + w - half - gap;
      return Path()
        ..moveTo(x0, cy)
        ..lineTo(x0 + half, cy - half)
        ..lineTo(x1 - half, cy - half)
        ..lineTo(x1, cy)
        ..lineTo(x1 - half, cy + half)
        ..lineTo(x0 + half, cy + half)
        ..close();
    }

    // Đoạn dọc.
    Path vert(double cx, double y0, double y1) {
      final a = y0 + gap;
      final b = y1 - gap;
      return Path()
        ..moveTo(cx, a)
        ..lineTo(cx + half, a + half)
        ..lineTo(cx + half, b - half)
        ..lineTo(cx, b)
        ..lineTo(cx - half, b - half)
        ..lineTo(cx - half, a + half)
        ..close();
    }

    final left = x + half;
    final right = x + w - half;
    final top = y + half;
    final bottom = y + h - half;

    seg(_a, horiz(top));
    seg(_g, horiz(midY));
    seg(_d, horiz(bottom));
    seg(_f, vert(left, top, midY));
    seg(_b, vert(right, top, midY));
    seg(_e, vert(left, midY, bottom));
    seg(_c, vert(right, midY, bottom));
  }

  @override
  bool shouldRepaint(covariant _LedPainter old) =>
      old.text != text || old.color != color || old.colonOn != colonOn;
}
