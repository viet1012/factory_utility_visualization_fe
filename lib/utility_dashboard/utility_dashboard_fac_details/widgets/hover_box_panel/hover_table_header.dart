import 'package:flutter/material.dart';

import 'hover_panel_style.dart';

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
