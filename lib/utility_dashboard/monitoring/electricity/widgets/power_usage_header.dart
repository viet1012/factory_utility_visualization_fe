import 'package:flutter/material.dart';

import '../../../shared/charts/value_format.dart';
import '../controller/power_usage_controller.dart';
import '../model/power_usage.dart';
import 'electricity_style.dart';

/// "Power usage" + khoang thoi gian + toggle kWh | USD va Day | Week | Month.
class PowerUsageHeader extends StatelessWidget {
  final PowerUsageController controller;

  const PowerUsageHeader({super.key, required this.controller});

  String _subtitle() {
    final data = controller.data;
    if (data == null) return 'All factories';

    var current = formatPlantRange(data.from, data.to);
    if (controller.isViewingToday && current != kMissingValue) {
      final end = PlantTime.tryParse(data.to);
      final hour = end != null && !end.isMidnight
          ? end.hour
          : DateTime.now().hour;
      current = '$current to ${PlantTime.formatHour(hour)}';
    }
    final previous = formatPlantRange(data.prevFrom, data.prevTo);

    return 'All factories · $current against $previous';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Power usage',
                style: TextStyle(
                  color: ElectricityColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _subtitle(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ElectricityColors.textDim,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (controller.usdAvailable) ...[
          SegmentToggle<PowerUnit>(
            values: PowerUnit.values,
            selected: controller.unit,
            labelOf: (u) => u.label,
            onChanged: controller.setUnit,
          ),
          const SizedBox(width: 10),
        ],
        SegmentToggle<PowerPeriod>(
          values: PowerPeriod.values,
          selected: controller.period,
          labelOf: (p) => p.label,
          onChanged: controller.setPeriod,
        ),
      ],
    );
  }
}

class SegmentToggle<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  const SegmentToggle({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: ElectricityColors.track,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: ElectricityColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final value in values)
            _Segment(
              label: labelOf(value),
              selected: value == selected,
              onTap: () => onChanged(value),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF1F4E79) : Colors.transparent,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: selected ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? ElectricityColors.text
                  : ElectricityColors.textDim,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
