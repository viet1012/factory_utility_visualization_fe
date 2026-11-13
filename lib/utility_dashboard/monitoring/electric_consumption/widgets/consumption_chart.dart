import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../shared/charts/value_format.dart';
import '../../electricity/widgets/electricity_style.dart';
import '../model/electric_consumption.dart';

/// Mau chart: 4 slot categorical da kiem tra (dataviz validate_palette, nen
/// card #0A1A2C, dark): lightness band, chroma, CVD ke nhau (>= 8.4), normal
/// vision (>= 19.8), contrast >= 3:1. Thu tu chong cot Normal → High-peak →
/// Low-peak → Solar giu dung thu tu da kiem tra.
abstract final class ConsumptionColors {
  static const Color normal = Color(0xFF3987E5);
  static const Color highPeak = Color(0xFFD95926);
  static const Color lowPeak = Color(0xFF199E70);
  static const Color solar = Color(0xFFC98500);

  /// Dien luoi khi khong co bang gia (khong tach khung gio).
  static const Color grid = normal;

  /// Duong tong: muc chu chinh (khong phai mot series mau).
  static const Color total = ElectricityColors.text;

  /// Vien be mat (khe 2px giua cac khoi chong, vong quanh marker).
  static const Color surface = ElectricityColors.cardBg;

  /// Nen nhom cot: ky truoc / Chu nhat.
  static const Color monthBand = Color(0x0FFFFFFF);
  static const Color sundayBand = Color(0x0AFFFFFF);

  /// Nen cot "hom nay" trong bang (cyan rat nhat).
  static const Color todayBand = Color(0x165CD6FF);

  /// Chu cua ngay chua du du lieu (muc chu phu, nghieng + `*`).
  static const Color partial = ElectricityColors.textDim;
  static const double partialAlpha = .45;

  /// Mau trang thai (dataviz status palette, tach biet voi mau series),
  /// luon di kem icon + chu, khong dung mau don le de bao nghia.
  static const Color statusGood = Color(0xFF0CA30C);
  static const Color statusWarning = Color(0xFFFAB219);
  static const Color statusSerious = Color(0xFFEC835A);

  /// Trang thai thieu du lieu (coverage thap).
  static const Color warning = statusWarning;

  /// Chu tren nen card #0A1A2C (WCAG contrast):
  /// - [titleAccent] 10.5:1: ten scope / tieu de chart (diem nhan cyan)
  /// - [subtle] 11.2:1: chu phu doc duoc (don vi, nhan KPI, legend)
  /// - [muted] 7.0:1: ghi chu (thay textFaint 3.4:1 bi chim)
  static const Color titleAccent = Color(0xFF5CD6FF);
  static const Color subtle = Color(0xFFC3D0DE);
  static const Color muted = Color(0xFF93A6BC);

  static const Color gridLine = Color(0x10FFFFFF);
  static const Color axisLine = Color(0x33FFFFFF);
}

/// Quy tac lam tron hien thi (so goc giu nguyen trong model va khi copy
/// sang Excel):
/// - gia tri ngay / trung binh ngay: MWh so nguyen (50), K$ 1 so le (2.0)
/// - tong ky: MWh so nguyen (1,172), K$ 1 so le (94.3)
/// - truc Y: MWh so nguyen, K$ 1 so le
abstract final class ConsumptionFormat {
  static int value(ConsumptionUnit unit) => unit == ConsumptionUnit.mwh ? 0 : 1;

  static int total(ConsumptionUnit unit) => unit == ConsumptionUnit.mwh ? 0 : 1;

  static int axis(ConsumptionUnit unit) => unit == ConsumptionUnit.mwh ? 0 : 1;

  static final Map<int, NumberFormat> _fixed = {};

  /// So le co dinh (giu so 0 cuoi) de cot bang thang hang: `1,172.0`.
  static String fixed(double? value, int decimals) {
    if (value == null || !value.isFinite) return kMissingValue;
    final format = _fixed.putIfAbsent(
      decimals,
      () => NumberFormat(decimals == 0 ? '#,##0' : '#,##0.${'0' * decimals}'),
    );
    return format.format(value);
  }
}

int decimalsOf(ConsumptionUnit unit) => ConsumptionFormat.value(unit);

class _StackDef {
  final String name;
  final Color color;
  final double? Function(EnergyValues v) pick;

  const _StackDef(this.name, this.color, this.pick);
}

/// "KVH Elec. Daily Consumption – [MWh]": cot chong theo khung gio (+ solar
/// voi KVH) va duong tong. Truc X 2 tang: "Avg / day" (cac ky truoc) | ky
/// dang xem (tung ngay).
///
/// Ky truoc chua co du lieu o dau danh sach bi bo (khong ve cot rong). Ngay
/// chua du du lieu ve cot mo, nhan `*`; ngay dang chay ([partialDate]) khong
/// noi vao duong tong de khong tao cu "rot" gia.
class ConsumptionChart extends StatefulWidget {
  final ConsumptionScope scope;
  final ConsumptionUnit unit;
  final bool tariffAvailable;

