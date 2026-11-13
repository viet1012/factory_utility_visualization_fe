import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../shared/charts/chart_hover_style.dart';
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

  const ConsumptionChart({
    super.key,
    required this.scope,
    required this.unit,
    required this.tariffAvailable,
    this.partialDate,
    this.partialUntil,
    this.billLabel,
  });

  @override
  State<ConsumptionChart> createState() => _ConsumptionChartState();
}

class _ConsumptionChartState extends State<ConsumptionChart> {
  late final TooltipBehavior _tooltip = TooltipBehavior(
    enable: true,
    builder: (data, point, series, pointIndex, seriesIndex) =>
        _tooltipCard(data as ConsumptionPoint),
  );

  ConsumptionScope get scope => widget.scope;
  ConsumptionUnit get unit => widget.unit;

  /// Khong co bang gia: MWh chi con tong dien luoi (+ solar).
  bool get _splitByTime => widget.tariffAvailable;

  String get _totalName =>
      scope.includesSolar ? 'Total (Electric + Solar)' : 'Total Electricity';

  double? _totalOf(EnergyValues v) => scope.headlineOf(v);

  bool _isPartial(ConsumptionPoint p) => p.isPartial(widget.partialDate);

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
      return month == null ? p.key : _monthNames[month.month - 1];
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
    final title = p.label.isEmpty ? text : '${p.label}, $text';
    if (!_isPartial(p)) return title;
    final until = _isRunningDay(p) ? widget.partialUntil : null;
    return until == null ? '$title · incomplete' : '$title · until $until';
  }

  /// MOT dong phu "Data" gop do phu du lieu (giu tooltip thap): vd
  /// `92.7% · 51/55 meters · incomplete`,
  /// `18/30 full days · 3,466.3 MWh excluded`. null khi khong co gi.
  (String, String)? _dataRow(ConsumptionPoint p) {
    final meters = p.isMonthly ? null : _metersText(p);
    final parts = [
      if (p.isMonthly && p.completeDays != null)
        '${p.completeDays}/${p.days ?? '?'} full days',
      if (!p.isMonthly && p.coveragePct != null)
        '${formatValue(p.coveragePct, decimals: 1)}%',
      ?meters,
      if (_isPartial(p)) 'incomplete',
      if (p.excludedMwh != null && p.excludedMwh! > 0)
        '${ConsumptionFormat.fixed(p.excludedMwh, 1)} MWh excluded',
    ];
    return parts.isEmpty ? null : ('Data', parts.join(' · '));
  }

  /// `51/55 meters` (co meter gui du lieu / cau hinh). BE cu khong co
  /// `reportingMeters`: `55 meters`, doi so voi ngay lien truoc thi them
  /// `(−4 vs day before)`.
  String? _metersText(ConsumptionPoint p) {
    final meters = p.meters;
    if (meters == null || meters == 0) return null;
    if (p.reportingMeters case final reporting?) {
      return '$reporting/$meters meters';
    }

    int? previous;
    for (final d in scope.daily) {
      if (d.key == p.key) break;
      if (d.hasData && d.meters != null && d.meters! > 0) previous = d.meters;
    }
    if (previous == null || previous == meters) return '$meters meters';
    final delta = meters - previous;
    final sign = delta > 0 ? '+' : '−';
    return '$meters meters ($sign${delta.abs()} vs day before)';
  }

  static const int _maxMissingLines = 5;

  /// Dong canh bao meter thieu du lieu + ngay khong co gia.
  List<(String, Color?)> _notes(ConsumptionPoint p) {
    final missing = p.isMonthly ? const <MissingMeter>[] : p.missingMeters;
    final notes = <(String, Color?)>[];

    if (missing.isNotEmpty) {
      notes.add((
        '⚠ ${missing.length} meter${missing.length == 1 ? '' : 's'} missing',
        ElectricityColors.up,
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
              lines.add(('$since: ${names.join(', ')}', names.length));
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
        notes.add(('  $text', ElectricityColors.up));
      }
      if (lines.length > _maxMissingLines) {
        var more = 0;
        for (final (_, count) in lines.skip(_maxMissingLines)) {
          more += count;
        }
        notes.add(('  +$more more', ElectricityColors.up));
      }
    }

    if (widget.tariffAvailable && p.noTariff) {
      notes.add((r'No tariff for this day – K$ not available', null));
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

    // Chi ghi so tai diem moi nhat cua duong tong (khong ghi moi diem).
    var labelIndex = -1;
    for (var i = points.length - 1; i >= 0; i--) {
      final v = points[i].valuesOf(unit);
      if (v != null && _totalOf(v) != null && !_isRunningDay(points[i])) {
        labelIndex = i;
        break;
      }
    }

    const labelStyle = TextStyle(
      color: ElectricityColors.textDim,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    return SfCartesianChart(
      margin: const EdgeInsets.fromLTRB(0, 4, 6, 0),
      plotAreaBorderWidth: 0,
      tooltipBehavior: _tooltip,
      legend: const Legend(
        isVisible: true,
        position: LegendPosition.top,
        alignment: ChartAlignment.near,
        overflowMode: LegendItemOverflowMode.wrap,
        iconHeight: 10,
        iconWidth: 10,
        itemPadding: 12,
        padding: 4,
        textStyle: TextStyle(color: ConsumptionColors.subtle, fontSize: 11.5),
      ),
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
          final style = _isPartial(p)
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
            dataSource: points,
            xValueMapper: (p, _) => p.key,
            yValueMapper: (p, _) {
              final v = p.valuesOf(unit);
              return v == null ? null : stack.pick(v);
            },
            color: stack.color,
            pointColorMapper: (p, _) => _isPartial(p)
                ? stack.color.withValues(alpha: ConsumptionColors.partialAlpha)
                : stack.color,
            // Khe 2px mau be mat giua cac khoi chong / cot ke nhau.
            borderColor: ConsumptionColors.surface,
            borderWidth: 1,
            width: .72,
            spacing: 0,
            animationDuration: 350,
          ),
        LineSeries<ConsumptionPoint, String>(
          name: _totalName,
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
          dataLabelSettings: DataLabelSettings(
            isVisible: labelIndex >= 0,
            labelAlignment: ChartDataLabelAlignment.top,
            builder: (data, point, series, pointIndex, seriesIndex) {
              if (pointIndex != labelIndex) return const SizedBox.shrink();
              final v = (data as ConsumptionPoint).valuesOf(unit);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: ConsumptionColors.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ElectricityColors.cardBorder),
                ),
                child: Text(
                  ConsumptionFormat.fixed(
                    v == null ? null : _totalOf(v),
                    decimals,
                  ),
                  style: const TextStyle(
                    color: ElectricityColors.text,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
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

    final dataRow = _dataRow(p);
    final notes = _notes(p);

    // Ngay co MWh nhung chua co gia: chart K$ khong co cot, tooltip chi ghi
    // do phu du lieu + ly do.
    if (v == null && unit == ConsumptionUnit.kusd && p.noTariff) {
      return _FitTooltip(
        child: ChartHoverCard(
          title: _tooltipTitle(p),
          rows: [?dataRow],
          notes: notes,
        ),
      );
    }

    if (v == null) {
      return _FitTooltip(
        child: ChartHoverCard(
          title: _tooltipTitle(p),
          rows: [('Status', p.isMonthly ? 'No data recorded' : 'No data yet')],
        ),
      );
    }

    final stacks = _stacks;
    final showGridTotal = _splitByTime && scope.includesSolar;

    return _FitTooltip(
      child: ChartHoverCard(
        title: _tooltipTitle(p),
        notes: notes,
        rows: [
          for (final s in stacks) (s.name, fmt(s.pick(v))),
          if (showGridTotal) ('Grid total', fmt(v.totalElectricity)),
          (_totalName, fmt(_totalOf(v))),
          if (dataRow != null) dataRow,
        ],
        swatches: [
          for (final s in stacks) s.color,
          if (showGridTotal) null,
          ConsumptionColors.total,
          if (dataRow != null) null,
        ],
      ),
    );
  }
}

/// Syncfusion gioi han tooltip trong vung ve cua chart: chart thap (o luoi
/// Charts) ma tooltip nhieu dong se tran (RenderFlex overflow). Thu nho
/// tooltip cho vua thay vi tran; du cho thi giu nguyen kich thuoc.
class _FitTooltip extends StatelessWidget {
  final Widget child;

  const _FitTooltip({required this.child});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topLeft,
      child: child,
    );
  }
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
