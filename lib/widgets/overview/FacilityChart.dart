// import 'dart:async';
// import 'package:flutter/material.dart';
// import '../../model/facility_filtered.dart';
// import '../line_chart_painter.dart';
//
// class FacilityChart extends StatefulWidget {
//   final FacilityFiltered facility;
//   final String title;
//   final Color color;
//   final int maxPoints;
//
//   const FacilityChart({
//     super.key,
//     required this.facility,
//     this.title = 'Electric Power Output',
//     this.color = Colors.orange,
//     this.maxPoints = 30,
//   });
//
//   @override
//   State<FacilityChart> createState() => _FacilityChartState();
// }
//
// class _FacilityChartState extends State<FacilityChart> {
//   late List<double> data;
//   Timer? timer;
//
//   @override
//   void initState() {
//     super.initState();
//     // Khởi tạo mảng dữ liệu
//     data = List.generate(widget.maxPoints, (index) => 0);
//     // Cập nhật dữ liệu mỗi giây (hoặc mỗi phút, tùy)
//     timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateData());
//   }
//
//   void _updateData() {
//     // Lấy signal liên quan đến title (ví dụ 'power', 'temperature', 'flow')
//     final signal = widget.facility.signals.firstWhere(
//       (s) => s.description.toLowerCase().contains(widget.title.toLowerCase()),
//       orElse: () => widget.facility.signals.first,
//     );
//
//     final newValue = signal.value; // đã là double
//
//     // 🔹 In thông tin ra console
//     print('Chart title: ${widget.title}');
//     print('Matched signal: ${signal.description}');
//     print('Value: ${signal.value}');
//     print('Unit: ${signal.unit}');
//
//     setState(() {
//       data.add(newValue);
//       if (data.length > widget.maxPoints) data.removeAt(0);
//     });
//   }
//
//   @override
//   void dispose() {
//     timer?.cancel();
//     super.dispose();
//   }
//
//   // 🔹 Sử dụng lại _buildChart
//   Widget _buildChart(String title, List<double> data, Color color) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: const Color(0xFF2A2A2A),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: color.withOpacity(0.3)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 12,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Expanded(
//             child: CustomPaint(
//               painter: LineChartPainter(data, color),
//               size: Size.infinite,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return _buildChart(widget.title, data, widget.color);
//   }
// }
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../model/facility_filtered.dart';

class AnimatedLineChartPainter extends CustomPainter {
  final List<double> from; // data trước
  final List<double> to; // data sau
  final double t; // 0..1
  final Color color;

  final double oldSignal; // ✅ old thật
  final double newSignal; // ✅ new thật

  AnimatedLineChartPainter({
    required this.from,
    required this.to,
    required this.t,
    required this.color,
    required this.oldSignal,
    required this.newSignal,
    Listenable? repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (to.isEmpty) return;

    final n = math.min(from.length, to.length);
    if (n < 2) return;

    // nội suy data (lerp) để mượt (NEW animated)
    final values = List<double>.generate(n, (i) {
      final a = from[i];
      final b = to[i];
      return a + (b - a) * t;
    });

    // min/max: tính theo data thật (to) để scale ổn định, không giật theo animation
    double minV = to.take(n).reduce(math.min);
    double maxV = to.take(n).reduce(math.max);

    final range = (maxV - minV).abs();
    final minRange = 5.0; // chỉnh theo loại signal
    final safeRange = math.max(range, minRange);

    // mở rộng biên để đỡ dính sát
    final mid = (maxV + minV) / 2.0;
    minV = mid - safeRange / 2.0;
    maxV = mid + safeRange / 2.0;
    final pad = safeRange * 0.15; // 15% padding
    minV -= pad;
    maxV += pad;

    const padL = 6.0, padR = 6.0, padT = 8.0, padB = 8.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;

    Offset ptFromValue(double v, int i) {
      // ✅ xShift: lúc t=0 => đứng ở slot i+1, lúc t=1 => về slot i
      final raw = i + (1.0 - t);
      final xIndex = raw.clamp(0.0, (n - 1).toDouble());

      final x = padL + (xIndex / (n - 1)) * w;

      final yNorm = (v - minV) / (maxV - minV);
      final y = padT + (1 - yNorm) * h;
      return Offset(x, y);
    }

    Offset pt(int i) => ptFromValue(values[i], i);

    // ===== line path =====
    final linePath = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (int i = 1; i < n; i++) {
      linePath.lineTo(pt(i).dx, pt(i).dy);
    }

    // ===== fill =====
    final fillPath = Path.from(linePath)
      ..lineTo(pt(n - 1).dx, padT + h)
      ..lineTo(pt(0).dx, padT + h)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color.withOpacity(0.22),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = color,
    );

    // ===== labels: PREV + NOW =====
    final last = n - 1;
    final prev = (n - 2).clamp(0, n - 1);

    // NOW animate từ prev -> now cho mượt
    final animatedNow = oldSignal + (newSignal - oldSignal) * t;

    // ✅ Prev ở slot prev, Now ở slot last
    final prevPt = ptFromValue(oldSignal, prev);
    final nowPt = ptFromValue(animatedNow, last);

    void drawLabel({
      required Offset anchor,
      required String text,
      required Color bg,
      required bool placeAbove,
    }) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final boxW = tp.width + 10;
      final boxH = tp.height + 6;

      double dx = anchor.dx - boxW / 2;
      double dy = placeAbove ? (anchor.dy - boxH - 8) : (anchor.dy + 8);

      // clamp tránh bị cắt
      dx = dx.clamp(0.0, size.width - boxW);
      dy = dy.clamp(0.0, size.height - boxH);

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(dx, dy, boxW, boxH),
        const Radius.circular(4),
      );

