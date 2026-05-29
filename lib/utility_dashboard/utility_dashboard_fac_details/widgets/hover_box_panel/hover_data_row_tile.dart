import 'package:flutter/material.dart';

import '../../../../utility_models/response/latest_record.dart';
import '../hover_box_panel.dart';
import 'hover_panel_style.dart';

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
