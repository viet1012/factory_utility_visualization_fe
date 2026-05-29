import 'package:flutter/material.dart';

import 'edit_toggle_button.dart';
import 'header_text.dart';

class TopHeader extends StatelessWidget {
  final String facId;
  final String lastText;
  final bool editMode;
  final VoidCallback onToggleEdit;

  const TopHeader({
    required this.facId,
    required this.lastText,
    required this.editMode,
    required this.onToggleEdit,
  });

  @override
  Widget build(BuildContext context) {
    final accent = editMode ? Colors.amberAccent : Colors.lightBlueAccent;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.factory_rounded, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: HeaderText(facId: facId, lastText: lastText),
          ),
          EditToggleButton(editMode: editMode, onTap: onToggleEdit),
        ],
      ),
    );
  }
}
