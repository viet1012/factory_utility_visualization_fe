import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../utility_dashboard_common/chart_theme.dart';
import '../../models/energy_monthly_summary.dart';

// ============================================================
// FORMATTER
// ============================================================

class MonthlyMetricFormat {
  const MonthlyMetricFormat._();

  static final NumberFormat _integer = NumberFormat('#,##0');

  static final NumberFormat _decimal = NumberFormat('#,##0.0');

  static final NumberFormat _money = NumberFormat('#,##0');

  static String utility(EnergyMonthlySummary item, double? value) {
    if (value == null) {
      return '--';
    }

    if (item.isElectricity) {
      return _integer.format(value);
    }

    return _decimal.format(value);
  }

  static String money(double? value) {
    if (value == null) {
      return '--';
    }

    return _money.format(value);
  }

  static String mode(EnergyMonthlySummary item) {
    return item.isElectricity ? 'MTD' : 'AVG';
  }

  static String unit(EnergyMonthlySummary item, ChartTheme theme) {
    final apiUnit = item.unit.trim();

    if (apiUnit.isNotEmpty) {
      return apiUnit;
    }

    return theme.unit.trim();
  }
}

// ============================================================
// DELTA BADGE
// ============================================================

class MonthlyMetricDeltaBadge extends StatelessWidget {
  final double? delta;

  const MonthlyMetricDeltaBadge({super.key, required this.delta});

  @override
  Widget build(BuildContext context) {
    final value = delta;

    if (value == null) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          '--',
          maxLines: 1,
          style: TextStyle(
            color: Colors.white.withOpacity(.35),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    final isUp = value > 0;
    final isDown = value < 0;

    final Color color;

    if (value == 0) {
      color = Colors.white54;
    } else if (isUp) {
      color = Colors.redAccent;
    } else {
      color = Colors.greenAccent;
    }

    final IconData icon;

    if (isUp) {
      icon = Icons.arrow_upward_rounded;
    } else if (isDown) {
      icon = Icons.arrow_downward_rounded;
    } else {
      icon = Icons.remove_rounded;
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 1),
          Text(
            '${value.abs().toStringAsFixed(1)}%',
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 16,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HEADER
// ============================================================

class MonthlyMetricHeader extends StatelessWidget {
  final String title;
  final Color color;

  const MonthlyMetricHeader({
    super.key,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 14,
        height: 1,
        fontWeight: FontWeight.w900,
        letterSpacing: .15,
      ),
    );
  }
}

// ============================================================
// VALUE
// ============================================================

class MonthlyMetricValueText extends StatelessWidget {
  final String value;
  final String unit;

  final Color color;

  final String? badge;

  final TextAlign textAlign;

  const MonthlyMetricValueText({
    super.key,
    required this.value,
    required this.unit,
    required this.color,
    this.badge,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedUnit = unit.trim();

    final normalizedBadge = badge?.trim().toUpperCase() ?? '';

    final alignment = textAlign == TextAlign.right
        ? Alignment.centerRight
        : Alignment.centerLeft;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -.30,
              ),
            ),

            if (normalizedUnit.isNotEmpty)
              TextSpan(
                text: ' $normalizedUnit',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),

            if (normalizedBadge.isNotEmpty)
              TextSpan(
                text: ' ($normalizedBadge)',
                style: TextStyle(
                  color: color.withOpacity(.9),
                  fontSize: 12.5,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .15,
                ),
              ),
          ],
        ),
        maxLines: 1,
        textAlign: textAlign,
      ),
    );
  }
}

class MonthlyMetricAnimatedUtilityRow extends StatelessWidget {
  final EnergyMonthlySummary item;
  final Color color;
  final String unit;

  const MonthlyMetricAnimatedUtilityRow({
    super.key,
    required this.item,
    required this.color,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: item.displayValue),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (_, animatedValue, __) => MonthlyMetricComparisonRow(
        currentValue: MonthlyMetricFormat.utility(item, animatedValue),
        currentUnit: unit,
        previousValue: MonthlyMetricFormat.utility(
          item,
          item.previousDisplayValue,
        ),
        previousUnit: unit,
        mode: MonthlyMetricFormat.mode(item),
        delta: item.deltaPercent,
        currentColor: color,
      ),
    );
  }
}

