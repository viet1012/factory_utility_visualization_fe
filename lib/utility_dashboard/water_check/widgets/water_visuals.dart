import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../../shared/charts/value_format.dart';
import '../models/water_check_models.dart';
import 'water_check_format.dart';
import 'water_layout.dart';

// ============================================================
// KIND
// ============================================================

/// Hinh hien thi cua mot group theo unit / code. Kich thuoc theo
/// [WaterVisualSize.figureSize].
enum WaterVisualKind {
  /// °C (W_Cool...): nhiet ke dung.
  thermometer(Icons.thermostat_rounded),

  /// kg/cm² / bar: dong ho kim 240°.
  dial(Icons.speed_rounded),

  /// m (W_LevCool): bon chua.
  tank(Icons.propane_tank_outlined),

  /// Unit khac: dong gon (thanh nguong).
  compact(Icons.sensors_rounded);

  final IconData icon;

  const WaterVisualKind(this.icon);

  static WaterVisualKind of(WaterGroup group) {
    final unit = group.unit.trim().toLowerCase();
    final code = group.code.trim().toLowerCase();

    if (group.isLevel) return tank;
    if (unit.contains('°c') ||
        unit == 'c' ||
        unit == 'degc' ||
        code.startsWith('w_cool')) {
      return thermometer;
    }
    if (unit.startsWith('kg/cm') || unit == 'bar' || code.contains('pres')) {
      return dial;
    }
    return compact;
  }
}

// ============================================================
// PALETTE
// ============================================================

/// Mau cua hinh theo theme sang / toi. Mau trang thai (xanh / cam / do)
/// dung chung voi phan con lai cua Water check.
class WaterPalette {
  final Brightness brightness;

  /// Chu chinh / chu mo.
  final Color text;
  final Color muted;

  /// Vien kim loai (bezel, than bon, ong nhiet ke).
  final Color bezel;
  final Color bezelShade;

  /// Mat dong ho: tam -> mep.
  final Color faceCenter;
  final Color faceEdge;

  /// Long ong / bon rong.
  final Color glass;

  const WaterPalette._({
    required this.brightness,
    required this.text,
    required this.muted,
    required this.bezel,
    required this.bezelShade,
    required this.faceCenter,
    required this.faceEdge,
    required this.glass,
  });

  factory WaterPalette.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;

    return WaterPalette._(
      brightness: scheme.brightness,
      text: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
      bezel: dark ? const Color(0xFF9AA4B2) : const Color(0xFF8C96A3),
      bezelShade: dark ? const Color(0xFF4B5563) : const Color(0xFFCBD2DB),
      faceCenter: dark ? const Color(0xFF16263D) : const Color(0xFFFFFFFF),
      faceEdge: dark ? const Color(0xFF0A1424) : const Color(0xFFE6EBF1),
      glass: scheme.onSurface.withValues(alpha: dark ? .06 : .05),
    );
  }

  bool get isDark => brightness == Brightness.dark;
}

/// Mau chat long / nuoc: xanh duong binh thuong, cam near, do over.
Color waterFluidColor(WaterStatus status) {
  return switch (status) {
    WaterStatus.stale || WaterStatus.stopped => kWaterStaleColor,
    _ => kWaterFluidColor,
  };
}

const Color kWaterFluidColor = Color(0xFF3B9EFF);

/// Mau so / kim: chu chinh khi OK, cam NEAR, do OVER / SENSOR_FAULT /
/// abnormal, xam STALE / STOPPED.
Color waterReadingColor(
  WaterStatus status,
  WaterPalette palette, {
  bool abnormal = false,
}) {
  if (status == WaterStatus.stopped) return palette.muted;
  if (abnormal ||
      status == WaterStatus.over ||
      status == WaterStatus.sensorFault) {
    return kWaterOverColor;
  }
  return switch (status) {
    WaterStatus.stale => palette.muted,
    _ => palette.text,
  };
}

