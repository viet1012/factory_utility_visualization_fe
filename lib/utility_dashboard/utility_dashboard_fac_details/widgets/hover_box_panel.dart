import 'package:flutter/material.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../../utility_dashboard_overview/'
    'utility_dashboard_overview_models/latest_tree_response.dart';
import 'hover_box_panel/hover_data_row_tile.dart';
import 'hover_box_panel/hover_panel_style.dart';
import 'hover_box_panel/hover_table_header.dart';

class HoverBoxPanel extends StatefulWidget {
  final String boxId;
  final String scadaId;

  final Rect imageRect;
  final Offset pos01;

  final List<LatestSignalDto> rows;

  final VoidCallback onEnterPanel;
  final VoidCallback onExitPanel;

  final String? category;

  const HoverBoxPanel({
    super.key,
    required this.boxId,
    required this.scadaId,
    required this.imageRect,
    required this.pos01,
    required this.rows,
    required this.onEnterPanel,
    required this.onExitPanel,
    this.category,
  });

  @override
  State<HoverBoxPanel> createState() {
    return _HoverBoxPanelState();
  }
}

class _HoverBoxPanelState extends State<HoverBoxPanel>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  late final AnimationController _flowController;

  @override
  void initState() {
    super.initState();

    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant HoverBoxPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    /*
     * Khi chọn Box ID khác, đưa danh sách trở lại đầu.
     */
    if (oldWidget.boxId != widget.boxId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }

        _scrollController.jumpTo(0);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _flowController.dispose();

    super.dispose();
  }

  ChartTheme get _theme {
    return ChartThemes.byCate(widget.category);
  }

  Rect get _panelRect {
    return calculatePanelRect(
      imageRect: widget.imageRect,
      pos01: widget.pos01,
      rowCount: widget.rows.length,
    );
  }

  int get _validRegisterCount {
    var count = 0;

    for (final row in widget.rows) {
      if (row.value != null) {
        count++;
      }
    }

    return count;
  }

  int get _missingRegisterCount {
    return widget.rows.length - _validRegisterCount;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final rect = _panelRect;
    final theme = _theme;

    return Positioned(
      left: rect.left,
      top: rect.top,
      child: MouseRegion(
        onEnter: (_) {
          widget.onEnterPanel();
        },
        onExit: (_) {
          widget.onExitPanel();
        },
        child: Material(
          color: Colors.transparent,
          child: RepaintBoundary(
            child: Container(
              width: rect.width,
              height: rect.height,
              decoration: _panelDecoration(theme),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(theme),
                  _buildSummaryBar(theme),
                  _buildTableHeader(),
                  Expanded(child: _buildList(theme)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PANEL DECORATION
  // ============================================================

  BoxDecoration _panelDecoration(ChartTheme theme) {
    return BoxDecoration(
      borderRadius: PanelStyle.radius,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF111C2D), Color(0xFF0A1422), Color(0xFF07101C)],
        stops: [0, .52, 1],
      ),
      border: Border.all(color: theme.line.withOpacity(.34), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.48),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: theme.line.withOpacity(.10),
          blurRadius: 16,
          spreadRadius: 1,
        ),
      ],
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(ChartTheme theme) {
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            theme.line.withOpacity(.19),
            theme.line.withOpacity(.07),
            Colors.transparent,
          ],
        ),
        border: Border(bottom: BorderSide(color: theme.line.withOpacity(.18))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildUtilityIcon(theme),
          const SizedBox(width: 11),

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        clean(widget.boxId).isEmpty
                            ? 'UNKNOWN BOX'
                            : clean(widget.boxId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .35,
                          height: 1.05,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryBadge(theme),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.hub_outlined,
                      size: 13,
                      color: Colors.white.withOpacity(.48),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        clean(widget.scadaId).isEmpty
                            ? 'SCADA not configured'
                            : 'SCADA ${clean(widget.scadaId)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.58),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          _buildRegisterCounter(theme),
        ],
      ),
    );
  }

  Widget _buildUtilityIcon(ChartTheme theme) {
    return AnimatedBuilder(
      animation: _flowController,
      builder: (context, child) {
        final pulse =
            .92 +
            (_flowController.value <= .5
                    ? _flowController.value
                    : 1 - _flowController.value) *
                .12;

        return Transform.scale(
          scale: pulse,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.line.withOpacity(.12),
              border: Border.all(color: theme.line.withOpacity(.38)),
              boxShadow: [
                BoxShadow(color: theme.line.withOpacity(.18), blurRadius: 9),
              ],
            ),
            child: Icon(theme.icon, color: theme.iconColor, size: 21),
          ),
        );
      },
    );
  }

  Widget _buildCategoryBadge(ChartTheme theme) {
    final text = _categoryLabel(widget.category);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: theme.line.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.line.withOpacity(.28)),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          color: theme.line,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .45,
          height: 1,
        ),
      ),
    );
  }

  Widget _buildRegisterCounter(ChartTheme theme) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.18),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.rows.length}',
            style: TextStyle(
              color: theme.line,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'REGISTERS',
            style: TextStyle(
              color: Colors.white.withOpacity(.46),
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .65,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY BAR
  // ============================================================

  Widget _buildSummaryBar(ChartTheme theme) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.12),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(.06)),
        ),
      ),
      child: Row(
        children: [
          _SummaryItem(
            icon: Icons.sensors_rounded,
            label: 'Signals',
            value: '${widget.rows.length}',
            color: theme.line,
          ),
          const SizedBox(width: 18),
          _SummaryItem(
            icon: Icons.check_circle_outline_rounded,
            label: 'Available',
            value: '$_validRegisterCount',
            color: const Color(0xFF4ADE80),
          ),
          const SizedBox(width: 18),
          _SummaryItem(
            icon: Icons.remove_circle_outline_rounded,
            label: 'No data',
            value: '$_missingRegisterCount',
            color: _missingRegisterCount > 0
                ? const Color(0xFFF59E0B)
                : Colors.white.withOpacity(.38),
          ),
          const Spacer(),
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: Colors.white.withOpacity(.32),
          ),
          const SizedBox(width: 5),
          Text(
            'Click outside to close',
            style: TextStyle(
              color: Colors.white.withOpacity(.34),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABLE
  // ============================================================

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.018),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(.06)),
        ),
      ),
      child: const TableHeader(),
    );
  }

  Widget _buildList(ChartTheme theme) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      trackVisibility: false,
      thickness: 5,
      radius: const Radius.circular(999),
      child: ListView.separated(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 11),
        itemCount: widget.rows.length,
        separatorBuilder: (_, __) {
          return const SizedBox(height: 3);
        },
        itemBuilder: (context, index) {
          final signal = widget.rows[index];

          return RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: index.isEven
                    ? Colors.white.withOpacity(.026)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DataRowTile(
                signal: signal,
                scadaId: widget.scadaId,
                isEven: index.isEven,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// SUMMARY ITEM
// ============================================================

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(.45),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PANEL POSITION
// ============================================================

Rect calculatePanelRect({
  required Rect imageRect,
  required Offset pos01,
  int rowCount = 0,
}) {
  final anchorLeft = imageRect.left + pos01.dx * imageRect.width;

  final anchorTop = imageRect.top + pos01.dy * imageRect.height;

  /*
   * Responsive theo kích thước ảnh.
   * Không ép tối thiểu 700 nếu màn hình nhỏ.
   */
  final availableWidth = (imageRect.width - 24).clamp(320.0, double.infinity);

  final preferredWidth = imageRect.width >= 1200
      ? imageRect.width * .64
      : imageRect.width >= 900
      ? imageRect.width * .72
      : imageRect.width * .86;

  final width = preferredWidth
      .clamp(520.0, availableWidth < 980 ? availableWidth : 980.0)
      .toDouble();

  const rowHeight = 43.0;

  /*
   * Header:
   * 64 main header
   * 42 summary
   * 39 table header
   * 18 padding
   */
  const fixedHeight = 163.0;

  final desiredHeight = fixedHeight + rowCount * rowHeight;

  final maxHeight = (imageRect.height - 16)
      .clamp(240.0, imageRect.height)
      .toDouble();

  final height = desiredHeight.clamp(250.0, maxHeight * .88).toDouble();

  const gap = 18.0;

  final hasSpaceOnRight = anchorLeft + gap + width <= imageRect.right - 8;

  final hasSpaceOnLeft = anchorLeft - gap - width >= imageRect.left + 8;

  late final double left;

  if (hasSpaceOnRight) {
    left = anchorLeft + gap;
  } else if (hasSpaceOnLeft) {
    left = anchorLeft - width - gap;
  } else {
    left = (anchorLeft - width / 2)
        .clamp(imageRect.left + 8, imageRect.right - width - 8)
        .toDouble();
  }

  final preferredTop = anchorTop - 34;

  final top = preferredTop
      .clamp(imageRect.top + 8, imageRect.bottom - height - 8)
      .toDouble();

  return Rect.fromLTWH(left, top, width, height);
}

// ============================================================
// FORMATTERS
// ============================================================

String clean(String? value) {
  return value?.trim() ?? '';
}

String fmtValue(num? value) {
  if (value == null) {
    return '-';
  }

  final number = value.toDouble();

  if (!number.isFinite) {
    return '-';
  }

  if (number == number.truncateToDouble()) {
    return number.toInt().toString();
  }

  return number.toStringAsFixed(2);
}

String formatTime(DateTime? time) {
  if (time == null) {
    return '-';
  }

  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')}';
}

String _categoryLabel(String? category) {
  final value = clean(category).toLowerCase();

  if (value.contains('water')) {
    return 'WATER';
  }

  if (value.contains('air') || value.contains('compressed')) {
    return 'COMPRESSED AIR';
  }

  if (value.contains('electric')) {
    return 'ELECTRICITY';
  }

  return clean(category).isEmpty ? 'UTILITY' : clean(category).toUpperCase();
}
