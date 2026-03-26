import 'package:flutter/material.dart';

class UtilityDashboardTopBar extends StatelessWidget {
  final String title;

  final String selectedFac; // "KVH" | "Fac_A" | "Fac_B" | "Fac_C"
  final ValueChanged<String> onFacChanged;

  final DateTime selectedMonth; // dùng ngày 1 của tháng
  final ValueChanged<DateTime> onMonthChanged;

  const UtilityDashboardTopBar({
    super.key,
    this.title = 'Utility Control System',
    required this.selectedFac,
    required this.onFacChanged,
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF0A1230);
    final pillBg = Colors.white.withOpacity(0.08);
    final border = Colors.white.withOpacity(0.12);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          // left title pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
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
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.92),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // center fac buttons
          _FacToggleBar(selected: selectedFac, onChanged: onFacChanged),

          const Spacer(),

          // right month picker
          _MonthPickerPill(month: selectedMonth, onChanged: onMonthChanged),
        ],
      ),
    );
  }
}

class _FacToggleBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _FacToggleBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('KVH', 'KVH'),
      ('FAC_A', 'Fac_A'),
      ('FAC_B', 'Fac_B'),
      ('FAC_C', 'Fac_C'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final it in items) ...[
            _FacPill(
              label: it.$1,
              value: it.$2,
              selected: selected == it.$2,
              onTap: () => onChanged(it.$2),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _FacPill extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _FacPill({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selColor = const Color(0xFF00C2FF);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? selColor.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? selColor.withOpacity(0.55)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 16, color: selColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? selColor.withOpacity(0.95)
                    : Colors.white.withOpacity(0.78),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthPickerPill extends StatelessWidget {
  final DateTime month; // date(yyyy,mm,1)
  final ValueChanged<DateTime> onChanged;

  const _MonthPickerPill({required this.month, required this.onChanged});

  String _label(DateTime m) {
    // Feb 2026 format
    const months = [
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
    return '${months[m.month - 1]} ${m.year}';
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPickerDialog(initial: month),
    );
    if (picked != null) onChanged(DateTime(picked.year, picked.month, 1));
  }

  @override
  Widget build(BuildContext context) {
    final border = Colors.white.withOpacity(0.12);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: Colors.white.withOpacity(0.78),
            ),
            const SizedBox(width: 10),
            Text(
              'Month:',
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: Row(
                children: [
                  Text(
                    _label(month),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.expand_more,
                    size: 18,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ],
              ),
            ),
          ],
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
    const months = [
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

    return Dialog(
      backgroundColor: const Color(0xFF0A1230),
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
            // year header
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => year -= 1),
                  icon: Icon(
                    Icons.chevron_left,
                    color: Colors.white.withOpacity(0.85),
                  ),
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
                  onPressed: () => setState(() => year += 1),
                  icon: Icon(
                    Icons.chevron_right,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // months grid
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
                final m = i + 1;
                final selected = m == month;

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => month = m),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF00C2FF).withOpacity(0.18)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF00C2FF).withOpacity(0.55)
                            : Colors.white.withOpacity(0.10),
                      ),
                    ),
                    child: Text(
                      months[i],
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF00C2FF).withOpacity(0.95)
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
                      backgroundColor: const Color(
                        0xFF00C2FF,
                      ).withOpacity(0.22),
                      foregroundColor: const Color(0xFF00C2FF),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: const Color(0xFF00C2FF).withOpacity(0.55),
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
