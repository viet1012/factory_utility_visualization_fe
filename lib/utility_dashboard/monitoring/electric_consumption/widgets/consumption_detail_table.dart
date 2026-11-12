import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../shared/charts/value_format.dart';
import '../../electricity/widgets/electricity_style.dart';
import '../model/electric_consumption.dart';
import 'consumption_chart.dart';

/// Bang so lieu duoi chart nhu sheet Excel: "Consumption [MWh]" (dong 28–35)
/// va "Amount [K$]" (dong 38–45). Cot trai co dinh (Description, Unit /
/// U.P), phan con lai cuon ngang: cac ky truoc (trung binh / ngay), tung
/// ngay cua ky, Total va Avg / day.
class ConsumptionDetailTable extends StatefulWidget {
  final ConsumptionScope scope;
  final ConsumptionUnit unit;
  final bool tariffAvailable;
  final UnitPrices? unitPrices;
  final String billLabel;
  final String? partialDate;

  const ConsumptionDetailTable({
    super.key,
    required this.scope,
    required this.unit,
    required this.tariffAvailable,
    required this.unitPrices,
    required this.billLabel,
    required this.partialDate,
  });

  @override
  State<ConsumptionDetailTable> createState() => _ConsumptionDetailTableState();
}

class _RowDef {
  final String label;

  /// Cot "Unit" (MWh) hoac "U.P [$/kWh]" (K$).
  final String unitText;
  final double? Function(EnergyValues v) pick;
  final bool emphasis;

  /// O mau trung voi series tren chart (null: dong tong).
  final Color? swatch;

  const _RowDef(
    this.label,
    this.unitText,
    this.pick, {
    this.emphasis = false,
    this.swatch,
  });
}

class _ConsumptionDetailTableState extends State<ConsumptionDetailTable> {
  /// Cot ten dong (kem don gia o bang K$), giong nhau o 2 bang.
  static const double _descWidth = 210;
  static const double _monthWidth = 62;
  static const double _dayWidth = 56;
  static const double _sumWidth = 74;
  static const double _rowHeight = 28;
  static const double _headHeight = 20;

  static final NumberFormat _price = NumberFormat('0.0000');

  final ScrollController _hScroll = ScrollController();
  bool _initialScrollDone = false;

  ConsumptionScope get scope => widget.scope;
  ConsumptionUnit get unit => widget.unit;
  bool get _isMwh => unit == ConsumptionUnit.mwh;

  /// Bo cac ky truoc rong o dau (giong chart).
  List<ConsumptionPoint> get _monthly =>
      scope.monthly.skipWhile((p) => p.isNoData).toList();

  @override
  void didUpdateWidget(covariant ConsumptionDetailTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Doi ky (vd Nov -> Oct): cuon lai toi ngay moi nhat cua ky moi.
    final oldFirst = oldWidget.scope.daily.firstOrNull?.key;
    final newFirst = widget.scope.daily.firstOrNull?.key;
    if (oldFirst != newFirst) _initialScrollDone = false;
  }

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  /// Ngay "hien tai" cua bang: ngay dang chay; khong co (ky da qua) thi ngay
  /// cuoi cung co du lieu. -1 khi ky chua co du lieu.
  int get _focusDayIndex {
    final daily = scope.daily;
    final running = daily.indexWhere((p) => p.key == widget.partialDate);
    if (running >= 0) return running;
    return daily.lastIndexWhere((p) => p.hasData);
  }

  bool _isToday(ConsumptionPoint p) =>
      !p.isMonthly && p.key == widget.partialDate && p.hasData;

  /// Vi tri cuon de ngay [_focusDayIndex] nam gan mep phai (con thay 2 ngay
  /// toi va cac ngay truoc do), nhu dang xem phan moi nhat cua sheet.
  double? _focusOffset() {
    if (!_hScroll.hasClients) return null;
    final position = _hScroll.position;
    if (!position.hasViewportDimension || !position.hasContentDimensions) {
      return null;
    }
    final index = _focusDayIndex;
    if (index < 0) return position.minScrollExtent;

    final dayEnd = _monthly.length * _monthWidth + (index + 1) * _dayWidth;
    final target = dayEnd + 2 * _dayWidth - position.viewportDimension;
    return target.clamp(position.minScrollExtent, position.maxScrollExtent);
  }

