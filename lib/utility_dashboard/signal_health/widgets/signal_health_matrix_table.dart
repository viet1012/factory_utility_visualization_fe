import 'package:flutter/material.dart';

import '../signal_health_style.dart';
import 'signal_health_common_widgets.dart';

class SignalHealthMatrixTable extends StatefulWidget {
  final List<dynamic> data;
  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const SignalHealthMatrixTable({
    super.key,
    required this.data,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<SignalHealthMatrixTable> createState() =>
      _SignalHealthMatrixTableState();
}

class _SignalHealthMatrixTableState extends State<SignalHealthMatrixTable> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardDecoration(),
      child: Column(
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: kCard2,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Row(
              children: [
                _HeaderCell('Facility', flex: 1),
                _HeaderCell('Category', flex: 1),
                _HeaderCell('SCADA', flex: 1),
                _HeaderCell('Box Device ID', flex: 3),
                _HeaderCell('Total', flex: 1, center: true),
                _HeaderCell('NG', flex: 1, center: true),
                _HeaderCell('Status', flex: 1, center: true),
                SizedBox(width: 44),
              ],
            ),
          ),

          Expanded(
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbColor: WidgetStatePropertyAll(Color(0xff00E5FF)),
                trackColor: WidgetStatePropertyAll(Color(0xff1e293b)),
                trackBorderColor: WidgetStatePropertyAll(Color(0xff38bdf8)),
                radius: Radius.circular(10),
              ),
              child: Scrollbar(
                controller: _controller,
                thumbVisibility: true,
                trackVisibility: true,
                interactive: true,
                radius: const Radius.circular(12),
                thickness: 10,

                child: ListView.separated(
                  controller: _controller,
                  padding: const EdgeInsets.all(8),
                  itemCount: widget.data.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final row = widget.data[index] as Map<String, dynamic>;
                    final isSelected = identical(row, widget.selected);
                    final isNg = row['status'] == 'NG';

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => widget.onSelect(row),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          // Selection (cyan) and severity (NG tint) are kept in
                          // separate channels: only selection draws a strong
                          // border, so the two states never stack.
                          color: isSelected
                              ? kBlue.withValues(alpha: .12)
                              : isNg
                              ? kOrange.withValues(alpha: .05)
                              : kCard,
                          border: Border.all(
                            color: isSelected
                                ? kBlue
                                : kBorder.withValues(alpha: .55),
                            width: isSelected ? 1.4 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _BodyCell('${row['fac']}', flex: 1, muted: true),
                            _BodyCell(
                              '${row['cate']}',
                              flex: 1,
                              child: _CategoryBadge('${row['cate']}'),
                            ),
                            _BodyCell(
                              '${row['scadaId']}',
                              flex: 1,
                              child: _SoftBadge('${row['scadaId']}'),
                            ),
                            _BodyCell(
                              '${row['boxDeviceId']}',
                              flex: 3,
                              bold: true,
                            ),
                            _BodyCell(
                              '${row['totalRegisters']}',
                              flex: 1,
                              center: true,
                              child: _RegisterNumber(
                                '${row['totalRegisters']}',
                                color: kSubText,
                              ),
                            ),
                            _BodyCell(
                              '${row['ngRegisters']}',
                              flex: 1,
                              center: true,
                              child: _RegisterNumber(
                                '${row['ngRegisters']}',
                                // Red only when there is actually something
                                // wrong; a zero count stays quiet.
                                color:
                                    (num.tryParse('${row['ngRegisters']}') ??
                                            0) >
                                        0
                                    ? kRed
                                    : kSubText.withValues(alpha: .7),
                              ),
                            ),
                            _BodyCell(
                              '${row['status']}',
                              flex: 1,
                              center: true,
                              child: StatusBadge('${row['status']}'),
                            ),
                            SizedBox(
                              width: 44,
                              child: Icon(
                                Icons.chevron_right,
                                color: isSelected
                                    ? const Color(0xff2563eb)
                                    : const Color(0xff94a3b8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: kBorder)),
            ),
            child: Row(
              children: [
                Text(
                  'Showing ${widget.data.length} records',
                  style: const TextStyle(
                    color: Color(0xff64748b),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Click a row to view details',
                  style: TextStyle(color: Color(0xff94a3b8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool center;

  const _HeaderCell(this.text, {required this.flex, this.center = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: center ? Alignment.center : Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            color: kSubText.withValues(alpha: .75),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: .3,
          ),
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool center;
  final bool bold;

  /// Secondary columns (Facility/Category/SCADA) sit a step below the
  /// Box Device ID so the identity column reads first.
  final bool muted;
  final Widget? child;

  const _BodyCell(
    this.text, {
    required this.flex,
    this.center = false,
    this.bold = false,
    this.muted = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: center ? Alignment.center : Alignment.centerLeft,
        child:
            child ??
            Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: muted ? kSubText : kText,
                fontSize: bold ? 14 : 13,
                fontWeight: bold
                    ? FontWeight.w800
                    : muted
                    ? FontWeight.w500
                    : FontWeight.w600,
              ),
            ),
      ),
    );
  }
}

class _RegisterNumber extends StatelessWidget {
  final String value;
  final Color color;

  const _RegisterNumber(this.value, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String text;

  const _CategoryBadge(this.text);

  @override
  Widget build(BuildContext context) {
    final isElectric = text.toLowerCase().contains('electric');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isElectric ? const Color(0xfffff7ed) : const Color(0xffeff6ff),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isElectric ? const Color(0xffea580c) : const Color(0xff2563eb),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  final String text;

  const _SoftBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xfff1f5f9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xff334155),
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }
}
