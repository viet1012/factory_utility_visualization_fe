import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../monitoring/electricity/widgets/electricity_style.dart'
    show PlantTime;
import '../../shared/charts/value_format.dart';
import '../../shared/formatters/month_formatter.dart';
import '../../shared/widgets/load_state_widgets.dart';
import '../../shared/widgets/price_missing_icon.dart';
import '../../shared/formatters/period_basis_formatter.dart';
import '../../shared/widgets/period_basis_note.dart';
import '../models/energy_monthly_summary.dart';
import '../providers/utility_monthly_summary_provider.dart';
import '../utility_dashboard_overview_widgets/month_label_badge.dart';

class MonthlySummaryScreen extends StatefulWidget {
  final String facId;
  final String month;

  const MonthlySummaryScreen({
    super.key,
    required this.facId,
    required this.month,
  });

  @override
  State<MonthlySummaryScreen> createState() => _MonthlySummaryScreenState();
}

class _MonthlySummaryScreenState extends State<MonthlySummaryScreen> {
  late final UtilityMonthlySummaryProvider _provider;

  @override
  void initState() {
    super.initState();

    _provider = context.read<UtilityMonthlySummaryProvider>();

    final initialFacId = widget.facId;
    final initialMonth = widget.month;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _configure(facId: initialFacId, month: initialMonth);
    });
  }

  @override
  void didUpdateWidget(covariant MonthlySummaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldFacId = oldWidget.facId.trim();
    final newFacId = widget.facId.trim();

    final oldMonth = oldWidget.month.trim();
    final newMonth = widget.month.trim();

    final sourceChanged = oldFacId != newFacId || oldMonth != newMonth;

    if (!sourceChanged) return;

    final nextFacId = widget.facId;
    final nextMonth = widget.month;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _configure(facId: nextFacId, month: nextMonth);
    });
  }

  /// Lay du lieu qua MonthlySummaryStore (cache 10 phut, dung chung voi o
  /// Fac tren MAP); polling do task MAP cua store dam nhan.
  void _configure({required String facId, required String month}) {
    _provider.configure(facId: facId, month: month);
  }

  String get monthLabel => MonthFormatter.label(widget.month);

  Future<void> _forceRefresh() async {
    final success = await _provider.forceRefresh();

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(
            success ? 'Monthly data refreshed' : 'Monthly refresh failed',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Selector<UtilityMonthlySummaryProvider, _MonthlySummaryViewModel>(
      selector: (_, provider) {
        return _MonthlySummaryViewModel(
          loading: provider.loading,
          refreshing: provider.refreshing,
          forceRefreshing: provider.forceRefreshing,
          error: provider.error,
          rows: provider.rows,
          electricity: provider.electricity,
          water: provider.water,
          air: provider.air,
          lastUpdatedAt: provider.lastUpdatedAt,
          refreshFailed: provider.refreshFailed,
        );
      },
      shouldRebuild: (previous, next) {
        return previous.loading != next.loading ||
            previous.refreshing != next.refreshing ||
            previous.forceRefreshing != next.forceRefreshing ||
            previous.error != next.error ||
            previous.lastUpdatedAt != next.lastUpdatedAt ||
            previous.refreshFailed != next.refreshFailed ||
            !identical(previous.rows, next.rows);
      },
      builder: (context, vm, _) {
        final electricity = vm.electricity;
        final water = vm.water;
        final air = vm.air;

        // Chua co so nao: dang tai (ke ca dang retry) -> skeleton; het retry
        // ma van loi -> the loi. Da co so: luon hien so (ke ca khi loi).
        final Widget body;
        if (vm.rows.isEmpty && vm.error != null && !vm.loading) {
          body = _SummaryErrorCard(
            onRetry: () => unawaited(_provider.retry()),
          );
        } else if (vm.rows.isEmpty) {
          body = const _SummarySkeletonRow();
        } else {
          body = Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (electricity != null)
                Expanded(child: _ElectricCard(item: electricity)),
              SizedBox(width: 4),
              if (water != null)
                Expanded(
                  child: _UtilityMinMaxCard(
                    item: water,
                    title: 'WATER',
                    subtitle: monthSubtitle(water.month, isMtd: false),
                    color: const Color(0xff22d3ee),
                    icon: Icons.water_drop_rounded,
                  ),
                ),
              SizedBox(width: 4),

              if (air != null)
                Expanded(
                  child: _UtilityMinMaxCard(
                    item: air,
                    title: 'AIR',
                    subtitle: monthSubtitle(air.month, isMtd: false),
                    color: const Color(0xffa855f7),
                    icon: Icons.air_rounded,
                  ),
                ),
            ],
          );
        }

        return RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xff020817),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    _Header(
                      month: widget.month,
                      pickAt: PeriodBasisFormatter.latestPickAt(
                        vm.rows.map((row) => row.pickAt),
                      ),
                      monthLabel: monthLabel,
                      forceRefreshing: vm.forceRefreshing,
                      onRefresh: _forceRefresh,
                      status: StaleDataBadge(
                        refreshing: vm.refreshing,
                        failed: vm.refreshFailed,
                        lastUpdatedAt: vm.lastUpdatedAt,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: body),
                  ],
                ),
                if (vm.refreshing)
                  const Positioned(
                    top: 32,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: Color(0xff22d3ee),
                      backgroundColor: Colors.transparent,
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

class _MonthlySummaryViewModel {
  final bool loading;
  final bool refreshing;
  final bool forceRefreshing;

  final Object? error;

  final List<EnergyMonthlySummary> rows;

  final EnergyMonthlySummary? electricity;
  final EnergyMonthlySummary? water;
  final EnergyMonthlySummary? air;

  final DateTime? lastUpdatedAt;
  final bool refreshFailed;

  const _MonthlySummaryViewModel({
    required this.loading,
    required this.refreshing,
    required this.forceRefreshing,
    required this.error,
    required this.rows,
    required this.electricity,
    required this.water,
    required this.air,
    required this.lastUpdatedAt,
    required this.refreshFailed,
  });
}

// ============================================================
// LOADING / ERROR
// ============================================================

const Color _electricColor = Color(0xffffcc33);
const Color _waterColor = Color(0xff22d3ee);
const Color _airColor = Color(0xffa855f7);

/// 3 the skeleton dung hinh dang the that (icon + title, so lon, 2 o prev,
/// footer); sau 5s hien dong goi y tai cham.
class _SummarySkeletonRow extends StatelessWidget {
  const _SummarySkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: SkeletonShimmer(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _SummaryCardSkeleton(color: _electricColor)),
                SizedBox(width: 4),
                Expanded(child: _SummaryCardSkeleton(color: _waterColor)),
                SizedBox(width: 4),
                Expanded(child: _SummaryCardSkeleton(color: _airColor)),
              ],
            ),
          ),
        ),
        const Positioned(
          left: 8,
          right: 8,
          bottom: 30,
          child: IgnorePointer(child: SlowLoadingHint()),
        ),
      ],
    );
  }
}

