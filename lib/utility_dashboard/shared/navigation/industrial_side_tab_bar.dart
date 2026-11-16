import 'dart:math' as math;

import 'package:flutter/material.dart';

class IndustrialSideTabItem {
  final IconData icon;
  final String text;

  /// Optional
  final String? tooltip;
  final Widget? trailing; // badge / dot / counter
  final bool enabled;

  const IndustrialSideTabItem({
    required this.icon,
    required this.text,
    this.tooltip,
    this.trailing,
    this.enabled = true,
  });
}

// ============================================================
// PALETTE / METRICS
// ============================================================

const _kAccent = Color(0xFF5CFF7A);
const _kAccentCyan = Color(0xFF00CFFF);
const _kBgTop = Color(0xFF0D1830);
const _kBgBottom = Color(0xFF070E1C);
const _kText = Color(0xFFE6EEF7);
const _kTextDim = Color(0xFF8DA2B8);

const _kTileH = 42.0;
const _kTileGap = 4.0;
const _kTileMarginH = 6.0;
const _kIconSlotMax = 40.0;

const _kWidthDuration = Duration(milliseconds: 260);
const _kIndicatorDuration = Duration(milliseconds: 320);
const _kStateDuration = Duration(milliseconds: 180);

/// Thanh tab doc ben trai.
///
/// - Khung chon (indicator) truot muot giua cac tab thay vi nhay.
/// - Thu gon / mo rong: chieu rong animate, nhan chu mo dan theo chieu rong
///   (khong "pop" o breakpoint, khong overflow giua chung).
/// - Hover / chon: mau icon + chu chuyen dan.
class IndustrialSideTabBar extends StatelessWidget {
  final TabController controller;
  final bool expanded;
  final VoidCallback onToggle;
  final List<IndustrialSideTabItem> tabs;

  final double collapsedWidth;
  final double expandedWidth;
  final EdgeInsets padding;

  /// branding
  final String title;
  final IconData brandIcon;

  /// Giu cho tuong thich API cu; nhan chu nay da mo dan theo chieu rong.
  final double expandBreakpoint;

  const IndustrialSideTabBar({
    super.key,
    required this.controller,
    required this.expanded,
    required this.onToggle,
    required this.tabs,
    this.collapsedWidth = 52,
    this.expandedWidth = 200,
    this.padding = const EdgeInsets.symmetric(vertical: 10),
    this.title = 'FAC UTILITY',
    this.brandIcon = Icons.factory_outlined,
    this.expandBreakpoint = 150,
  });

