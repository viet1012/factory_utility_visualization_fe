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

  /// when width < this => force compact layout to avoid overflow while animating
  final double expandBreakpoint;

  const IndustrialSideTabBar({
    super.key,
    required this.controller,
    required this.expanded,
    required this.onToggle,
    required this.tabs,
    this.collapsedWidth = 52, // ✅ nhỏ hơn 64
    this.expandedWidth = 200, // ✅ nhỏ hơn 240
    this.padding = const EdgeInsets.symmetric(vertical: 8),

    this.title = 'UTILITY',
    this.brandIcon = Icons.factory_outlined,

    this.expandBreakpoint = 150, // ✅ giảm theo expandedWidth mới
  });

  @override
  Widget build(BuildContext context) {
    final targetW = expanded ? expandedWidth : collapsedWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: targetW,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1324),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(6, 0),
          ),
        ],
      ),
      child: SafeArea(
        right: false,
        child: LayoutBuilder(
          builder: (context, c) {
            final effectiveExpanded = c.maxWidth >= expandBreakpoint;

            return Stack(
              children: [
                // ===== MAIN CONTENT =====
                Column(
                  children: [
                    // Header giờ chỉ để brand/title thôi (không chứa toggle nữa)
                    _Header(
                      expanded: effectiveExpanded,
                      title: title,
                      brandIcon: brandIcon,
                    ),
                    Divider(height: 1, color: Colors.white.withOpacity(0.10)),

                    Expanded(
                      child: AnimatedBuilder(
                        animation: controller,
                        builder: (_, __) {
                          final idx = controller.index;

                          return ListView.separated(
                            padding: padding,
                            itemCount: tabs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (_, i) {
                              final t = tabs[i];
                              final selected = i == idx;

                              return _TabTile(
                                expanded: effectiveExpanded,
                                item: t,
                                selected: selected,
                                onTap: t.enabled
                                    ? () {
                                        if (controller.index != i) {
                                          controller.animateTo(i);
                                        }
                                      }
                                    : null,
                              );
                            },
                          );
                        },
                      ),
                    ),

                    Divider(height: 1, color: Colors.white.withOpacity(0.10)),
                    _Footer(expanded: effectiveExpanded),
                  ],
                ),

                // ===== ALWAYS-VISIBLE TOGGLE (OVERLAY) =====
                Positioned(
                  top: 8,
                  right: 6,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: onToggle,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: Icon(
                          expanded ? Icons.chevron_left : Icons.chevron_right,
                          size: 18,
                          color: Colors.white.withOpacity(0.90),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool expanded;
  final String title;
  final IconData brandIcon;

  const _Header({
    required this.expanded,
    required this.title,
    required this.brandIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 44),
        // chừa chỗ cho toggle overlay
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: Icon(
                brandIcon,
                size: 16,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
            if (expanded) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final bool expanded;

  const _Footer({required this.expanded});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            Icons.circle,
            size: 10,
            color: const Color(0xFF5CFF7A).withOpacity(0.9),
          ),
          const SizedBox(width: 8),
          if (expanded)
            Expanded(
              child: Text(
                'Connected',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _TabTile extends StatefulWidget {
  final bool expanded;
  final IndustrialSideTabItem item;
  final bool selected;
  final VoidCallback? onTap;

  const _TabTile({
    required this.expanded,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_TabTile> createState() => _TabTileState();
}

class _TabTileState extends State<_TabTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.item;
    final selected = widget.selected;
    final enabled = widget.onTap != null;

    const accent = Color(0xFF5CFF7A);

    final fg = !enabled
        ? Colors.white.withOpacity(0.35)
        : selected
        ? accent
        : Colors.white.withOpacity(_hover ? 0.92 : 0.80);

    final bg = selected
        ? Colors.white.withOpacity(0.08)
        : _hover
        ? Colors.white.withOpacity(0.05)
        : Colors.transparent;

    final border = selected
        ? accent.withOpacity(0.35)
        : Colors.white.withOpacity(0.06);

    final tilePadding = EdgeInsets.symmetric(
      horizontal: widget.expanded ? 8 : 8, // ✅ giảm
      vertical: 10, // ✅ giảm
    );

    // giảm radius một chút cho gọn
    final radius = BorderRadius.circular(12);

    Widget content;

    if (widget.expanded) {
      content = Row(
        children: [
          Icon(t.icon, color: fg, size: 18), // ✅ icon nhỏ lại
          const SizedBox(width: 8), // ✅ giảm gap

          Expanded(
            child: Text(
              t.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                fontSize: 12.5, // ✅ chữ nhỏ lại chút
              ),
            ),
          ),

          if (t.trailing != null) ...[
            const SizedBox(width: 6),
            SizedBox(
              width: 28, // ✅ slot trailing nhỏ hơn
              height: 16,
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: t.trailing!,
                ),
              ),
            ),
          ],
        ],
      );
    } else {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.center,
            child: Icon(t.icon, color: fg, size: 20),
          ),
          if (t.trailing != null)
            Positioned(
              right: -2,
              top: -2,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 16, maxHeight: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: FittedBox(fit: BoxFit.scaleDown, child: t.trailing!),
                ),
              ),
            ),
        ],
      );
    }

    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: tilePadding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: Border.all(color: border),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: accent.withOpacity(0.15),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.hardEdge,
      child: content,
    );

    final wrapped = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: widget.onTap,
        child: tile,
      ),
    );

    if (!widget.expanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Tooltip(message: t.tooltip ?? t.text, child: wrapped),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: wrapped,
    );
  }
}