  /// `yyyy-MM-dd` cua ngay dang chay (null khi khong co).
  final String? partialDate;

  /// `09:00`: du lieu ngay [partialDate] moi den gio nay.
  final String? partialUntil;

  /// Nhan nhom cua phan daily, vd `Nov (Oct21 ~ Nov20]`.
  final String? billLabel;

  /// Nguong ngay du (response.minCoveragePct), cho chu thich `* incomplete`.
  final double? minCoveragePct;

  /// Toggle "Values": ghi so giua tung doan chong.
  final bool showValues;

  /// null: an nut "Values" o legend.
  final ValueChanged<bool>? onShowValuesChanged;

  const ConsumptionChart({
    super.key,
    required this.scope,
    required this.unit,
    required this.tariffAvailable,
    this.partialDate,
    this.partialUntil,
    this.billLabel,
    this.minCoveragePct,
    this.showValues = false,
    this.onShowValuesChanged,
  });

  @override
  State<ConsumptionChart> createState() => _ConsumptionChartState();
}

class _ConsumptionChartState extends State<ConsumptionChart> {
  /// Trackball chi de do diem dang hover (ca cot, khong can trung khoi):
  /// khong ve tooltip / marker cua Syncfusion, tooltip la overlay rieng
  /// bam theo con tro ([_TooltipLayout]).
  late final TrackballBehavior _trackball = TrackballBehavior(
    enable: true,
    activationMode: ActivationMode.singleTap,
    tooltipDisplayMode: TrackballDisplayMode.nearestPoint,
    lineType: TrackballLineType.vertical,
    lineColor: Colors.white.withValues(alpha: .22),
    lineWidth: 1,
    lineDashArray: const <double>[3, 3],
    markerSettings: const TrackballMarkerSettings(
      markerVisibility: TrackballVisibilityMode.hidden,
    ),
    builder: (context, details) => const SizedBox.shrink(),
  );

  /// Phan cua chart duoi vung ve (nhan truc X 2 tang + le tren), de uoc
  /// luong chieu cao vung ve cho nguong 14px cua so trong doan chong.
  static const double _xAxisReserve = 44;

  /// visibleMax cua truc Y (onActualRangeChanged); null: chua ve lan nao.
  double? _yMax;

