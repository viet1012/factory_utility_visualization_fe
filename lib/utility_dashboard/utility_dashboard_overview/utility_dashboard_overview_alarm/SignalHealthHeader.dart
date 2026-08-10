import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'SignalHealthMatrixController.dart';

const Color kSignalBg = Color(0xff07111f);
const Color kSignalText = Color(0xfff8fafc);
const Color kSignalBlue = Color(0xff38bdf8);

class SignalHealthKpiScreen extends StatelessWidget {
  /// Chiều cao cố định của toàn bộ khu vực KPI.
  final double height;

  const SignalHealthKpiScreen({super.key, this.height = 116});

  @override
  Widget build(BuildContext context) {
    /*
     * Selector chỉ trả về 5 giá trị nhỏ.
     *
     * Widget chỉ rebuild khi:
     * - loading thay đổi
     * - một trong 4 tổng KPI thay đổi
     *
     * Không rebuild chỉ vì List data đổi instance.
     */
    return Selector<SignalHealthMatrixController, _SignalHealthState>(
      selector: (_, controller) {
        final rows = controller.data;

        var totalRegister = 0;
        var totalNgRegister = 0;

        final facilities = <String>{};

        for (final item in rows) {
          final fac = item['fac']?.toString().trim();

          if (fac != null && fac.isNotEmpty) {
            facilities.add(fac);
          }

          totalRegister += _toInt(item['totalRegisters']);
          totalNgRegister += _toInt(item['ngRegisters']);
        }

        return _SignalHealthState(
          loading: controller.loading,
          totalFac: facilities.length,
          totalBoxDevice: rows.length,
          totalRegister: totalRegister,
          totalNgRegister: totalNgRegister,
        );
      },
      builder: (context, state, _) {
        if (state.loading && state.totalBoxDevice == 0) {
          return SizedBox(
            height: height,
            width: double.infinity,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: kSignalBlue,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        final items = <_SignalKpiItem>[
          _SignalKpiItem(
            title: 'FACILITY',
            value: state.totalFac,
            icon: Icons.factory_rounded,
            color: const Color(0xff3b82f6),
            pattern: _PatternType.factory,
          ),
          _SignalKpiItem(
            title: 'BOX DEVICE',
            value: state.totalBoxDevice,
            icon: Icons.memory_rounded,
            color: const Color(0xff8b5cf6),
            pattern: _PatternType.device,
          ),
          _SignalKpiItem(
            title: 'REGISTER',
            value: state.totalRegister,
            icon: Icons.menu_book_rounded,
            color: const Color(0xfff97316),
            pattern: _PatternType.chart,
          ),
          _SignalKpiItem(
            title: 'NG REGISTER',
            value: state.totalNgRegister,
            icon: Icons.warning_amber_rounded,
            color: const Color(0xffef4444),
            pattern: _PatternType.warning,
          ),
        ];

        return SizedBox(
          height: height,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: kSignalBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _SignalHealthCompactCard(item: items[0]),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _SignalHealthCompactCard(item: items[1]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _SignalHealthCompactCard(item: items[2]),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _SignalHealthCompactCard(item: items[3]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }
}

class _SignalHealthCompactCard extends StatelessWidget {
  final _SignalKpiItem item;

  const _SignalHealthCompactCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.color;

    return RepaintBoundary(
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withOpacity(0.30), width: 0.8),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff151d2d), Color(0xff101827), Color(0xff0f172a)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            /*
             * Painter được cache trong một RepaintBoundary riêng.
             * willChange=false vì hình nền không animate.
             */
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _KpiPatternPainter(
                    color: color.withOpacity(0.30),
                    type: item.pattern,
                  ),
                  isComplex: true,
                  willChange: false,
                ),
              ),
            ),

            Positioned(
              right: -4,
              bottom: -7,
              child: Icon(item.icon, size: 39, color: color.withOpacity(0.045)),
            ),

            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.13),
                    border: Border.all(
                      color: color.withOpacity(0.48),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(item.icon, size: 22, color: color),
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.1,
                        ),
                      ),

                      const SizedBox(height: 3),

                      FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${item.value}',
                          maxLines: 1,
                          style: const TextStyle(
                            color: kSignalText,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalHealthState {
  final bool loading;
  final int totalFac;
  final int totalBoxDevice;
  final int totalRegister;
  final int totalNgRegister;

  const _SignalHealthState({
    required this.loading,
    required this.totalFac,
    required this.totalBoxDevice,
    required this.totalRegister,
    required this.totalNgRegister,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _SignalHealthState &&
            runtimeType == other.runtimeType &&
            loading == other.loading &&
            totalFac == other.totalFac &&
            totalBoxDevice == other.totalBoxDevice &&
            totalRegister == other.totalRegister &&
            totalNgRegister == other.totalNgRegister;
  }

  @override
  int get hashCode {
    return Object.hash(
      loading,
      totalFac,
      totalBoxDevice,
      totalRegister,
      totalNgRegister,
    );
  }
}

class _SignalKpiItem {
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final _PatternType pattern;

  const _SignalKpiItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.pattern,
  });
}

enum _PatternType { factory, device, chart, warning }

class _KpiPatternPainter extends CustomPainter {
  final Color color;
  final _PatternType type;

  const _KpiPatternPainter({required this.color, required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

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
    final width = size.width;
    final height = size.height;

    final baseY = height * 0.80;
    final startX = width * 0.58;

    final path = Path()
      ..moveTo(startX, baseY)
      ..lineTo(startX, height * 0.44)
      ..lineTo(width * 0.68, height * 0.58)
      ..lineTo(width * 0.68, height * 0.40)
      ..lineTo(width * 0.79, height * 0.56)
      ..lineTo(width * 0.79, baseY)
      ..close();

    canvas.drawPath(path, paint);

    for (var index = 0; index < 3; index++) {
      final left = width * 0.62 + index * width * 0.055;

      canvas.drawRect(
        Rect.fromLTWH(left, height * 0.68, width * 0.025, height * 0.08),
        paint,
      );
    }

    for (var index = 0; index < 2; index++) {
      final x = width * 0.84 + index * width * 0.07;

      canvas.drawLine(Offset(x, baseY), Offset(x, height * 0.30), paint);

      canvas.drawCircle(Offset(x, height * 0.25), height * 0.06, paint);
    }
  }

  void _drawDevice(Canvas canvas, Size size, Paint paint) {
    final rect = Rect.fromLTWH(
      size.width * 0.68,
      size.height * 0.25,
      size.width * 0.24,
      size.height * 0.52,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.height * 0.08)),
      paint,
    );

    for (var index = 0; index < 4; index++) {
      final x = rect.left + rect.width * (0.18 + index * 0.20);

      canvas.drawLine(
        Offset(x, rect.top - size.height * 0.08),
        Offset(x, rect.top),
        paint,
      );

      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x, rect.bottom + size.height * 0.08),
        paint,
      );
    }