// ============================================================
// COMPARISON ROW
// ============================================================

class MonthlyMetricComparisonRow extends StatelessWidget {
  final String currentValue;
  final String currentUnit;

  final String previousValue;
  final String previousUnit;

  final String mode;

  final double? delta;

  final Color currentColor;

  const MonthlyMetricComparisonRow({
    super.key,
    required this.currentValue,
    required this.currentUnit,
    required this.previousValue,
    required this.previousUnit,
    required this.mode,
    required this.delta,
    required this.currentColor,
  });

  bool get _hasPrevious {
    final value = previousValue.trim();

    return value.isNotEmpty && value != '--';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = _MonthlyMetricColumnGeometry.from(constraints);

        return SizedBox(
          height: 28,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ==================================================
              // CURRENT
              // ==================================================
              Expanded(
                flex: 11,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: MonthlyMetricValueText(
                    value: currentValue,
                    unit: currentUnit,
                    badge: mode,
                    color: currentColor,
                    textAlign: TextAlign.left,
                  ),
                ),
              ),

              SizedBox(width: geometry.gap),

              // ==================================================
              // PREVIOUS MONTH
              // ==================================================
              Expanded(
                flex: 9,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _hasPrevious
                      ? MonthlyMetricValueText(
                          value: previousValue,
                          unit: previousUnit,
                          color: Colors.white,
                          textAlign: TextAlign.left,
                        )
                      : Text(
                          '--',
                          style: TextStyle(
                            color: Colors.white.withOpacity(.35),
                            fontSize: 17,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),

              SizedBox(width: geometry.gap),

              // ==================================================
              // DIFF
              // ==================================================
              SizedBox(
                width: geometry.diffWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: MonthlyMetricDeltaBadge(delta: delta),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// COLUMN HEADER
// ============================================================

class MonthlyMetricColumnsHeader extends StatelessWidget {
  const MonthlyMetricColumnsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 12.5,
      height: 1,
      fontWeight: FontWeight.w900,
      letterSpacing: .45,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = _MonthlyMetricColumnGeometry.from(constraints);

        Widget label(String text, TextAlign textAlign, Alignment alignment) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment,
            child: Text(text, maxLines: 1, textAlign: textAlign, style: style),
          );
        }

        return Row(
          children: [
            Expanded(
              flex: 11,
              child: label('CURRENT', TextAlign.left, Alignment.centerLeft),
            ),
            SizedBox(width: geometry.gap),
            Expanded(
              flex: 9,
              child: label('PRE MONTH', TextAlign.left, Alignment.centerLeft),
            ),
            SizedBox(width: geometry.gap),
            SizedBox(
              width: geometry.diffWidth,
              child: label('DIFF', TextAlign.right, Alignment.centerRight),
            ),
          ],
        );
      },
    );
  }
}

class _MonthlyMetricColumnGeometry {
  final double gap;
  final double diffWidth;

  const _MonthlyMetricColumnGeometry({
    required this.gap,
    required this.diffWidth,
  });

  factory _MonthlyMetricColumnGeometry.from(BoxConstraints constraints) {
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth.clamp(0.0, double.maxFinite).toDouble()
        : 300.0;
    final gap = (width * .025).clamp(0.0, 8.0).toDouble();
    final remaining = (width - gap * 2).clamp(0.0, width).toDouble();
    final diffWidth = (width * .20)
        .clamp(0.0, 60.0)
        .toDouble()
        .clamp(0.0, remaining * .45)
        .toDouble();

    return _MonthlyMetricColumnGeometry(gap: gap, diffWidth: diffWidth);
  }
}

// ============================================================
// INLINE STATE
// ============================================================

class MonthlyInlineState extends StatelessWidget {
  final IconData icon;

  final String title;
  final String message;

  final Future<void> Function()? onTap;

  const MonthlyInlineState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withOpacity(.55), size: 22),

        const SizedBox(height: 6),

        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(.84),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 2),

        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(.52),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    if (onTap == null) {
      return Center(child: content);
    }

    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          onTap!();
        },
        child: Padding(padding: const EdgeInsets.all(10), child: content),
      ),
    );
  }
}
