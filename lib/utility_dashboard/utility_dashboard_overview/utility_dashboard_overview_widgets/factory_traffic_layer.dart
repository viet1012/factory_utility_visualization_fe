import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Kích thước gốc của ảnh nền SPC2_AM.png / SPC2_AM_night.png.
/// Mọi toạ độ làn đường bên dưới tính theo pixel của ảnh này,
/// rồi được map sang widget theo [BoxFit] giống hệt Image.asset.
const Size kFactorySceneImageSize = Size(1672, 941);

/// Lớp tán cây cắt ra từ ảnh nền (cùng kích thước), vẽ đè lên xe
/// để xe chạy luồn dưới tán cây ở đường ngoài cổng.
const String kFactoryDayTreesAsset = 'assets/images/SPC2_AM_trees.png';
const String kFactoryNightTreesAsset = 'assets/images/SPC2_AM_night_trees.png';

/// Lớp xe chạy (top-down) phủ lên ảnh nền nhà máy.
///
/// - Xe chạy đúng làn (lưu thông bên phải), giảm tốc khi vào cua,
///   bật xi-nhan trước khi rẽ, sáng đèn phanh khi giảm tốc.
/// - Xe vào/ra cổng được xếp lịch vào khoảng trống của làn chính nên
///   không bao giờ chồng lên nhau.
/// - Xe bị che bởi cầu MISUMI và tán cây như trong ảnh thật
///   (lớp `*_trees.png` cắt từ ảnh nền, vẽ đè lên xe).
/// - Render bằng sprite atlas vẽ sẵn + `drawAtlas` (lọc bilinear) nên xe
///   di chuyển mượt tới từng phần pixel, mỗi frame không tính blur nào.
/// - Ban ngày: bóng đổ theo hướng nắng. Ban đêm: đèn pha + đèn hậu.
class FactoryTrafficLayer extends StatefulWidget {
  final bool isActive;
  final bool isDay;
  final BoxFit fit;
  final String? dayTreesAsset;
  final String? nightTreesAsset;

  const FactoryTrafficLayer({
    super.key,
    required this.isActive,
    required this.isDay,
    this.fit = BoxFit.cover,
    this.dayTreesAsset = kFactoryDayTreesAsset,
    this.nightTreesAsset = kFactoryNightTreesAsset,
  });

  @override
  State<FactoryTrafficLayer> createState() => _FactoryTrafficLayerState();
}