  /// 0 khi thu gon -> 1 khi mo het; nhan chu chi bat dau hien tu ~40%.
  double _labelOpacity(double width) {
    final span = expandedWidth - collapsedWidth;
    if (span <= 0) return 1;
    final t = ((width - collapsedWidth) / span).clamp(0.0, 1.0);
    return Curves.easeOut.transform(((t - .4) / .6).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _kWidthDuration,
      curve: Curves.easeOutCubic,
      width: expanded ? expandedWidth : collapsedWidth,
      // Vien phai ve o foreground: khong an mat 1px chieu rong cua noi dung
      // (border trong decoration lam noi dung chi con 51px -> overflow).
      foregroundDecoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kBgTop, _kBgBottom],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(6, 0),
          ),
        ],
      ),
      child: SafeArea(
        right: false,
        child: LayoutBuilder(
          builder: (context, c) {
            final labelOpacity = _labelOpacity(c.maxWidth);

            // O icon tinh theo chieu rong THUC (tru SafeArea / vien...) de
            // khi thu gon khong bao gio vuot qua chieu rong thanh.
            final iconSlot =
                (math.min(c.maxWidth, collapsedWidth) - _kTileMarginH * 2)
                    .clamp(0.0, _kIconSlotMax);

            return Column(
              children: [
                _Header(
                  labelOpacity: labelOpacity,
                  expanded: expanded,
                  title: title,
                  brandIcon: brandIcon,
                  onToggle: onToggle,
                ),
                const _GlowDivider(),
                Expanded(
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (_, __) => _TabList(
                      tabs: tabs,
                      selectedIndex: controller.index,
                      labelOpacity: labelOpacity,
                      iconSlot: iconSlot,
                      padding: padding,
                      onSelect: (i) {
                        // Doi ngay (khong animateTo 300ms cua TabController)
                        // de noi dung tab chuyen tuc thi.
                        if (controller.index != i) controller.index = i;
                      },
                    ),
                  ),
                ),
                const _GlowDivider(),
                _Footer(labelOpacity: labelOpacity, iconSlot: iconSlot),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// TAB LIST + SLIDING INDICATOR
// ============================================================

class _TabList extends StatelessWidget {
  final List<IndustrialSideTabItem> tabs;
  final int selectedIndex;
  final double labelOpacity;
  final double iconSlot;
  final EdgeInsets padding;
  final ValueChanged<int> onSelect;

  const _TabList({
    required this.tabs,
    required this.selectedIndex,
    required this.labelOpacity,
    required this.iconSlot,
    required this.padding,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedIndex >= 0 && selectedIndex < tabs.length;

    return SingleChildScrollView(
      padding: padding,
      child: Stack(
        children: [
          if (hasSelection)
            AnimatedPositioned(
              duration: _kIndicatorDuration,
              curve: Curves.easeOutCubic,
              top: selectedIndex * (_kTileH + _kTileGap),
              left: _kTileMarginH,
              right: _kTileMarginH,
              height: _kTileH,
              child: const _SelectionIndicator(),
            ),
          Column(
            children: [
              for (var i = 0; i < tabs.length; i++) ...[
                if (i > 0) const SizedBox(height: _kTileGap),
                _TabTile(
                  item: tabs[i],
                  selected: i == selectedIndex,
                  labelOpacity: labelOpacity,
                  iconSlot: iconSlot,
                  onTap: tabs[i].enabled ? () => onSelect(i) : null,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: LinearGradient(
          colors: [
            _kAccent.withValues(alpha: .20),
            _kAccent.withValues(alpha: .06),
          ],
        ),
        border: Border.all(color: _kAccent.withValues(alpha: .38)),
        boxShadow: [
          BoxShadow(
            color: _kAccent.withValues(alpha: .14),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            color: _kAccent,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(3),
            ),
            boxShadow: [
              BoxShadow(color: _kAccent.withValues(alpha: .8), blurRadius: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabTile extends StatefulWidget {
  final IndustrialSideTabItem item;
  final bool selected;
  final double labelOpacity;
  final double iconSlot;
  final VoidCallback? onTap;

  const _TabTile({
    required this.item,
    required this.selected,
    required this.labelOpacity,
    required this.iconSlot,
    required this.onTap,
  });

  @override
  State<_TabTile> createState() => _TabTileState();
}

class _TabTileState extends State<_TabTile> {
  bool _hover = false;

  void _setHover(bool value) {
    if (_hover != value) setState(() => _hover = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.item;
    final selected = widget.selected;
    final enabled = widget.onTap != null;
    final showLabel = widget.labelOpacity > 0;

    final fg = !enabled
        ? _kTextDim.withValues(alpha: .45)
        : selected
        ? _kAccent
        : (_hover ? _kText : _kTextDim);

    final labelColor = !enabled
        ? _kTextDim.withValues(alpha: .45)
        : selected
        ? _kText
        : (_hover ? _kText : _kTextDim);

    Widget tile = AnimatedContainer(
      duration: _kStateDuration,
      curve: Curves.easeOutCubic,
      height: _kTileH,
      decoration: BoxDecoration(
        // Nen tab dang chon do indicator ve; o day chi co hover.
        color: !selected && _hover
            ? Colors.white.withValues(alpha: .05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          // O icon co dinh = chieu rong thanh khi thu gon -> icon khong xe dich
          // khi mo / dong thanh.
          SizedBox(
            width: widget.iconSlot,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedScale(
                  scale: selected ? 1.12 : (_hover ? 1.05 : 1),
                  duration: _kStateDuration,
                  curve: Curves.easeOutBack,
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: fg),
                    duration: _kStateDuration,
                    builder: (_, color, __) =>
                        Icon(t.icon, color: color, size: 19),
                  ),
                ),
                if (t.trailing != null && !showLabel)
                  Positioned(
                    right: 4,
                    top: 6,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 16,
                        maxHeight: 16,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: t.trailing!,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: showLabel
                ? Opacity(
                    opacity: widget.labelOpacity,
                    child: Row(
                      children: [
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: _kStateDuration,
                            style: TextStyle(
                              color: labelColor,
                              fontWeight: selected
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              letterSpacing: selected ? .6 : .3,
                              fontSize: 12.5,
                            ),
                            child: Text(
                              t.text,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                            ),
                          ),
                        ),
                        if (t.trailing != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4, right: 8),
                            child: SizedBox(
                              height: 16,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: t.trailing!,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );

    tile = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          splashColor: _kAccent.withValues(alpha: .10),
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          onTap: widget.onTap,
          child: tile,
        ),
      ),
    );

    // Thu gon (chua thay chu): hien tooltip ten tab.
    if (widget.labelOpacity < .5) {
      tile = Tooltip(
        message: t.tooltip ?? t.text,
        waitDuration: const Duration(milliseconds: 300),
        child: tile,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kTileMarginH),
      child: tile,
    );
  }
}

// ============================================================
// HEADER / FOOTER
// ============================================================

class _Header extends StatelessWidget {
  final double labelOpacity;
  final bool expanded;
  final String title;
  final IconData brandIcon;
  final VoidCallback onToggle;

  const _Header({
    required this.labelOpacity,
    required this.expanded,
    required this.title,
    required this.brandIcon,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          // Brand: mo dan theo chieu rong; khi thu gon chi con nut toggle.
          Expanded(
            child: labelOpacity <= 0
                ? const SizedBox.shrink()
                : Opacity(
                    opacity: labelOpacity,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: 0,
                        maxWidth: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      _kAccentCyan.withValues(alpha: .28),
                                      _kAccent.withValues(alpha: .18),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: _kAccentCyan.withValues(alpha: .35),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _kAccentCyan.withValues(
                                        alpha: .18,
                                      ),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  brandIcon,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: .92),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                title,
                                maxLines: 1,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .94),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 9),
            child: _ToggleButton(expanded: expanded, onTap: onToggle),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatefulWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _ToggleButton({required this.expanded, required this.onTap});

  @override
  State<_ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<_ToggleButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.expanded ? 'Collapse' : 'Expand',
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: _kStateDuration,
            curve: Curves.easeOutCubic,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _hover ? .12 : .05),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: _hover
                    ? _kAccentCyan.withValues(alpha: .45)
                    : Colors.white.withValues(alpha: .10),
              ),
            ),
            // Mui ten xoay 180° thay vi doi icon.
            child: AnimatedRotation(
              turns: widget.expanded ? 0 : .5,
              duration: _kWidthDuration,
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.chevron_left_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: _hover ? 1 : .85),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowDivider extends StatelessWidget {
  const _GlowDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: .14),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final double labelOpacity;
  final double iconSlot;

  const _Footer({required this.labelOpacity, required this.iconSlot});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: iconSlot + _kTileMarginH * 2,
            child: Center(
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: _kAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kAccent.withValues(alpha: .7),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (labelOpacity > 0)
            Expanded(
              child: Opacity(
                opacity: labelOpacity,
                child: Text(
                  'Connected',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