Color _shade(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

/// Lam tron len so "dep": 1, 2, 2.5, 5 × 10^n.
double niceCeil(double value) {
  if (value <= 0 || !value.isFinite) return 1;

  final exponent = math.pow(10, (math.log(value) / math.ln10).floor());
  final fraction = value / exponent;

  final nice = fraction <= 1
      ? 1
      : fraction <= 2
      ? 2
      : fraction <= 2.5
      ? 2.5
      : fraction <= 5
      ? 5
      : 10;

  return nice * exponent.toDouble();
}

// ============================================================
// SCALES
// ============================================================

/// Thang nhiet ke: 0–50 °C, co nguong high thi high × 1.3 (lam tron len 10
/// de vach chinh moi 10 roi dung dau thang).
double thermometerMax(WaterGroup group) {
  final high = group.primaryThreshold?.high;
  if (high == null || high <= 0) return 50;
  return math.max(10, (high * 1.3 / 10).ceil() * 10.0);
}

/// Thang dong ho: VCH 0–4; nhom khac 0 → lam tron len
/// (max(gia tri lon nhat cua nhom, nguong) × 1.2).
double dialMax(WaterGroup group, WaterSignal signal) {
  if (_isVch(signal) || _isVchText(group.name)) return 4;

  var top = 0.0;
  for (final item in group.signals) {
    final value = item.value ?? item.lastValue;
    if (value != null) top = math.max(top, value);
  }

  final rule = group.primaryThreshold;
  if (rule?.high != null) top = math.max(top, rule!.high!);
  if (rule?.low != null) top = math.max(top, rule!.low!);

  return niceCeil(top * 1.2);
}

bool _isVch(WaterSignal signal) =>
    _isVchText(signal.deviceName) ||
    _isVchText(signal.boxDeviceId) ||
    _isVchText(signal.name);

bool _isVchText(String text) => text.toUpperCase().contains('VCH');

/// Thang bon chua: 0 → high × 1.2.
double tankMax(WaterGroup group, WaterSignal signal) {
  final rule = group.primaryThreshold;
  final high = rule?.high;
  if (high != null && high > 0) return high * 1.2;

  final low = rule?.low;
  final value = signal.value ?? signal.lastValue ?? 0;
  return niceCeil(math.max(math.max(low ?? 0, value), 1) * 1.2);
}

// ============================================================
// THERMOMETER
// ============================================================

/// Nhiet ke dung: tu trai sang phai nhan thang | vach (chinh moi 10, phu
/// moi 5) | dai mau nguong | ong bo tron + bau tron 2 lop | pill nguong.
/// Chat long theo trang thai (co vet sang); vach do net dut tai nguong keo
/// qua thang va ong; tam giac ◀ mau trang thai chi gia tri tren thang.
class WaterThermometer extends StatelessWidget {
  final WaterGroup group;
  final WaterSignal signal;
  final int decimals;
  final bool animate;
  final WaterVisualSize tier;

  const WaterThermometer({
    super.key,
    required this.group,
    required this.signal,
    required this.decimals,
    required this.animate,
    required this.tier,
  });

  @override
  Widget build(BuildContext context) {
    final palette = WaterPalette.of(context);
    final size = tier.figureSize(WaterVisualKind.thermometer);

    final max = thermometerMax(group);
    final rule = group.primaryThreshold;
    final value = signal.status == WaterStatus.stale ? null : signal.value;
    final fluid = value == null
        ? palette.muted
        : waterFluidColor(signal.status);

    return SizedBox(
      width: size.width,
      height: size.height,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: 0,
          end: (value ?? 0).clamp(0, max).toDouble(),
        ),
        duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, level, _) => CustomPaint(
          painter: _ThermometerPainter(
            level: value == null ? null : level,
            max: max,
            low: rule?.low,
            high: rule?.high,
            unit: group.unit,
            decimals: decimals,
            fluid: fluid,
            pointer: _chipColor(signal.status, palette),
            palette: palette,
            tier: tier,
          ),
        ),
      ),
    );
  }
}

class _ThermometerPainter extends CustomPainter {
  /// Gia tri dang ve (da clamp 0..max); null = khong co tin hieu.
  final double? level;
  final double max;
  final double? low;
  final double? high;
  final String unit;
  final int decimals;
  final Color fluid;
  final Color pointer;
  final WaterPalette palette;
  final WaterVisualSize tier;