  void _scrollToFocusOnce() {
    if (_initialScrollDone) return;
    _initialScrollDone = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _focusOffset();
      if (target != null) _hScroll.jumpTo(target);
    });
  }

  void _animateToFocus() {
    final target = _focusOffset();
    if (target == null) return;
    _hScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  // ============================================================
  // ROWS
  // ============================================================

  String _priceText(double? price) =>
      _isMwh ? unit.label : (price == null ? '' : _price.format(price));

  List<_RowDef> get _rows {
    final prices = widget.unitPrices;
    final unitText = _isMwh ? unit.label : '';
    return [
      if (widget.tariffAvailable) ...[
        _RowDef(
          'Normal time',
          _priceText(prices?.gridNormal),
          (v) => v.normal,
          swatch: ConsumptionColors.normal,
        ),
        _RowDef(
          'High-peak time',
          _priceText(prices?.gridHighPeak),
          (v) => v.highPeak,
          swatch: ConsumptionColors.highPeak,
        ),
        _RowDef(
          'Low-peak time',
          _priceText(prices?.gridLowPeak),
          (v) => v.lowPeak,
          swatch: ConsumptionColors.lowPeak,
        ),
      ],
      _RowDef(
        scope.includesSolar ? 'Total Electricity' : 'Total',
        unitText,
        (v) => v.totalElectricity,
        emphasis: !scope.includesSolar,
        swatch: widget.tariffAvailable ? null : ConsumptionColors.grid,
      ),
      if (scope.includesSolar) ...[
        _RowDef(
          'Total Solar',
          unitText,
          (v) => v.solar,
          swatch: ConsumptionColors.solar,
        ),
        _RowDef(
          'Total ( Electric + Solar )',
          unitText,
          (v) => v.total,
          emphasis: true,
        ),
      ],
    ];
  }

  /// Avg / day: backend moi (co completeDays) da tinh tren ngay du; backend
  /// cu thi tu tinh tren cac ngay du.
  double? _average(_RowDef row) {
    if (scope.completeDays != null) {
      final avg = scope.averageOf(unit);
      return avg == null ? null : row.pick(avg);
    }
    var sum = 0.0;
    var count = 0;
    for (final p in scope.fullDays(widget.partialDate)) {
      final v = p.valuesOf(unit);
      final value = v == null ? null : row.pick(v);
      if (value == null) continue;
      sum += value;
      count++;
    }
    return count == 0 ? null : sum / count;
  }

  double? _total(_RowDef row) {
    final total = scope.totalOf(unit);
    return total == null ? null : row.pick(total);
  }

  // ============================================================
  // LABELS
  // ============================================================

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _monthLabel(ConsumptionPoint p) {
    final month = parseBillMonth(p.key);
    if (month == null) return p.key;
    final yy = (month.year % 100).toString().padLeft(2, '0');
    return "${_monthNames[month.month - 1]}'$yy";
  }

  String _dayLabel(ConsumptionPoint p) {
    final date = DateTime.tryParse(p.key);
    if (date == null) return p.key;
    // Ngay dau ky / dau thang: kem thang nhu Excel (8/21, 9/1).
    final first = p == scope.daily.first || date.day == 1;
    return first ? '${date.month}/${date.day}' : '${date.day}';
  }

  bool _isSunday(ConsumptionPoint p) => p.label.toLowerCase().startsWith('sun');

  // ============================================================
  // COPY (dan vao Excel)
  // ============================================================

  Future<void> _copy() async {
    final rows = _rows;
    // Copy giu du 3 so le (so goc), khong lam tron theo hien thi.
    String num(double? v) => v == null ? '' : v.toStringAsFixed(3);

    final lines = <String>[
      [
        'Description',
        _isMwh ? 'Unit' : r'U.P [$/kWh]',
        for (final p in _monthly) _monthLabel(p),
        for (final p in scope.daily) p.key,
        'Total',
        'Avg/day',
      ].join('\t'),
      for (final row in rows)
        [
          row.label,
          row.unitText,
          for (final p in [..._monthly, ...scope.daily]) num(_valueOf(p, row)),
          num(_total(row)),
          num(_average(row)),
        ].join('\t'),
    ];

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
          '${scope.name} [${unit.label}] copied (paste into Excel)',
        ),
      ),
    );
  }

  double? _valueOf(ConsumptionPoint p, _RowDef row) {
    final v = p.valuesOf(unit);
    return v == null ? null : row.pick(v);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (!_isMwh && !widget.tariffAvailable) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          r'Amount [K$]: tariff not available for this bill period.',
          style: TextStyle(color: ConsumptionColors.subtle, fontSize: 12),
        ),
      );
    }

    _scrollToFocusOnce();
    final rows = _rows;
    final showCoverage = _isMwh;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              _isMwh ? 'Consumption [MWh]' : r'Amount [K$]',
              style: const TextStyle(
                color: ElectricityColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            _ScrollButtons(
              controller: _hScroll,
              onLatest: _focusDayIndex >= 0 ? _animateToFocus : null,
              latestLabel: widget.partialDate == null ? 'Latest' : 'Today',
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Copy table (paste into Excel)',
              onPressed: _copy,
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              color: ConsumptionColors.subtle,
              icon: const Icon(Icons.copy_rounded),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: ElectricityColors.cardBorder),
            borderRadius: BorderRadius.circular(6),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _frozenColumns(rows, showCoverage),
              Expanded(
                // Web / desktop: Flutter mac dinh khong cho keo bang chuot
                // -> bat them chuot / trackpad / but de keo ngang bang.
                // Shift + con lan cung cuon ngang (Flutter ho tro san).
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: const {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                    },
                  ),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Scrollbar(
                      controller: _hScroll,
                      thumbVisibility: true,
                      interactive: true,
                      thickness: 8,
                      radius: const Radius.circular(4),
                      child: SingleChildScrollView(
                        controller: _hScroll,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _scrollColumns(rows, showCoverage),
                      ),
                    ),
                  ),
                ),
              ),
              // Total / Avg per day ghim ben phai, khong cuon theo.
              _pinnedColumns(rows, showCoverage),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- pinned right (Total / Avg per day) ----------------

  Widget _pinnedColumns(List<_RowDef> rows, bool showCoverage) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ElectricityColors.cardBg,
        border: const Border(
          left: BorderSide(color: ElectricityColors.cardBorder),
        ),
        // Bong nhe ve phia trai: cho thay phan giua dang cuon "duoi" khoi nay.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .35),
            blurRadius: 8,
            offset: const Offset(-3, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: _sumWidth * 2,
            height: _headHeight,
            alignment: Alignment.center,
            child: const Text(
              'This period',
              style: TextStyle(
                color: ConsumptionColors.subtle,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Row(
            children: [
              _columnHeader('Total', 'to date', _sumWidth),
              _columnHeader('Avg / day', 'full days', _sumWidth),
            ],
          ),
          for (final (index, row) in rows.indexed)
            _rowBox(
              index: index,
              emphasis: row.emphasis,
              child: Row(
                children: [
                  _valueCell(
                    _total(row),
                    _sumWidth,
                    bold: true,
                    decimals: ConsumptionFormat.total(unit),
                  ),
                  _valueCell(_average(row), _sumWidth, bold: true),
                ],
              ),
            ),
          if (showCoverage)
            _rowBox(
              index: rows.length,
              child: _coverageCell(_scopeCoverage(), _sumWidth * 2),
            ),
        ],
      ),
    );
  }

  // ---------------- frozen (Description [+ $/kWh]) ----------------

  /// Cot trai co dinh, cung do rong o ca 2 bang de cot so thang hang.
  /// Don vi da nam o tieu de bang ("Consumption [MWh]" / "Amount [K$]")
  /// nen khong lap "MWh" moi dong; bang K$ ghi don gia mo, can phai ngay
  /// trong o ten dong.
  Widget _frozenColumns(List<_RowDef> rows, bool showCoverage) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ElectricityColors.cardBg,
        border: Border(right: BorderSide(color: ElectricityColors.cardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerCell('', _descWidth, _headHeight),
          SizedBox(
            width: _descWidth,
            height: _headHeight * 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Description',
                      style: TextStyle(
                        color: ConsumptionColors.subtle,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!_isMwh)
                    const Text(
                      r'$/kWh',
                      style: TextStyle(
                        color: ConsumptionColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
          for (final (index, row) in rows.indexed)
            _rowBox(
              index: index,
              emphasis: row.emphasis,
              child: _labelCell(row),
            ),
          if (showCoverage)
            _rowBox(
              index: rows.length,
              child: _textCell(
                'Data coverage (days / %)',
                _descWidth,
                align: TextAlign.left,
                color: ConsumptionColors.muted,
                italic: true,
              ),
            ),
        ],
      ),
    );
  }

  // ---------------- group header (nhan dinh) ----------------

  /// Hang nhom tren cung cua phan cuon ngang. Nen cua moi nhom phu het
  /// chieu rong nhom; nhan thi chi nam trong phan nhom DANG NHIN THAY (theo
  /// vi tri cuon), nen khong bi cat giua chu (vd "y bill period") khi bang
  /// mo o phan daily. Phan nhin thay qua hep thi an nhan.
  Widget _groupRow(List<(String, double, Color?)> groups) {
    final total = groups.fold(0.0, (sum, g) => sum + g.$2);

    return SizedBox(
      width: total,
      height: _headHeight,
      child: AnimatedBuilder(
        animation: _hScroll,
        builder: (context, _) {
          final position = _hScroll.hasClients ? _hScroll.position : null;
          final ready =
              position != null &&
              position.hasPixels &&
              position.hasViewportDimension;
          final visibleStart = ready ? position.pixels : 0.0;
          final visibleEnd = ready
              ? visibleStart + position.viewportDimension
              : total;

          final children = <Widget>[];
          var start = 0.0;
          for (final (text, width, bg) in groups) {
            final end = start + width;
            children.add(
              Positioned(
                left: start,
                width: width,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bg,
                    border: start == 0
                        ? null
                        : const Border(
                            left: BorderSide(
                              color: ElectricityColors.cardBorder,
                            ),
                          ),
                  ),
                ),
              ),
            );

            final left = math.max(start, visibleStart);
            final right = math.min(end, visibleEnd);
            if (right - left >= 48) {
              children.add(
                Positioned(
                  left: left,
                  width: right - left,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ConsumptionColors.subtle,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            start = end;
          }

          return Stack(children: children);
        },
      ),
    );
  }

  // ---------------- scrollable (periods / days) ----------------

  Widget _scrollColumns(List<_RowDef> rows, bool showCoverage) {
    final monthly = _monthly;
    final daily = scope.daily;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hang nhom: "Avg / day" (cac ky truoc) | ky dang xem.
        _groupRow([
          if (monthly.isNotEmpty)
            (
              'Avg / day',
              monthly.length * _monthWidth,
              ConsumptionColors.monthBand,
            ),
          (widget.billLabel, daily.length * _dayWidth, null),
        ]),
        // Header 2 dong: nhan + thu.
        Row(
          children: [
            for (final p in monthly)
              _columnHeader(
                _monthLabel(p),
                'avg',
                _monthWidth,
                bg: ConsumptionColors.monthBand,
                faded: p.isNoData,
              ),
            for (final p in daily)
              _isToday(p)
                  // Hom nay: nhan cyan "Today", vach nhan tren dau cot.
                  ? _columnHeader(
                      _dayLabel(p),
                      'Today',
                      _dayWidth,
                      accent: true,
                      bg: ConsumptionColors.todayBand,
                    )
                  : _columnHeader(
                      _dayLabel(p) +
                          (p.isPartial(widget.partialDate) ? '*' : ''),
                      p.label,
                      _dayWidth,
                      color: p.isPartial(widget.partialDate)
                          ? ConsumptionColors.partial
                          : null,
                      italic: p.isPartial(widget.partialDate),
                      bg: _isSunday(p) ? ConsumptionColors.sundayBand : null,
                    ),
          ],
        ),
        for (final (index, row) in rows.indexed)
          _rowBox(
            index: index,
            emphasis: row.emphasis,
            child: Row(
              children: [
                for (final p in monthly)
                  _valueCell(
                    _valueOf(p, row),
                    _monthWidth,
                    bg: ConsumptionColors.monthBand,
                    bold: row.emphasis,
                  ),
                for (final p in daily)
                  _valueCell(
                    _valueOf(p, row),
                    _dayWidth,
                    bold: row.emphasis,
                    partial: p.isPartial(widget.partialDate),
                    bg: _isToday(p)
                        ? ConsumptionColors.todayBand
                        : _isSunday(p)
                        ? ConsumptionColors.sundayBand
                        : null,
                  ),
              ],
            ),
          ),
        if (showCoverage)
          _rowBox(
            index: rows.length,
            child: Row(
              children: [
                for (final p in monthly)
                  _coverageCell(_monthCoverage(p), _monthWidth, bg: true),
                for (final p in daily)
                  _coverageCell(
                    _dayCoverage(p),
                    _dayWidth,
                    // Hom nay chua het ngay: thieu la binh thuong, khong bao.
                    warn: p.isPartial(widget.partialDate) && !_isToday(p),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String _monthCoverage(ConsumptionPoint p) {
    if (p.isNoData) return '';
    if (p.completeDays == null) return '';
    return '${p.completeDays}/${p.days ?? '?'}';
  }

  String _dayCoverage(ConsumptionPoint p) {
    if (p.isNoData) return '';
    final pct = p.coveragePct;
    return pct == null ? '' : '${formatValue(pct, decimals: 0)}%';
  }

  String _scopeCoverage() {
    final full = scope.fullDays(widget.partialDate).length;
    final partial = scope.partialDays(widget.partialDate).length;
    return partial == 0 ? '$full full days' : '$full full + $partial partial';
  }

  // ============================================================
  // CELLS
  // ============================================================

  /// Dong xen ke nen nhe de do theo hang; dong tong dam hon.
  Widget _rowBox({
    required Widget child,
    required int index,
    bool emphasis = false,
  }) {
    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        color: emphasis
            ? Colors.white.withValues(alpha: .05)
            : index.isOdd
            ? Colors.white.withValues(alpha: .02)
            : null,
        border: Border(
          top: BorderSide(
            color: emphasis
                ? Colors.white.withValues(alpha: .18)
                : Colors.white.withValues(alpha: .05),
          ),
        ),
      ),
      child: child,
    );
  }

  Widget _headerCell(String text, double width, double height) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: ConsumptionColors.subtle,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _columnHeader(
    String top,
    String bottom,
    double width, {
    Color? color,
    Color? bg,
    bool faded = false,
    bool italic = false,
    bool accent = false,
  }) {
    final base = faded
        ? ConsumptionColors.muted
        : (color ?? ElectricityColors.text);
    // Moi dong 1 line, khong xuong dong; thieu cho thi co lai (scaleDown)
    // de khong tran chieu cao o tieu de.
    Widget line(String text, TextStyle style) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, softWrap: false, style: style),
    );

    return Container(
      width: width,
      height: _headHeight * 2,
      decoration: BoxDecoration(
        color: bg,
        // Cot noi bat (hom nay): vach cyan tren dau cot.
        border: accent
            ? const Border(
                top: BorderSide(color: ConsumptionColors.titleAccent, width: 2),
              )
            : null,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          line(
            top,
            TextStyle(
              color: base,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          if (bottom.isNotEmpty)
            line(
              bottom,
              accent
                  ? const TextStyle(
                      color: ConsumptionColors.titleAccent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    )
                  : TextStyle(
                      color: color ?? ConsumptionColors.muted,
                      fontSize: 9.5,
                    ),
            ),
        ],
      ),
    );
  }

  /// Ten dong + o mau cua series (dong tong khong co o mau).
  Widget _labelCell(_RowDef row) {
    return SizedBox(
      width: _descWidth,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              child: row.swatch == null
                  ? null
                  : Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: row.swatch,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
            ),
            Expanded(
              child: Text(
                row.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ElectricityColors.text,
                  fontSize: 12,
                  fontWeight: row.emphasis ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
            // Bang K$: don gia cua dong (khung gio), mo + can phai.
            if (!_isMwh && row.unitText.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                row.unitText,
                style: const TextStyle(
                  color: ConsumptionColors.muted,
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _textCell(
    String text,
    double width, {
    TextAlign align = TextAlign.center,
    Color? color,
    bool bold = false,
    bool italic = false,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          text,
          textAlign: align,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color ?? ElectricityColors.text,
            fontSize: 11,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }

  Widget _valueCell(
    double? value,
    double width, {
    Color? bg,
    bool bold = false,
    bool partial = false,
    int? decimals,
  }) {
    final missing = value == null;
    return Container(
      width: width,
      color: bg,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        ConsumptionFormat.fixed(
          value,
          decimals ?? ConsumptionFormat.value(unit),
        ),
        maxLines: 1,
        style: TextStyle(
          color: missing
              ? ConsumptionColors.muted
              : partial
              ? ConsumptionColors.partial
              : ElectricityColors.text,
          fontSize: 12,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          fontStyle: partial ? FontStyle.italic : FontStyle.normal,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _coverageCell(
    String text,
    double width, {
    bool bg = false,
    bool warn = false,
  }) {
    return Container(
      width: width,
      color: bg ? ConsumptionColors.monthBand : null,
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: warn ? ConsumptionColors.warning : ConsumptionColors.muted,
          fontSize: 10,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

/// ◀ ▶ cuon bang ngang ~80% khung nhin moi lan; mo nut khi da o dau / cuoi.
/// `[⦿ Today] ◀ ▶`: ve ngay hien tai / cuon trang trai, phai.
class _ScrollButtons extends StatelessWidget {
  final ScrollController controller;

  /// Cuon ve ngay hien tai (null: an nut, ky chua co du lieu).
  final VoidCallback? onLatest;

  /// `Today` (ky dang chay) hoac `Latest` (ky da qua).
  final String latestLabel;

  const _ScrollButtons({
    required this.controller,
    this.onLatest,
    this.latestLabel = 'Today',
  });

  static const String _hint =
      'Drag the table, use Shift + mouse wheel, or these buttons';

  void _page(int direction) {
    if (!controller.hasClients) return;
    final position = controller.position;
    final target =
        (position.pixels + direction * position.viewportDimension * .8).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final position = controller.hasClients ? controller.position : null;
        final ready =
            position != null &&
            position.hasPixels &&
            position.hasContentDimensions;
        final canBack = ready && position.pixels > position.minScrollExtent;
        final canForward =
            ready && position.pixels < position.maxScrollExtent - .5;

        Widget button(IconData icon, String tooltip, int direction, bool on) =>
            IconButton(
              tooltip: '$tooltip\n$_hint',
              onPressed: on ? () => _page(direction) : null,
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              color: ConsumptionColors.subtle,
              disabledColor: ElectricityColors.textFaint,
              icon: Icon(icon),
            );

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onLatest != null)
              TextButton.icon(
                onPressed: onLatest,
                style: TextButton.styleFrom(
                  foregroundColor: ConsumptionColors.titleAccent,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.my_location_rounded, size: 14),
                label: Text(latestLabel),
              ),
            button(Icons.chevron_left_rounded, 'Scroll left', -1, canBack),
            button(Icons.chevron_right_rounded, 'Scroll right', 1, canForward),
          ],
        );
      },
    );
  }
}
