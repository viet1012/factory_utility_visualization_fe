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

  Rect get _rect => calculatePanelRect(
    imageRect: widget.imageRect,
    pos01: widget.pos01,
    rowCount: widget.rows.length,
  );

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
                    PanelHeader(boxId: widget.boxId, total: widget.rows.length),

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
          final row = widget.rows[index];

          return DataRowTile(row: row, isEven: index.isEven);
        },
      ),
    );
  }
}

class PanelStyle {
  static const panelBg = Color(0xF20B1324);
  static const headerBg = Color(0xFF13223A);
  static const accent = Color(0xFF38BDF8);

  static const double scadaW = 72;
  static const double plcW = 78;
  static const double valueW = 112;
  static const double timeW = 92;
  static const double gap = 12;

  static final radius = BorderRadius.circular(18);

  static final panelDecoration = BoxDecoration(
    color: panelBg,
    borderRadius: radius,
    border: Border.all(color: accent.withOpacity(0.36)),
    boxShadow: [
      const BoxShadow(
        color: Colors.black54,
        blurRadius: 24,
        offset: Offset(0, 12),
      ),
      BoxShadow(
        color: accent.withOpacity(0.16),
        blurRadius: 18,
        spreadRadius: 1,
      ),
    ],
  );
}

class TextStyles {
  ////////////////////////////////////////////////////////////
  /// HEADER
  ////////////////////////////////////////////////////////////
  static final header = TextStyle(
    color: Colors.white.withOpacity(0.74),
    fontWeight: FontWeight.w800,
    fontSize: 14.5,
    letterSpacing: 0.2,
  );

  ////////////////////////////////////////////////////////////
  /// CELL
  ////////////////////////////////////////////////////////////
  static final cell = TextStyle(
    color: Colors.white.withOpacity(0.90),
    fontWeight: FontWeight.w800,
    fontSize: 15.5,
    height: 1.0,
  );

  ////////////////////////////////////////////////////////////
  /// VALUE
  ////////////////////////////////////////////////////////////
  static const value = TextStyle(
    color: PanelStyle.accent,
    fontWeight: FontWeight.w900,
    fontSize: 16,
    letterSpacing: 0.3,
  );
}

class PanelHeader extends StatelessWidget {
  final String boxId;
  final int total;

  const PanelHeader({super.key, required this.boxId, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PanelStyle.headerBg,
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
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

class TableHeader extends StatelessWidget {
  const TableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: const Row(
        children: [
          SizedBox(width: PanelStyle.scadaW, child: HeaderText('SCADA')),

          SizedBox(width: PanelStyle.gap),

          Expanded(child: HeaderText('Name')),

          SizedBox(width: PanelStyle.gap),

          SizedBox(width: PanelStyle.plcW, child: HeaderText('PLC')),

          SizedBox(width: PanelStyle.gap),

          SizedBox(
            width: PanelStyle.valueW,
            child: HeaderText('Value', align: TextAlign.right),
          ),

          SizedBox(width: PanelStyle.gap),

          SizedBox(
            width: PanelStyle.timeW,
            child: HeaderText('Time', align: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class HeaderText extends StatelessWidget {
  final String text;
  final TextAlign align;

  const HeaderText(this.text, {super.key, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyles.header,
    );
  }
}

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
    final row = widget.row;

    final bg = _hovered
        ? PanelStyle.accent.withOpacity(0.13)
        : widget.isEven
        ? Colors.white.withOpacity(0.035)
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) {
        if (!_hovered) {
          setState(() => _hovered = true);
        }
      },
      onExit: (_) {
        if (_hovered) {
          setState(() => _hovered = false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        height: 39,
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _hovered
                ? PanelStyle.accent.withOpacity(0.20)
                : Colors.white.withOpacity(0.045),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: PanelStyle.scadaW,
              child: CellText(clean(row.scadaId), bold: true),
            ),

            const SizedBox(width: PanelStyle.gap),

            Expanded(
              child: Tooltip(
                message: clean(row.nameEn).isEmpty ? '-' : clean(row.nameEn),
                waitDuration: const Duration(milliseconds: 450),
                child: CellText(clean(row.nameEn)),
              ),
            ),

            const SizedBox(width: PanelStyle.gap),

            SizedBox(
              width: PanelStyle.plcW,
              child: CellText(row.plcAddress, bold: true),
            ),

            const SizedBox(width: PanelStyle.gap),
            SizedBox(
              width: PanelStyle.valueW,
              child: Align(
                alignment: Alignment.centerRight,
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: fmtValue(row.value),
                        style: TextStyles.value,
                      ),
                      TextSpan(
                        text: ' ${clean(row.unit)}',
                        style: TextStyles.value.copyWith(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.55),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: PanelStyle.gap),

            SizedBox(
              width: PanelStyle.timeW,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _timeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
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
  final bool bold;

  const CellText(this.value, {super.key, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final text = value.trim().isEmpty ? '-' : value.trim();

    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyles.cell.copyWith(
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
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

  final rowHeight = 44.0;
  final headerHeight = 92.0;
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

  return Rect.fromLTWH(left, top, width, height);
}

String clean(String? value) {
  return value?.trim() ?? '';
}

String fmtValue(double? value) {
  if (value == null) return '-';

  if (value % 1 == 0) {
    return value.toInt().toString();
  }

  return value.toStringAsFixed(2);
}

String formatTime(DateTime t) {
  return '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';
}