  const _ThermometerPainter({
    required this.level,
    required this.max,
    required this.low,
    required this.high,
    required this.unit,
    required this.decimals,
    required this.fluid,
    required this.pointer,
    required this.palette,
    required this.tier,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = tier.scale;
    final tube = 12 * s;
    final bulb = 26 * s;
    final majorTick = 7 * s;
    final minorTick = 4 * s;
    final bandWidth = 4 * s;

    final labels = [
      for (var v = 0.0; v <= max + 1e-9; v += 10)
        (
          value: v,
          text: _plainText(
            formatValue(v, decimals: 0),
            TextStyle(
              color: palette.muted,
              fontSize: tier.font(9),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
    ];
    final labelWidth = labels.fold<double>(
      0,
      (width, label) => math.max(width, label.text.width),
    );

    final pills = [
      for (final edge in [high, low])
        if (edge != null && edge >= 0 && edge <= max)
          (
            edge: edge,
            pill: _Pill(
              formatWithUnit(edge, unit, decimals: decimals),
              tier,
              palette.muted,
            ),
          ),
    ];
    final pillWidth = pills.fold<double>(
      0,
      (width, item) => math.max(width, item.pill.width),
    );

    // Bo cuc ngang (tuong doi), roi can giua trong khung.
    final tickRightRel = labelWidth + 2 * s + majorTick;
    final bandLeftRel = tickRightRel + s;
    final tubeLeftRel = bandLeftRel + bandWidth + 6 * s;
    final tubeRightRel = tubeLeftRel + tube;
    final pillLeftRel = tubeRightRel + 4 * s;
    final contentWidth = pills.isEmpty
        ? tubeLeftRel + tube / 2 + bulb / 2
        : pillLeftRel + pillWidth;
    final dx = math.max(0.0, (size.width - contentWidth) / 2);

    final tickRight = dx + tickRightRel;
    final bandLeft = dx + bandLeftRel;
    final bandRight = bandLeft + bandWidth;
    final tubeLeft = dx + tubeLeftRel;
    final tubeRight = dx + tubeRightRel;
    final tubeCenter = (tubeLeft + tubeRight) / 2;

    // Bo cuc doc: 0 ngay tren bau, max chua cho nua nhan / pill.
    final bulbCenter = Offset(tubeCenter, size.height - bulb / 2 - 1);
    final yZero = bulbCenter.dy - bulb / 2 - 2 * s;
    final pillHalf = pills.isEmpty ? 0.0 : pills.first.pill.height / 2;
    final yTop = math.max(labels.first.text.height / 2, pillHalf) + 2;
    double yOf(double v) => yZero - (v / max).clamp(0.0, 1.0) * (yZero - yTop);

    // Dai mau nguong.
    for (final (from, to, color) in _thresholdBands(
      max: max,
      low: low,
      high: high,
      neutral: palette.muted.withValues(alpha: .25),
    )) {
      canvas.drawRect(
        Rect.fromLTRB(bandLeft, yOf(to), bandRight, yOf(from)),
        Paint()..color = color,
      );
    }

    // Vach + nhan thang.
    final major = Paint()
      ..color = palette.muted
      ..strokeWidth = 1.2 * s;
    final minor = Paint()
      ..color = palette.muted.withValues(alpha: .7)
      ..strokeWidth = .8 * s;
    for (var v = 0.0; v <= max + 1e-9; v += 5) {
      final y = yOf(v);
      final isMajor = (v / 10 - (v / 10).round()).abs() < 1e-9;
      canvas.drawLine(
        Offset(tickRight - (isMajor ? majorTick : minorTick), y),
        Offset(tickRight, y),
        isMajor ? major : minor,
      );
    }
    for (final label in labels) {
      label.text.paint(
        canvas,
        Offset(
          dx + labelWidth - label.text.width,
          yOf(label.value) - label.text.height / 2,
        ),
      );
    }

    // Ong: long ong, chat long, vet sang, vien.
    final tubeRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(tubeLeft, yTop - tube / 2, tubeRight, bulbCenter.dy),
      Radius.circular(tube / 2),
    );
    canvas.drawRRect(tubeRect, Paint()..color = palette.glass);

    final current = level;
    if (current != null) {
      final inset = 2.5 * s;
      final fluidRect = Rect.fromLTRB(
        tubeLeft + inset,
        yOf(current),
        tubeRight - inset,
        bulbCenter.dy,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(fluidRect, Radius.circular(tube / 2 - inset)),
        Paint()
          ..shader = LinearGradient(
            colors: [
              _shade(fluid, -.12),
              _shade(fluid, .12),
              _shade(fluid, -.12),
            ],
          ).createShader(fluidRect),
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(tubeCenter - .7 * s, yTop, 1.4 * s, yZero - yTop),
      Paint()
        ..color = Colors.white.withValues(alpha: palette.isDark ? .16 : .45),
    );
    canvas.drawRRect(
      tubeRect,
      Paint()
        ..color = palette.bezel
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * s,
    );

    _paintBulb(
      canvas,
      center: bulbCenter,
      radius: bulb / 2,
      fluid: fluid,
      rim: palette.bezel,
      glass: palette.faceEdge,
      scale: s,
    );

    // Vach nguong trung tinh (net dut manh) qua thang + ong, pill ben phai.
    final limit = Paint()
      ..color = palette.muted.withValues(alpha: .7)
      ..strokeWidth = math.max(1.0, 1 * s);
    for (final item in pills) {
      final y = yOf(item.edge);
      _dashed(
        canvas,
        Offset(tickRight - majorTick, y),
        Offset(tubeRight + 2 * s, y),
        limit,
      );
    }
    _paintPills(
      canvas,
      [for (final item in pills) (y: yOf(item.edge), pill: item.pill)],
      left: dx + pillLeftRel,
      height: size.height,
    );

    if (current != null) {
      _paintPointer(
        canvas,
        tip: Offset(bandRight + .5 * s, yOf(current)),
        size: 5 * s,
        color: pointer,
        outline: palette.faceCenter,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ThermometerPainter old) =>
      old.level != level ||
      old.max != max ||
      old.low != low ||
      old.high != high ||
      old.unit != unit ||
      old.decimals != decimals ||
      old.fluid != fluid ||
      old.pointer != pointer ||
      old.tier != tier ||
      old.palette.brightness != palette.brightness;
}

/// Bau nhiet ke 2 lop: vong ngoai vien kim loai, loi cung mau chat long.
void _paintBulb(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required Color fluid,
  required Color rim,
  required Color glass,
  required double scale,
}) {
  canvas.drawCircle(center, radius - .6, Paint()..color = glass);
  canvas.drawCircle(
    center,
    radius - .6,
    Paint()
      ..color = rim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * scale,
  );

  final core = radius - 4 * scale;
  canvas.drawCircle(
    center,
    core,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.35, -.35),
        colors: [_shade(fluid, .16), _shade(fluid, -.1)],
      ).createShader(Rect.fromCircle(center: center, radius: core)),
  );
}

// ============================================================
// DIAL
// ============================================================

/// Dong ho kim 240°: bezel kim loai + mat gradient, vach chinh / phu, dai
/// mau mong (do / cam / xanh, khong nguong: xam), kim co duoi, num 2 lop,
/// gia tri + don vi trong mat. Mini gauge ([WaterVisualSize.miniDial],
/// 84×78): bo vach chia + nhan so, bezel mong, gia tri >= 14px.
class WaterPressureDial extends StatelessWidget {
  final WaterGroup group;
  final WaterSignal signal;
  final int decimals;
  final bool animate;
  final WaterVisualSize tier;

  const WaterPressureDial({
    super.key,
    required this.group,
    required this.signal,
    required this.decimals,
    required this.animate,
    required this.tier,
  });

  @override
  Widget build(BuildContext context) {
    final palette = WaterPalette.of(context);
    final size = tier.figureSize(WaterVisualKind.dial);
    final s = tier.scale;

    // Mini gauge: chi cung nguong (day hon), kim, gia tri; bezel mong.
    final mini = tier.miniDial;
    // Cung nguong manh: xanh la cho [low, high], con lai xam.
    final band = (mini ? 3.5 : 3) * s;
    final valueFont = mini ? math.max(14.0, 14 * s) : tier.valueFont;

    final max = dialMax(group, signal);
    final stopped = signal.status == WaterStatus.stopped;
    final value = waterDisplayValue(signal);
    final abnormal = value != null && value < 0;
    final needle = value == null
        ? palette.muted
        : waterReadingColor(signal.status, palette, abnormal: abnormal);

    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _DialFacePainter(palette, s, bezel: (mini ? 1.2 : 3) * s),
          ),
          SfRadialGauge(
            enableLoadingAnimation: animate,
            animationDuration: 300,
            axes: [
              RadialAxis(
                minimum: 0,
                maximum: max,
                interval: max / 4,
                startAngle: 150,
                endAngle: 30,
                radiusFactor: mini ? .92 : .88,
                showAxisLine: false,
                showTicks: !mini,
                showLabels: !mini,
                minorTicksPerInterval: 9,
                tickOffset: band + 1,
                labelOffset: 3 * s,
                offsetUnit: GaugeSizeUnit.logicalPixel,
                ticksPosition: ElementsPosition.inside,
                labelsPosition: ElementsPosition.inside,
                majorTickStyle: MajorTickStyle(
                  length: .1,
                  lengthUnit: GaugeSizeUnit.factor,
                  thickness: 1.6 * s,
                  color: palette.muted,
                ),
                minorTickStyle: MinorTickStyle(
                  length: .05,
                  lengthUnit: GaugeSizeUnit.factor,
                  thickness: .7 * s,
                  color: palette.muted.withValues(alpha: .7),
                ),
                axisLabelStyle: GaugeTextStyle(
                  fontSize: tier.font(9),
                  color: palette.muted,
                ),
                onLabelCreated: (args) {
                  final number = double.tryParse(args.text);
                  if (number == null) return;

                  // s < 0.9: chi giu nhan min / max.
                  final edge =
                      number.abs() < 1e-9 || (number - max).abs() < max * 1e-6;
                  args.text = tier.minMaxLabelsOnly && !edge
                      ? ''
                      : formatValue(number, decimals: decimals);
                },
                ranges: _ranges(max, palette, band, stopped: stopped),
                pointers: [
                  NeedlePointer(
                    value: (value ?? 0).clamp(0, max).toDouble(),
                    enableAnimation: false,
                    needleLength: .75,
                    lengthUnit: GaugeSizeUnit.factor,
                    needleStartWidth: 1 * s,
                    needleEndWidth: 4 * s,
                    needleColor: needle,
                    tailStyle: TailStyle(
                      length: .15,
                      width: 4 * s,
                      lengthUnit: GaugeSizeUnit.factor,
                      color: needle,
                    ),
                    knobStyle: KnobStyle(
                      knobRadius: .08,
                      sizeUnit: GaugeSizeUnit.factor,
                      color: palette.faceCenter,
                      borderColor: palette.bezel,
                      borderWidth: .04,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Gia tri + don vi trong mat (ca mini gauge), >= 14px; ve ngoai
          // SfRadialGauge de luon hien.
          Align(
            alignment: Alignment(0, mini ? .55 : .5),
            child: FractionallySizedBox(
              widthFactor: .7,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value == null
                          ? kMissingValue
                          : formatWaterValue(signal, decimals),
                      maxLines: 1,
                      style: TextStyle(
                        color: needle,
                        fontSize: waterIsAbnormal(signal.status)
                            ? valueFont * WaterVisualSize.problemValueScale
                            : valueFont,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      group.unit,
                      maxLines: 1,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: tier.font(9, min: 9),
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<GaugeRange> _ranges(
    double max,
    WaterPalette palette,
    double width, {
    bool stopped = false,
  }) {
    GaugeRange band(double from, double to, Color color) {
      return GaugeRange(
        startValue: from.clamp(0, max).toDouble(),
        endValue: to.clamp(0, max).toDouble(),
        color: color,
        startWidth: width,
        endWidth: width,
        sizeUnit: GaugeSizeUnit.logicalPixel,
      );
    }

    final rule = group.primaryThreshold;
    final low = rule?.low;
    final high = rule?.high;

    // Bom dung / khong nguong: ca dai mau xam.
    if (stopped || (low == null && high == null)) {
      return [band(0, max, palette.muted.withValues(alpha: .35))];
    }

    // Chi vung an toan xanh la; ngoai vung an toan xam (khong do / cam).
    final safeFrom = low ?? 0;
    final safeTo = high ?? max;
    final gray = palette.muted.withValues(alpha: .35);

    return [
      if (safeFrom > 0) band(0, safeFrom, gray),
      band(safeFrom, safeTo, kWaterOkColor.withValues(alpha: .8)),
      if (safeTo < max) band(safeTo, max, gray),
    ];
  }
}

/// Bezel kim loai + mat dong ho radial gradient, cung tam / ban kinh voi
/// SfRadialGauge (khong canScaleToFit: tam o giua, r = canh ngan / 2).
class _DialFacePainter extends CustomPainter {
  final WaterPalette palette;
  final double scale;

  /// Be day bezel (mini gauge: mong).
  final double bezel;

  const _DialFacePainter(this.palette, this.scale, {required this.bezel});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = bezel;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [palette.faceCenter, palette.faceEdge],
        ).createShader(rect),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..shader = SweepGradient(
          colors: [
            palette.bezel,
            palette.bezelShade,
            palette.bezel,
            palette.bezelShade,
            palette.bezel,
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _DialFacePainter old) =>
      old.palette.brightness != palette.brightness ||
      old.scale != scale ||
      old.bezel != bezel;
}

// ============================================================
// TANK
// ============================================================

/// Bon chua hinh tru: nuoc gradient ngang, mat nuoc gon song (chu ky ~4s),
/// so muc nuoc trong bon. Ben phai: thuoc met co dai 3 vung nguong + tam
/// giac ◀ chi muc nuoc, roi pill "max …" / "min …" ben ngoai; vach do net
/// dut min / max tu mep trai than toi thuoc. Song dung khi STALE va khi tab
/// an (TickerMode).
class WaterTank extends StatefulWidget {
  final WaterGroup group;
  final WaterSignal signal;
  final int decimals;
  final bool animate;
  final WaterVisualSize tier;

  const WaterTank({
    super.key,
    required this.group,
    required this.signal,
    required this.decimals,
    required this.animate,
    required this.tier,
  });

  @override
  State<WaterTank> createState() => _WaterTankState();
}

class _WaterTankState extends State<WaterTank>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  bool get _stale => widget.signal.status == WaterStatus.stale;

  @override
  void initState() {
    super.initState();
    _syncWave();
  }

  @override
  void didUpdateWidget(covariant WaterTank oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncWave();
  }

  void _syncWave() {
    if (_stale) {
      _wave.stop();
    } else if (!_wave.isAnimating) {
      _wave.repeat();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = WaterPalette.of(context);
    final size = widget.tier.figureSize(WaterVisualKind.tank);
    final signal = widget.signal;

    final max = tankMax(widget.group, signal);
    final value = _stale ? null : signal.value;
    final fraction = value == null ? 0.0 : (value / max).clamp(0.0, 1.0);
    final rule = widget.group.primaryThreshold;

    return SizedBox(
      width: size.width,
      height: size.height,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: fraction),
        duration: widget.animate
            ? const Duration(milliseconds: 300)
            : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, level, _) => CustomPaint(
          painter: _TankPainter(
            wave: _wave,
            level: value == null ? null : level,
            value: value,
            unit: widget.group.unit,
            max: max,
            low: rule?.low,
            high: rule?.high,
            water: waterFluidColor(signal.status),
            pointer: _chipColor(signal.status, palette),
            palette: palette,
            decimals: widget.decimals,
            tier: widget.tier,
            emphasize: waterIsAbnormal(signal.status),
          ),
        ),
      ),
    );
  }
}

class _TankPainter extends CustomPainter {
  final Animation<double> wave;

  /// Muc nuoc 0..1 (null = khong co tin hieu).
  final double? level;
  final double? value;
  final String unit;
  final double max;
  final double? low;
  final double? high;
  final Color water;

  /// Mau tam giac ◀ chi muc nuoc tren thuoc.
  final Color pointer;
  final WaterPalette palette;
  final int decimals;
  final WaterVisualSize tier;

  /// Hinh co van de: so muc nuoc to hon 15%.
  final bool emphasize;

  _TankPainter({
    required this.wave,
    required this.level,
    required this.value,
    required this.unit,
    required this.max,
    required this.low,
    required this.high,
    required this.water,
    required this.pointer,
    required this.palette,
    required this.decimals,
    required this.tier,
    this.emphasize = false,
  }) : super(repaint: wave);

  double get _s => tier.scale;

  /// Buoc vach thuoc: 0.5 m, thang lon thi gap doi; so moi 1 m.
  double get _rulerStep {
    var step = .5;
    while (max / step > 16) {
      step *= 2;
    }
    return step;
  }

  List<({double edge, _Pill pill})> get _pills => [
    for (final (edge, label) in [(high, 'max'), (low, 'min')])
      if (edge != null && edge >= 0 && edge <= max)
        (
          edge: edge,
          pill: _Pill(
            '$label ${formatWithUnit(edge, unit, decimals: decimals)}',
            tier,
            palette.muted,
          ),
        ),
  ];

  TextPainter _rulerLabel(double v) => _plainText(
    formatValue(v, decimals: 1),
    TextStyle(
      color: palette.muted,
      fontSize: tier.font(9),
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final capHeight = 12 * _s;
    final zoneWidth = 5 * _s;
    final majorTick = 6 * _s;

    // Bo cuc ngang tu phai sang trai: pill | so thuoc | vach | dai vung |
    // than bon (phan con lai).
    final pills = _pills;
    final pillWidth = pills.fold<double>(
      0,
      (w, item) => math.max(w, item.pill.width),
    );
    final labelWidth = _rulerLabel(max).width;

    final pillLeft = size.width - pillWidth - 1;
    final labelLeft =
        (pills.isEmpty ? size.width : pillLeft - 3 * _s) - labelWidth;
    final zoneRight = labelLeft - 2 * _s - majorTick;
    final zoneLeft = zoneRight - zoneWidth;

    final left = 3.0;
    final right = zoneLeft - 5 * _s;
    final top = capHeight / 2 + 2;
    final bottom = size.height - capHeight / 2 - 2;
    final width = right - left;

    // Vung chua nuoc: tu day than (0) toi mieng (max).
    final fillTop = top + capHeight / 2;
    final fillBottom = bottom;
    double yOf(double v) =>
        fillBottom - (v / max).clamp(0.0, 1.0) * (fillBottom - fillTop);

    final topCap = Rect.fromLTRB(
      left,
      top - capHeight / 2,
      right,
      top + capHeight / 2,
    );
    final bottomCap = Rect.fromLTRB(
      left,
      bottom - capHeight / 2,
      right,
      bottom + capHeight / 2,
    );

    final body = Path()
      ..moveTo(left, top)
      ..lineTo(left, bottom)
      ..arcTo(bottomCap, math.pi, -math.pi, false)
      ..lineTo(right, top)
      ..arcTo(topCap, 0, -math.pi, false)
      ..close();

    // Long bon.
    canvas.drawPath(body, Paint()..color = palette.glass);

    // Nuoc.
    final current = level;
    if (current != null && current > 0) {
      final surface = fillBottom - current * (fillBottom - fillTop);
      final phase = wave.value * 2 * math.pi;
      final amplitude = 2.0 * _s;

      final waterPath = Path()..moveTo(left, surface);
      for (var x = 0.0; x <= width; x += 2) {
        final y =
            surface + math.sin(phase + x / width * 2 * math.pi) * amplitude;
        waterPath.lineTo(left + x, y);
      }
      waterPath
        ..lineTo(right, bottom + capHeight)
        ..lineTo(left, bottom + capHeight)
        ..close();

      final waterRect = Rect.fromLTRB(left, surface, right, bottom);
      canvas.save();
      canvas.clipPath(body);
      canvas.drawPath(
        waterPath,
        Paint()
          ..shader = LinearGradient(
            colors: [
              _shade(water, -.14).withValues(alpha: .92),
              _shade(water, .1).withValues(alpha: .85),
              _shade(water, -.14).withValues(alpha: .92),
            ],
          ).createShader(waterRect),
      );
      canvas.restore();

      _paintLevelLabel(canvas, surface, left, right, bottom);
    }

    // Vet sang doc ben trai than.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + 7 * _s, top + 6 * _s, 3 * _s, bottom - top - 10),
        const Radius.circular(2),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: palette.isDark ? .14 : .5),
    );

    // Vien than + nap.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * _s
      ..shader = LinearGradient(
        colors: [palette.bezel, palette.bezelShade, palette.bezel],
      ).createShader(Rect.fromLTRB(left, 0, right, size.height));
    canvas.drawPath(body, rim);
    canvas.drawOval(topCap, rim);

    _paintRuler(
      canvas,
      zoneLeft: zoneLeft,
      zoneRight: zoneRight,
      majorTick: majorTick,
      labelLeft: labelLeft,
      fillTop: fillTop,
      fillBottom: fillBottom,
      yOf: yOf,
    );

    // Vach min / max trung tinh (net dut manh): tu mep trai than toi thuoc;
    // pill ben ngoai thuoc.
    final limit = Paint()
      ..color = palette.muted.withValues(alpha: .7)
      ..strokeWidth = math.max(1.0, 1 * _s);
    for (final item in pills) {
      final y = yOf(item.edge);
      _dashed(canvas, Offset(left, y), Offset(zoneRight, y), limit);
    }
    _paintPills(
      canvas,
      [for (final item in pills) (y: yOf(item.edge), pill: item.pill)],
      left: pillLeft,
      height: size.height,
    );

    final reading = value;
    if (reading != null) {
      _paintPointer(
        canvas,
        tip: Offset(zoneRight + .5 * _s, yOf(reading)),
        size: 5 * _s,
        color: pointer,
        outline: palette.faceCenter,
      );
    }
  }

  /// So muc nuoc ngay duoi mat nuoc, chu trang vien toi.
  void _paintLevelLabel(
    Canvas canvas,
    double surface,
    double left,
    double right,
    double bottom,
  ) {
    final current = value;
    if (current == null) return;

    final text = formatWithUnit(current, unit, decimals: decimals);
    TextPainter painter(Paint? stroke) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize:
              tier.font(12) *
              (emphasize ? WaterVisualSize.problemValueScale : 1),
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
          foreground: stroke,
          color: stroke == null ? Colors.white : null,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: right - left);

    final outline = painter(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * _s
        ..color = Colors.black.withValues(alpha: .55),
    );
    final fill = painter(null);

    final y = (surface + 5 * _s)
        .clamp(0.0, bottom - fill.height - 2)
        .toDouble();
    final offset = Offset(left + (right - left - fill.width) / 2, y);
    outline.paint(canvas, offset);
    fill.paint(canvas, offset);
  }

  /// Thuoc met ben phai than: dai 3 vung (do duoi min, xanh min–max, do tren
  /// max), vach moi buoc (0.5 m, thang lon thi gap doi), so moi 1 m.
  void _paintRuler(
    Canvas canvas, {
    required double zoneLeft,
    required double zoneRight,
    required double majorTick,
    required double labelLeft,
    required double fillTop,
    required double fillBottom,
    required double Function(double) yOf,
  }) {
    for (final (from, to, color) in _thresholdBands(
      max: max,
      low: low,
      high: high,
      neutral: palette.muted.withValues(alpha: .25),
    )) {
      canvas.drawRect(
        Rect.fromLTRB(zoneLeft, yOf(to), zoneRight, yOf(from)),
        Paint()..color = color,
      );
    }

    final line = Paint()
      ..color = palette.muted
      ..strokeWidth = 1;

    final step = _rulerStep;
    final labelEvery = step < 1 ? 2 : 1;

    var i = 0;
    for (var v = 0.0; v <= max + 1e-9; v += step, i++) {
      final y = yOf(v);
      final major = i % labelEvery == 0;

      canvas.drawLine(
        Offset(zoneRight, y),
        Offset(zoneRight + (major ? majorTick : majorTick * .6), y),
        line,
      );
      if (!major) continue;

      final label = _rulerLabel(v);
      label.paint(canvas, Offset(labelLeft, y - label.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _TankPainter old) {
    return old.level != level ||
        old.value != value ||
        old.max != max ||
        old.low != low ||
        old.high != high ||
        old.water != water ||
        old.pointer != pointer ||
        old.unit != unit ||
        old.decimals != decimals ||
        old.tier != tier ||
        old.emphasize != emphasize ||
        old.palette.brightness != palette.brightness;
  }
}

// ============================================================
// STATUS CHIP
// ============================================================

/// "Normal / Near limit / Abnormal / No signal / No limit / Stopped /
/// Sensor fault".
String waterChipLabel(WaterStatus status, {bool? nearHigh}) {
  return switch (status) {
    WaterStatus.ok => 'Normal',
    WaterStatus.near => switch (nearHigh) {
      true => 'Near max',
      false => 'Near min',
      null => 'Near limit',
    },
    WaterStatus.over => 'Abnormal',
    WaterStatus.stale => 'No signal',
    WaterStatus.noThreshold => 'No limit',
    WaterStatus.stopped => 'Stopped',
    WaterStatus.sensorFault => 'Sensor fault',
  };
}

/// Chip chi hien khi khac binh thuong (OK / NO_THRESHOLD: khong chip).
bool waterChipVisible(WaterStatus status) =>
    status != WaterStatus.ok && status != WaterStatus.noThreshold;

IconData? _chipIcon(WaterStatus status, bool? nearHigh) {
  return switch (status) {
    WaterStatus.over => Icons.warning_amber_rounded,
    WaterStatus.near =>
      nearHigh == false
          ? Icons.arrow_drop_down_rounded
          : Icons.arrow_drop_up_rounded,
    WaterStatus.stopped => Icons.pause_rounded,
    WaterStatus.stale => Icons.wifi_off_rounded,
    _ => null,
  };
}

Color _chipColor(WaterStatus status, WaterPalette palette) {
  final neutral =
      status == WaterStatus.stale ||
      status == WaterStatus.noThreshold ||
      status == WaterStatus.stopped;
  return neutral ? palette.muted : waterStatusColor(status);
}

/// Chip trang thai: chu 12px dam, padding 3×10, bo tron, icon theo trang
/// thai ([nearHigh]: NEAR phia max ▲ / min ▼). [dotOnly]: chi cham mau.
class WaterStatusChip extends StatelessWidget {
  final WaterStatus status;
  final WaterVisualSize tier;
  final bool dotOnly;
  final bool? nearHigh;

  const WaterStatusChip({
    super.key,
    required this.status,
    this.tier = WaterVisualSize.base,
    this.dotOnly = false,
    this.nearHigh,
  });

  @override
  Widget build(BuildContext context) {
    final palette = WaterPalette.of(context);
    final color = _chipColor(status, palette);
    final icon = _chipIcon(status, nearHigh);
    final arrow = status == WaterStatus.near;

    // NEAR: chip nho trung tinh, nen trong suot.
    final background = arrow
        ? Colors.transparent
        : color.withValues(alpha: .18);
    final border = color.withValues(alpha: arrow ? .35 : .55);

    if (dotOnly) {
      return Tooltip(
        message: waterChipLabel(status),
        child: WaterStatusDot(status: status, size: 7),
      );
    }

    return Container(
      height: tier.chipHeight,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: arrow ? 6 : 10, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: arrow ? tier.chipFont + 6 : tier.chipFont + 1,
              color: color,
            ),
            SizedBox(width: arrow ? 0 : 3),
          ],
          Text(
            waterChipLabel(status, nearHigh: nearHigh),
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: tier.chipFont,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// THRESHOLD HELPERS (nhiet ke / bon chua)
// ============================================================

TextPainter _plainText(String text, TextStyle style) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
}

/// Dai mau doc theo thang 0..max: chi vung an toan [low, high] xanh la nhat
/// (opacity 0.5); ngoai vung an toan (va khong nguong) la [neutral] xam nhat.
List<(double, double, Color)> _thresholdBands({
  required double max,
  required double? low,
  required double? high,
  required Color neutral,
}) {
  if (low == null && high == null) return [(0, max, neutral)];

  double clamp(double v) => v.clamp(0, max).toDouble();
  final safeFrom = clamp(low ?? 0);
  final safeTo = clamp(high ?? max);

  final bands = <(double, double, Color)>[
    (0, safeFrom, neutral),
    (safeFrom, safeTo, kWaterOkColor.withValues(alpha: .5)),
    (safeTo, max, neutral),
  ];
  return [
    for (final band in bands)
      if (band.$2 > band.$1) band,
  ];
}

/// Pill nguong trung tinh: nen / vien xam mo theo theme, chu 11px (toi
/// thieu 10px).
class _Pill {
  final TextPainter text;
  final Color color;
  final double padX;
  final double padY;

  _Pill(String label, WaterVisualSize tier, this.color)
    : padX = 5 * tier.scale.clamp(.8, 1.4),
      padY = 2 * tier.scale.clamp(.8, 1.4),
      text = _plainText(
        label,
        TextStyle(
          color: color,
          fontSize: tier.font(11, min: 10),
          fontWeight: FontWeight.w700,
          height: 1.1,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );

  double get width => text.width + padX * 2;
  double get height => text.height + padY * 2;

  void paint(Canvas canvas, Offset topLeft) {
    final rect = RRect.fromRectAndRadius(
      topLeft & Size(width, height),
      Radius.circular(height / 2),
    );
    canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: .1));
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = color.withValues(alpha: .35),
    );
    text.paint(canvas, topLeft + Offset(padX, padY));
  }
}

/// Ve pill can giua theo y cua vach; 2 pill qua gan thi day cach nhau toi
/// thieu [minGap] (tam - tam, khong nho hon chieu cao pill), giu trong khung.
void _paintPills(
  Canvas canvas,
  List<({double y, _Pill pill})> items, {
  required double left,
  required double height,
  double minGap = 14,
}) {
  if (items.isEmpty) return;

  final sorted = [...items]..sort((a, b) => a.y.compareTo(b.y));
  final centers = [for (final item in sorted) item.y];

  for (var i = 1; i < centers.length; i++) {
    final gap = math.max(
      minGap,
      (sorted[i - 1].pill.height + sorted[i].pill.height) / 2 + 2,
    );
    if (centers[i] - centers[i - 1] < gap) {
      // Day ca 2 ra hai phia tu diem giua.
      final mid = (centers[i] + centers[i - 1]) / 2;
      centers[i - 1] = mid - gap / 2;
      centers[i] = mid + gap / 2;
    }
  }

  // Giu ca cum trong [0, height].
  final top = centers.first - sorted.first.pill.height / 2;
  final bottom = centers.last + sorted.last.pill.height / 2;
  final shift = top < 0
      ? -top
      : bottom > height
      ? height - bottom
      : 0.0;

  for (var i = 0; i < sorted.length; i++) {
    final pill = sorted[i].pill;
    pill.paint(canvas, Offset(left, centers[i] + shift - pill.height / 2));
  }
}

/// Tam giac ◀ mau trang thai, dinh tai [tip] (chi vao thang).
void _paintPointer(
  Canvas canvas, {
  required Offset tip,
  required double size,
  required Color color,
  required Color outline,
}) {
  final path = Path()
    ..moveTo(tip.dx, tip.dy)
    ..lineTo(tip.dx + size, tip.dy - size * .75)
    ..lineTo(tip.dx + size, tip.dy + size * .75)
    ..close();
  canvas.drawPath(path, Paint()..color = color);
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = outline,
  );
}

// ============================================================
// DASH
// ============================================================

void _dashed(Canvas canvas, Offset from, Offset to, Paint paint) {
  const dash = 4.0;
  const gap = 3.0;

  final length = (to - from).distance;
  if (length <= 0) return;
  final direction = (to - from) / length;

  var t = 0.0;
  while (t < length) {
    final end = math.min(t + dash, length);
    canvas.drawLine(from + direction * t, from + direction * end, paint);
    t += dash + gap;
  }
}
