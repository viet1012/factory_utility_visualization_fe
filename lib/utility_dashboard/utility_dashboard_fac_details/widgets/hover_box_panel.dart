import 'package:flutter/material.dart';

import '../../../utility_models/response/latest_record.dart';

class HoverBoxPanel extends StatefulWidget {
  final String boxId;
  final Rect imageRect;
  final Offset pos01;
  final List<LatestRecordDto> rows;
  final VoidCallback onEnterPanel;
  final VoidCallback onExitPanel;

  const HoverBoxPanel({
    super.key,
    required this.boxId,
    required this.imageRect,
    required this.pos01,
    required this.rows,
    required this.onEnterPanel,
    required this.onExitPanel,
  });

  @override
  State<HoverBoxPanel> createState() => _HoverBoxPanelState();
}

class _HoverBoxPanelState extends State<HoverBoxPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Rect get _rect =>
      calculatePanelRect(imageRect: widget.imageRect, pos01: widget.pos01);

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: _rect.left,
      top: _rect.top,
      child: MouseRegion(
        onEnter: (_) => widget.onEnterPanel(),
        onExit: (_) => widget.onExitPanel(),
        child: Material(
          color: Colors.transparent,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Container(
              width: _rect.width,
              constraints: BoxConstraints(
                maxHeight: widget.imageRect.height * 0.85,
              ),
              decoration: PanelStyle.panelDecoration,
              child: ClipRRect(
                borderRadius: PanelStyle.radius,
                child: Column(
                  mainAxisSize: MainAxisSize.min, // 👈 QUAN TRỌNG
                  children: [
                    PanelHeader(boxId: widget.boxId, total: widget.rows.length),

                    ////////////////////////////////////////////////////
                    /// LIST (AUTO RESIZE)
                    ////////////////////////////////////////////////////
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

  ////////////////////////////////////////////////////////////
  /// LIST
  ////////////////////////////////////////////////////////////
  Widget _buildList() {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        shrinkWrap: true,
        // 👈 QUAN TRỌNG
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        itemCount: widget.rows.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Column(children: [TableHeader(), SizedBox(height: 6)]);
          }

          final row = widget.rows[index - 1];
          return DataRowTile(row: row, isEven: (index - 1).isEven);
        },
      ),
    );
  }
}

////////////////////////////////////////////////////////////////
/// STYLE
////////////////////////////////////////////////////////////////

class PanelStyle {
  static const panelBg = Color(0xF20B1324);
  static const headerBg = Color(0xFF13223A);
  static const accent = Color(0xFF38BDF8);

  static final radius = BorderRadius.circular(18);

  static final panelDecoration = BoxDecoration(
    color: panelBg,
    borderRadius: radius,
    border: Border.all(color: accent.withOpacity(0.35)),
    boxShadow: [
      BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 12)),
      BoxShadow(
        color: accent.withOpacity(0.16),
        blurRadius: 18,
        spreadRadius: 1,
      ),
    ],
  );
}

class TextStyles {
  static final header = TextStyle(
    color: Colors.white.withOpacity(0.78),
    fontWeight: FontWeight.w800,
    fontSize: 15,
  );

  static final cell = TextStyle(
    color: Colors.white.withOpacity(0.84),
    fontWeight: FontWeight.w600,
    fontSize: 15,
  );

  static const value = TextStyle(
    color: PanelStyle.accent,
    fontWeight: FontWeight.w900,
    fontSize: 15,
  );
}

////////////////////////////////////////////////////////////////
/// HEADER
////////////////////////////////////////////////////////////////

class PanelHeader extends StatelessWidget {
  final String boxId;
  final int total;

  const PanelHeader({super.key, required this.boxId, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PanelStyle.headerBg,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          const Icon(
            Icons.view_in_ar_rounded,
            color: PanelStyle.accent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Box $boxId',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: PanelStyle.accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: PanelStyle.accent.withOpacity(0.38)),
            ),
            child: Text(
              '$total items',
              style: const TextStyle(
                color: PanelStyle.accent,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////////
/// TABLE HEADER
////////////////////////////////////////////////////////////////

class TableHeader extends StatelessWidget {
  const TableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 18, child: HeaderText('SCADA')),
          Expanded(flex: 20, child: HeaderText('PLC')),
          Expanded(
            flex: 10,
            child: Align(
              alignment: Alignment.centerRight,
              child: HeaderText('Value'),
            ),
          ),
          Expanded(
            flex: 13,
            child: Align(
              alignment: Alignment.centerRight,
              child: HeaderText('Time'),
            ),
          ),
        ],
      ),
    );
  }
}

class HeaderText extends StatelessWidget {
  final String text;

  const HeaderText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyles.header);
  }
}

////////////////////////////////////////////////////////////////
/// DATA ROW
////////////////////////////////////////////////////////////////

class DataRowTile extends StatefulWidget {
  final LatestRecordDto row;
  final bool isEven;

  const DataRowTile({super.key, required this.row, required this.isEven});

  @override
  State<DataRowTile> createState() => _DataRowTileState();
}

class _DataRowTileState extends State<DataRowTile> {
  bool _hovered = false;

  String get _timeText => formatTime(widget.row.recordedAt);

  @override
  Widget build(BuildContext context) {
    final bg = _hovered
        ? PanelStyle.accent.withOpacity(0.13)
        : widget.isEven
        ? Colors.white.withOpacity(0.035)
        : Colors.transparent;

    final valueText = widget.row.value?.toStringAsFixed(2) ?? '-';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _hovered
                ? PanelStyle.accent.withOpacity(0.18)
                : Colors.white.withOpacity(0.04),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 18,
              child: CellText((widget.row.scadaId ?? '').trim()),
            ),
            Expanded(flex: 20, child: CellText(widget.row.plcAddress)),
            Expanded(
              flex: 10,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(valueText, style: TextStyles.value),
              ),
            ),
            Expanded(
              flex: 13,
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: Colors.white.withOpacity(0.52),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _timeText,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.76),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CellText extends StatelessWidget {
  final String value;

  const CellText(this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      value.isEmpty ? '-' : value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyles.cell,
    );
  }
}

////////////////////////////////////////////////////////////////
/// HELPERS
////////////////////////////////////////////////////////////////

Rect calculatePanelRect({required Rect imageRect, required Offset pos01}) {
  final anchorLeft = imageRect.left + pos01.dx * imageRect.width;
  final anchorTop = imageRect.top + pos01.dy * imageRect.height;

  final width = (imageRect.width * 0.46).clamp(380.0, 720.0).toDouble();
  final height = (imageRect.height * 0.62).clamp(280.0, 500.0).toDouble();

  final preferRight = anchorLeft + 28 + width < imageRect.right;

  final left = preferRight
      ? anchorLeft + 28
      : (anchorLeft - width - 28).clamp(
          imageRect.left + 8,
          imageRect.right - width - 8,
        );

  final top = anchorTop.clamp(imageRect.top + 8, imageRect.bottom - height - 8);

  return Rect.fromLTWH(left, top, width, height);
}

String formatTime(DateTime t) {
  return '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';
}