    canvas.drawRect(
      Rect.fromCenter(
        center: rect.center,
        width: rect.width * 0.42,
        height: rect.height * 0.35,
      ),
      paint,
    );
  }

  void _drawChart(Canvas canvas, Size size, Paint paint) {
    final baseY = size.height * 0.82;
    final startX = size.width * 0.60;

    for (var index = 0; index < 5; index++) {
      final barWidth = size.width * 0.035;
      final barHeight = size.height * (0.18 + index * 0.10);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            startX + index * size.width * 0.065,
            baseY - barHeight,
            barWidth,
            barHeight,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }

    final path = Path()
      ..moveTo(size.width * 0.57, size.height * 0.64)
      ..cubicTo(
        size.width * 0.67,
        size.height * 0.28,
        size.width * 0.78,
        size.height * 0.72,
        size.width * 0.94,
        size.height * 0.18,
      );

    canvas.drawPath(path, paint);
  }

  void _drawWarning(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width * 0.79, size.height * 0.54);

    final radius = size.height * 0.34;

    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx - radius * 0.85, center.dy + radius * 0.72)
      ..lineTo(center.dx + radius * 0.85, center.dy + radius * 0.72)
      ..close();

    canvas.drawPath(path, paint);

    final warningPaint = Paint()
      ..color = color.withOpacity(0.55)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.35),
      Offset(center.dx, center.dy + radius * 0.22),
      warningPaint,
    );

    canvas.drawCircle(
      Offset(center.dx, center.dy + radius * 0.45),
      1.4,
      warningPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _KpiPatternPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.type != type;
  }
}
