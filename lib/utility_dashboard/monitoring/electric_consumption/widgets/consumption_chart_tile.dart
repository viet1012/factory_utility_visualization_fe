import 'package:flutter/material.dart';

import '../../electricity/widgets/electricity_style.dart';
import '../../electricity/widgets/power_usage_header.dart' show SegmentToggle;
import '../model/electric_consumption.dart';
import 'consumption_chart.dart';

/// Ten ngan cua scope cho tieu de / nut chon: `TTL KVH: A&B + C` -> `TTL KVH`.
String scopeShortName(ConsumptionScope scope) {
  final name = scope.name.split(':').first.trim();
  return name.isEmpty ? scope.code : name;
}

String _unitTitle(ConsumptionUnit unit) =>
    unit == ConsumptionUnit.mwh ? 'Consumption' : 'Amount';

/// Mot chart kem tieu de `Consumption · MWh` va nut phong to.
///
/// [title] null: chi ghi `Consumption · MWh` (dung trong card cua scope);
/// co [title]: `TTL KVH · Consumption · MWh` (luoi Charts).
class ConsumptionChartTile extends StatelessWidget {
  final ElectricConsumptionResponse data;
  final ConsumptionScope scope;
  final ConsumptionUnit unit;
  final String? title;

  /// Chieu cao vung chart; null: chiem het cho con lai (trong Expanded).
  final double? chartHeight;

  /// Toggle "Values" dung chung (controller.showValues / setShowValues).
  final bool showValues;
  final ValueChanged<bool>? onShowValuesChanged;

  const ConsumptionChartTile({
    super.key,
    required this.data,
    required this.scope,
    required this.unit,
    this.title,
    this.chartHeight,
    this.showValues = false,
    this.onShowValuesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final chart = ConsumptionChart(
      scope: scope,
      unit: unit,
      tariffAvailable: data.tariffAvailable,
      partialDate: data.partialDate,
      partialUntil: data.partialUntil,
      billLabel: billLabelOf(data),
      minCoveragePct: data.minCoveragePct,
      showValues: showValues,
      onShowValuesChanged: onShowValuesChanged,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: chartHeight == null ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Row(
          children: [
            // Vach nhan cyan: tieu de chart noi bat tren nen toi.
            Container(
              width: 3,
              height: 14,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: ConsumptionColors.titleAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    if (title != null)
                      TextSpan(
                        text: '$title  ·  ',
                        style: const TextStyle(
                          color: ConsumptionColors.titleAccent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    TextSpan(
                      text: _unitTitle(unit),
                      style: const TextStyle(
                        color: ElectricityColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: '  ·  ${unit.label}',
                      style: const TextStyle(
                        color: ConsumptionColors.subtle,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            IconButton(
              tooltip: 'Expand chart',
              onPressed: () => showConsumptionChartDialog(
                context,
                data: data,
                scope: scope,
                unit: unit,
              ),
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              color: ConsumptionColors.subtle,
              icon: const Icon(Icons.open_in_full_rounded),
            ),
          ],
        ),
        if (chartHeight == null)
          Expanded(child: chart)
        else
          SizedBox(height: chartHeight, child: chart),
      ],
    );
  }
}

String billLabelOf(ElectricConsumptionResponse data) =>
    data.billPeriod.label.isEmpty ? data.month : data.billPeriod.label;

/// Xem chart lon (gan toan man hinh). Doi duoc scope (TTL KVH / Fac A&B /
/// Fac C) va MWh | K$ ngay trong hop thoai; Esc / nut X de dong.
Future<void> showConsumptionChartDialog(
  BuildContext context, {
  required ElectricConsumptionResponse data,
  required ConsumptionScope scope,
  required ConsumptionUnit unit,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .7),
    builder: (_) => _ChartDialog(data: data, scope: scope, unit: unit),
  );
}

class _ChartDialog extends StatefulWidget {
  final ElectricConsumptionResponse data;
  final ConsumptionScope scope;
  final ConsumptionUnit unit;

  const _ChartDialog({
    required this.data,
    required this.scope,
    required this.unit,
  });

  @override
  State<_ChartDialog> createState() => _ChartDialogState();
}

class _ChartDialogState extends State<_ChartDialog> {
  late String _scopeCode = widget.scope.code;
  late ConsumptionUnit _unit = widget.unit;

  /// Chart phong to: mac dinh ghi so tung doan (rieng, khong luu controller).
  bool _showValues = true;

  ConsumptionScope get _scope => widget.data.scopes.firstWhere(
    (s) => s.code == _scopeCode,
    orElse: () => widget.scope,
  );

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final scope = _scope;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: ElectricityColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ElectricityColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${scope.name}  ·  ${_unitTitle(_unit)} [${_unit.label}]',
                      style: const TextStyle(
                        color: ElectricityColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bill period ${billLabelOf(data)}',
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
                    if (data.scopes.length > 1)
                      SegmentToggle<String>(
                        values: [for (final s in data.scopes) s.code],
                        selected: _scopeCode,
                        labelOf: (code) => scopeShortName(
                          data.scopes.firstWhere((s) => s.code == code),
                        ),
                        onChanged: (code) => setState(() => _scopeCode = code),
                      ),
                    const SizedBox(width: 10),
                    SegmentToggle<ConsumptionUnit>(
                      values: ConsumptionUnit.values,
                      selected: _unit,
                      labelOf: (u) => u.label,
                      onChanged: (u) => setState(() => _unit = u),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Close (Esc)',
                      onPressed: () => Navigator.of(context).pop(),
                      color: ConsumptionColors.subtle,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ConsumptionChart(
                // Key theo scope + unit: doi lua chon thi ve lai tu dau.
                key: ValueKey('${scope.code}-${_unit.name}'),
                scope: scope,
                unit: _unit,
                tariffAvailable: data.tariffAvailable,
                partialDate: data.partialDate,
                partialUntil: data.partialUntil,
                billLabel: billLabelOf(data),
                minCoveragePct: data.minCoveragePct,
                showValues: _showValues,
                onShowValuesChanged: (v) => setState(() => _showValues = v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