class _FactoryTrafficLayerState extends State<FactoryTrafficLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _clock = ValueNotifier<double>(0);
  final _TrafficScene _scene = _TrafficScene.build();

  /// Thời gian đã chạy trước lần pause gần nhất (giây).
  double _clockBase = 0;

  /// Sprite atlas vẽ sẵn 1 lần cho ngày / đêm (tạo khi cần lần đầu).
  _SpriteAtlas? _dayAtlas;
  _SpriteAtlas? _nightAtlas;

  _SpriteAtlas _atlasFor(bool isDay) => isDay
      ? (_dayAtlas ??= _SpriteAtlas.build(_scene, isDay: true))
      : (_nightAtlas ??= _SpriteAtlas.build(_scene, isDay: false));

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _clock.value = _clockBase + elapsed.inMicroseconds / 1e6;
    });
    if (widget.isActive) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant FactoryTrafficLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;

    if (widget.isActive) {
      _ticker.start();
    } else {
      _clockBase = _clock.value;
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    _dayAtlas?.dispose();
    _nightAtlas?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trees = widget.isDay ? widget.dayTreesAsset : widget.nightTreesAsset;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              isComplex: true,
              willChange: true,
              painter: _TrafficPainter(
                scene: _scene,
                clock: _clock,
                atlas: _atlasFor(widget.isDay),
                isDay: widget.isDay,
                fit: widget.fit,
              ),
            ),
          ),
          if (trees != null)
            AnimatedSwitcher(
              duration: const Duration(seconds: 1),
              child: Image.asset(
                trees,
                key: ValueKey(trees),
                fit: widget.fit,
                width: double.infinity,
                height: double.infinity,
                alignment: Alignment.center,
                gaplessPlayback: true,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scene definition
// ---------------------------------------------------------------------------

enum _Kind { car, suv, van, truck, bike }

/// Đoạn bật xi-nhan: [from, to] theo quãng đường, side = 1 (phải) / -1 (trái).
typedef _Signal = ({double from, double to, int side});

class _Route {
  static const double _step = 2;

  final ui.PathMetric metric;
  final List<(double, double)> _speedKeys;
  final List<_Signal> signals;

  /// Quãng đường (px) để fade in ở đầu / fade out ở cuối tuyến
  /// (dùng cho đầu đường nội bộ bị hàng rào che).
  final double fadeIn;
  final double fadeOut;

  /// Thời điểm đi tới mẫu thứ i (mỗi mẫu cách nhau [_step] px).
  late final List<double> _times;

  /// [speedKeys]: (quãng đường px, tốc độ px/s), nội suy tuyến tính.
  _Route(
    Path path,
    List<(double, double)> speedKeys, {
    this.signals = const [],
    this.fadeIn = 0,
    this.fadeOut = 0,
  }) : metric = path.computeMetrics().first,
       _speedKeys = speedKeys {
    final n = (length / _step).ceil();
    final times = List<double>.filled(n + 1, 0);
    for (var i = 1; i <= n; i++) {
      final d0 = (i - 1) * _step;
      final d1 = math.min(i * _step, length);
      times[i] = times[i - 1] + (d1 - d0) / speedAt((d0 + d1) / 2);
    }
    _times = times;
  }

  double get length => metric.length;

  double get duration => _times.last;

  double speedAt(double d) {
    final keys = _speedKeys;
    if (d <= keys.first.$1) return keys.first.$2;
    for (var i = 1; i < keys.length; i++) {
      final (d1, v1) = keys[i];
      if (d <= d1) {
        final (d0, v0) = keys[i - 1];
        final f = (d - d0) / (d1 - d0);
        // ease để tăng/giảm tốc mượt
        return v0 + (v1 - v0) * (f * f * (3 - 2 * f));
      }
    }
    return keys.last.$2;
  }

  bool isBraking(double d) => speedAt(d + 6) < speedAt(d) - 0.4;

  double timeAt(double d) {
    final x = (d / _step).clamp(0.0, _times.length - 1.0);
    final i = x.floor();
    if (i >= _times.length - 1) return _times.last;
    return _times[i] + (_times[i + 1] - _times[i]) * (x - i);
  }

  double distAt(double t) {
    var lo = 0;
    var hi = _times.length - 1;
    if (t >= _times[hi]) return length;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (_times[mid] <= t) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final f = (t - _times[lo]) / (_times[hi] - _times[lo]);
    return math.min((lo + f) * _step, length);
  }

  int signalAt(double d) {
    for (final s in signals) {
      if (d >= s.from && d <= s.to) return s.side;
    }
    return 0;
  }
}

class _Vehicle {
  final _Route route;

  /// Thời điểm (giây, trong chu kỳ [_TrafficScene.period]) xe bắt đầu tuyến.
  final double offset;
  final _Kind kind;
  final Color color;

  const _Vehicle(this.route, this.offset, this.kind, this.color);

  double get length => _VehicleArt.lengthOf(kind);

  double get width => _VehicleArt.widthOf(kind);
}

class _TrafficScene {
  /// Mọi xe lặp lại theo cùng chu kỳ để lịch "nhập làn" luôn đúng.
  static const double period = 36;

  final List<_Vehicle> vehicles;

  const _TrafficScene(this.vehicles);

  // Đường nội bộ: vạch giữa đi từ (910, 300) xuống (941, 775).
  static double _laneX(double y, double side) =>
      910 + (y - 300) * 0.0653 + side * 14;

  static double _len(Path p) =>
      p.computeMetrics().fold(0.0, (sum, m) => sum + m.length);

  factory _TrafficScene.build() {
    // Đường ngoài cổng: mặt đường y ≈ 800..885, nằm ngang.
    const xRight = 1740.0;
    const xLeft = -70.0;
    const westY = 834.0; // làn trên: xe chạy sang trái
    const eastY = 852.0; // làn dưới: xe chạy sang phải
    const bikeY = 862.0; // xe máy sát lề phải

    const vMain = 70.0; // ~42 km/h (xe van đậu trong ảnh dài ~30px ≈ 5m)
    const vEast = 78.0;
    const vBike = 92.0;
    const vGate = 34.0; // đường nội bộ ~20 km/h
    const vTurn = 22.0;

    final west = _Route(
      Path()
        ..moveTo(xRight, westY)
        ..lineTo(xLeft, westY),
      const [(0, vMain)],
    );
    final east = _Route(
      Path()
        ..moveTo(xLeft, eastY)
        ..lineTo(xRight, eastY),
      const [(0, vEast)],
    );
    final bikeEast = _Route(
      Path()
        ..moveTo(xLeft, bikeY)
        ..lineTo(xRight, bikeY),
      const [(0, vBike)],
    );

    // --- Xe vào cổng: làn trên từ phải sang, giảm tốc, rẽ phải vào làn phải.
    final inX = _laneX(780, 1);
    final inA = Path()
      ..moveTo(xRight, westY)
      ..lineTo(1000, westY);
    final inB = Path()
      ..moveTo(1000, westY)
      ..cubicTo(972, westY, inX, westY - 22, inX, 780);
    final a1 = _len(inA);
    final b1 = _len(inB);
    final inbound = _Route(
      Path.from(inA)
        ..cubicTo(972, westY, inX, westY - 22, inX, 780)
        ..lineTo(_laneX(268, 1), 268),
      [
        (0, vMain),
        (a1 - 150, vMain),
        (a1, vTurn),
        (a1 + b1, vTurn),
        (a1 + b1 + 70, vGate),
      ],
      signals: [(from: a1 - 260, to: a1 + b1 * 0.8, side: 1)],
      fadeOut: 35,
    );

    // --- Xe ra cổng: làn trái đường nội bộ, giảm tốc, rẽ phải nhập làn trên.
    const mergeX = 890.0;
    final outX = _laneX(770, -1);
    final outA = Path()
      ..moveTo(_laneX(268, -1), 268)
      ..lineTo(outX, 770);
    final outB = Path()
      ..moveTo(outX, 770)
      ..cubicTo(outX + 1.7, 800, mergeX + 28, westY, mergeX, westY);
    final a2 = _len(outA);
    final b2 = _len(outB);
    const accel = 130.0;
    final outbound = _Route(
      Path.from(outA)
        ..cubicTo(outX + 1.7, 800, mergeX + 28, westY, mergeX, westY)
        ..lineTo(xLeft, westY),
      [
        (0, vGate),
        (a2 - 70, vGate),
        (a2, vTurn),
        (a2 + b2, vTurn + 4),
        (a2 + b2 + accel, vMain),
      ],
      signals: [(from: a2 - 120, to: a2 + b2 * 0.8, side: 1)],
      fadeIn: 35,
    );

    // Lịch xe làn trên (W). Xe IN / OUT được xếp vào giữa khoảng trống
    // giữa 2 xe W liên tiếp để không bao giờ chồng lên nhau.
    const westOffsets = [0.0, 9.6, 17.2, 27.4];
    double gapMid(int i) {
      final a = westOffsets[i];
      final b = i + 1 < westOffsets.length
          ? westOffsets[i + 1]
          : westOffsets[0] + period;
      return ((a + b) / 2) % period;
    }

    // Khi xe OUT đã tăng tốc xong (dFull), nó phải đứng đúng vị trí
    // của "slot" ảo giữa 2 xe W.
    final dFull = a2 + b2 + accel;
    final xFull = mergeX - accel;
    double outOffsetForGap(int i) =>
        (gapMid(i) - outbound.timeAt(dFull) + (xRight - xFull) / vMain) %
        period;

    // Màu hơi trầm cho khớp tông ảnh chụp.
    const white = Color(0xFFDADCDD);
    const silver = Color(0xFFA7ACB2);
    const black = Color(0xFF2A2D31);
    const red = Color(0xFF8E2A2E);
    const blue = Color(0xFF34507A);
    const grey = Color(0xFF686E76);

    return _TrafficScene([
      // Làn trên (sang trái)
      _Vehicle(west, westOffsets[0], _Kind.car, white),
      _Vehicle(west, westOffsets[1], _Kind.suv, black),
      _Vehicle(west, westOffsets[2], _Kind.truck, silver),
      _Vehicle(west, westOffsets[3], _Kind.car, red),

      // Vào / ra nhà máy
      _Vehicle(inbound, gapMid(0), _Kind.van, white),
      _Vehicle(inbound, gapMid(2), _Kind.car, blue),
      _Vehicle(outbound, outOffsetForGap(1), _Kind.car, silver),
      _Vehicle(outbound, outOffsetForGap(3), _Kind.suv, grey),

      // Làn dưới (sang phải)
      _Vehicle(east, 2.0, _Kind.car, blue),
      _Vehicle(east, 11.0, _Kind.van, white),
      _Vehicle(east, 19.5, _Kind.car, black),
      _Vehicle(east, 28.0, _Kind.truck, white),

      // Xe máy
      _Vehicle(bikeEast, 5.0, _Kind.bike, red),
      _Vehicle(bikeEast, 16.5, _Kind.bike, black),
      _Vehicle(bikeEast, 29.0, _Kind.bike, blue),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Sprite atlas: mọi hình xe vẽ sẵn 1 lần (độ phân giải x3) vào 1 ảnh.
// Mỗi frame chỉ "dán" sprite bằng drawAtlas -> không tính blur, không path,
// vị trí sub-pixel được lọc bilinear nên chuyển động mượt.
// ---------------------------------------------------------------------------

class _Sprite {
  /// Vùng của sprite trong atlas (px atlas).
  final Rect src;

  /// Điểm neo (px atlas) — điểm này đặt đúng vào vị trí xe.
  final Offset anchor;

  const _Sprite(this.src, this.anchor);
}

class _SpriteAtlas {
  /// Số px atlas cho 1 px ảnh nền: vẽ dư để thu nhỏ vẫn nét.
  static const double ss = 3;
  static const double _cellW = 64; // px ảnh nền
  static const double _cellH = 40;
  static const int _cols = 8;

  final ui.Image image;

  /// Thân xe theo thứ tự [_TrafficScene.vehicles]: bản nét / bản mờ
  /// (đường ngoài cổng bị mờ tilt-shift).
  final List<_Sprite> sharp;
  final List<_Sprite> blurred;
  final Map<_Kind, _Sprite> shadow;

  /// Vệt đèn pha (chỉ có ở atlas ban đêm), neo tại đầu xe.
  final _Sprite? beamCar;
  final _Sprite? beamBike;
  final _Sprite redGlow;
  final _Sprite amberGlow;

  _SpriteAtlas._({
    required this.image,
    required this.sharp,
    required this.blurred,
    required this.shadow,
    required this.beamCar,
    required this.beamBike,
    required this.redGlow,
    required this.amberGlow,
  });

  static const double blurSigma = 2.2;

  /// Làm mềm nhẹ bản "nét": chi tiết mảnh < 1px (gương, viền kính) khi thu
  /// nhỏ + dịch sub-pixel sẽ nhấp nháy (shimmer) -> mắt thấy như giật.
  static const double sharpSigma = 0.45;

  factory _SpriteAtlas.build(_TrafficScene scene, {required bool isDay}) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    var index = 0;

    _Sprite add(Offset anchorInCell, void Function(Canvas c) draw) {
      final col = index % _cols;
      final row = index ~/ _cols;
      index++;
      final origin = Offset(col * _cellW * ss, row * _cellH * ss);
      final anchor = origin + anchorInCell * ss;
      canvas.save();
      canvas.translate(anchor.dx, anchor.dy);
      canvas.scale(ss);
      draw(canvas);
      canvas.restore();
      return _Sprite(
        Rect.fromLTWH(origin.dx, origin.dy, _cellW * ss, _cellH * ss),
        anchor,
      );
    }

    const center = Offset(_cellW / 2, _cellH / 2);
    final sharp = [
      for (final v in scene.vehicles)
        add(
          center,
          (c) => _VehicleArt.body(c, v, isDay: isDay, sigma: sharpSigma),
        ),
    ];
    final blurred = [
      for (final v in scene.vehicles)
        add(
          center,
          (c) => _VehicleArt.body(c, v, isDay: isDay, sigma: blurSigma),
        ),
    ];
    final shadow = {
      for (final k in _Kind.values)
        k: add(center, (c) => _VehicleArt.shadow(c, k)),
    };
    const beamAnchor = Offset(4, _cellH / 2);
    final beamCar = isDay
        ? null
        : add(beamAnchor, (c) => _VehicleArt.beam(c, bike: false));
    final beamBike = isDay
        ? null
        : add(beamAnchor, (c) => _VehicleArt.beam(c, bike: true));
    final redGlow = add(center, _VehicleArt.redGlow);
    final amberGlow = add(center, _VehicleArt.amberGlow);

    final rows = (index + _cols - 1) ~/ _cols;
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (_cols * _cellW * ss).ceil(),
      (rows * _cellH * ss).ceil(),
    );
    picture.dispose();

    return _SpriteAtlas._(
      image: image,
      sharp: sharp,
      blurred: blurred,
      shadow: shadow,
      beamCar: beamCar,
      beamBike: beamBike,
      redGlow: redGlow,
      amberGlow: amberGlow,
    );
  }

  void dispose() => image.dispose();
}

/// Vẽ hình xe trong hệ toạ độ của xe: tâm (0,0), đầu xe hướng +x,
/// bên phải người lái là +y. Đơn vị: px ảnh nền.
abstract final class _VehicleArt {
  static const _glass = Color(0xFF151B24);
  static const _nightTint = Color(0xFF0A1424);
  static const _headlight = Color(0xFFFFF1D0);
  static const _taillight = Color(0xFFFF2D3F);
  static const _amber = Color(0xFFFFB020);

  static double lengthOf(_Kind k) => switch (k) {
    _Kind.car => 21,
    _Kind.suv => 23,
    _Kind.van => 27,
    _Kind.truck => 42,
    _Kind.bike => 7,
  };

  static double widthOf(_Kind k) => switch (k) {
    _Kind.car => 10,
    _Kind.suv => 11,
    _Kind.van => 11.5,
    _Kind.truck => 12.5,
    _Kind.bike => 3,
  };

  static RRect _bodyRect(_Kind k) {
    final len = lengthOf(k);
    final wid = widthOf(k);
    return RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: len, height: wid),
      Radius.circular(wid * (k == _Kind.bike ? 0.5 : 0.28)),
    );
  }

  static void shadow(Canvas c, _Kind k) {
    c.drawRRect(
      _bodyRect(k).inflate(0.6),
      Paint()
        ..color = Colors.black
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
  }

  static void body(
    Canvas c,
    _Vehicle v, {
    required bool isDay,
    required double sigma,
  }) {
    final kind = v.kind;
    final len = lengthOf(kind);
    final wid = widthOf(kind);
    final isBike = kind == _Kind.bike;
    final blur = sigma > 0 ? MaskFilter.blur(BlurStyle.normal, sigma) : null;
    final p = Paint()
      ..isAntiAlias = true
      ..maskFilter = blur;

    final base = isDay ? v.color : Color.lerp(v.color, _nightTint, 0.6)!;
    final lit = Color.lerp(base, Colors.white, isDay ? 0.22 : 0.06)!;
    final shade = Color.lerp(base, Colors.black, isDay ? 0.28 : 0.2)!;

    // Thân xe: sáng ở giữa nóc, tối dần ra 2 sườn (không phụ thuộc hướng xe).
    p.shader = ui.Gradient.linear(
      Offset(0, -wid / 2),
      Offset(0, wid / 2),
      [shade, lit, shade],
      const [0, .5, 1],
    );
    c.drawRRect(_bodyRect(kind), p);
    p.shader = null;

    switch (kind) {
      case _Kind.bike:
        p.color = isDay ? const Color(0xFFD8D8D2) : const Color(0xFF5B6270);
        c.drawCircle(const Offset(-0.6, 0), 1.6, p);
      case _Kind.truck:
        p.color = Color.lerp(lit, Colors.white, isDay ? 0.1 : 0.02)!;
        c.drawRect(
          Rect.fromLTRB(
            -len / 2 + 0.8,
            -wid / 2 + 0.7,
            len * 0.22,
            wid / 2 - 0.7,
          ),
          p,
        );
        p.color = Colors.black.withValues(alpha: 0.25);
        c.drawRect(Rect.fromLTRB(len * 0.22, -wid / 2, len * 0.27, wid / 2), p);
        p.color = _glass.withValues(alpha: 0.9);
        c.drawRect(
          Rect.fromLTRB(len * 0.36, -wid / 2 + 1.4, len * 0.43, wid / 2 - 1.4),
          p,
        );
      case _Kind.car:
      case _Kind.suv:
      case _Kind.van:
        final front = kind == _Kind.van ? 0.36 : 0.22;
        final rear = kind == _Kind.van ? -0.42 : -0.30;
        p.color = _glass.withValues(alpha: 0.92);
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              len * rear,
              -wid / 2 + 1.2,
              len * front,
              wid / 2 - 1.2,
            ),
            const Radius.circular(1.8),
          ),
          p,
        );
        if (isDay) {
          p.color = Colors.white.withValues(alpha: 0.22);
          c.drawRect(
            Rect.fromLTRB(
              len * (front - 0.07),
              -wid / 2 + 1.6,
              len * (front - 0.03),
              wid * 0.1,
            ),
            p,
          );
        }
        p.color = Color.lerp(base, lit, 0.6)!;
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              len * (rear + 0.09),
              -wid / 2 + 1.8,
              len * (front - 0.11),
              wid / 2 - 1.8,
            ),
            const Radius.circular(1.4),
          ),
          p,
        );
        p.color = shade;
        c.drawRect(
          Rect.fromLTWH(len * front - 1.5, -wid / 2 - 1.1, 1.6, 1.2),
          p,
        );
        c.drawRect(
          Rect.fromLTWH(len * front - 1.5, wid / 2 - 0.1, 1.6, 1.2),
          p,
        );
    }

    // Đèn pha + đèn hậu (mức sáng thường; phanh/xi-nhan vẽ thêm khi chạy).
    final lampY = isBike
        ? const <double>[0]
        : <double>[-wid * 0.32, wid * 0.32];
    final lampR = isBike ? 0.8 : 1.0;
    p.color = _headlight.withValues(alpha: isDay ? 0.5 : 1.0);
    for (final y in lampY) {
      c.drawCircle(Offset(len / 2 - 0.9, y), lampR, p);
    }
    p.color = _taillight.withValues(alpha: isDay ? 0.45 : 0.8);
    for (final y in lampY) {
      c.drawCircle(Offset(-len / 2 + 0.8, y), lampR, p);
    }
  }

  /// Vệt đèn pha, neo tại đầu xe (x = 0).
  static void beam(Canvas c, {required bool bike}) {
    final reach = bike ? 26.0 : 50.0;
    final halfStart = bike ? 1.0 : 4.0;
    final spread = bike ? 6.0 : 14.0;
    final path = Path()
      ..moveTo(0, -halfStart)
      ..lineTo(reach, -halfStart - spread)
      ..lineTo(reach, halfStart + spread)
      ..lineTo(0, halfStart)
      ..close();
    c.drawPath(
      path,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..shader = ui.Gradient.linear(Offset.zero, Offset(reach, 0), [
          _headlight.withValues(alpha: 0.6),
          _headlight.withValues(alpha: 0),
        ]),
    );
  }

  /// Quầng đỏ 2 đèn hậu (neo tại đuôi xe).
  static void redGlow(Canvas c) {
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 7, height: 12),
      Paint()
        ..color = _taillight
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6),
    );
  }

  /// Đèn xi-nhan: lõi sáng + quầng.
  static void amberGlow(Canvas c) {
    c.drawCircle(
      Offset.zero,
      2.6,
      Paint()
        ..color = _amber.withValues(alpha: 0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
    c.drawCircle(Offset.zero, 1.0, Paint()..color = _amber);
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

/// Gom các sprite cùng chế độ blend để vẽ bằng 1 lệnh drawAtlas.
class _AtlasBatch {
  final List<RSTransform> transforms = [];
  final List<Rect> rects = [];
  final List<Color> colors = [];

  void add(_Sprite s, double angle, Offset pos, double alpha, [double k = 1]) {
    if (alpha <= 0.004) return;
    transforms.add(
      RSTransform.fromComponents(
        rotation: angle,
        scale: k / _SpriteAtlas.ss,
        anchorX: s.anchor.dx - s.src.left,
        anchorY: s.anchor.dy - s.src.top,
        translateX: pos.dx,
        translateY: pos.dy,
      ),
    );
    rects.add(s.src);
    colors.add(Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0)));
  }

  void draw(Canvas canvas, ui.Image image, Paint paint) {
    if (transforms.isEmpty) return;
    canvas.drawAtlas(
      image,
      transforms,
      rects,
      colors,
      BlendMode.modulate,
      null,
      paint,
    );
  }
}

class _TrafficPainter extends CustomPainter {
  final _TrafficScene scene;
  final ValueNotifier<double> clock;
  final _SpriteAtlas atlas;
  final bool isDay;
  final BoxFit fit;

  _TrafficPainter({
    required this.scene,
    required this.clock,
    required this.atlas,
    required this.isDay,
    required this.fit,
  }) : super(repaint: clock);

  static final Paint _normal = Paint()
    ..filterQuality = FilterQuality.medium
    ..isAntiAlias = true;
  static final Paint _additive = Paint()
    ..filterQuality = FilterQuality.medium
    ..blendMode = BlendMode.plus;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Map toạ độ ảnh gốc -> toạ độ widget (giống Image.asset + Alignment.center).
    const imageSize = kFactorySceneImageSize;
    final fitted = applyBoxFit(fit, imageSize, size);
    final src = Alignment.center.inscribe(
      fitted.source,
      Offset.zero & imageSize,
    );
    final dst = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    final sx = dst.width / src.width;
    final sy = dst.height / src.height;

    final shadows = _AtlasBatch();
    final beams = _AtlasBatch();
    final bodies = _AtlasBatch();
    final glows = _AtlasBatch();

    final t = clock.value;
    final blinkOn = (t * 1.6) % 1.0 < 0.55;
    final shadowOffset = isDay ? const Offset(2.2, 2.8) : const Offset(0, 0.8);

    final vehicles = scene.vehicles;
    for (var i = 0; i < vehicles.length; i++) {
      final v = vehicles[i];
      final route = v.route;
      final tau = (t - v.offset) % _TrafficScene.period;
      if (tau > route.duration) continue;

      final d = route.distAt(tau);
      final tangent = route.metric.getTangentForOffset(d);
      if (tangent == null) continue;

      var alpha = 1.0;
      if (route.fadeIn > 0) alpha *= _smooth(0, route.fadeIn, d);
      if (route.fadeOut > 0) {
        alpha *= _smooth(0, route.fadeOut, route.length - d);
      }
      if (alpha <= 0.01) continue;

      final pos = tangent.position;
      final dir = tangent.vector; // vector đơn vị
      final angle = math.atan2(dir.dy, dir.dx);
      final right = Offset(-dir.dy, dir.dx);
      final isBike = v.kind == _Kind.bike;
      final halfLen = v.length / 2;

      // Bóng đổ
      shadows.add(
        atlas.shadow[v.kind]!,
        angle,
        pos + shadowOffset,
        alpha * (isDay ? 0.42 : 0.4),
      );

      // Đèn pha ban đêm
      final beam = isBike ? atlas.beamBike : atlas.beamCar;
      if (beam != null) beams.add(beam, angle, pos + dir * halfLen, alpha);

      // Thân xe: chuyển dần từ bản nét sang bản mờ khi ra đường ngoài.
      final mix = ((pos.dy - 785) / 20 / _SpriteAtlas.blurSigma).clamp(
        0.0,
        1.0,
      );
      if (mix > 0.01) bodies.add(atlas.blurred[i], angle, pos, alpha);
      if (mix < 0.99) {
        bodies.add(atlas.sharp[i], angle, pos, alpha * (1 - mix));
      }

      // Đèn hậu: quầng đỏ ban đêm, sáng mạnh khi phanh.
      final braking = route.isBraking(d);
      final tailGlow = braking ? (isDay ? 0.55 : 1.0) : (isDay ? 0.0 : 0.5);
      glows.add(
        atlas.redGlow,
        angle,
        pos - dir * halfLen,
        alpha * tailGlow,
        isBike ? 0.45 : 1,
      );

      // Xi-nhan nhấp nháy
      final side = blinkOn ? route.signalAt(d) : 0;
      if (side != 0 && !isBike) {
        final s = right * (side * (v.width / 2 - 0.9));
        glows.add(
          atlas.amberGlow,
          angle,
          pos + dir * (halfLen - 1.2) + s,
          alpha,
        );
        glows.add(
          atlas.amberGlow,
          angle,
          pos - dir * (halfLen - 1.2) + s,
          alpha,
        );
      }
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(dst.left - src.left * sx, dst.top - src.top * sy);
    canvas.scale(sx, sy);

    final img = atlas.image;
    shadows.draw(canvas, img, _normal);
    beams.draw(canvas, img, _additive);
    bodies.draw(canvas, img, _normal);
    glows.draw(canvas, img, _additive);

    canvas.restore();
  }

  static double _smooth(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  @override
  bool shouldRepaint(covariant _TrafficPainter old) =>
      old.isDay != isDay ||
      old.fit != fit ||
      old.scene != scene ||
      old.atlas != atlas;
}
