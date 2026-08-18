import 'package:flutter/material.dart';

import '../../utility_dashboard_common/chart_theme.dart';
import '../models/group_frame_types.dart';
import 'edit_actions.dart';
import 'edit_toggle_button.dart';
import 'header_text.dart';

class TopHeader extends StatelessWidget {
  // ============================================================
  // HEADER
  // ============================================================

  final String facId;
  final String lastText;

  // ============================================================
  // EDIT
  // ============================================================

  final bool editMode;
  final VoidCallback onToggleEdit;

  final ArrowDirection selectedDirection;

  final VoidCallback onPickColor;

  final ValueChanged<ArrowDirection> onChangeDirection;

  // ============================================================
  // UTILITY
  // ============================================================

  final String utilityType;

  final ValueChanged<String> onUtilityChanged;

  const TopHeader({
    super.key,

    required this.facId,
    required this.lastText,

    required this.editMode,
    required this.onToggleEdit,

    required this.selectedDirection,
    required this.onPickColor,
    required this.onChangeDirection,

    required this.utilityType,
    required this.onUtilityChanged,
  });

  // ============================================================
  // TYPES
  // ============================================================

  static const String electricity = 'ELECTRICITY';

  static const String water = 'WATER';

  static const String air = 'AIR';

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final accent = editMode ? Colors.amberAccent : Colors.lightBlueAccent;

    return Container(
      height: 50,

      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: accent.withOpacity(.22)),
      ),

      child: Row(
        children: [
          // ====================================================
          // FACTORY
          // ====================================================
          Icon(Icons.factory_rounded, color: accent, size: 22),

          const SizedBox(width: 10),

          // ====================================================
          // FAC + LAST UPDATE
          // ====================================================
          Expanded(
            child: HeaderText(facId: facId, lastText: lastText),
          ),

          // ====================================================
          // UTILITY SELECTOR
          // ====================================================
          _UtilityButton(
            type: electricity,
            selectedType: utilityType,
            onTap: onUtilityChanged,
          ),

          const SizedBox(width: 6),

          _UtilityButton(
            type: water,
            selectedType: utilityType,
            onTap: onUtilityChanged,
          ),

          const SizedBox(width: 6),

          _UtilityButton(
            type: air,
            selectedType: utilityType,
            onTap: onUtilityChanged,
          ),

          // ====================================================
          // EDIT ACTIONS
          // ====================================================
          if (editMode) ...[
            const SizedBox(width: 12),

            Container(
              width: 1,
              height: 26,
              color: Colors.white.withOpacity(.10),
            ),

            const SizedBox(width: 8),

            EditActions(
              selectedDirection: selectedDirection,

              onPickColor: onPickColor,

              onChangeDirection: onChangeDirection,
            ),
          ],

          // ====================================================
          // EDIT TOGGLE
          // ====================================================
          const SizedBox(width: 8),

          EditToggleButton(editMode: editMode, onTap: onToggleEdit),
        ],
      ),
    );
  }
}

// ============================================================
// UTILITY BUTTON
// ============================================================

class _UtilityButton extends StatelessWidget {
  final String type;

  final String selectedType;

  final ValueChanged<String> onTap;

  const _UtilityButton({
    required this.type,
    required this.selectedType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = selectedType == type;

    final theme = ChartThemes.byCate(type);

    return Tooltip(
      message: '${theme.title} (${theme.unit})',

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius: BorderRadius.circular(8),

          onTap: () {
            if (!selected) {
              onTap(type);
            }
          },

          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),

            height: 34,

            padding: const EdgeInsets.symmetric(horizontal: 10),

            decoration: BoxDecoration(
              color: selected
                  ? theme.line.withOpacity(.15)
                  : Colors.white.withOpacity(.025),

              borderRadius: BorderRadius.circular(8),

              border: Border.all(
                color: selected
                    ? theme.line.withOpacity(.85)
                    : Colors.white.withOpacity(.10),
              ),
            ),

            child: Row(
              mainAxisSize: MainAxisSize.min,

              children: [
                Icon(
                  theme.icon,

                  size: 16,

                  color: selected ? theme.iconColor : Colors.white54,
                ),

                const SizedBox(width: 5),

                Text(
                  theme.title,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white60,

                    fontSize: 10.5,

                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
