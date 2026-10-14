import 'package:flutter/material.dart';

enum AppActionType { edit }

class AppActionButton extends StatelessWidget {
  final AppActionType type;
  final VoidCallback? onPressed;
  final bool compact;
  final bool outlined;
  final String? text;
  final IconData? icon;

  const AppActionButton({
    super.key,
    required this.type,
    required this.onPressed,
    this.compact = false,
    this.outlined = true,
    this.text,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(type);

    final foreground = config.color;
    final label = text ?? config.label;
    final actionIcon = icon ?? config.icon;

    final style = outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: foreground,
            side: BorderSide(color: foreground.withValues(alpha: 0.35)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(compact ? 10 : 12),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: compact ? 8 : 11,
            ),
          )
        : FilledButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: foreground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(compact ? 10 : 12),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: compact ? 8 : 11,
            ),
          );

    return outlined
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(actionIcon, size: compact ? 16 : 18),
            label: Text(
              label,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: style,
          )
        : FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(actionIcon, size: compact ? 16 : 18),
            label: Text(
              label,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: style,
          );
  }

  _ActionConfig _getConfig(AppActionType type) {
    switch (type) {
      case AppActionType.edit:
        return const _ActionConfig(
          label: 'Edit',
          icon: Icons.edit_outlined,
          color: Colors.white,
        );
    }
  }
}

class _ActionConfig {
  final String label;
  final IconData icon;
  final Color color;

  const _ActionConfig({
    required this.label,
    required this.icon,
    required this.color,
  });
}