class _SummaryCardSkeleton extends StatelessWidget {
  final Color color;

  const _SummaryCardSkeleton({required this.color});

  @override
  Widget build(BuildContext context) {
    return _CardFrame(
      color: color,
      child: Column(
        children: [
          // Icon + title / subtitle.
          Row(
            children: const [
              SkeletonBox(width: 30, height: 30, radius: 15),
              SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 72, height: 12),
                    SizedBox(height: 5),
                    SkeletonBox(width: 92, height: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // So lon.
          const SkeletonBox(width: 96, height: 26),
          const SizedBox(height: 14),
          // 2 o prev.
          const Row(
            children: [
              Expanded(child: SkeletonBox(height: 52, radius: 8)),
              SizedBox(width: 6),
              Expanded(child: SkeletonBox(height: 52, radius: 8)),
            ],
          ),
          const Spacer(),
          // Footer.
          const SkeletonBox(width: 110, height: 18, radius: 999),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// Het retry ma chua co so: loi gon trong mot khung the chiem dung vung 3
/// the (khong doi kich thuoc khoi).
class _SummaryErrorCard extends StatelessWidget {
  final VoidCallback onRetry;

  const _SummaryErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _CardFrame(
      color: Colors.white.withValues(alpha: .5),
      child: InlineLoadError(onRetry: onRetry),
    );
  }
}

final _numFmt = NumberFormat('#,##0');
final _moneyFmt = NumberFormat('#,##0');

String fmt(num? v) => v == null ? kMissingValue : _numFmt.format(v);

String money(num? v) => v == null ? kMissingValue : _moneyFmt.format(v);

String monthSubtitle(String month, {required bool isMtd}) {
  final label = MonthFormatter.uppercaseLabel(month);

  return isMtd ? 'MTD $label' : 'AVG $label';
}

class _Header extends StatelessWidget {
  /// yyyyMM cua panel (de ghi khoang ngay thang duong lich).
  final String month;

  /// Gio du lieu moi nhat (pickAt) cua response monthly-summary.
  final PlantTime? pickAt;
  final String monthLabel;
  final bool forceRefreshing;
  final Future<void> Function() onRefresh;

  /// Badge "dang cap nhat" / "cap nhat loi" (rong khi khong co gi).
  final Widget status;

  const _Header({
    required this.month,
    required this.pickAt,
    required this.monthLabel,
    required this.forceRefreshing,
    required this.onRefresh,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          const Icon(
            Icons.bar_chart_rounded,
            color: Color(0xffa5b4fc),
            size: 17,
          ),
          const SizedBox(width: 5),
          const Text(
            'SUMMARY',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            '(MONTHLY)',
            style: TextStyle(
              color: Color(0xff22d3ee),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          // Ky tinh: thang duong lich (khac ky hoa don cua Elec. consumption).
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              // Nhan ngan `Nov 1–16`; chi tiet (calendar month, gio pickAt,
              // ky hoa don) nam trong tooltip ⓘ.
              child: PeriodBasisNote(
                text: PeriodBasisFormatter.calendarMonthShortLabel(
                  month,
                  pickAt: pickAt,
                ),
                scaleDownText: true,
                tooltip: PeriodBasisFormatter.billPeriodHint(
                  month,
                  pickAt: pickAt,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          status,
          const SizedBox(width: 4),
          MonthLabelBadge(monthLabel: monthLabel),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Clear cache and reload database',
            child: SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: forceRefreshing
                    ? null
                    : () {
                        unawaited(onRefresh());
                      },
                icon: forceRefreshing
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xff22d3ee),
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        size: 17,
                        color: Color(0xff22d3ee),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ElectricCard extends StatelessWidget {
  final EnergyMonthlySummary item;

  const _ElectricCard({required this.item});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xffffcc33);
    final unit = item.unit.isEmpty ? 'kWh' : item.unit;

    // value / prevValue / usdCost / prevUsdCost = dien luoi official (EVN
    // neu co, khong thi so do). KHONG dung totalEnergyValue (= load).
    return _SummaryCard(
      color: color,
      icon: Icons.bolt_rounded,
      title: 'ELECTRICITY',
      badge: item.gridSourceLabel,
      badgeTooltip: item.gridSourceTooltip,
      subtitle: monthSubtitle(item.month, isMtd: true),
      child: Column(
        children: [
          _MainValue(value: fmt(item.value), unit: unit, color: color),

          // const SizedBox(height: 6),
          _MainValue(
            value: money(item.usdCost),
            unit: 'USD',
            color: color,
            priceMissing: item.priceMissing,
          ),

          // const SizedBox(height: 6),
          _FitLabel(
            'Prev Month',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  icon: Icons.monetization_on_outlined,
                  label: unit,
                  value: fmt(item.prevValue),
                  color: Colors.white70,
                ),
              ),
              Expanded(
                child: _InfoTile(
                  icon: Icons.history_rounded,
                  label: 'USD',
                  value: money(item.prevUsdCost),
                  color: Colors.white70,
                  priceMissing: item.prevPriceMissing,
                ),
              ),
            ],
          ),

          // const SizedBox(height: 6),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _DeltaPill(
                delta: item.value == null || item.previousDisplayValue == null
                    ? null
                    : item.deltaPercent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UtilityMinMaxCard extends StatelessWidget {
  final EnergyMonthlySummary item;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _UtilityMinMaxCard({
    required this.item,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final unit = item.unit.isEmpty ? 'm³' : item.unit;
    return _SummaryCard(
      color: color,
      icon: icon,
      title: title,
      subtitle: subtitle,
      child: Column(
        children: [
          _MainValue(value: item.avgValue.toString(), unit: unit, color: color),

          // const SizedBox(height: 6),
          _InfoLine(
            icon: Icons.history_rounded,
            label: 'Prev Avg',
            value: '${fmt(item.prevAvgValue)} $unit',
            color: Colors.white70,
          ),

          // const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _SmallMetric(
                  icon: Icons.arrow_downward_rounded,
                  label: 'MIN',
                  value: item.minValue?.toString() ?? '--',
                  unit: unit,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: _SmallMetric(
                  icon: Icons.waves_rounded,
                  label: 'AVG',
                  value: item.avgValue?.toString() ?? '--',
                  unit: unit,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: _SmallMetric(
                  icon: Icons.arrow_upward_rounded,
                  label: 'MAX',
                  value: item.maxValue?.toString() ?? '--',
                  unit: unit,
                  color: color,
                ),
              ),
            ],
          ),

          // const SizedBox(height: 6),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _DeltaPill(delta: item.deltaPercent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Khung the (nen / vien / bong theo [color]) dung chung cho the that,
/// skeleton va the loi -> cung hinh dang, cung kich thuoc.
class _CardFrame extends StatelessWidget {
  final Color color;
  final Widget child;

  const _CardFrame({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .75), width: .9),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .16),
            blurRadius: 16,
            spreadRadius: -9,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Nhan ngan 1 dong: thu nho chu khi thieu cho thay vi ellipsis.
class _FitLabel extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _FitLabel(this.text, {this.style});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: style,
      ),
    );
  }
}

/// Chip nho canh title (vd `EVN + Đo`), vien / nen theo mau the.
class _TitleBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _TitleBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: .6), width: .8),
      ),
      child: _FitLabel(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          height: 1.1,
          fontWeight: FontWeight.w800,
          letterSpacing: .3,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  /// Chip nho ben phai title; tu xuong dong khi khong du cho.
  final String? badge;
  final String? badgeTooltip;

  const _SummaryCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.badge,
    this.badgeTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return _CardFrame(
      color: color,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: .16),
                  border: Border.all(color: color.withValues(alpha: .8)),
                ),
                child: Icon(icon, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 5,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _FitLabel(
                          title,
                          style: TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (badge != null)
                          badgeTooltip == null
                              ? _TitleBadge(text: badge!, color: color)
                              : Tooltip(
                                  message: badgeTooltip,
                                  waitDuration: const Duration(
                                    milliseconds: 200,
                                  ),
                                  child: _TitleBadge(
                                    text: badge!,
                                    color: color,
                                  ),
                                ),
                      ],
                    ),
                    _FitLabel(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .68),
                        // fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _MainValue extends StatelessWidget {
  final String value;
  final String unit;
  final Color color;
  final bool priceMissing;

  const _MainValue({
    required this.value,
    required this.unit,
    required this.color,
    this.priceMissing = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Flexible cho FittedBox 1 chiều rộng tối đa cụ thể (= phần còn
          // lại sau khi trừ SizedBox + unit) để nó thực sự co khi `value`
          // dài, thay vì lấy kích thước tự nhiên rồi làm cả Row tràn ra.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 26,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 3),

          // unit không cần Flexible vì luôn ngắn (kWh, USD...), nhưng vẫn
          // giữ overflow: ellipsis làm lớp bảo hiểm cuối cùng phòng khi
          // unit bất ngờ dài hơn dự kiến.
          Text(
            unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color.withValues(alpha: .9),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          PriceMissingIcon(visible: priceMissing),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .17),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        children: [
          // Icon(icon, size: 18, color: color),
          //
          // const SizedBox(width: 3),
          _FitLabel(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool priceMissing;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.priceMissing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      // padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final fontSize = (constraints.maxWidth * 0.08).clamp(15.0, 28.0);

              return Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: fontSize,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              );
            },
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              PriceMissingIcon(visible: priceMissing, size: 12),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _SmallMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // height: 46,
      // padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 14),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  final double? delta;

  const _DeltaPill({required this.delta});

  @override
  Widget build(BuildContext context) {
    // Thieu mot trong hai ky: bo trong thay vi ghi 0%.
    if (delta == null) return const SizedBox.shrink();
    final d = delta!;
    final isUp = d > 0;
    final color = isUp ? Colors.redAccent : Colors.lightGreenAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 3),
          Text(
            '${d.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            'vs prev',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .6),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
