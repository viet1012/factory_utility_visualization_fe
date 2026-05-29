import 'package:flutter/material.dart';

class EditToggleButton extends StatelessWidget {
  final bool editMode;
  final VoidCallback onTap;

  const EditToggleButton({required this.editMode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = editMode ? Colors.amberAccent : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: editMode
              ? Colors.amber.withOpacity(0.16)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: editMode
                ? Colors.amberAccent
                : Colors.white.withOpacity(0.14),
          ),
        ),
        child: Row(
          children: [
            Icon(
              editMode ? Icons.edit_off_rounded : Icons.edit_rounded,
              size: 17,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              editMode ? 'Editing' : 'Edit',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
