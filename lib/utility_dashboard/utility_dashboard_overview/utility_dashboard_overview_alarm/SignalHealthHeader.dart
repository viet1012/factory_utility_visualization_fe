import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'SignalHealthMatrixController.dart';

const kBg = Color(0xff07111f);
const kCard = Color(0xff101827);
const kText = Color(0xfff8fafc);
const kSubText = Color(0xff94a3b8);
const kBlue = Color(0xff38bdf8);
const kRed = Color(0xffef4444);

class SignalHealthKpiScreen extends StatelessWidget {
  const SignalHealthKpiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SignalHealthMatrixController>();

    if (c.loading && c.data.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: kBlue, strokeWidth: 2.5),
      );
    }

    final rows = c.data;

    final totalFac = rows.map((e) => e['fac']).toSet().length;
    final totalBoxDevice = rows.length;

    final totalRegister = rows.fold<int>(
      0,
      (sum, e) => sum + _toInt(e['totalRegisters']),
    );

    final totalNgRegister = rows.fold<int>(
      0,
      (sum, e) => sum + _toInt(e['ngRegisters']),
    );

    return Container(
      color: kBg,
      padding: const EdgeInsets.all(12),
      child: SignalHealthKpiRow(
        totalFac: totalFac,
        totalBoxDevice: totalBoxDevice,
        totalRegister: totalRegister,
        totalNgRegister: totalNgRegister,
      ),
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}

class SignalHealthKpiRow extends StatelessWidget {
  final int totalFac;
  final int totalBoxDevice;
  final int totalRegister;
  final int totalNgRegister;

  const SignalHealthKpiRow({
    super.key,
    required this.totalFac,
    required this.totalBoxDevice,
    required this.totalRegister,
    required this.totalNgRegister,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiModel(
        title: 'FACILITY',
        value: totalFac,
        subtitle: 'Tổng số FAC',
        icon: Icons.factory_rounded,
        color: const Color(0xff3b82f6),
        pattern: _PatternType.factory,
      ),
      _KpiModel(
        title: 'BOX DEVICE',
        value: totalBoxDevice,
        subtitle: 'Tổng số BoxDevice',
        icon: Icons.memory_rounded,
        color: const Color(0xff8b5cf6),
        pattern: _PatternType.device,
      ),
      _KpiModel(
        title: 'REGISTER',
        value: totalRegister,
        subtitle: 'Tổng số Register',
        icon: Icons.menu_book_rounded,
        color: const Color(0xfff97316),
        pattern: _PatternType.chart,
      ),
      _KpiModel(
        title: 'NG REGISTER',
        value: totalNgRegister,
        subtitle: 'Tổng số Register lỗi',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xffef4444),
        danger: true,
        pattern: _PatternType.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;

        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: SignalHealthKpiCard(model: cards[0])),
                  const SizedBox(width: 14),
                  Expanded(child: SignalHealthKpiCard(model: cards[1])),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: SignalHealthKpiCard(model: cards[2])),
                  const SizedBox(width: 14),
                  Expanded(child: SignalHealthKpiCard(model: cards[3])),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: SignalHealthKpiCard(model: cards[i])),
              if (i != cards.length - 1) const SizedBox(width: 16),
            ],
          ],
        );
      },
    );
  }
}

class SignalHealthKpiCard extends StatelessWidget {
  final _KpiModel model;

  const SignalHealthKpiCard({required this.model});

