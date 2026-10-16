import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shared/charts/value_format.dart';
import '../../shared/widgets/scada_panel_frame.dart';
import '../models/water_check_models.dart';
import 'water_check_format.dart';
import 'water_gauges.dart';
import 'water_layout.dart';
import 'water_signal_chart_dialog.dart';
import 'water_visuals.dart';

/// Mot cot xuong: tieu de + cac hang khoi (xem [arrangeWaterColumn]).
///
/// Cao theo noi dung (khong keo gian), toi da bang chieu cao cha; chi cuon
/// khi [WaterLayoutPlan] khong the gon them. Kich thuoc khung khop voi
/// [WaterColumnMetrics].
class WaterFacilityColumn extends StatelessWidget {
  final WaterFacility facility;
  final WaterStatus? filter;
  final WaterLayoutPlan plan;
  final GlobalKey Function(String signalKey) keyOf;
  final String? flashKey;
  final int flashToken;
  final ValueChanged<WaterSignalRef> onOpenSignal;

  const WaterFacilityColumn({
    super.key,
    required this.facility,
    required this.filter,
    required this.plan,
    required this.keyOf,
    required this.flashKey,
    required this.flashToken,
    required this.onOpenSignal,
  });

  /// Do neu co OVER, cam neu co NEAR / STALE / SENSOR_FAULT, xanh neu on
  /// (STOPPED khong tinh la loi).
  Color get _overallColor {
    var near = false;
    for (final signal in facility.signals) {
      if (signal.status == WaterStatus.over) return kWaterOverColor;
      if (signal.status == WaterStatus.near ||
          signal.status == WaterStatus.stale ||
          signal.status == WaterStatus.sensorFault) {
        near = true;
      }
    }
    return near ? kWaterNearColor : kWaterOkColor;
  }

  @override
  Widget build(BuildContext context) {
    final palette = WaterPalette.of(context);
    final layout = plan.columns[facility.facId];

    final total = facility.signalCount;
    final shown = facility.signals.where(_isVisible).length;

    // Bo khoi / hang khong con diem do nao sau khi loc.
    final shelves = [
      if (layout != null)
        for (final shelf in layout.shelves)
          if (shelf.items.any((item) => item.block.items.any(_isVisibleItem)))
            shelf,
    ];

    return ScadaPanelFrame(
      color: kWaterAccent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          WaterColumnMetrics.padLeft,
          WaterColumnMetrics.padTop,
          WaterColumnMetrics.padRight,
          WaterColumnMetrics.padBottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ColumnHeader(
              facId: facility.facId,
              count: filter == null
                  ? '$total points'
                  : '$shown / $total points',
              color: _overallColor,
            ),
            const SizedBox(height: WaterColumnMetrics.headerGap),
            if (shelves.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  filter == null
                      ? 'No water points'
                      : 'No ${waterStatusLabel(filter!).toLowerCase()} points',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    right: WaterColumnMetrics.scrollPad,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (final shelf in shelves) _buildShelf(shelf)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Mot hang: khoi rong chiem ca hang, khoi hep canh nhau theo be rong
  /// planner da chia.
  Widget _buildShelf(WaterShelf shelf) {
    Widget section(WaterShelfItem item) => _BlockSection(
      facId: facility.facId,
      block: item.block,
      compact: item.compact,
      size: plan.size,
      isVisible: _isVisibleItem,
      keyOf: keyOf,
      flashKey: flashKey,
      flashToken: flashToken,
      onOpenSignal: onOpenSignal,
    );

    if (shelf.items.length == 1) return section(shelf.items.first);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < shelf.items.length; i++) ...[
          if (i > 0) SizedBox(width: plan.size.spacing),
          // Phan du chia deu: dung flex theo be rong planner.
          Expanded(
            flex: (shelf.items[i].width * 10).round(),
            child: section(shelf.items[i]),
          ),
        ],
      ],
    );
  }

  bool _isVisible(WaterSignal signal) =>
      filter == null || signal.status == filter;

  bool _isVisibleItem(WaterBlockItem item) => _isVisible(item.signal);
}

class _ColumnHeader extends StatelessWidget {
  final String facId;
  final String count;
  final Color color;

