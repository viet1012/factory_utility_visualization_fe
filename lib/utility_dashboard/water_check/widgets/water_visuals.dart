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
    WaterStatus.near => kWaterNearColor,
    WaterStatus.over => kWaterOverColor,
    WaterStatus.stale => kWaterStaleColor,
    _ => kWaterFluidColor,
  };
}

const Color kWaterFluidColor = Color(0xFF3B9EFF);

/// Mau so / kim: chu chinh khi OK, cam NEAR, do OVER / abnormal.
Color waterReadingColor(
  WaterStatus status,
  WaterPalette palette, {
  bool abnormal = false,
}) {
  if (abnormal || status == WaterStatus.over) return kWaterOverColor;
  return switch (status) {
    WaterStatus.near => kWaterNearColor,
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

/// "near min ▼" / "near max ▲" cho bon chua dang NEAR.
String? tankNearCaption(WaterGroup group, WaterSignal signal) {
  final value = signal.value;
  final rule = group.primaryThreshold;
  if (signal.status != WaterStatus.near || value == null || rule == null) {
    return null;
  }

  final low = rule.low;
  final high = rule.high;
  if (high == null && low == null) return null;

  final nearHigh =
      high != null &&
      (low == null || (high - value).abs() < (value - low).abs());
  return nearHigh ? 'near max ▲' : 'near min ▼';
}

// ============================================================
// THERMOMETER
// ============================================================

/// Nhiet ke dung: ong bo tron co vien, chat long theo trang thai (co vet
/// sang), bau tron 2 lop, vach chinh moi 10 (co so), vach phu moi 5, vach
/// do net dut "max" tai nguong high.
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
    final s = tier.scale;

    final tube = 12 * s;
    final bulb = 26 * s;

    final max = thermometerMax(group);
    final high = group.primaryThreshold?.high;
    final value = signal.status == WaterStatus.stale ? null : signal.value;
    final fluid = value == null
        ? palette.muted
        : waterFluidColor(signal.status);

    return SizedBox(
      width: size.width,
      height: size.height,
      child: SfLinearGauge(
        orientation: LinearGaugeOrientation.vertical,
        minimum: 0,
        maximum: max,
        interval: 10,
        minorTicksPerInterval: 1,
        animateAxis: false,
        animateRange: false,
        tickPosition: LinearElementPosition.outside,
        labelPosition: LinearLabelPosition.outside,
        tickOffset: 3 * s,
        labelOffset: 3 * s,
        majorTickStyle: LinearTickStyle(
          length: 7 * s,
          thickness: 1.2 * s,
          color: palette.muted,
        ),
        minorTickStyle: LinearTickStyle(
          length: 4 * s,
          thickness: .8 * s,
          color: palette.muted.withValues(alpha: .7),
        ),
        axisLabelStyle: TextStyle(
          color: palette.muted,
          fontSize: tier.font(9),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        axisTrackStyle: LinearAxisTrackStyle(
          thickness: tube,
          edgeStyle: LinearEdgeStyle.bothCurve,
          color: palette.glass,
          borderColor: palette.bezel,
          borderWidth: 1.2 * s,
        ),
        barPointers: [
          if (value != null)
            LinearBarPointer(
              value: value.clamp(0, max).toDouble(),
              thickness: tube - 5 * s,
              edgeStyle: LinearEdgeStyle.bothCurve,
              enableAnimation: animate,
              animationDuration: 300,
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  _shade(fluid, -.12),
                  _shade(fluid, .12),
                  _shade(fluid, -.12),
                ],
              ).createShader(bounds),
            ),
          // Vet sang manh trong ong.
          LinearBarPointer(
            value: max,
            thickness: 1.4 * s,
            enableAnimation: false,
            color: Colors.white.withValues(alpha: palette.isDark ? .16 : .45),
          ),
        ],
        markerPointers: [
          LinearWidgetPointer(
            value: 0,
            enableAnimation: false,
            child: SizedBox(
              width: bulb,
              height: bulb,
              child: CustomPaint(
                painter: _BulbPainter(
                  fluid: fluid,
                  rim: palette.bezel,
                  glass: palette.faceEdge,
                  scale: s,
                ),
              ),
            ),
          ),
          if (high != null && high <= max) ...[
            LinearWidgetPointer(
              value: high,
              enableAnimation: false,
              child: SizedBox(
                width: tube + 12 * s,
                height: 1.6,
                child: const CustomPaint(
                  painter: _DashPainter(kWaterOverColor),
                ),
              ),
            ),
            LinearWidgetPointer(
              value: high,
              enableAnimation: false,
              position: LinearElementPosition.inside,
              offset: 4 * s,
              child: Text(
                'max',
                style: TextStyle(
                  color: kWaterOverColor,
                  fontSize: tier.font(9),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bau nhiet ke 2 lop: vong ngoai vien kim loai, loi cung mau chat long.
class _BulbPainter extends CustomPainter {
  final Color fluid;
  final Color rim;
  final Color glass;
  final double scale;

  const _BulbPainter({
    required this.fluid,
    required this.rim,
    required this.glass,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

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

  @override
  bool shouldRepaint(covariant _BulbPainter old) =>
      old.fluid != fluid ||
      old.rim != rim ||
      old.glass != glass ||
      old.scale != scale;
}

// ============================================================
// DIAL
// ============================================================

/// Dong ho kim 240°: bezel kim loai + mat gradient, vach chinh / phu, dai
/// mau mong (do / cam / xanh, khong nguong: xam), kim co duoi, num 2 lop,
/// gia tri + don vi trong mat.
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
    final band = 5 * s;

    final max = dialMax(group, signal);
    final value = signal.status == WaterStatus.stale ? null : signal.value;
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
          CustomPaint(painter: _DialFacePainter(palette, s)),
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
                radiusFactor: .88,
                showAxisLine: false,
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
                ranges: _ranges(max, palette, band),
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
                annotations: [
                  GaugeAnnotation(
                    angle: 90,
                    positionFactor: .45,
                    widget: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          value == null
                              ? kMissingValue
                              : formatValue(value, decimals: decimals),
                          style: TextStyle(
                            color: needle,
                            fontSize: tier.valueFont,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          group.unit,
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: tier.font(8),
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<GaugeRange> _ranges(double max, WaterPalette palette, double width) {
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

    if (low == null && high == null) {
      return [band(0, max, palette.muted.withValues(alpha: .35))];
    }

    // 10% sat nguong: theo be rong [low, high], co mot phia thi theo nguong.
    final margin = (low != null && high != null)
        ? (high - low).abs() * .1
        : (high ?? low)!.abs() * .1;

    return [
      if (low != null && low > 0) band(0, low, kWaterOverColor),
      if (low != null) band(low, low + margin, kWaterNearColor),
      band(
        low != null ? low + margin : 0,
        high != null ? high - margin : max,
        kWaterOkColor,
      ),
      if (high != null) band(high - margin, high, kWaterNearColor),
      if (high != null && high < max) band(high, max, kWaterOverColor),
    ];
  }
}

/// Bezel kim loai + mat dong ho radial gradient, cung tam / ban kinh voi
/// SfRadialGauge (khong canScaleToFit: tam o giua, r = canh ngan / 2).
class _DialFacePainter extends CustomPainter {
  final WaterPalette palette;
  final double scale;

  const _DialFacePainter(this.palette, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 3 * scale;
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
      old.palette.brightness != palette.brightness || old.scale != scale;
}

// ============================================================
// TANK
// ============================================================

/// Bon chua hinh tru: nuoc gradient ngang, mat nuoc gon song (chu ky ~4s),
/// thuoc met ben phai, vach do min / max, so muc nuoc trong bon. Song dung
/// khi STALE va khi tab an (TickerMode).
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
            palette: palette,
            decimals: widget.decimals,
            tier: widget.tier,
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
  final WaterPalette palette;
  final int decimals;
  final WaterVisualSize tier;

  _TankPainter({
    required this.wave,
    required this.level,
    required this.value,
    required this.unit,
    required this.max,
    required this.low,
    required this.high,
    required this.water,
    required this.palette,
    required this.decimals,
    required this.tier,
  }) : super(repaint: wave);

  double get _s => tier.scale;

  @override
  void paint(Canvas canvas, Size size) {
    final rulerWidth = 34 * _s;
    final capHeight = 12 * _s;

    final left = 3.0;
    final right = size.width - rulerWidth - 4 * _s;
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

    _paintRuler(canvas, right + 6 * _s, fillTop, fillBottom, yOf);
    _paintLimits(canvas, left, right, yOf);
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
          fontSize: tier.font(12),
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

  /// Thuoc met: vach moi 0.5 m, so moi 1 m (thang lon thi gian buoc).
  void _paintRuler(
    Canvas canvas,
    double x,
    double fillTop,
    double fillBottom,
    double Function(double) yOf,
  ) {
    final line = Paint()
      ..color = palette.muted
      ..strokeWidth = 1;
    canvas.drawLine(Offset(x, fillTop), Offset(x, fillBottom), line);

    var step = .5;
    while (max / step > 16) {
      step *= 2;
    }
    final labelEvery = step < 1 ? 2 : 1;

    var i = 0;
    for (var v = 0.0; v <= max + 1e-9; v += step, i++) {
      final y = yOf(v);
      final major = i % labelEvery == 0;

      canvas.drawLine(
        Offset(x, y),
        Offset(x + (major ? 6 : 3.5) * _s, y),
        line,
      );
      if (!major) continue;

      final label = TextPainter(
        text: TextSpan(
          text: formatValue(v, decimals: 1),
          style: TextStyle(
            color: palette.muted,
            fontSize: tier.font(9),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      label.paint(canvas, Offset(x + 8 * _s, y - label.height / 2));
    }
  }

  /// Vach do net dut min / max qua than toi thuoc, chu ben trong than.
  void _paintLimits(
    Canvas canvas,
    double left,
    double right,
    double Function(double) yOf,
  ) {
    final paint = Paint()
      ..color = kWaterOverColor
      ..strokeWidth = 1.3 * _s;

    for (final (edge, label) in [(low, 'min'), (high, 'max')]) {
      if (edge == null || edge < 0 || edge > max) continue;

      final y = yOf(edge);
      _dashed(canvas, Offset(left, y), Offset(right + 6 * _s, y), paint);

      final text = TextPainter(
        text: TextSpan(
          text: '$label ${formatValue(edge, decimals: decimals)}',
          style: TextStyle(
            color: kWaterOverColor,
            fontSize: tier.font(9),
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      text.paint(canvas, Offset(right - text.width - 4, y - text.height - 1));
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
        old.unit != unit ||
        old.decimals != decimals ||
        old.tier != tier ||
        old.palette.brightness != palette.brightness;
  }
}

// ============================================================
// STATUS CHIP
// ============================================================

/// "Normal / Near limit / Abnormal / No signal / No limit".
String waterChipLabel(WaterStatus status) {
  return switch (status) {
    WaterStatus.ok => 'Normal',
    WaterStatus.near => 'Near limit',
    WaterStatus.over => 'Abnormal',
    WaterStatus.stale => 'No signal',
    WaterStatus.noThreshold => 'No limit',
  };
}

Color _chipColor(WaterStatus status, WaterPalette palette) {
  final neutral =
      status == WaterStatus.stale || status == WaterStatus.noThreshold;
  return neutral ? palette.muted : waterStatusColor(status);
}

/// Chip trang thai bang chu; [dotOnly]: chi cham mau + tooltip.
class WaterStatusChip extends StatelessWidget {
  final WaterStatus status;
  final WaterVisualSize tier;
  final bool dotOnly;

  const WaterStatusChip({
    super.key,
    required this.status,
    this.tier = WaterVisualSize.base,
    this.dotOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = WaterPalette.of(context);
    final color = _chipColor(status, palette);

    if (dotOnly) {
      return Tooltip(
        message: waterChipLabel(status),
        child: WaterStatusDot(status: status, size: 7),
      );
    }

    return Container(
      height: tier.chipHeight,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: 7 * tier.scale),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .35), width: .8),
      ),
      child: Text(
        waterChipLabel(status),
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: tier.chipFont,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
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

class _DashPainter extends CustomPainter {
  final Color color;

  const _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    _dashed(
      canvas,
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = color
        ..strokeWidth = size.height,
    );
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
}