  /// Goi trong luc layout cua chart -> cap nhat o frame sau.
  void _setYMax(double? value) {
    if (value == null || value == _yMax) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && value != _yMax) setState(() => _yMax = value);
    });
  }

  /// Uoc luong truc Y truoc khi co [_yMax]: tong lon nhat + ~10%.
  double _dataMax(List<ConsumptionPoint> points) {
    var max = 0.0;
    for (final p in points) {
      final v = p.valuesOf(unit);
      final total = v == null ? null : _totalOf(v);
      if (total != null && total > max) max = total;
    }
    return max * 1.1;
  }

  /// Series dang an (bam vao legend, giong toggle cua legend Syncfusion).
  final Set<String> _hidden = {};

  void _toggleSeries(String name) => setState(() {
    if (!_hidden.remove(name)) _hidden.add(name);
  });

  /// Diem dang hover (chi so trong [_points]) va vi tri con tro.
  int? _hoverIndex;
  Offset? _pointer;
  Timer? _touchHideTimer;

  @override
  void dispose() {
    _touchHideTimer?.cancel();
    super.dispose();
  }

  /// Goi tu callback cua Syncfusion: co the roi vao luc dang build / layout
  /// thi doi sang frame sau.
  void _setHoverIndex(int? index) {
    _trackedThisEvent = true;
    if (index == _hoverIndex) return;
    void apply() {
      if (mounted && index != _hoverIndex) {
        setState(() => _hoverIndex = index);
      }
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  /// Syncfusion (con) nhan su kien truoc Listener (cha): neu su kien nay
  /// khong cho ra diem nao (ngoai vung ve, dang animation) thi an tooltip.
  bool _trackedThisEvent = false;

  void _onPointer(PointerEvent event) {
    _touchHideTimer?.cancel();
    final tracked = _trackedThisEvent;
    _trackedThisEvent = false;
    setState(() {
      _pointer = event.localPosition;
      if (!tracked) _hoverIndex = null;
    });
  }

  void _clearHover() {
    _touchHideTimer?.cancel();
    if (_hoverIndex == null && _pointer == null) return;
    setState(() {
      _hoverIndex = null;
      _pointer = null;
    });
  }

  /// Cam ung: giu tooltip mot luc sau khi nhac tay (giong trackball cu).
  void _onPointerUp(PointerEvent event) {
    if (event.kind == PointerDeviceKind.mouse) return;
    _touchHideTimer?.cancel();
    _touchHideTimer = Timer(const Duration(milliseconds: 2500), _clearHover);
  }

  ConsumptionScope get scope => widget.scope;
  ConsumptionUnit get unit => widget.unit;

  /// Khong co bang gia: MWh chi con tong dien luoi (+ solar).
  bool get _splitByTime => widget.tariffAvailable;

  String get _totalName =>
      scope.includesSolar ? 'Total (Electric + Solar)' : 'Total Electricity';

  double? _totalOf(EnergyValues v) => scope.headlineOf(v);

  bool _isPartial(ConsumptionPoint p) => p.isPartial(widget.partialDate);

  /// Ve mo + nhan `*`: ngay partial hoac ky truoc chua du ngay
  /// (completeDays < days).
  bool _isFaded(ConsumptionPoint p) => _isPartial(p) || p.isIncompleteMonth;

  /// Ngay dang chay (du lieu den gio hien tai).
  bool _isRunningDay(ConsumptionPoint p) =>
      !p.isMonthly && p.key == widget.partialDate;

  List<_StackDef> get _stacks => [
    if (_splitByTime) ...[
      _StackDef('Normal', ConsumptionColors.normal, (v) => v.normal),
      _StackDef('High-peak', ConsumptionColors.highPeak, (v) => v.highPeak),
      _StackDef('Low-peak', ConsumptionColors.lowPeak, (v) => v.lowPeak),
    ] else
      _StackDef('Grid', ConsumptionColors.grid, (v) => v.totalElectricity),
    if (scope.includesSolar)
      _StackDef('Solar', ConsumptionColors.solar, (v) => v.solar),
  ];

  /// Bo cac ky truoc rong o dau (backend chua co lich su).
  List<ConsumptionPoint> get _points => [
    ...scope.monthly.skipWhile((p) => p.isNoData),
    ...scope.daily,
  ];

  // ============================================================
  // LABELS
  // ============================================================

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Monthly `2026-08` -> `Aug`; daily `2026-08-21` -> `21` (ngay 1 / ngay
  /// dau ky: `9/1`). Ngay chua du du lieu them `*`.
  String _axisLabel(ConsumptionPoint p, bool firstDay) {
    if (p.isMonthly) {
      final month = parseBillMonth(p.key);
      final text = month == null ? p.key : _monthNames[month.month - 1];
      return p.isIncompleteMonth ? '$text*' : text;
    }
    final date = DateTime.tryParse(p.key);
    final text = date == null
        ? p.key
        : (firstDay || date.day == 1)
        ? '${date.month}/${date.day}'
        : '${date.day}';
    return _isPartial(p) ? '$text*' : text;
  }

  String _tooltipTitle(ConsumptionPoint p) {
    if (p.isMonthly) {
      final label = p.label.isEmpty ? p.key : p.label;
      return '$label · avg / day';
    }
    final date = PlantTime.tryParse(p.key);
    final text = date == null ? p.key : PlantTime.formatDate(date.date);
    return p.label.isEmpty ? text : '${p.label}, $text';
  }

  /// Chip trang thai canh tieu de: `until 09:00` (ngay dang chay),
  /// `incomplete`, ky truoc chua du ngay `18/30 days complete`; null khi du.
  String? _tooltipStatus(ConsumptionPoint p) {
    if (p.isIncompleteMonth) {
      return '${p.completeDays}/${p.days} days complete';
    }
    if (p.isMonthly || !_isPartial(p)) return null;
    final until = _isRunningDay(p) ? widget.partialUntil : null;
    return until == null ? 'incomplete' : 'until $until';
  }

  /// Cac dong do phu du lieu (cot phai cua tooltip).
  List<(String, String)> _dataFacts(ConsumptionPoint p) {
    final meters = p.isMonthly ? null : _metersText(p);
    return [
      // Ky chua du ngay: so ngay da nam o chip trang thai.
      if (p.isMonthly && p.completeDays != null && !p.isIncompleteMonth)
        ('Days complete', '${p.completeDays}/${p.days ?? '?'}'),
      if (!p.isMonthly && p.coveragePct != null)
        ('Coverage', '${formatValue(p.coveragePct, decimals: 1)}%'),
      if (meters != null) ('Meters', meters),
      if (p.excludedMwh != null && p.excludedMwh! > 0)
        ('Excluded', '${ConsumptionFormat.fixed(p.excludedMwh, 1)} MWh'),
    ];
  }

  /// `51/55 meters` (co meter gui du lieu / cau hinh). BE cu khong co
  /// `reportingMeters`: `55 meters`, doi so voi ngay lien truoc thi them
  /// `(−4 vs day before)`.
  String? _metersText(ConsumptionPoint p) {
    final meters = p.meters;
    if (meters == null || meters == 0) return null;
    if (p.reportingMeters case final reporting?) {
      return '$reporting/$meters';
    }

    int? previous;
    for (final d in scope.daily) {
      if (d.key == p.key) break;
      if (d.hasData && d.meters != null && d.meters! > 0) previous = d.meters;
    }
    if (previous == null || previous == meters) return '$meters';
    final delta = meters - previous;
    final sign = delta > 0 ? '+' : '−';
    return '$meters ($sign${delta.abs()} vs day before)';
  }

  static const int _maxMissingLines = 5;

  /// Dong canh bao meter thieu du lieu + ngay khong co gia.
  List<(String, _NoteKind)> _notes(ConsumptionPoint p) {
    final missing = p.isMonthly ? const <MissingMeter>[] : p.missingMeters;
    final notes = <(String, _NoteKind)>[];

    if (missing.isNotEmpty) {
      notes.add((
        '${missing.length} meter${missing.length == 1 ? '' : 's'} missing',
        _NoteKind.warning,
      ));

      // (text, so meter) - NO_DATA cung lastDataAt gop thanh mot dong.
      final lines = <(String, int)>[];
      final noData = <String?, List<String>>{};
      for (final m in missing) {
        if (m.reason == MissingReason.noData) {
          noData.putIfAbsent(m.lastDataAt, () => []).add(m.meter);
        }
      }
      final groupedDone = <String?>{};
      for (final m in missing) {
        switch (m.reason) {
          case MissingReason.noData:
            if (!groupedDone.add(m.lastDataAt)) continue;
            final names = noData[m.lastDataAt]!;
            final last = formatPlantDateTime(m.lastDataAt);
            if (names.length == 1) {
              lines.add((
                last == null
                    ? '${m.meter} · no data'
                    : '${m.meter} · no data (last $last)',
                1,
              ));
            } else {
              final since = last == null ? 'no data' : 'no data since $last';
              lines.add(('$since:\n${names.join('  ·  ')}', names.length));
            }
          case MissingReason.partial:
            lines.add((
              m.hours == null
                  ? '${m.meter} · partial'
                  : '${m.meter} · ${m.hours}/24 h',
              1,
            ));
          case MissingReason.outlier:
            lines.add((
              m.hours == null
                  ? '${m.meter} · dropped (outlier)'
                  : '${m.meter} · ${m.hours} h dropped (outlier)',
              1,
            ));
          case MissingReason.unknown:
            lines.add(('${m.meter} · missing', 1));
        }
      }

      for (final (text, _) in lines.take(_maxMissingLines)) {
        notes.add((text, _NoteKind.detail));
      }
      if (lines.length > _maxMissingLines) {
        var more = 0;
        for (final (_, count) in lines.skip(_maxMissingLines)) {
          more += count;
        }
        notes.add(('+$more more', _NoteKind.detail));
      }
    }

    if (widget.tariffAvailable && p.noTariff) {
      notes.add((r'No tariff for this day – K$ not available', _NoteKind.info));
    }
    return notes;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (unit == ConsumptionUnit.kusd && !widget.tariffAvailable) {
      return const _ChartMessage(
        icon: Icons.price_change_outlined,
        text: 'Tariff not available for this bill period (K\$ hidden)',
      );
    }

    final points = _points;
    if (points.every((p) => p.isNoData)) {
      return const _ChartMessage(
        icon: Icons.insert_chart_outlined,
        text: 'No consumption data',
      );
    }

    final byKey = {for (final p in points) p.key: p};
    final monthly = [
      for (final p in points)
        if (p.isMonthly) p,
    ];
    final daily = scope.daily;
    final firstDayKey = daily.isEmpty ? null : daily.first.key;
    final decimals = ConsumptionFormat.value(unit);
    final axisDecimals = ConsumptionFormat.axis(unit);

    final hoverIndex = _hoverIndex;
    final pointer = _pointer;
    final hovered =
        hoverIndex != null && hoverIndex >= 0 && hoverIndex < points.length
        ? points[hoverIndex]
        : null;

    final chartArea = MouseRegion(
      onExit: (_) => _clearHover(),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerHover: _onPointer,
        onPointerDown: _onPointer,
        onPointerMove: _onPointer,
        onPointerUp: _onPointerUp,
        onPointerCancel: (_) => _clearHover(),
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, box) => _chart(
                  points: points,
                  byKey: byKey,
                  monthly: monthly,
                  daily: daily,
                  firstDayKey: firstDayKey,
                  decimals: decimals,
                  axisDecimals: axisDecimals,
                  monthlyStep: _monthlyLabelStep(box.maxWidth, points, monthly),
                  plotHeight: box.maxHeight - _xAxisReserve,
                ),
              ),
            ),
            if (hovered != null && pointer != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomSingleChildLayout(
                    delegate: _TooltipLayout(pointer),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topLeft,
                      child: _tooltipCard(hovered),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _legend(),
        const SizedBox(height: 2),
        Expanded(child: chartArea),
      ],
    );
  }

  /// Nhan thang (`Jul*`, `Aug*`) rong hon o cot ngay -> dinh nhau. Uoc
  /// luong be rong moi cot tu be rong chart, do nhan thang rong nhat; khong
  /// du khoang cach toi thieu thi chi hien moi `step` nhan.
  static const double _yAxisReserve = 48;
  static const double _minLabelGap = 8;

  int _monthlyLabelStep(
    double width,
    List<ConsumptionPoint> points,
    List<ConsumptionPoint> monthly,
  ) {
    if (monthly.length < 2 || !width.isFinite || points.isEmpty) return 1;
    final slot = (width - _yAxisReserve) / points.length;
    if (slot <= 0) return 1;

    var widest = 0.0;
    for (final p in monthly) {
      final painter = TextPainter(
        text: TextSpan(
          text: _axisLabel(p, false),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            fontStyle: _isFaded(p) ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }

    final needed = widest + _minLabelGap;
    return needed <= slot ? 1 : (needed / slot).ceil();
  }

  // ============================================================
  // LEGEND
  // ============================================================

  /// Legend tu ve (thay legend Syncfusion) de them duoc muc `* incomplete`
  /// co tooltip ngay sau "Total". Bam vao muc series = an / hien series.
  Widget _legend() {
    const textStyle = TextStyle(
      color: ConsumptionColors.subtle,
      fontSize: 11.5,
    );

    Widget item(String name, Widget icon) {
      final hidden = _hidden.contains(name);
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _toggleSeries(name),
          child: Opacity(
            opacity: hidden ? .35 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 5),
                  Text(name, style: textStyle),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget bars(Color color) =>
        Icon(Icons.bar_chart_rounded, size: 14, color: color);

    const line = SizedBox(
      width: 16,
      height: 10,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Divider(height: 2, thickness: 2, color: ConsumptionColors.total),
          CircleAvatar(radius: 3, backgroundColor: ConsumptionColors.total),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2),
      child: Wrap(
        spacing: 14,
        runSpacing: 0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final s in _stacks) item(s.name, bars(s.color)),
          item(_totalName, line),
          _incompleteLegend(),
          if (widget.onShowValuesChanged != null) _valuesToggle(),
        ],
      ),
    );
  }

  /// Nut nho `☐ Values`: ghi so giua tung doan chong.
  Widget _valuesToggle() {
    final on = widget.showValues;
    final color = on ? ConsumptionColors.titleAccent : ConsumptionColors.muted;
    return Tooltip(
      message: on ? 'Hide segment values' : 'Show segment values',
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onShowValuesChanged?.call(!on),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: on
                  ? ConsumptionColors.titleAccent.withValues(alpha: .14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: on
                    ? ConsumptionColors.titleAccent.withValues(alpha: .5)
                    : ElectricityColors.cardBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  on
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 13,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  'Values',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `▢ * incomplete`: o xam nhat cung do mo cot partial + giai thich.
  Widget _incompleteLegend() {
    final pct = widget.minCoveragePct;
    final threshold = pct == null
        ? 'coverage below the full-day threshold'
        : 'coverage < ${formatValue(pct, decimals: 0)}%';

    return Tooltip(
      message:
          'Day: $threshold (missing meter-hours) or today.\n'
          'Month: not all days complete – average uses complete days only.\n'
          'Faded bars are under-counted.',
      waitDuration: const Duration(milliseconds: 200),
      child: MouseRegion(
        cursor: SystemMouseCursors.help,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: ConsumptionColors.subtle.withValues(
                    alpha: ConsumptionColors.partialAlpha,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                '* incomplete',
                style: TextStyle(
                  color: ConsumptionColors.muted,
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chart({
    required List<ConsumptionPoint> points,
    required Map<String, ConsumptionPoint> byKey,
    required List<ConsumptionPoint> monthly,
    required List<ConsumptionPoint> daily,
    required String? firstDayKey,
    required int decimals,
    required int axisDecimals,
    required int monthlyStep,
    required double plotHeight,
  }) {
    // Chieu cao (px) toi thieu cua mot doan chong de ghi so (toggle Values).
    final yMax = _yMax ?? _dataMax(points);
    bool tallEnough(double value) =>
        yMax > 0 && plotHeight > 0 && value / yMax * plotHeight >= 14;

    // Nhan thang hien moi [monthlyStep] nhan, dem lui tu thang gan nhat
    // (luon giu thang gan nhat). Nhan ngay khong doi.
    final lastMonthly = monthly.length - 1;
    final monthlyIndex = {for (final (i, p) in monthly.indexed) p.key: i};

    const labelStyle = TextStyle(
      color: ElectricityColors.textDim,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    return SfCartesianChart(
      margin: const EdgeInsets.fromLTRB(0, 4, 6, 0),
      plotAreaBorderWidth: 0,
      trackballBehavior: _trackball,
      onTrackballPositionChanging: (args) =>
          _setHoverIndex(args.chartPointInfo.dataPointIndex),
      // Legend tu ve phia tren ([_legend]).
      legend: const Legend(isVisible: false),
      onActualRangeChanged: (args) {
        if (args.orientation == AxisOrientation.vertical) {
          _setYMax((args.visibleMax as num?)?.toDouble());
        }
      },
      primaryXAxis: CategoryAxis(
        interval: 1,
        labelPlacement: LabelPlacement.betweenTicks,
        labelIntersectAction: AxisLabelIntersectAction.hide,
        majorGridLines: const MajorGridLines(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        axisLine: const AxisLine(color: ConsumptionColors.axisLine),
        labelStyle: labelStyle,
        axisLabelFormatter: (details) {
          final p = byKey[details.text];
          if (p == null) return ChartAxisLabel(details.text, labelStyle);
          if (p.isMonthly && monthlyStep > 1) {
            final i = monthlyIndex[p.key] ?? lastMonthly;
            if ((lastMonthly - i) % monthlyStep != 0) {
              return ChartAxisLabel('', labelStyle);
            }
          }
          final style = _isFaded(p)
              ? labelStyle.copyWith(fontStyle: FontStyle.italic)
              : p.label.toLowerCase().startsWith('sun')
              ? labelStyle.copyWith(
                  color: ElectricityColors.text,
                  fontWeight: FontWeight.w700,
                )
              : labelStyle;
          return ChartAxisLabel(_axisLabel(p, p.key == firstDayKey), style);
        },
        multiLevelLabelStyle: const MultiLevelLabelStyle(
          borderType: MultiLevelBorderType.squareBrace,
          borderColor: ConsumptionColors.axisLine,
          borderWidth: 1,
          textStyle: TextStyle(
            color: ConsumptionColors.subtle,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        multiLevelLabels: [
          if (monthly.isNotEmpty)
            CategoricalMultiLevelLabel(
              start: monthly.first.key,
              end: monthly.last.key,
              text: 'Avg / day',
            ),
          if (daily.isNotEmpty)
            CategoricalMultiLevelLabel(
              start: daily.first.key,
              end: daily.last.key,
              text: widget.billLabel ?? 'Daily',
            ),
        ],
        plotBands: [
          if (monthly.isNotEmpty)
            PlotBand(
              start: -0.5,
              end: monthly.length - 0.5,
              color: ConsumptionColors.monthBand,
            ),
          for (final (i, p) in points.indexed)
            if (!p.isMonthly && p.label.toLowerCase().startsWith('sun'))
              PlotBand(
                start: i - 0.5,
                end: i + 0.5,
                color: ConsumptionColors.sundayBand,
              ),
        ],
      ),
      primaryYAxis: NumericAxis(
        minimum: 0,
        desiredIntervals: 4,
        rangePadding: ChartRangePadding.additional,
        // Don vi truc Y (chu doc canh truc): MWh / K$.
        title: AxisTitle(
          text: unit == ConsumptionUnit.mwh ? 'MWh' : r'K$',
          textStyle: const TextStyle(
            color: ConsumptionColors.subtle,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        // Syncfusion chon buoc 1 / 2 / 5 × 10^n: voi gia tri thuc te (MWh
        // >= 10, K$ >= 1) nhan MWh so nguyen / K$ 1 so le khong bi trung.
        axisLabelFormatter: (details) => ChartAxisLabel(
          ConsumptionFormat.fixed(details.value.toDouble(), axisDecimals),
          details.textStyle,
        ),
        majorGridLines: const MajorGridLines(
          width: 1,
          color: ConsumptionColors.gridLine,
        ),
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        labelStyle: labelStyle,
      ),
      series: <CartesianSeries<ConsumptionPoint, String>>[
        for (final stack in _stacks)
          StackedColumnSeries<ConsumptionPoint, String>(
            name: stack.name,
            initialIsVisible: !_hidden.contains(stack.name),
            dataSource: points,
            xValueMapper: (p, _) => p.key,
            yValueMapper: (p, _) {
              final v = p.valuesOf(unit);
              return v == null ? null : stack.pick(v);
            },
            color: stack.color,
            pointColorMapper: (p, _) => _isFaded(p)
                ? stack.color.withValues(alpha: ConsumptionColors.partialAlpha)
                : stack.color,
            // Khe 2px mau be mat giua cac khoi chong / cot ke nhau.
            borderColor: ConsumptionColors.surface,
            borderWidth: 1,
            width: .72,
            spacing: 0,
            animationDuration: 350,
            // Toggle "Values": so giua doan, an khi = 0 hoac doan < 14px.
            dataLabelSettings: DataLabelSettings(
              isVisible: widget.showValues,
              labelAlignment: ChartDataLabelAlignment.middle,
              labelIntersectAction: LabelIntersectAction.hide,
              builder: (data, point, series, pointIndex, seriesIndex) {
                final v = (data as ConsumptionPoint).valuesOf(unit);
                final value = v == null ? null : stack.pick(v);
                if (value == null || value == 0 || !tallEnough(value)) {
                  return const SizedBox.shrink();
                }
                return Text(
                  ConsumptionFormat.fixed(value, decimals),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
        LineSeries<ConsumptionPoint, String>(
          name: _totalName,
          initialIsVisible: !_hidden.contains(_totalName),
          dataSource: points,
          xValueMapper: (p, _) => p.key,
          yValueMapper: (p, _) {
            if (_isRunningDay(p)) return null;
            final v = p.valuesOf(unit);
            return v == null ? null : _totalOf(v);
          },
          color: ConsumptionColors.total,
          width: 2,
          animationDuration: 350,
          markerSettings: const MarkerSettings(
            isVisible: true,
            width: 7,
            height: 7,
            color: ConsumptionColors.total,
            borderColor: ConsumptionColors.surface,
            borderWidth: 2,
          ),
          // So tong tren moi marker (monthly + daily); diem `*` mau mo.
          dataLabelSettings: DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.top,
            labelIntersectAction: LabelIntersectAction.hide,
            builder: (data, point, series, pointIndex, seriesIndex) {
              final p = data as ConsumptionPoint;
              final v = p.valuesOf(unit);
              final total = v == null ? null : _totalOf(v);
              if (total == null) return const SizedBox.shrink();
              return Text(
                ConsumptionFormat.fixed(total, decimals),
                style: TextStyle(
                  color: _isFaded(p)
                      ? ConsumptionColors.muted
                      : ElectricityColors.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tooltipCard(ConsumptionPoint p) {
    final v = p.valuesOf(unit);
    final decimals = ConsumptionFormat.value(unit);
    String fmt(double? value) => value == null
        ? kMissingValue
        : '${ConsumptionFormat.fixed(value, decimals)} ${unit.label}';

    final facts = _dataFacts(p);
    final notes = _notes(p);
    final title = _tooltipTitle(p);
    final status = _tooltipStatus(p);

    Widget card(List<_TipRow> rows, {String? message}) => _ConsumptionTooltip(
      title: title,
      status: status,
      rows: rows,
      message: message,
      facts: facts,
      notes: notes,
    );

    // Ngay co MWh nhung chua co gia: chart K$ khong co cot, tooltip chi ghi
    // do phu du lieu + ly do.
    if (v == null && unit == ConsumptionUnit.kusd && p.noTariff) {
      return card(const []);
    }
    if (v == null) {
      return card(
        const [],
        message: p.isMonthly ? 'No data recorded' : 'No data yet',
      );
    }

    final stacks = _stacks;
    final total = _totalOf(v);
    final showGridTotal = _splitByTime && scope.includesSolar;
    double? share(double? part) =>
        part == null || total == null || total == 0 ? null : part / total * 100;

    return card([
      for (final s in stacks)
        _TipRow(
          s.name,
          fmt(s.pick(v)),
          swatch: s.color,
          share: share(s.pick(v)),
        ),
      if (showGridTotal)
        _TipRow('Grid total', fmt(v.totalElectricity), divider: true),
      _TipRow(
        _totalName,
        fmt(total),
        swatch: ConsumptionColors.total,
        emphasis: true,
        divider: !showGridTotal,
      ),
    ]);
  }
}

/// Mot dong gia tri trong tooltip.
class _TipRow {
  final String label;
  final String value;
  final Color? swatch;

  /// Ty trong % tren tong (chi cac khoi chong).
  final double? share;
  final bool emphasis;

  /// Ke vach phan cach phia tren (bat dau phan tong).
  final bool divider;

  const _TipRow(
    this.label,
    this.value, {
    this.swatch,
    this.share,
    this.emphasis = false,
    this.divider = false,
  });
}

enum _NoteKind { warning, detail, info }

/// Tooltip ngang 2 cot: trai la gia tri (bang can thang, kem % ty trong),
/// phai la chat luong du lieu (coverage, meter, meter thieu). Thap hon kieu
/// xep doc nen vua vung chart, khong tran de len bang ben duoi.
class _ConsumptionTooltip extends StatelessWidget {
  final String title;
  final String? status;
  final List<_TipRow> rows;
  final String? message;
  final List<(String, String)> facts;
  final List<(String, _NoteKind)> notes;

  const _ConsumptionTooltip({
    required this.title,
    required this.status,
    required this.rows,
    required this.message,
    required this.facts,
    required this.notes,
  });

  static const Color _bg = Color(0xFF0B1728);
  static const Color _border = Color(0xFF2A4566);
  static const Color _label = Color(0xFFAFC0D3);
  static const TextStyle _num = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    final hasValues = rows.isNotEmpty || message != null;
    final hasSide = facts.isNotEmpty || notes.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasValues) _values(),
                if (hasValues && hasSide) ...[
                  const SizedBox(width: 14),
                  Container(width: 1, color: _border),
                  const SizedBox(width: 14),
                ],
                if (hasSide)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: _side(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (status != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: ConsumptionColors.titleAccent.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ConsumptionColors.titleAccent.withValues(alpha: .45),
              ),
            ),
            child: Text(
              status!,
              style: const TextStyle(
                color: ConsumptionColors.titleAccent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _values() {
    if (rows.isEmpty) {
      return Text(
        message ?? '',
        style: const TextStyle(color: _label, fontSize: 13),
      );
    }

    final showShare = rows.any((r) => r.share != null);
    TableRow row(_TipRow r) {
      final valueStyle = r.emphasis ? _num.copyWith(fontSize: 14) : _num;
      final pad = EdgeInsets.only(top: r.divider ? 7 : 3, bottom: 1);
      return TableRow(
        decoration: r.divider
            ? const BoxDecoration(
                border: Border(top: BorderSide(color: _border)),
              )
            : null,
        children: [
          Padding(
            padding: pad,
            child: r.swatch == null
                ? const SizedBox(width: 10)
                : Container(
                    width: r.emphasis ? 12 : 10,
                    height: r.emphasis ? 3 : 10,
                    decoration: BoxDecoration(
                      color: r.swatch,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
          ),
          Padding(
            padding: pad.copyWith(left: 8, right: 18),
            child: Text(
              r.label,
              style: TextStyle(
                color: r.emphasis ? Colors.white : _label,
                fontSize: 13,
                fontWeight: r.emphasis ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: pad,
            child: Text(r.value, textAlign: TextAlign.right, style: valueStyle),
          ),
          if (showShare)
            Padding(
              padding: pad.copyWith(left: 10),
              child: Text(
                r.share == null ? '' : '${r.share!.round()}%',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: ConsumptionColors.muted,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      );
    }

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [for (final r in rows) row(r)],
    );
  }

  Widget _side() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (facts.isNotEmpty) ...[
          const Text(
            'DATA',
            style: TextStyle(
              color: ConsumptionColors.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 3),
          for (final (label, value) in facts)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$label  ',
                      style: const TextStyle(color: _label),
                    ),
                    TextSpan(
                      text: value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
        ],
        for (final (i, (text, kind)) in notes.indexed)
          Padding(
            padding: EdgeInsets.only(
              top: kind == _NoteKind.detail
                  ? 3
                  : (i == 0 && facts.isEmpty ? 0 : 9),
              left: kind == _NoteKind.detail ? 18 : 0,
            ),
            child: kind == _NoteKind.detail
                ? Text(
                    text,
                    style: TextStyle(
                      color: ElectricityColors.up.withValues(alpha: .85),
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        kind == _NoteKind.warning
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline_rounded,
                        size: 14,
                        color: kind == _NoteKind.warning
                            ? ElectricityColors.up
                            : _label,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          text,
                          style: TextStyle(
                            color: kind == _NoteKind.warning
                                ? ElectricityColors.up
                                : _label,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}

/// Dat tooltip bam con tro, luon nam TRONG vung chart:
/// - mac dinh ben phai / duoi con tro;
/// - gan mep phai thi lat sang trai, gan mep duoi thi lat len tren;
/// - van khong du cho (chart hep / thap) thi ep sat mep trong vung chart.
/// Tooltip lon hon vung chart thi bi thu nho (FittedBox ben trong).
class _TooltipLayout extends SingleChildLayoutDelegate {
  final Offset pointer;

  const _TooltipLayout(this.pointer);

  /// Khoang cach tu con tro toi tooltip.
  static const double _gap = 14;

  /// Le toi thieu so voi mep chart.
  static const double _edge = 6;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    return BoxConstraints.loose(
      Size(
        math.max(0, size.width - _edge * 2),
        math.max(0, size.height - _edge * 2),
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double place(double at, double child, double extent) {
      final after = at + _gap;
      final before = at - _gap - child;
      final double pos;
      if (after + child <= extent - _edge) {
        pos = after;
      } else if (before >= _edge) {
        pos = before;
      } else {
        // Ca 2 phia deu khong du: chon phia rong hon roi ep vao trong.
        pos = at > extent / 2 ? before : after;
      }
      final max = math.max(_edge, extent - _edge - child);
      return pos.clamp(_edge, max);
    }

    return Offset(
      place(pointer.dx, childSize.width, size.width),
      place(pointer.dy, childSize.height, size.height),
    );
  }

  @override
  bool shouldRelayout(_TooltipLayout oldDelegate) =>
      oldDelegate.pointer != pointer;
}

class _ChartMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ChartMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: ConsumptionColors.muted, size: 28),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ElectricityColors.textDim,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