      canvas.drawRRect(rect, Paint()..color = bg);
      tp.paint(canvas, Offset(dx + 5, dy + 3));
    }

    // nếu 2 label gần nhau thì cho Prev xuống dưới, Now lên trên
    final tooClose = (nowPt.dy - prevPt.dy).abs() < 18;

    drawLabel(
      anchor: prevPt,
      text: 'Prev: ${oldSignal.toStringAsFixed(1)}',
      bg: color.withOpacity(0.45),
      placeAbove: !tooClose, // nếu gần nhau thì Prev đặt dưới
    );

    drawLabel(
      anchor: nowPt,
      text: 'Now: ${newSignal.toStringAsFixed(1)}',
      bg: color.withOpacity(0.85),
      placeAbove: true,
    );
  }

  @override
  bool shouldRepaint(covariant AnimatedLineChartPainter old) {
    return old.t != t || old.color != color || old.to != to || old.from != from;
  }
}

class FacilityChart extends StatefulWidget {
  final FacilityFiltered facility;
  final String title;
  final Color color;
  final int maxPoints;

  const FacilityChart({
    super.key,
    required this.facility,
    this.title = 'Temperature',
    this.color = Colors.red,
    this.maxPoints = 30,
  });

  @override
  State<FacilityChart> createState() => _FacilityChartState();
}

class _FacilityChartState extends State<FacilityChart>
    with SingleTickerProviderStateMixin {
  late List<double> _data;
  late List<double> _prevData;

  late final AnimationController _animCtrl;

  double _oldSignal = 0;
  double _newSignal = 0;

  @override
  void initState() {
    super.initState();

    _data = List.generate(widget.maxPoints, (_) => 0);
    _prevData = List.from(_data);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..value = 1;

    // ✅ lấy điểm đầu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateData();
    });
  }

  @override
  void didUpdateWidget(covariant FacilityChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ✅ chỉ update khi dữ liệu provider thực sự đổi (hoặc title đổi)
    final facChanged = oldWidget.facility != widget.facility;
    final titleChanged = oldWidget.title != widget.title;

    if (facChanged || titleChanged) {
      _updateData();
    }
  }

  void _updateData() {
    if (widget.facility.signals.isEmpty) return;

    final titleLower = widget.title.toLowerCase();
    final signal = widget.facility.signals.firstWhere(
      (s) => s.description.toLowerCase().contains(titleLower),
      orElse: () => widget.facility.signals.first,
    );

    final nowValue = signal.value;

    // ✅ prev lấy từ point cuối hiện có (trước khi add)
    final prevValue = _data.isNotEmpty ? _data.last : nowValue;

    // nếu value không đổi thì khỏi animate
    if (_data.isNotEmpty && (nowValue - prevValue).abs() < 1e-9) return;

    _prevData = List.from(_data);

    final next = List<double>.from(_data)..add(nowValue);
    if (next.length > widget.maxPoints) next.removeAt(0);
    _data = next;

    _oldSignal = prevValue;
    _newSignal = nowValue;

    debugPrint(
      'Prev=${_oldSignal.toStringAsFixed(2)} Now=${_newSignal.toStringAsFixed(2)}',
    );

    _animCtrl
      ..stop()
      ..value = 0
      ..forward();

    setState(() {});
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (_, __) {
                return CustomPaint(
                  painter: AnimatedLineChartPainter(
                    from: _prevData,
                    to: _data,
                    t: _animCtrl.value,
                    color: widget.color,
                    oldSignal: _oldSignal,
                    newSignal: _newSignal,
                    repaint: _animCtrl,
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
