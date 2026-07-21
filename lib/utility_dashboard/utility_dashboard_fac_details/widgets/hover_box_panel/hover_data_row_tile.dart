import 'package:flutter/material.dart';

import '../../../utility_dashboard_overview/'
    'utility_dashboard_overview_models/latest_tree_response.dart';
import '../hover_box_panel.dart';
import 'hover_panel_style.dart';

class DataRowTile extends StatefulWidget {
  final LatestSignalDto signal;
  final String scadaId;
  final bool isEven;

  const DataRowTile({
    super.key,
    required this.signal,
    required this.scadaId,
    required this.isEven,
  });

  @override
  State<DataRowTile> createState() => _DataRowTileState();
}

class _DataRowTileState extends State<DataRowTile> {
  bool _hovered = false;

  LatestSignalDto get signal => widget.signal;

  String get _nameText {
    final nameEn = clean(signal.nameEn);

    if (nameEn.isNotEmpty) {
      return nameEn;
    }

    final plcAddress = clean(signal.plcAddress);

    return plcAddress.isNotEmpty ? plcAddress : '-';
  }

  String get _timeText {
    final recordedAt = signal.recordedAt;

    if (recordedAt == null) {
      return '-';
    }

    if (recordedAt is DateTime) {
      return formatTime(recordedAt);
    }

    final parsed = DateTime.tryParse(recordedAt.toString());

    return parsed == null ? '-' : formatTime(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _hovered
        ? PanelStyle.accent.withOpacity(0.13)
        : widget.isEven
        ? Colors.white.withOpacity(0.035)
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) {
        if (_hovered) return;

        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        if (!_hovered) return;

        setState(() {
          _hovered = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        height: 39,
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
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
              child: CellText(widget.scadaId, bold: true),
            ),
            const SizedBox(width: PanelStyle.gap),

            Expanded(
              child: Tooltip(
                message: _nameText,
                waitDuration: const Duration(milliseconds: 450),
                child: CellText(_nameText),
              ),
            ),
            const SizedBox(width: PanelStyle.gap),

            SizedBox(
              width: PanelStyle.plcW,
              child: CellText(clean(signal.plcAddress), bold: true),
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
                        text: fmtValue(signal.value),
                        style: TextStyles.value,
                      ),
                      TextSpan(
                        text: _unitText,
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

  String get _unitText {
    final unit = clean(signal.unit);

    return unit.isEmpty ? '' : ' $unit';
  }
}

class CellText extends StatelessWidget {
  final String value;
  final bool bold;

  const CellText(this.value, {super.key, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final displayText = value.trim().isEmpty ? '-' : value.trim();

    return Text(
      displayText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyles.cell.copyWith(
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }
}
