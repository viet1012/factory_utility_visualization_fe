import 'package:factory_utility_visualization/utility_dashboard/shared/widgets/scada_tab_button.dart';
import 'package:flutter/material.dart';

import '../../shared/formatters/month_formatter.dart';

class UtilityDashboardTopBar extends StatelessWidget {
  final String selectedFac;
  final ValueChanged<String> onFacChanged;
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;

  const UtilityDashboardTopBar({
    super.key,
    required this.selectedFac,
    required this.onFacChanged,
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _UtilityTopBarStyle.background,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          const _TitlePill(),
          const SizedBox(width: 14),
          _FacToggleBar(selected: selectedFac, onChanged: onFacChanged),
          const Spacer(),
          _MonthPickerPill(month: selectedMonth, onChanged: onMonthChanged),
        ],
      ),
    );
  }
}

class _UtilityTopBarStyle {
  static const background = Color(0xFF0A1230);
  static const selectedColor = Color(0xFF00C2FF);

  static BoxDecoration glassBox({
    required BorderRadius borderRadius,
    Color? color,
    Color? borderColor,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white.withOpacity(0.06),
      borderRadius: borderRadius,
      border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.10)),
      boxShadow: boxShadow ?? const [],
    );
  }
}

class _UtilityMonthLabel {
  static const months = [
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

  static String format(DateTime date) {
    return MonthFormatter.fromDateTime(date);
  }
}

class _TitlePill extends StatelessWidget {
  const _TitlePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _UtilityTopBarStyle.glassBox(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.08),
        borderColor: Colors.white.withOpacity(0.12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.factory_outlined,
            size: 18,
            color: Colors.cyanAccent.withOpacity(0.9),
          ),
          const SizedBox(width: 10),
          Text(
            'Utility Control System',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _FacilityTabItem {
  final String label;
  final String value;

  const _FacilityTabItem(this.label, this.value);
}

class _FacToggleBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  static const items = [
    _FacilityTabItem('KVH', 'KVH'),
    _FacilityTabItem('FAC_A', 'Fac_A'),
    _FacilityTabItem('FAC_B', 'Fac_B'),
    _FacilityTabItem('FAC_C', 'Fac_C'),
  ];

  const _FacToggleBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF050B18).withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _UtilityTopBarStyle.selectedColor.withOpacity(0.20),
        ),
        boxShadow: [
          BoxShadow(
            color: _UtilityTopBarStyle.selectedColor.withOpacity(0.10),
            blurRadius: 14,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            ScadaTabButton(
              label: items[i].label,
              selected: selected == items[i].value,
              onTap: () => onChanged(items[i].value),
            ),
            if (i < items.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _MonthPickerPill extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  const _MonthPickerPill({required this.month, required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPickerDialog(initial: month),
    );

    if (picked != null) {
      onChanged(DateTime(picked.year, picked.month, 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ScadaMonthButton(
      month: month,
      color: _UtilityTopBarStyle.selectedColor.withOpacity(.7),
      onTap: () => _pick(context),
    );
  }

}

class _ScadaMonthButton extends StatelessWidget {
  final DateTime month;
  final VoidCallback onTap;
  final Color color;

  const _ScadaMonthButton({
    required this.month,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: CustomPaint(
        painter: ScadaTabPainter(color: color, selected: true),
        child: Container(
          height: 36,
          constraints: const BoxConstraints(minWidth: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                _UtilityMonthLabel.format(month),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 16, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  final DateTime initial;

  const _MonthPickerDialog({required this.initial});

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int year;
  late int month;

  @override
  void initState() {
    super.initState();
    year = widget.initial.year;
    month = widget.initial.month;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _UtilityTopBarStyle.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _YearHeader(
              year: year,
              onPrev: () => setState(() => year -= 1),
              onNext: () => setState(() => year += 1),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              itemCount: 12,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              itemBuilder: (_, i) {
                final currentMonth = i + 1;
                final selected = currentMonth == month;

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => month = currentMonth),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? _UtilityTopBarStyle.selectedColor.withOpacity(0.18)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? _UtilityTopBarStyle.selectedColor.withOpacity(0.55)
                            : Colors.white.withOpacity(0.10),
                      ),
                    ),
                    child: Text(
                      _UtilityMonthLabel.months[i],
                      style: TextStyle(
                        color: selected
                            ? _UtilityTopBarStyle.selectedColor.withOpacity(0.95)
                            : Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white.withOpacity(0.75)),
                    ),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _UtilityTopBarStyle.selectedColor
                          .withOpacity(0.22),
                      foregroundColor: _UtilityTopBarStyle.selectedColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _UtilityTopBarStyle.selectedColor.withOpacity(
                            0.55,
                          ),
                        ),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context, DateTime(year, month, 1));
                    },
                    child: const Text('Apply'),
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

class _YearHeader extends StatelessWidget {
  final int year;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _YearHeader({
    required this.year,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: Icon(Icons.chevron_left, color: Colors.white.withOpacity(0.85)),
        ),
        Expanded(
          child: Center(
            child: Text(
              '$year',
              style: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: Icon(
            Icons.chevron_right,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ],
    );
  }
}