  const _ColumnHeader({
    required this.facId,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = WaterPalette.of(context);

    return SizedBox(
      height: WaterColumnMetrics.headerHeight,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: .6), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            facId,
            style: TextStyle(
              color: palette.text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Text(
            count,
            style: TextStyle(
              color: palette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BLOCK
// ============================================================

/// Mot khoi: cac group cung loai hinh + unit (moi hinh giu nguong rieng).
class _BlockSection extends StatelessWidget {
  final String facId;
  final WaterBlock block;

  /// Dang dong gon thay cho hinh (plan gon de vua man hinh).
  final bool compact;
  final WaterVisualSize size;
  final bool Function(WaterBlockItem item) isVisible;
  final GlobalKey Function(String signalKey) keyOf;
  final String? flashKey;
  final int flashToken;
  final ValueChanged<WaterSignalRef> onOpenSignal;

  const _BlockSection({
    required this.facId,
    required this.block,
    required this.compact,
    required this.size,
    required this.isVisible,
    required this.keyOf,
    required this.flashKey,
    required this.flashToken,
    required this.onOpenSignal,
  });

  @override
  Widget build(BuildContext context) {
    int decimalsOf(WaterGroup group) =>
        waterDecimals(code: group.code, unit: group.unit);

    final items = block.items.where(isVisible).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    WaterSignalRef refOf(WaterBlockItem item) => WaterSignalRef(
      facId: facId,
      boxDeviceId: item.signal.boxDeviceId,
      plcAddress: item.signal.plcAddress,
      name: item.signal.name,
      deviceName: item.signal.deviceName,
      unit: item.group.unit,
    );

    Widget flash(String key, Widget child) => _Flash(
      key: keyOf(key),
      active: key == flashKey,
      token: flashToken,
      child: child,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: WaterColumnMetrics.blockPad / 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BlockTitle(
            icon: block.kind.icon,
            name: block.title,
            thresholdText: block.thresholdText(decimalsOf),
            size: size,
            issues: block.items.where((item) => _isIssue(item.signal)).length,
            abnormal: block.items.any(
              (item) => waterIsAbnormal(item.signal.status),
            ),
          ),
          if (compact)
            for (final item in items)
              flash(
                item.key,
                _SignalRow(
                  group: item.group,
                  signal: item.signal,
                  name: item.name,
                  decimals: decimalsOf(item.group),
                  onTap: () => onOpenSignal(refOf(item)),
                ),
              )
          else
            Wrap(
              spacing: size.spacing,
              runSpacing: size.spacing,
              children: [
                for (final item in items)
                  flash(
                    item.key,
                    _VisualTile(
                      kind: block.kind,
                      tier: size,
                      group: item.group,
                      signal: item.signal,
                      name: item.name,
                      decimals: decimalsOf(item.group),
                      onTap: () => onOpenSignal(refOf(item)),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Diem do can xem (giong card To check): OVER / SENSOR_FAULT / NEAR /
/// STALE. STOPPED khong phai loi.
bool _isIssue(WaterSignal signal) =>
    waterIsProblem(signal.status) || signal.status == WaterStatus.stale;

/// Icon + ten khoi + badge "N issues" ben trai, nguong chung ben phai.
class _BlockTitle extends StatelessWidget {
  final IconData icon;
  final String name;
  final String? thresholdText;
  final WaterVisualSize size;

  /// So diem do co van de; badge do neu co abnormal, cam neu khong.
  final int issues;
  final bool abnormal;

  const _BlockTitle({
    required this.icon,
    required this.name,
    required this.thresholdText,
    required this.size,
    this.issues = 0,
    this.abnormal = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = WaterPalette.of(context);

    return Container(
      height: size.titleHeight,
      margin: const EdgeInsets.only(bottom: WaterColumnMetrics.titleExtra - 1),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: kWaterAccent.withValues(alpha: .18)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: size.titleFont + 2, color: kWaterAccent),
          const SizedBox(width: 5),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: kWaterAccent,
                      fontSize: size.titleFont,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (issues > 0) ...[
                  const SizedBox(width: 6),
                  _IssuesBadge(count: issues, abnormal: abnormal, size: size),
                ],
              ],
            ),
          ),
          if (thresholdText != null) ...[
            const SizedBox(width: 8),
            Text(
              thresholdText!,
              maxLines: 1,
              style: TextStyle(
                color: palette.muted,
                fontSize: size.titleFont - .5,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IssuesBadge extends StatelessWidget {
  final int count;
  final bool abnormal;
  final WaterVisualSize size;

  const _IssuesBadge({
    required this.count,
    required this.abnormal,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final color = abnormal ? kWaterOverColor : kWaterNearColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .6)),
      ),
      child: Text(
        count == 1 ? '1 issue' : '$count issues',
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: size.titleFont - 1.5,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}

// ============================================================
// SIGNAL
// ============================================================

String _valueText(WaterSignal signal, String unit, int decimals) {
  if (signal.status == WaterStatus.stale) return kMissingValue;
  final text = formatWaterValue(signal, decimals);
  final u = unit.trim();
  return text == kMissingValue || u.isEmpty ? text : '$text $u';
}

/// Mot diem do dang hinh, kich thuoc co dinh theo (loai, tier):
/// hinh + (gia tri, chi nhiet ke) + ten ngan + chip trang thai (small: cham
/// canh ten) + chu thich (dong ho / bon). Chi animate lan dau.
class _VisualTile extends StatefulWidget {
  final WaterVisualKind kind;
  final WaterVisualSize tier;
  final WaterGroup group;
  final WaterSignal signal;
  final String name;
  final int decimals;
  final VoidCallback onTap;

  const _VisualTile({
    required this.kind,
    required this.tier,
    required this.group,
    required this.signal,
    required this.name,
    required this.decimals,
    required this.onTap,
  });

  @override
  State<_VisualTile> createState() => _VisualTileState();
}

class _VisualTileState extends State<_VisualTile>
    with SingleTickerProviderStateMixin {
  bool _animate = true;

  /// Halo pulse 2 lan khi vua chuyen sang trang thai co van de.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _animate = false);
  }

  @override
  void didUpdateWidget(covariant _VisualTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final status = widget.signal.status;
    if (status != oldWidget.signal.status && waterIsProblem(status)) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signal = widget.signal;
    final status = signal.status;
    final tier = widget.tier;
    final stale = status == WaterStatus.stale;
    final problem = waterIsProblem(status);
    final palette = WaterPalette.of(context);
    final size = tier.figureSize(widget.kind);

    final figure = switch (widget.kind) {
      WaterVisualKind.thermometer => WaterThermometer(
        group: widget.group,
        signal: signal,
        decimals: widget.decimals,
        animate: _animate,
        tier: tier,
      ),
      WaterVisualKind.dial => WaterPressureDial(
        group: widget.group,
        signal: signal,
        decimals: widget.decimals,
        animate: _animate,
        tier: tier,
      ),
      _ => WaterTank(
        group: widget.group,
        signal: signal,
        decimals: widget.decimals,
        animate: _animate,
        tier: tier,
      ),
    };

    // NO_THRESHOLD: khong chip, ten hoi mo, tooltip "No limit set".
    final noLimit = status == WaterStatus.noThreshold;
    Widget nameText = Text(
      widget.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: noLimit ? palette.text.withValues(alpha: .6) : palette.text,
        fontSize: tier.nameFont,
        fontWeight: FontWeight.w600,
      ),
    );
    if (noLimit) {
      nameText = Tooltip(message: 'No limit set', child: nameText);
    }

    final reason = waterShortReason(signal, widget.group, widget.decimals);
    final reasonColor = waterIsAbnormal(status)
        ? kWaterOverColor
        : status == WaterStatus.near
        ? kWaterNearColor
        : palette.muted;

    return Tooltip(
      message: waterTooltip(signal, widget.group, widget.decimals),
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size.width,
          height: tier.tileHeight(widget.kind),
          child: Column(
            children: [
              _Halo(
                color: problem ? waterStatusColor(status) : null,
                pulse: _pulse,
                child: RepaintBoundary(
                  child: Opacity(opacity: stale ? .5 : 1, child: figure),
                ),
              ),
              if (widget.kind == WaterVisualKind.thermometer)
                SizedBox(
                  height: tier.valueHeight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _valueText(signal, widget.group.unit, widget.decimals),
                      maxLines: 1,
                      style: TextStyle(
                        color: waterReadingColor(status, palette),
                        fontSize: problem
                            ? tier.valueFont * WaterVisualSize.problemValueScale
                            : tier.valueFont,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 2),
              SizedBox(
                height: tier.nameHeight,
                // Binh thuong: khong chip, chi cham xanh 6px canh ten.
                child: status == WaterStatus.ok
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: kWaterOkColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(child: nameText),
                        ],
                      )
                    : nameText,
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: tier.chipHeight,
                child: waterChipVisible(status)
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: WaterStatusChip(
                          status: status,
                          tier: tier,
                          nearHigh: status == WaterStatus.near
                              ? waterLimitIsHigh(signal, widget.group)
                              : null,
                        ),
                      )
                    : null,
              ),
              SizedBox(
                height: tier.captionHeight,
                child: reason == null
                    ? null
                    : Align(
                        alignment: Alignment.bottomCenter,
                        child: Text(
                          reason,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: reasonColor,
                            fontSize: tier.captionFont,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vien + halo mo quanh hinh co van de (khong doi kich thuoc). [pulse] chay
/// 0 -> 1: halo sang len 2 lan roi ve muc nghi, khong lap lai.
class _Halo extends StatelessWidget {
  final Color? color;
  final Animation<double> pulse;
  final Widget child;

  const _Halo({required this.color, required this.pulse, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = color;
    if (c == null) return child;

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final t = pulse.isAnimating ? pulse.value : 0.0;
        // 2 dinh trong 0..1.
        final boost = (1 - math.cos(t * 4 * math.pi)) / 2;

        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: c.withValues(alpha: .55 + .4 * boost),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: c.withValues(alpha: .28 + .35 * boost),
                blurRadius: 8 + 10 * boost,
                spreadRadius: 1 + 2 * boost,
                blurStyle: BlurStyle.outer,
              ),
            ],
          ),
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Dong gon (unit khac, hoac nhom bi gon lai de vua man hinh).
class _SignalRow extends StatelessWidget {
  final WaterGroup group;
  final WaterSignal signal;
  final String name;
  final int decimals;
  final VoidCallback onTap;

  const _SignalRow({
    required this.group,
    required this.signal,
    required this.name,
    required this.decimals,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = WaterPalette.of(context);
    final hasBar = signal.status != WaterStatus.noThreshold;

    return Tooltip(
      message: waterTooltip(signal, group, decimals),
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: WaterColumnMetrics.compactRowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = math.min(110.0, constraints.maxWidth * .3);

                return Row(
                  children: [
                    WaterStatusDot(status: signal.status),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    RepaintBoundary(
                      child: hasBar
                          ? WaterThresholdBar(
                              group: group,
                              signal: signal,
                              width: barWidth,
                            )
                          : SizedBox(width: barWidth),
                    ),
                    SizedBox(
                      width: 84,
                      child: Text(
                        _valueText(signal, group.unit, decimals),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: waterReadingColor(signal.status, palette),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FLASH
// ============================================================

/// Nhap nhay nhe ~1.5s khi diem do duoc chon tu card issue.
class _Flash extends StatefulWidget {
  final bool active;
  final int token;
  final Widget child;

  const _Flash({
    super.key,
    required this.active,
    required this.token,
    required this.child,
  });

  @override
  State<_Flash> createState() => _FlashState();
}

class _FlashState extends State<_Flash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _Flash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active &&
        (!oldWidget.active || oldWidget.token != widget.token)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        // 3 nhip, tat dan ve cuoi.
        final pulse = _controller.isAnimating
            ? math.sin(t * 3 * math.pi).abs() * (1 - t * .5)
            : 0.0;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: kWaterAccent.withValues(alpha: .22 * pulse),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: kWaterAccent.withValues(alpha: .7 * pulse),
            ),
          ),
          child: child,
        );
      },
    );
  }
}