  @override
  Widget build(BuildContext context) {
    final color = model.color;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 8),
            child: child,
          ),
        );
      },
      child: Container(
        // height: 118,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xff081e50), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(.22),
              blurRadius: 22,
              spreadRadius: -10,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xff151d2d),
                      const Color(0xff111827),
                      const Color(0xff0f172a),
                    ],
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: CustomPaint(
                painter: _KpiPatternPainter(
                  color: color.withOpacity(.4),
                  type: model.pattern,
                ),
              ),
            ),

            Positioned(
              right: -6,
              bottom: -16,
              child: Icon(model.icon, size: 96, color: color.withOpacity(.055)),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          color.withOpacity(.34),
                          color.withOpacity(.12),
                        ],
                      ),
                      border: Border.all(color: color.withOpacity(.55)),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(.24),
                          blurRadius: 18,
                          spreadRadius: -6,
                        ),
                      ],
                    ),
                    child: Icon(model.icon, color: color, size: 32),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${model.value}',
                            style: const TextStyle(
                              color: kText,
                              fontSize: 34,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        // const SizedBox(height: 5),
                        // Text(
                        //   model.subtitle,
                        //   maxLines: 1,
                        //   overflow: TextOverflow.ellipsis,
                        //   style: const TextStyle(
                        //     color: kSubText,
                        //     fontSize: 13,
                        //     fontWeight: FontWeight.w600,
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiModel {
  final String title;
  final int value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool danger;
  final _PatternType pattern;

  const _KpiModel({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.pattern,
    this.danger = false,
  });
}

enum _PatternType { factory, device, chart, warning }

class _KpiPatternPainter extends CustomPainter {
  final Color color;
  final _PatternType type;

  _KpiPatternPainter({required this.color, required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    switch (type) {
      case _PatternType.factory:
        _drawFactory(canvas, size, paint);
        break;
      case _PatternType.device:
        _drawDevice(canvas, size, paint);
        break;
      case _PatternType.chart:
        _drawChart(canvas, size, paint);
        break;
      case _PatternType.warning:
        _drawWarning(canvas, size, paint);
        break;
    }
  }

  void _drawFactory(Canvas canvas, Size size, Paint paint) {
    final baseY = size.height * .72;
    final startX = size.width * .58;

    final path = Path()
      ..moveTo(startX, baseY)
      ..lineTo(startX, baseY - 28)
      ..lineTo(startX + 20, baseY - 16)
      ..lineTo(startX + 20, baseY - 34)
      ..lineTo(startX + 42, baseY - 20)
      ..lineTo(startX + 42, baseY)
      ..close();

    canvas.drawPath(path, paint);

    for (int i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTWH(startX + 8 + i * 10, baseY - 10, 5, 5),
        paint,
      );
    }

    for (int i = 0; i < 3; i++) {
      final x = startX + 65 + i * 18;
      canvas.drawLine(Offset(x, baseY), Offset(x, baseY - 46), paint);
      canvas.drawCircle(Offset(x, baseY - 50), 5, paint);
    }
  }

  void _drawDevice(Canvas canvas, Size size, Paint paint) {
    final rect = Rect.fromLTWH(size.width * .68, size.height * .28, 58, 48);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      paint,
    );

    for (int i = 0; i < 5; i++) {
      final x = rect.left + 8 + i * 10;
      canvas.drawLine(Offset(x, rect.top - 8), Offset(x, rect.top), paint);
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x, rect.bottom + 8),
        paint,
      );
    }

    canvas.drawRect(
      Rect.fromCenter(center: rect.center, width: 22, height: 18),
      paint,
    );
  }

  void _drawChart(Canvas canvas, Size size, Paint paint) {
    final baseY = size.height * .76;
    final startX = size.width * .62;

    for (int i = 0; i < 5; i++) {
      final h = 18.0 + i * 9;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(startX + i * 18, baseY - h, 11, h),
          const Radius.circular(3),
        ),
        paint,
      );
    }

    final path = Path()
      ..moveTo(startX - 8, baseY - 22)
      ..cubicTo(
        startX + 18,
        baseY - 54,
        startX + 48,
        baseY - 12,
        startX + 86,
        baseY - 68,
      );

    canvas.drawPath(path, paint);
  }

  void _drawWarning(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width * .76, size.height * .55);
    final r = 42.0;

    final path = Path()
      ..moveTo(center.dx, center.dy - r)
      ..lineTo(center.dx - r * .95, center.dy + r * .75)
      ..lineTo(center.dx + r * .95, center.dy + r * .75)
      ..close();

    canvas.drawPath(path, paint);

    final p = Paint()
      ..color = color.withOpacity(.16)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx, center.dy - 14),
      Offset(center.dx, center.dy + 14),
      p,
    );
    canvas.drawCircle(Offset(center.dx, center.dy + 29), 3, p);
  }

  @override
  bool shouldRepaint(covariant _KpiPatternPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.type != type;
  }
}
