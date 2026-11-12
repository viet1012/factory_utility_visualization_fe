import 'package:flutter/material.dart';

import '../../shared/charts/value_format.dart';
import '../../shared/formatters/period_basis_formatter.dart';
import '../../shared/widgets/period_basis_note.dart';
import '../electricity/widgets/electricity_style.dart';
import '../electricity/widgets/power_usage_header.dart' show SegmentToggle;
import 'controller/electric_consumption_controller.dart';
import 'model/electric_consumption.dart';
import 'widgets/consumption_chart.dart';
import 'widgets/consumption_chart_tile.dart';
import 'widgets/consumption_detail_table.dart';

/// MONITORING › Elec. consumption: ban web cua sheet "FY26-Sep + Solar1"
/// (ELECTRIC CONSUMPTION DAILY MONITORING). Moi scope (TTL KVH, Fac A&B,
/// Fac C) mot hang gom chart [MWh] va [K$].
class ElectricConsumptionScreen extends StatelessWidget {
  final ElectricConsumptionController controller;

  const ElectricConsumptionScreen({super.key, required this.controller});

  static const double _gap = 10;

  /// Du rong thi MWh | K$ dat canh nhau nhu Excel.
  static const double _sideBySideBreakpoint = 1200;
  static const double _chartHeight = 320;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final data = controller.data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(controller: controller),
            const SizedBox(height: 6),
            SizedBox(
              height: 3,
              child: controller.loading && data != null
                  ? const LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Colors.transparent,
                      color: ElectricityColors.facB,
                    )
                  : null,
            ),
            if (data != null && controller.error != null)
              _InlineError(
                message: controller.error!,
                onRetry: controller.retry,
              ),
            const SizedBox(height: 6),
            Expanded(child: _body(data)),
          ],
        );
      },
    );
  }

  Widget _body(ElectricConsumptionResponse? data) {
    if (data == null) {
      if (controller.error != null && !controller.loading) {
        return _ErrorView(
          message: controller.error!,
          onRetry: controller.retry,
        );
      }
      return const _Skeleton();
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: controller.loading ? .5 : 1,
      child: IgnorePointer(
        ignoring: controller.loading,
        child: LayoutBuilder(
          builder: (context, box) {
            final sideBySide = box.maxWidth >= _sideBySideBreakpoint;

            if (controller.view == ConsumptionView.charts) {
              return _ChartsGrid(data: data, box: box);
            }

            return ListView(
              children: [
                _TariffBar(data: data),
                if (_DataNotes.hasNotes(data)) ...[
                  const SizedBox(height: 6),
                  _DataNotes(data: data),
                ],
                const SizedBox(height: _gap),
                if (data.scopes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'No scopes returned for this bill period',
                        style: TextStyle(color: ConsumptionColors.subtle),
                      ),
                    ),
                  ),
                for (final scope in data.scopes) ...[
                  _ScopeSection(
                    data: data,
                    scope: scope,
                    billDays: data.billPeriod.days,
                    tariffAvailable: data.tariffAvailable,
                    partialDate: data.partialDate,
                    partialUntil: data.partialUntil,
                    sideBySide: sideBySide,
                    chartHeight: _chartHeight,
                    showDetail: controller.showDetail,
                    unitPrices: data.unitPrices,
                    billLabel: data.billPeriod.label.isEmpty
                        ? data.month
                        : data.billPeriod.label,
                  ),
                  const SizedBox(height: _gap),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// HEADER
// ============================================================

class _Header extends StatelessWidget {
  final ElectricConsumptionController controller;

  const _Header({required this.controller});

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _subtitle() {
    final data = controller.data;
    if (data == null) return 'F2 · TTL KVH, Fac A&B, Fac C';

    final period = data.billPeriod.label.isEmpty
        ? data.month
        : data.billPeriod.label;
    return 'F2 · Bill period $period · ${_dataUntilText(data)}';
  }

  /// `dataUntil` la moc ket thuc: 00:00 duoc coi la het ngay truoc.
  static String _dataUntilText(ElectricConsumptionResponse data) {
    final until = PlantTime.tryParse(data.dataUntil);
    final from = PlantTime.tryParse(data.billPeriod.from);
    if (until == null) return 'no data yet';
    if (from != null && !until.date.isAfter(from.date) && until.isMidnight) {
      return 'no data yet';
    }
    if (until.isMidnight) {
      final last = until.date.subtract(const Duration(days: 1));
      return 'data through ${PlantTime.formatDate(last)}';
    }
    return 'data until ${PlantTime.formatDate(until.date)} '
        '${PlantTime.formatHour(until.hour)}';
  }

  @override
  Widget build(BuildContext context) {
    final month = controller.month;
    final monthText = '${_months[month.month - 1]} ${month.year}';

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Electric consumption daily monitoring',
              style: TextStyle(
                color: ElectricityColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            // Subtitle giu nguyen + icon ⓘ: ky hoa don khac thang duong lich
            // cua SUMMARY / Solar.
            PeriodBasisNote(
              text: _subtitle(),
              tooltip: PeriodBasisFormatter.billPeriodHint,
              style: const TextStyle(
                color: ConsumptionColors.subtle,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentToggle<ConsumptionView>(
              values: ConsumptionView.values,
              selected: controller.view,
              labelOf: (v) => v.label,
              onChanged: controller.setView,
            ),
            const SizedBox(width: 8),
            // Bang chi tiet chi co o Overview.
            if (controller.view == ConsumptionView.overview) ...[
              _DetailToggle(
                selected: controller.showDetail,
                onTap: controller.toggleDetail,
              ),
              const SizedBox(width: 12),
            ] else
              const SizedBox(width: 4),
            const Text(
              'History',
              style: TextStyle(color: ConsumptionColors.subtle, fontSize: 12),
            ),
            const SizedBox(width: 6),
            SegmentToggle<int>(
              values: ElectricConsumptionController.historyOptions,
              selected: controller.months,
              labelOf: (m) => '${m}M',
              onChanged: controller.setMonths,
            ),
            const SizedBox(width: 12),
            _MonthNavigator(
              text: monthText,
              onPrev: () => controller.shiftMonth(-1),
              onNext: controller.canGoNext
                  ? () => controller.shiftMonth(1)
                  : null,
            ),
            if (!controller.isViewingCurrent) ...[
              const SizedBox(width: 6),
              TextButton(
                onPressed: controller.goToCurrent,
                child: const Text('Current'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Bat / tat bang chi tiet (nhu bang so duoi chart cua Excel).
class _DetailToggle extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _DetailToggle({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? ElectricityColors.text : ConsumptionColors.subtle;
    return Tooltip(
      message: selected ? 'Hide detail tables' : 'Show detail tables',
      child: Material(
        color: selected ? const Color(0xFF1F4E79) : ElectricityColors.track,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
          side: const BorderSide(color: ElectricityColors.cardBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.table_chart_outlined, size: 15, color: color),
                const SizedBox(width: 6),
                Text(
                  'Detail',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthNavigator extends StatelessWidget {
  final String text;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  const _MonthNavigator({
    required this.text,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    Widget arrow(IconData icon, VoidCallback? onTap, String tooltip) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        color: ElectricityColors.text,
        // Nut bi khoa giu mau mo de doc ra la khong bam duoc.
        disabledColor: ElectricityColors.textFaint,
        icon: Icon(icon),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: ElectricityColors.track,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: ElectricityColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          arrow(Icons.chevron_left, onPrev, 'Previous bill period'),
          SizedBox(
            width: 76,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ElectricityColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          arrow(Icons.chevron_right, onNext, 'Next bill period'),
        ],
      ),
    );
  }
}

// ============================================================
// TARIFF
// ============================================================

class _TariffBar extends StatelessWidget {
  final ElectricConsumptionResponse data;

  const _TariffBar({required this.data});

  @override
  Widget build(BuildContext context) {
    final prices = data.unitPrices;

    if (!data.tariffAvailable || prices == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ElectricityColors.up.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ElectricityColors.up.withValues(alpha: .4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: ElectricityColors.up),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tariff (F2_Utility_Cost_Master) not available for this bill '
                'period: time-of-use split and K\$ are hidden, totals only.',
                style: TextStyle(color: ElectricityColors.up, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ElectricityColors.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ElectricityColors.cardBorder),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Unit price [\$/kWh]',
            style: TextStyle(
              color: ConsumptionColors.subtle,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          _PriceGroup(
            title: 'Grid',
            normal: prices.gridNormal,
            highPeak: prices.gridHighPeak,
            lowPeak: prices.gridLowPeak,
          ),
          _PriceGroup(
            title: 'Solar',
            normal: prices.solarNormal,
            highPeak: prices.solarHighPeak,
            lowPeak: prices.solarLowPeak,
          ),
        ],
      ),
    );
  }
}

class _PriceGroup extends StatelessWidget {
  final String title;
  final double? normal;
  final double? highPeak;
  final double? lowPeak;

  const _PriceGroup({
    required this.title,
    required this.normal,
    required this.highPeak,
    required this.lowPeak,
  });

  @override
  Widget build(BuildContext context) {
    Widget item(String label, Color color, double? value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, color: color),
          const SizedBox(width: 5),
          Text(
            '$label ',
            style: const TextStyle(
              color: ConsumptionColors.subtle,
              fontSize: 12,
            ),
          ),
          Text(
            formatValue(value, decimals: 4),
            style: const TextStyle(
              color: ElectricityColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$title:',
          style: const TextStyle(
            color: ElectricityColors.text,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        item('Normal', ConsumptionColors.normal, normal),
        const SizedBox(width: 12),
        item('High-peak', ConsumptionColors.highPeak, highPeak),
        const SizedBox(width: 12),
        item('Low-peak', ConsumptionColors.lowPeak, lowPeak),
      ],
    );
  }
}

// ============================================================
// SCOPE (TTL KVH / Fac A&B / Fac C)
// ============================================================

/// Che do Charts: chi chart, moi scope mot hang `MWh | K$` nhu vung chart
/// cua Excel. Du cao thi vua khit man hinh; khong du thi cuon (moi o toi
/// thieu [_minTile]). Moi chart co nut ⤢ de xem lon.
class _ChartsGrid extends StatelessWidget {
  final ElectricConsumptionResponse data;
  final BoxConstraints box;

  const _ChartsGrid({required this.data, required this.box});

  static const double _gap = 10;
  static const double _minTile = 260;
  static const double _twoColumnBreakpoint = 1000;

  @override
  Widget build(BuildContext context) {
    final scopes = data.scopes;
    if (scopes.isEmpty) {
      return const Center(
        child: Text(
          'No scopes returned for this bill period',
          style: TextStyle(color: ConsumptionColors.subtle),
        ),
      );
    }

    final twoColumns = box.maxWidth >= _twoColumnBreakpoint;
    final rows = twoColumns ? scopes.length : scopes.length * 2;
    final fit = (box.maxHeight - _gap * (rows - 1)) / rows;
    final tileHeight = fit > _minTile ? fit : _minTile;

    Widget tile(ConsumptionScope scope, ConsumptionUnit unit) => Container(
      height: tileHeight,
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 8),
      decoration: BoxDecoration(
        color: ElectricityColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ElectricityColors.cardBorder),
      ),
      child: ConsumptionChartTile(
        data: data,
        scope: scope,
        unit: unit,
        title: scopeShortName(scope),
      ),
    );

    return ListView(
      children: [
        for (final (index, scope) in scopes.indexed) ...[
          if (index > 0) const SizedBox(height: _gap),
          if (twoColumns)
            Row(
              children: [
                Expanded(child: tile(scope, ConsumptionUnit.mwh)),
                const SizedBox(width: _gap),
                Expanded(child: tile(scope, ConsumptionUnit.kusd)),
              ],
            )
          else ...[
            tile(scope, ConsumptionUnit.mwh),
            const SizedBox(height: _gap),
            tile(scope, ConsumptionUnit.kusd),
          ],
        ],
      ],
    );
  }
}

class _ScopeSection extends StatelessWidget {
  final ElectricConsumptionResponse data;
  final ConsumptionScope scope;
  final int billDays;
  final bool tariffAvailable;
  final String? partialDate;
  final String? partialUntil;
  final bool sideBySide;
  final double chartHeight;
  final bool showDetail;
  final UnitPrices? unitPrices;
  final String billLabel;

  const _ScopeSection({
    required this.data,
    required this.scope,
    required this.billDays,
    required this.tariffAvailable,
    required this.partialDate,
    required this.partialUntil,
    required this.sideBySide,
    required this.chartHeight,
    required this.showDetail,
    required this.unitPrices,
    required this.billLabel,
  });

  /// Bang so lieu nhu Excel: MWh roi K$.
  Widget _detail() {
    Widget table(ConsumptionUnit unit) => ConsumptionDetailTable(
      scope: scope,
      unit: unit,
      tariffAvailable: tariffAvailable,
      unitPrices: unitPrices,
      billLabel: billLabel,
      partialDate: partialDate,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PanelTitle(title: 'Detail', subtitle: 'same rows as the Excel'),
        const SizedBox(height: 8),
        table(ConsumptionUnit.mwh),
        const SizedBox(height: 14),
        table(ConsumptionUnit.kusd),
      ],
    );
  }

  /// `Consumption · MWh  ⤢` + chart; ⤢ mo chart lon.
  Widget _chart(ConsumptionUnit unit) {
    return ConsumptionChartTile(
      data: data,
      scope: scope,
      unit: unit,
      chartHeight: chartHeight,
    );
  }

  /// `19 full days + 4 partial (today until 10:00) / 31 days`.
  String _progressText() {
    final full = scope.fullDays(partialDate).length;
    final partialDays = scope.partialDays(partialDate);
    final todayPartial =
        partialUntil != null && partialDays.any((p) => p.key == partialDate);
    final partial = switch (partialDays.length) {
      0 => '',
      1 when todayPartial => ' + today until $partialUntil',
      final n when todayPartial => ' + $n partial (today until $partialUntil)',
      final n => ' + $n partial',
    };
    return '$full full days$partial / $billDays days';
  }

  /// Ky truoc backend tra 0 (chua co du lieu).
  int get _noDataMonths => scope.monthly.where((p) => p.isNoData).length;

  @override
  Widget build(BuildContext context) {
    final mwh = _chart(ConsumptionUnit.mwh);
    final kusd = _chart(ConsumptionUnit.kusd);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: ElectricityColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ElectricityColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Ten scope: chu cyan dam, de nhan ra tung khoi KVH / Fac.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: ConsumptionColors.titleAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    scope.name,
                    style: const TextStyle(
                      color: ConsumptionColors.titleAccent,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .2,
                    ),
                  ),
                ],
              ),
              _Pill(text: _progressText()),
              if (_noDataMonths > 0)
                Text(
                  '$_noDataMonths of ${scope.monthly.length} past periods '
                  'without data (hidden)',
                  style: const TextStyle(
                    color: ConsumptionColors.muted,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _KpiRow(
            scope: scope,
            partialDate: partialDate,
            tariffAvailable: tariffAvailable,
          ),
          const SizedBox(height: 16),
          if (sideBySide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: mwh),
                const SizedBox(width: 20),
                Expanded(child: kusd),
              ],
            )
          else ...[
            mwh,
            const SizedBox(height: 16),
            kusd,
          ],
          if (showDetail) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: ElectricityColors.cardBorder),
            const SizedBox(height: 12),
            _detail(),
          ],
        ],
      ),
    );
  }
}

/// "Consumption · MWh".
class _PanelTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PanelTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: title,
            style: const TextStyle(
              color: ElectricityColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: '  ·  $subtitle',
            style: const TextStyle(color: ConsumptionColors.subtle),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 14),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;

  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: ElectricityColors.track,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ElectricityColors.cardBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(color: ConsumptionColors.subtle, fontSize: 11),
      ),
    );
  }
}

/// Ghi chu nguon du lieu: lich su tu ngay nao, meter bi loai, nguong ngay du.
class _DataNotes extends StatelessWidget {
  final ElectricConsumptionResponse data;

  const _DataNotes({required this.data});

  static bool hasNotes(ElectricConsumptionResponse data) =>
      data.historyStartDate != null ||
      data.excludedMeters.isNotEmpty ||
      data.minCoveragePct != null;

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const TextStyle _style = TextStyle(
    color: ConsumptionColors.muted,
    fontSize: 11,
  );

  /// Tooltip cua "N meter(s) excluded": meter nao, va luong dien bi loai
  /// theo tung ky (lay tu scope tong KVH) de biet anh huong toi so lieu.
  String _excludedTooltip() {
    final total = data.scopes.firstWhere(
      (s) => s.includesSolar,
      orElse: () => data.scopes.first,
    );

    final perPeriod = <String>[
      for (final p in total.monthly)
        if ((p.excludedMwh ?? 0) > 0)
          '${_monthName(p.key)} ${ConsumptionFormat.fixed(p.excludedMwh, 1)}',
    ];
    var thisPeriod = 0.0;
    for (final p in total.daily) {
      thisPeriod += p.excludedMwh ?? 0;
    }

    return [
      'Left out of every total (unreliable readings):',
      '  ${data.excludedMeters.join(', ')}',
      '',
      'Energy removed by data checks (${scopeShortName(total)}, MWh):',
      if (perPeriod.isNotEmpty) '  ${perPeriod.join('  ·  ')}',
      '  This period: ${thisPeriod > 0 ? ConsumptionFormat.fixed(thisPeriod, 1) : 'none'}',
    ].join('\n');
  }

  static String _monthName(String key) {
    final month = parseBillMonth(key);
    return month == null ? key : _monthNames[month.month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final start = PlantTime.tryParse(data.historyStartDate);
    final notes = [
      if (start != null)
        'History from ${PlantTime.formatDate(start.date)}, ${start.year}',
      if (data.minCoveragePct != null)
        'Full day = coverage ≥ ${formatValue(data.minCoveragePct, decimals: 0)}%',
    ];
    final excluded = data.excludedMeters.length;

    return Row(
      children: [
        const Icon(
          Icons.info_outline,
          size: 14,
          color: ConsumptionColors.muted,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            notes.join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _style,
          ),
        ),
        // Meter bi loai: chi ghi so luong; re chuot xem meter nao va bi loai
        // bao nhieu MWh moi ky (co y nghia thay vi chi liet ke ma meter).
        if (excluded > 0 && data.scopes.isNotEmpty) ...[
          if (notes.isNotEmpty) const Text('  ·  ', style: _style),
          Tooltip(
            message: _excludedTooltip(),
            waitDuration: const Duration(milliseconds: 200),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$excluded meter${excluded == 1 ? '' : 's'} excluded',
                  style: _style.copyWith(
                    color: ConsumptionColors.subtle,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: ConsumptionColors.muted,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.help_outline_rounded,
                  size: 13,
                  color: ConsumptionColors.muted,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Hang chi so cua scope: tong ky den nay, trung binh / ngay (so voi ky
/// truoc), chi phi / ngay, ty trong gio cao diem va solar.
class _KpiRow extends StatelessWidget {
  final ConsumptionScope scope;
  final String? partialDate;
  final bool tariffAvailable;

  const _KpiRow({
    required this.scope,
    required this.partialDate,
    required this.tariffAvailable,
  });

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Ky truoc gan nhat co du lieu (de so sanh trung binh / ngay).
  ConsumptionPoint? get _previous {
    for (final p in scope.monthly.reversed) {
      if (p.hasData) return p;
    }
    return null;
  }

  static double? _changePct(double? now, double? before) {
    if (now == null || before == null || before == 0) return null;
    return (now - before) / before * 100;
  }

  static double? _share(double? part, double? whole) {
    if (part == null || whole == null || whole == 0) return null;
    return part / whole * 100;
  }

  @override
  Widget build(BuildContext context) {
    final totalMwh = scope.dailyTotalMwh;
    final avgMwh = scope.fullDayAverage(ConsumptionUnit.mwh, partialDate);
    final avgKusd = scope.fullDayAverage(ConsumptionUnit.kusd, partialDate);

    final previous = _previous;
    final prevMonth = parseBillMonth(previous?.key);
    final vsText = prevMonth == null
        ? null
        : 'vs ${_monthNames[prevMonth.month - 1]} avg';
    final prevMwh = scope.headlineOf(previous?.valuesOf(ConsumptionUnit.mwh));
    final prevKusd = scope.headlineOf(previous?.valuesOf(ConsumptionUnit.kusd));

    Widget delta(double? now, double? before) {
      final pct = _changePct(now, before);
      if (pct == null || vsText == null) return const SizedBox.shrink();
      return ChangeBadge(changePct: pct, suffix: vsText);
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _KpiTile(
          label: 'Period to date',
          value: ConsumptionFormat.fixed(
            scope.headlineOf(totalMwh),
            ConsumptionFormat.total(ConsumptionUnit.mwh),
          ),
          unit: 'MWh',
          footer: tariffAvailable
              ? Text(
                  '${ConsumptionFormat.fixed(scope.headlineOf(scope.dailyTotalKusd), ConsumptionFormat.total(ConsumptionUnit.kusd))} K\$',
                  style: _KpiTile.footerStyle,
                )
              : null,
        ),
        _KpiTile(
          label: 'Avg / day',
          tooltip: 'Average over complete days only',
          value: ConsumptionFormat.fixed(
            avgMwh,
            ConsumptionFormat.value(ConsumptionUnit.mwh),
          ),
          unit: 'MWh',
          footer: delta(avgMwh, prevMwh),
        ),
        if (tariffAvailable)
          _KpiTile(
            label: 'Cost / day',
            tooltip: 'Average over complete days only',
            value: ConsumptionFormat.fixed(
              avgKusd,
              ConsumptionFormat.value(ConsumptionUnit.kusd),
            ),
            unit: 'K\$',
            footer: delta(avgKusd, prevKusd),
          ),
        if (tariffAvailable)
          _KpiTile(
            label: 'High-peak share',
            tooltip: 'High-peak energy / grid energy, period to date',
            value: formatValue(
              _share(totalMwh?.highPeak, totalMwh?.totalElectricity),
              decimals: 0,
            ),
            unit: '%',
            footer: const Text('of grid energy', style: _KpiTile.footerStyle),
          ),
        if (scope.includesSolar)
          _KpiTile(
            label: 'Solar share',
            tooltip: 'Solar energy / total energy, period to date',
            value: formatValue(
              _share(totalMwh?.solar, totalMwh?.total),
              decimals: 0,
            ),
            unit: '%',
            footer: const Text('of total energy', style: _KpiTile.footerStyle),
          ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Widget? footer;
  final String? tooltip;

  const _KpiTile({
    required this.label,
    required this.value,
    required this.unit,
    this.footer,
    this.tooltip,
  });

  static const TextStyle footerStyle = TextStyle(
    color: ConsumptionColors.subtle,
    fontSize: 11,
  );

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: ElectricityColors.track.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ElectricityColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: ConsumptionColors.subtle,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: ElectricityColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    color: ConsumptionColors.subtle,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (footer != null) ...[const SizedBox(height: 4), footer!],
        ],
      ),
    );

    return tooltip == null ? tile : Tooltip(message: tooltip!, child: tile);
  }
}

// ============================================================
// STATES
// ============================================================

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        SkeletonBox(height: 36),
        SizedBox(height: 10),
        SkeletonBox(height: 340),
        SizedBox(height: 10),
        SkeletonBox(height: 340),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            color: ElectricityColors.up,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ElectricityColors.text, fontSize: 13),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: ElectricityColors.up,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ElectricityColors.up, fontSize: 12),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
