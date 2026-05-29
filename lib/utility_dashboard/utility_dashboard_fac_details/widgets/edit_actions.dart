import 'package:flutter/material.dart';

import '../models/group_frame_types.dart';
import 'app_bar_icon_button.dart';

class EditActions extends StatelessWidget {
  final ArrowDirection selectedDirection;
  final VoidCallback onPickColor;
  final ValueChanged<ArrowDirection> onChangeDirection;

  const EditActions({
    required this.selectedDirection,
    required this.onPickColor,
    required this.onChangeDirection,
  });

  static const _buttons = [
    (Icons.arrow_left, ArrowDirection.left),
    (Icons.keyboard_arrow_up, ArrowDirection.up),
    (Icons.keyboard_arrow_down, ArrowDirection.down),
    (Icons.arrow_right, ArrowDirection.right),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBarIconButton(
          icon: Icons.palette,
          selected: false,
          onTap: onPickColor,
        ),
        const SizedBox(width: 6),
        for (final button in _buttons)
          AppBarIconButton(
            icon: button.$1,
            selected: selectedDirection == button.$2,
            onTap: () => onChangeDirection(button.$2),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}
