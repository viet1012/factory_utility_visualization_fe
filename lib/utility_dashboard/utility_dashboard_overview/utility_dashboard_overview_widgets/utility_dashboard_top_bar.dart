import 'package:flutter/material.dart';

class UtilityDashboardTopBar extends StatelessWidget {
  final String title;
  final String selectedFac;
  final ValueChanged<String> onFacChanged;
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;
  final bool hasAlarm;
  final Animation<double>? blinkAnimation;

  const UtilityDashboardTopBar({
    super.key,
    this.title = 'Utility Control System',
    required this.selectedFac,
    required this.onFacChanged,
    required this.selectedMonth,
    required this.onMonthChanged,
    required this.hasAlarm,
    this.blinkAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final animation = blinkAnimation ?? const AlwaysStoppedAnimation<double>(0);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;

        final bgColor = hasAlarm
            ? Color.lerp(
                UtilityTopBarStyle.background,
                Colors.red.withOpacity(0.6), // 🔥 màu alarm
                t,
              )
            : UtilityTopBarStyle.background;

        return Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bgColor, // ✅ đã animate
            border: Border(
              bottom: BorderSide(
                color: hasAlarm
                    ? Colors.redAccent.withOpacity(0.7)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          child: Row(
            children: [
              _AlarmTitlePill(
                title: title,
                hasAlarm: hasAlarm,
                blinkAnimation: blinkAnimation,
              ),
              const SizedBox(width: 14),
              _FacToggleBar(selected: selectedFac, onChanged: onFacChanged),
              const Spacer(),
              _MonthPickerPill(month: selectedMonth, onChanged: onMonthChanged),
            ],
          ),
        );
      },
    );
  }
}

class UtilityTopBarStyle {
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

class UtilityMonthLabel {
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
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _AlarmTitlePill extends StatelessWidget {
  final String title;
  final bool hasAlarm;
  final Animation<double>? blinkAnimation;

  const _AlarmTitlePill({
    required this.title,
    required this.hasAlarm,
    required this.blinkAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final animation = blinkAnimation ?? const AlwaysStoppedAnimation<double>(0);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final bgOpacity = hasAlarm ? (0.18 + t * 0.35) : 0.08;
        final glowOpacity = hasAlarm ? (0.25 + t * 0.55) : 0.25;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: UtilityTopBarStyle.glassBox(
            borderRadius: BorderRadius.circular(12),
            color: hasAlarm
                ? Colors.red.withOpacity(bgOpacity)
                : Colors.white.withOpacity(0.08),
            borderColor: hasAlarm
                ? Colors.redAccent.withOpacity(0.95)
                : Colors.white.withOpacity(0.12),
            boxShadow: hasAlarm
                ? [
                    BoxShadow(
                      color: Colors.red.withOpacity(glowOpacity),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: _AlarmSweepText(
            enabled: hasAlarm,
            progress: t,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.factory_outlined,
                  size: 18,
                  color: hasAlarm
                      ? Colors.white
                      : Colors.cyanAccent.withOpacity(0.9),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AlarmSweepText extends StatelessWidget {
  final bool enabled;
  final double progress;
  final Widget child;

  const _AlarmSweepText({
    required this.enabled,
    required this.progress,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        final h = bounds.height;
        final sweepY = (-0.6 * h) + (progress * 2.2 * h);

        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Colors.white,
            Color(0xFFFFE082),
            Colors.redAccent,
            Colors.white,
          ],
          stops: [
            ((sweepY - 18) / h).clamp(0.0, 1.0),
            ((sweepY - 6) / h).clamp(0.0, 1.0),
            ((sweepY + 6) / h).clamp(0.0, 1.0),
            ((sweepY + 18) / h).clamp(0.0, 1.0),
          ],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}

class FacilityTabItem {
  final String label;
  final String value;

  const FacilityTabItem(this.label, this.value);
}

class _FacToggleBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  static const items = [
    FacilityTabItem('KVH', 'KVH'),
    FacilityTabItem('FAC_A', 'Fac_A'),
    FacilityTabItem('FAC_B', 'Fac_B'),
    FacilityTabItem('FAC_C', 'Fac_C'),
  ];

  const _FacToggleBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: UtilityTopBarStyle.glassBox(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _FacPill(
              item: items[i],
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

class _FacPill extends StatelessWidget {
  final FacilityTabItem item;
  final bool selected;
  final VoidCallback onTap;

  const _FacPill({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selColor = UtilityTopBarStyle.selectedColor;

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
              item.label,
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: UtilityTopBarStyle.glassBox(
          borderRadius: BorderRadius.circular(12),
          borderColor: Colors.white.withOpacity(0.12),
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
              decoration: UtilityTopBarStyle.glassBox(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withOpacity(0.08),
              ),
              child: Row(
                children: [
                  Text(
                    UtilityMonthLabel.format(month),
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
    return Dialog(
      backgroundColor: UtilityTopBarStyle.background,
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
                          ? UtilityTopBarStyle.selectedColor.withOpacity(0.18)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? UtilityTopBarStyle.selectedColor.withOpacity(0.55)
                            : Colors.white.withOpacity(0.10),
                      ),
                    ),
                    child: Text(
                      UtilityMonthLabel.months[i],
                      style: TextStyle(
                        color: selected
                            ? UtilityTopBarStyle.selectedColor.withOpacity(0.95)
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
                      backgroundColor: UtilityTopBarStyle.selectedColor
                          .withOpacity(0.22),
                      foregroundColor: UtilityTopBarStyle.selectedColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: UtilityTopBarStyle.selectedColor.withOpacity(
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
