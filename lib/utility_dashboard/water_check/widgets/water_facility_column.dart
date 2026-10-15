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

  /// Do neu co OVER, cam neu co NEAR / STALE, xanh neu on.
  Color get _overallColor {
    var near = false;
    for (final signal in facility.signals) {
      if (signal.status == WaterStatus.over) return kWaterOverColor;
      if (signal.status == WaterStatus.near ||
          signal.status == WaterStatus.stale) {
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

/// Icon + ten khoi ben trai, nguong chung ben phai.
class _BlockTitle extends StatelessWidget {
  final IconData icon;
  final String name;
  final String? thresholdText;
  final WaterVisualSize size;

  const _BlockTitle({
    required this.icon,
    required this.name,
    required this.thresholdText,
    required this.size,
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

// ============================================================
// SIGNAL
// ============================================================

String _valueText(WaterSignal signal, String unit, int decimals) {
  if (signal.status == WaterStatus.stale) return kMissingValue;
  return formatWithUnit(signal.value, unit, decimals: decimals);
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

class _VisualTileState extends State<_VisualTile> {
  bool _animate = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _animate = false);
  }

  String? get _caption {
    final signal = widget.signal;
    final value = signal.value;

    if (widget.kind == WaterVisualKind.dial &&
        signal.status != WaterStatus.stale &&
        value != null &&
        value < 0) {
      return 'pump stopped?';
    }
    if (widget.kind == WaterVisualKind.tank) {
      return tankNearCaption(widget.group, signal);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final signal = widget.signal;
    final tier = widget.tier;
    final stale = signal.status == WaterStatus.stale;
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

    final caption = _caption;
    final nameText = Text(
      widget.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: palette.text,
        fontSize: tier.nameFont,
        fontWeight: FontWeight.w600,
      ),
    );

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
              RepaintBoundary(
                child: Opacity(opacity: stale ? .5 : 1, child: figure),
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
                        color: waterReadingColor(signal.status, palette),
                        fontSize: tier.valueFont,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 2),
              SizedBox(
                height: tier.nameHeight,
                child: tier.showChip
                    ? nameText
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          WaterStatusChip(
                            status: signal.status,
                            tier: tier,
                            dotOnly: true,
                          ),
                          const SizedBox(width: 4),
                          Flexible(child: nameText),
                        ],
                      ),
              ),
              if (tier.showChip) ...[
                const SizedBox(height: 2),
                WaterStatusChip(status: signal.status, tier: tier),
              ],
              if (widget.kind != WaterVisualKind.thermometer)
                SizedBox(
                  height: tier.captionHeight,
                  child: caption == null
                      ? null
                      : Align(
                          alignment: Alignment.bottomCenter,
                          child: Text(
                            caption,
                            maxLines: 1,
                            style: TextStyle(
                              color: signal.status == WaterStatus.near
                                  ? kWaterNearColor
                                  : kWaterOverColor,
                              fontSize: tier.captionFont,
                              fontWeight: FontWeight.w800,
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
