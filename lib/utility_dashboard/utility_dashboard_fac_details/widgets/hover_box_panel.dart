import 'package:flutter/material.dart';

import '../../utility_dashboard_overview/'
    'utility_dashboard_overview_models/latest_tree_response.dart';
import 'hover_box_panel/hover_data_row_tile.dart';
import 'hover_box_panel/hover_panel_header.dart';
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
  State<HoverBoxPanel> createState() => _HoverBoxPanelState();
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
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _flowController.dispose();

    super.dispose();
  }

  Rect get _rect {
    return calculatePanelRect(
      imageRect: widget.imageRect,
      pos01: widget.pos01,
      rowCount: widget.rows.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: _rect.left,
      top: _rect.top,
      child: MouseRegion(
        onEnter: (_) => widget.onEnterPanel(),
        onExit: (_) => widget.onExitPanel(),
        child: Material(
          color: Colors.transparent,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Container(
              width: _rect.width,
              constraints: BoxConstraints(maxHeight: _rect.height),
              decoration: PanelStyle.panelDecoration,
              child: ClipRRect(
                borderRadius: PanelStyle.radius,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PanelHeader(
                      boxId: widget.boxId,
                      total: widget.rows.length,
                      category: widget.category,
                      flowController: _flowController,
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(10, 10, 10, 6),
                      child: TableHeader(),
                    ),
                    Flexible(child: _buildList()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      radius: const Radius.circular(999),
      child: ListView.builder(
        controller: _scrollController,
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        itemCount: widget.rows.length,
        itemBuilder: (context, index) {
          final signal = widget.rows[index];

          return DataRowTile(
            signal: signal,
            scadaId: widget.scadaId,
            isEven: index.isEven,
          );
        },
      ),
    );
  }
}

Rect calculatePanelRect({
  required Rect imageRect,
  required Offset pos01,
  int rowCount = 0,
}) {
  final anchorLeft = imageRect.left + pos01.dx * imageRect.width;

  final anchorTop = imageRect.top + pos01.dy * imageRect.height;

  final width = (imageRect.width * 0.68).clamp(700.0, 980.0).toDouble();

  const rowHeight = 44.0;
  const headerHeight = 120.0;

  final contentHeight = headerHeight + rowCount * rowHeight;

  final height = contentHeight.clamp(220.0, imageRect.height * 0.82).toDouble();

  final preferRight = anchorLeft + 26 + width < imageRect.right;

  final left = preferRight
      ? anchorLeft + 26
      : (anchorLeft - width - 26).clamp(
          imageRect.left + 8,
          imageRect.right - width - 8,
        );

  final top = anchorTop.clamp(imageRect.top + 8, imageRect.bottom - height - 8);

  return Rect.fromLTWH(left.toDouble(), top.toDouble(), width, height);
}

String clean(String? value) {
  return value?.trim() ?? '';
}

String fmtValue(num? value) {
  if (value == null) {
    return '-';
  }

  final number = value.toDouble();

  if (number % 1 == 0) {
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
